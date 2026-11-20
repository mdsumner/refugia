#!/usr/bin/env bash
## Fetch Antarctic region layers from the AADC data server (data.aad.gov.au)
## and write them as GeoParquet and GeoPackage.
##
## data.aad.gov.au is not reachable from the cloud sessions, but it is from
## Gadi (login node or copyq). Run inside the GDAL container (GDAL >= 3.11
## for the `gdal vector` CLI), for example
##
##   singularity exec $SIF bash gadi/aad_layers.sh /g/data/jk72/$USER/refugia/aad
##
## then bring the output folder back (rsync to Nectar, Acacia, or upload the
## files to the project). Files are read directly over HTTP with /vsicurl/;
## for a shapefile GDAL finds the .dbf/.shx/.prj siblings by swapping the
## extension at the end of the URL, which works with the EDS download?prefix=
## form (checked by Michael on Gadi, 2026-11-20: ACBR layer opens, 24,464
## polygons, WGS 84 south polar stereographic).
##
## Source dataset: AADC EDS dataset 6825D031-0752-4F8E-82E4-F4DC3A88C6D6,
## shapefiles from Terauds et al. 2012 (Diversity and Distributions), which
## defined ACBR version 1 (15 regions). ACBR version 2 (Terauds and Lee 2016,
## 16 regions: adds the Prince Charles Mountains as region 16) is the current one
## and should replace v1 once its EDS address is found (see ACBR_V2 below).

set -euo pipefail
OUT=${1:-aad}
mkdir -p "$OUT"
EDS=https://data.aad.gov.au/eds/api/dataset
T12=$EDS/6825D031-0752-4F8E-82E4-F4DC3A88C6D6/object/download?prefix=
## path inside the Terauds 2012 dataset, URL-encoded (space %20, slash %2F)
P12="Shapefiles%20from%20Terauds%20et%20al%202012%20DDI"

convert () {  # convert <src> <name>
  local src=$1 name=$2
  gdal vector info --summary "$src" || { echo "cannot open $src"; return 1; }
  gdal vector convert --overwrite "$src" "$OUT/$name.parquet"
  gdal vector convert --overwrite "$src" "$OUT/$name.gpkg"
  ls -l "$OUT/$name".*
}

## 1. ACBR v1 (Terauds et al. 2012): ice-free polygons labelled by region
convert "/vsicurl/${T12}${P12}%2FACBRs%2FACBRs%20for%20export.shp" acbr_v1_terauds2012

## 2. ASPA / ASMA (October 2011 snapshot in the same dataset). Only single
##    objects can be fetched: a folder prefix returns NoSuchKey (checked
##    2026-11-20), so file names inside ERA_ASPA_ASMA_Oct2011 must come from
##    the AADC metadata page. The objects sit in the AADC S3 store under
##    aadc-datasets/ASAC_3095_Antarctic_Biogeography_shapefiles/. Confirmed:
FOLDER="${T12}${P12}%2FASPAs%2FERA_ASPA_ASMA_Oct2011"
convert "/vsicurl/${FOLDER}%2FASMA_points_Aug2011.shp" asma_points_2011 || true
##    ASPA polygons: add the file name when known, for example
##    convert "/vsicurl/${FOLDER}%2F<ASPA polygons>.shp" aspa_polygons_2011

## 3. ACBR v2 (Terauds and Lee 2016) and the ice-free layer (Toth and Terauds
##    2023, https://doi.org/10.26179/7mnh-j215): fill in the EDS dataset id
##    and file path from the AADC metadata pages, then
## ACBR_V2="/vsicurl/$EDS/<dataset-id>/object/download?prefix=<path-to>.shp"
## convert "$ACBR_V2" acbr_v2_terauds_lee2016
## The ice-free layer is a 100 m GeoTIFF; keep it as a COG instead:
## gdal raster convert --of COG "/vsicurl/$EDS/<dataset-id>/object/download?prefix=<path-to>.tif" "$OUT/icefree_toth_terauds2023.tif"

ls -l "$OUT"
