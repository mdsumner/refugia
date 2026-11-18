#!/bin/bash
## Find AGCD on Gadi, from a login node. ls/find only, shallow.
##
##   bash gadi/agcd_probe.sh                       # all versions under /g/data/zv2/agcd
##   ROOT=/g/data/zv2/agcd/v1-0-3 bash gadi/agcd_probe.sh
##
## Layout: <ROOT>/<version>/<variable>/<mode>/<grid>/<frequency>/*.nc
## Prints every variable/mode/grid/frequency leaf per version with its file
## count and first and last file, then the header of one file per variable,
## so AGCD_DIR, VARS and GLOB_TAIL can be set in agcd_sums.pbs.
set -u
ROOT=${ROOT:-/g/data/zv2/agcd}
echo "# agcd probe $(date -Is) $(hostname) ${USER:-?}, ROOT=$ROOT"
case "$(basename "$ROOT")" in v[0-9]*) versions="$ROOT" ;; *) versions=$(ls -d "$ROOT"/v*/ 2>/dev/null) ;; esac
for vdir in $versions; do
  vdir=${vdir%/}
  echo "## $(basename "$vdir")"
  find "$vdir" -mindepth 4 -maxdepth 4 -type d 2>/dev/null | sort | while read -r leaf; do
    n=$(ls "$leaf" 2>/dev/null | grep -c '\.nc$')
    first=$(ls "$leaf" 2>/dev/null | grep '\.nc$' | head -1)
    last=$(ls "$leaf" 2>/dev/null | grep '\.nc$' | tail -1)
    printf '  %-40s %5s files  %s .. %s\n' "${leaf#$vdir/}" "$n" "$first" "$last"
  done
done
module load netcdf >/dev/null 2>&1 || true
for v in tmax tmin precip; do
  f=$(find $versions -maxdepth 5 -path "*/$v/*/r005/01day/*" -name '*.nc' 2>/dev/null | sort | tail -1)
  [ -n "$f" ] || { echo "## no daily r005 file for $v"; continue; }
  echo "## header of $f"
  ncdump -h "$f" 2>/dev/null | sed -n '1,40p'
done
