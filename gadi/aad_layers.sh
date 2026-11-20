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

## 3. ACBR v2 (Terauds 2016): AADC record
##    AAS_4296_Antarctic_Conservation_Biogeographic_Regions_v2. Michael
##    downloaded the zip by hand (ACBRs_v2_2016.shp, field ACBR_Name); add
##    its EDS URL here when known.

## 4. Antarctic Ecosystem Inventory (Toth et al. 2024), EDS dataset
##    cb8c6d56-8a78-4032-a455-cb58cb4bb6de, prefix AADC_4568_2024/. Rasters
##    are 100 m GeoTIFFs; they are rewritten as COGs (nearest-neighbour
##    overviews for the class rasters, average for continuous ones). The
##    Tier 1 URLs are confirmed (Michael, 2026-11-20); the others follow the
##    folder and file names in the AADC record description and may need
##    correcting (a wrong name fails with NoSuchKey and the script goes on).
AEI=$EDS/cb8c6d56-8a78-4032-a455-cb58cb4bb6de/object/download?prefix=AADC_4568_2024
T1="TIER%201%20Major%20Environmental%20Units"
cog () {  # cog <url> <name> <resampling>
  local src=$1 name=$2 rs=${3:-nearest}
  gdal raster info "$src" > /dev/null 2>&1 || { echo "cannot open $src"; return 1; }
  gdal raster convert --overwrite --of COG --co COMPRESS=DEFLATE --co OVERVIEW_RESAMPLING=$rs \
    "$src" "$OUT/$name.tif"
  ls -l "$OUT/$name.tif"
}
## the class table travels beside the COG as <name>.vat.dbf
cog "/vsicurl/${AEI}%2F${T1}%2FTier1_MEUs.tif" aei_tier1_meu nearest || true
curl -sSL -o "$OUT/aei_tier1_meu.vat.dbf" "${AEI}%2F${T1}%2FTier1_MEUs.tif.vat.dbf" || true
cog "/vsicurl/${AEI}%2F${T1}%2FConf1.tif" aei_tier1_confidence average || true
## abiotic variables (2014-15 climate fields at 100 m)
for v in MeanTemp_1415_bm Total_DD_1415_minus5_bm elevation_bm; do
  cog "/vsicurl/${AEI}%2F${T1}%2FAbiotic%20Variables%2F${v}.tif" "aei_${v}" average || true
done
## Tier 2 (31 habitat complexes) and Tier 3 (309 regional ecosystems): fill
## in the folder and file names from the record (or the EDS listing), e.g.
## cog "/vsicurl/${AEI}%2F<TIER 2 folder>%2F<file>.tif" aei_tier2_habitat nearest
## curl -sSL -o "$OUT/aei_tier2_habitat.vat.dbf" "${AEI}%2F<TIER 2 folder>%2F<file>.tif.vat.dbf"
## cog "/vsicurl/${AEI}%2F<TIER 3 folder>%2F<file>.tif" aei_tier3_ecosystem nearest

ls -l "$OUT"
