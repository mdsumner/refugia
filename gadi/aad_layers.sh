#!/usr/bin/env bash
## Fetch Antarctic region layers from the AADC data server (data.aad.gov.au)
## and write them as GeoParquet and GeoPackage.
##
## data.aad.gov.au is not reachable from the cloud sessions, but it is from
## Gadi (login node or copyq). Run inside the GDAL container (GDAL >= 3.11
## for the `gdal vector` CLI), for example
##
##   module load singularity
##   SIF=${SIF:-/g/data/jk72/$USER/sif_lib/gdal-r-python-extras_latest.sif}
##   singularity exec -B /g/data "$SIF" bash gadi/aad_layers.sh /g/data/jk72/$USER/refugia/aad
##
## (the same image and default as gadi/agcd_sums.pbs and gadi/ice_sums.pbs)
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

## 3. ACBR v2 (Terauds 2016): AADC record
##    AAS_4296_Antarctic_Conservation_Biogeographic_Regions_v2. Michael
##    downloaded the zip by hand (ACBRs_v2_2016.shp, field ACBR_Name); add
##    its EDS URL here when known.

## 4. Antarctic Ecosystem Inventory (Toth et al. 2024), EDS dataset
##    cb8c6d56-8a78-4032-a455-cb58cb4bb6de, prefix AADC_4568_2024/. Rasters
##    are 100 m GeoTIFFs; they are rewritten as COGs (nearest-neighbour
##    overviews for the class rasters, average for continuous ones). The
##    URLs below were all confirmed by Michael (2026-11-20). A missing object
##    prints "cannot open" and the script goes on.
AEI=$EDS/cb8c6d56-8a78-4032-a455-cb58cb4bb6de/object/download?prefix=AADC_4568_2024
T1="TIER%201%20Major%20Environmental%20Units"
cog () {  # cog <url> <name> <resampling>
  local src=$1 name=$2 rs=${3:-nearest}
  gdal raster info "$src" > /dev/null 2>&1 || { echo "cannot open $src"; return 1; }
  gdal raster convert --overwrite --of COG --co COMPRESS=DEFLATE --co OVERVIEW_RESAMPLING=$rs \
    "$src" "$OUT/$name.tif"
  ls -l "$OUT/$name.tif"
}
T2="TIER%202%20Habitat%20Complexes"
T3="TIER%203%20Bioregional%20ecosystem%20types"
AB="${T1}%2FAbiotic%20predictors"
## class rasters, each with its value attribute table as <name>.vat.dbf
cls () {  # cls <folder> <file stem> <name>
  cog "/vsicurl/${AEI}%2F$1%2F$2.tif" "$3" nearest || return 0
  curl -sSL -o "$OUT/$3.tif.vat.dbf" "${AEI}%2F$1%2F$2.tif.vat.dbf" || true
}
cls "$T1" Tier1_MEUs aei_tier1_meu
cls "$T2" Tier2_HCs aei_tier2_habitat
cls "$T3" Tier3_BETs_int aei_tier3_ecosystem
## continuous: 2014-15 mean temperature and degree days above -5 deg C (100 m)
for v in MeanTemp_1415_bm Total_DD_1415_minus5_bm; do
  cog "/vsicurl/${AEI}%2F${AB}%2F${v}.tif" "aei_${v}" average || true
done

ls -l "$OUT"
