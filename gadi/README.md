# gadi

Scripts to run on NCI Gadi, pulled via git. Outputs are small cell-sum files; bring them back by rsync to Nectar, git, or Acacia.

- `agcd_probe.sh`: find AGCD daily 0.05 deg files and variable names (login node)
- `agcd_sums.R`, `agcd_sums.pbs`: AGCD to S2 level 10 cell sums per region and year

The container image and project defaults follow imos-sor/nci (`jk72`, `gdal-r-python-extras` sif). AGCD layout on Gadi (from the NCI catalogue, 2026-11-18): `/g/data/zv2/agcd/<version>/<variable>/<mode>/<grid>/<frequency>/`, so `AGCD_DIR=/g/data/zv2/agcd/<version>` with `<mode>` = mean (tmax, tmin) or total (precip), `<grid>` = r005, `<frequency>` = 01day. Needs zv2 membership (applied for 2026-11-18). The version and file names are to be confirmed with the probe.
