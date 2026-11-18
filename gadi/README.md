# gadi

Scripts to run on NCI Gadi, pulled via git. Outputs are small cell-sum files; bring them back by rsync to Nectar, git, or Acacia.

- `agcd_probe.sh`: find AGCD daily 0.05 deg files and variable names (login node)
- `agcd_sums.R`, `agcd_sums.pbs`: AGCD to S2 level 10 cell sums per region and year

The container image and project defaults follow imos-sor/nci (`jk72`, `gdal-r-python-extras` sif). AGCD layout on Gadi (from the NCI catalogue, 2026-11-18): `/g/data/zv2/agcd/<version>/<variable>/<mode>/<grid>/<frequency>/`, so `AGCD_DIR=/g/data/zv2/agcd/<version>` with `<mode>` = mean (tmax, tmin) or total (precip), `<grid>` = r005, `<frequency>` = 01day. Needs zv2 membership (applied for 2026-11-18). The version and file names are to be confirmed with the probe.

## AGCD versions on Gadi (probe, 2026-11-18)

- `v1-0-4`: daily r005 tmax and tmin 1910-2025, precip (total, calib, weight) 1900-2025, vapour pressure 1971-2025. Use this one.
- `v1`, `v1-0-1` to `v1-0-3`: the same layout, ending 2020 to 2024.
- `v2`, `v2-0-1` to `v2-0-4`: monthly precip only, at r005 and r001.
- NetCDF variable names match the folder names (`tmax`, `tmin`, `precip`). The grid is 886 x 691, lon/lat.

    qsub -P gv90 -l storage=gdata/zv2+gdata/jk72 \
      -v AGCD_DIR=/g/data/zv2/agcd/v1-0-4,VARS=tmax+tmin+precip \
      gadi/agcd_sums.pbs
