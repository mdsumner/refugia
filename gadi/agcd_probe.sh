#!/bin/bash
## Find AGCD on Gadi, from a login node. ls only, shallow.
##
##   bash gadi/agcd_probe.sh            # looks under /g/data/zv2 by default
##   ROOT=/g/data/<proj>/<path> bash gadi/agcd_probe.sh
##
## Prints the first levels of the tree, the daily 0.05 deg files for
## tmax / tmin / precip if found, and the header of one file, so the path
## and variable names can be set in agcd_sums.pbs.
set -u
ROOT=${ROOT:-/g/data/zv2}
echo "# agcd probe $(date -Is) $(hostname) $USER, ROOT=$ROOT"
echo "## groups"; id -Gn | tr ' ' '\n' | sort | tr '\n' ' '; echo
ls -la "$ROOT" 2>&1 | head -20
echo "## three levels"
find "$ROOT" -mindepth 1 -maxdepth 3 -type d 2>/dev/null | head -60
for v in tmax tmin precip; do
  echo "## $v daily r005 candidates (first 5 and count)"
  find "$ROOT" -maxdepth 8 -path "*$v*" -path "*r005*" -name "*.nc" 2>/dev/null | sort > /tmp/agcd_$v.txt
  head -5 /tmp/agcd_$v.txt; echo "count: $(wc -l < /tmp/agcd_$v.txt)"
done
f=$(head -1 /tmp/agcd_tmax.txt)
if [ -n "$f" ]; then
  echo "## header of $f"
  module load netcdf >/dev/null 2>&1 || true
  ncdump -h "$f" 2>/dev/null | head -60
fi
