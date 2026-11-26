#!/bin/bash
## Check everything gadi/ffdi.pbs needs, from a login node. ls and imports only.
##
##   bash gadi/ffdi_probe.sh
##
## Prints: project memberships; BARRA-C2 version folders and first/last monthly files for the
## three inputs and the land fraction (fx/sftlf); AGCD precip and tmax first/last years; and
## which python (NCI xp65 analysis3, or the GDAL container) imports xclim, xarray, netCDF4, scipy;
## whether R in the container loads terra, s2 and the refugia functions; and a verdict per stage.
set -u
cd "$(dirname "$0")/.."   # repo root, as ffdi.pbs runs
AGCD_DIR=${AGCD_DIR:-/g/data/zv2/agcd/v1-0-4}
BARRA_DIR=${BARRA_DIR:-/g/data/ob53/BARRA2/output/reanalysis/AUST-04/BOM/ERA5/historical/hres/BARRA-C2/v1}
SIF=${SIF:-/g/data/jk72/$USER/sif_lib/gdal-r-python-extras_latest.sif}
echo "# ffdi probe $(date -Is) $(hostname) ${USER:-?}"
echo "## projects: $(id -nG | tr ' ' '\n' | grep -E '^(gv90|jk72|zv2|ob53|xp65)$' | tr '\n' ' ')(need gv90 jk72 zv2 ob53, and xp65 for PYENV=xp65)"
for leaf in day/tasmax day/sfcWindmax 1hr/hurs fx/sftlf; do
  d="$BARRA_DIR/$leaf"
  if [ -d "$d" ]; then
    v=$(ls -d "$d"/v* 2>/dev/null | tail -1)
    first=$(ls "$v" | head -1); last=$(ls "$v" | tail -1)
    span="$(echo "$first" | grep -oE '[0-9]{6}-' | tr -d -) .. $(echo "$last" | grep -oE '[0-9]{6}-' | tr -d -)"
    [ "$span" = " .. " ] && span=$first   # fx files carry no dates
    printf '## BARRA-C2 %-15s %s: %s files, %s\n' "$leaf" "$(basename "$v")" "$(ls "$v" | wc -l)" "$span"
  else
    echo "## BARRA-C2 $leaf: not visible at $d (join ob53, and check the path)"
  fi
done
for p in precip/total tmax/mean; do
  d="$AGCD_DIR/$p/r005/01day"
  [ -d "$d" ] && echo "## AGCD $p: $(ls "$d" | head -1) .. $(ls "$d" | tail -1)" || echo "## AGCD $p: not visible at $d"
done
check='import xclim, xarray, netCDF4, scipy; print("xclim", xclim.__version__, "xarray", xarray.__version__, "netCDF4", netCDF4.__version__, "scipy", scipy.__version__)'
xp=$( ( { module use /g/data/xp65/public/modules && module load conda/analysis3; } >/dev/null 2>&1 || { echo "conda/analysis3 did not load"; exit 1; }
        python3 -c "$check" ) 2>&1 | tail -1 )
sif=$( ( module load singularity >/dev/null 2>&1; SINGULARITYENV_PYTHONNOUSERSITE=1 singularity exec -B /g/data "$SIF" python3 -c "$check" ) 2>&1 | tail -1 )
## Stage 2 is Rscript in the container, run from the repo root with only the container's R library
rcheck='tryCatch({if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else invisible(lapply(list.files("R", full.names = TRUE), source)); stopifnot(exists("build_grid_mapping"), exists("sum_to_cells")); cat("terra", format(packageVersion("terra")), "s2", format(packageVersion("s2")), "\n")}, error = function(e) cat("error:", gsub("[[:space:]]+", " ", conditionMessage(e)), "\n"))'
r=$( ( module load singularity >/dev/null 2>&1; SINGULARITYENV_R_LIBS_USER=/nonexistent SINGULARITYENV_R_LIBS= singularity exec -B /g/data "$SIF" Rscript -e "$rcheck" ) 2>&1 | grep -v "^Execution halted" | tail -1 )
echo "## python in xp65 conda/analysis3: $xp"
case "$sif" in xclim*) echo "## python in the container: $sif" ;;
  *) echo "## python in the container: no xclim (not needed unless you choose -v PYENV=sif)" ;; esac
echo "## R in the container: $r"
case "$xp" in
  xclim*) echo "## stage 1 (FFDI, python): ready with the default PYENV=xp65" ;;
  *) case "$sif" in xclim*) echo "## stage 1 (FFDI, python): add -v PYENV=sif to qsub (xp65 has no xclim)" ;;
       *) echo "## stage 1 (FFDI, python): NOT READY, no python with xclim" ;; esac ;;
esac
case "$r" in terra*) echo "## stage 2 (cell sums, R): ready" ;;
  *) echo "## stage 2 (cell sums, R): NOT READY (see the R line)" ;; esac
