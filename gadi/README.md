# gadi

Scripts to run on NCI Gadi, pulled via git. Outputs are small cell-sum files; bring them back by rsync to Nectar, git, or Acacia.

- `agcd_probe.sh`: find AGCD daily 0.05 deg files and variable names (login node)
- `agcd_sums.R`, `agcd_sums.pbs`: AGCD to S2 level 10 cell sums per region and year

The container image and project defaults follow imos-sor/nci (`jk72`, `gdal-r-python-extras` sif). Paths under `/g/data/zv2` are to be confirmed with the probe.
