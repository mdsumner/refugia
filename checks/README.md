# checks

Literature and protected-area comparison tables, one per pilot.

## ASPAs (Antarctic land and sea, 2026-11-20)

`Rscript checks/aspa_overlap.R <ASPAs_polygons_v5_2024.shp> <refugia_dir> <outdir>`
against Terauds et al. (2024), Antarctic Specially Protected Areas 2024
Update, doi:10.26179/4qk0-cz71 (119 polygons, 75 ASPAs). A cell counts if
its S2 polygon touches an ASPA polygon, which is generous for ASPAs smaller
than a level 13 cell.

| sector | ice-free L13 cells | touching an ASPA | share | land holdout candidates | touching an ASPA | share |
|---|---|---|---|---|---|---|
| Peninsula | 38,072 | 473 | 0.012 | 11,025 | 21 | 0.002 |
| Weddell | 11,023 | 102 | 0.009 | 2,251 | 49 | 0.022 |
| Indian | 15,974 | 195 | 0.012 | 4,898 | 50 | 0.010 |
| W Pacific | 10,615 | 30 | 0.003 | 2,837 | 23 | 0.008 |
| Ross | 56,173 | 707 | 0.013 | 14,515 | 66 | 0.005 |
| Bell-Amundsen | 11,607 | 0 | 0 | 3,899 | 0 | 0 |
| all | 143,464 | 1,507 | 0.011 | 39,425 | 209 | 0.005 |

- 72 of the 75 ASPAs touch ice-free land; about 1% of ice-free cells do.
- Candidate land holdouts are half as likely as ice-free land in general to
  touch an ASPA (0.5% against 1.1%), and much less in the Peninsula (0.2%
  against 1.2%). ASPAs sit mostly on coastal sites (bird colonies, moss
  beds), while the holdout candidates lean inland and to the slow-warming
  ranges, so the two select different ground.
- Marine ASPAs (7) touch 21 seasonal sea ice cells and 17 summer open-water
  cells; none of the sea ice holdouts and 2 SST holdouts.
- One ASPA polygon (153) is rebuilt by s2 as its complement; the script
  flips polygons larger than a hemisphere.
