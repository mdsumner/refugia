#!/bin/bash
## Check everything gadi/ffdi.pbs needs, from a login node. ls and imports only.
##
##   bash gadi/ffdi_probe.sh
##
## Prints: project memberships; BARRA-C2 version folders and first/last monthly files for the
## three inputs and the land fraction (fx/sftlf); AGCD precip and tmax first/last years; and
## which python (NCI xp65 analysis3, or the GDAL container) imports xclim, xarray, netCDF4, scipy.
set -u
AGCD_DIR=${AGCD_DIR:-/g/data/zv2/agcd/v1-0-4}
BARRA_DIR=${BARRA_DIR:-/g/data/ob53/BARRA2/output/reanalysis/AUST-04/BOM/ERA5/historical/hres/BARRA-C2/v1}
SIF=${SIF:-/g/data/jk72/$USER/sif_lib/gdal-r-python-extras_latest.sif}
echo "# ffdi probe $(date -Is) $(hostname) ${USER:-?}"
echo "## projects: $(id -nG | tr ' ' '\n' | grep -E '^(gv90|jk72|zv2|ob53|xp65)$' | tr '\n' ' ')(need gv90 jk72 zv2 ob53, and xp65 for PYENV=xp65)"
for leaf in day/tasmax day/sfcWindmax 1hr/hurs fx/sftlf; do
  d="$BARRA_DIR/$leaf"
  if [ -d "$d" ]; then
    v=$(ls -d "$d"/v* 2>/dev/null | tail -1)
    printf '## BARRA-C2 %-15s %s: %s files, %s .. %s\n' "$leaf" "$(basename "$v")" "$(ls "$v" | wc -l)" \
      "$(ls "$v" | head -1 | grep -oE '[0-9]{6}-' | tr -d -)" "$(ls "$v" | tail -1 | grep -oE '[0-9]{6}-' | tr -d -)"
  else
    echo "## BARRA-C2 $leaf: not visible at $d (join ob53, and check the path)"
  fi
done
for p in precip/total tmax/mean; do
  d="$AGCD_DIR/$p/r005/01day"
  [ -d "$d" ] && echo "## AGCD $p: $(ls "$d" | head -1) .. $(ls "$d" | tail -1)" || echo "## AGCD $p: not visible at $d"
done
check='import xclim, xarray, netCDF4, scipy; print("xclim", xclim.__version__, "xarray", xarray.__version__, "netCDF4", netCDF4.__version__, "scipy", scipy.__version__)'
echo "## python, PYENV=xp65:"
( module use /g/data/xp65/public/modules 2>/dev/null && module load conda/analysis3 2>/dev/null && python3 -c "$check" ) 2>&1 | tail -1
echo "## python, PYENV=sif ($SIF):"
( module load singularity 2>/dev/null && SINGULARITYENV_PYTHONNOUSERSITE=1 singularity exec -B /g/data "$SIF" python3 -c "$check" ) 2>&1 | tail -1
