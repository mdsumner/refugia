# checks

Literature and protected-area comparison tables, one per pilot.

## ASPAs (Antarctic land and sea, 2026-11-20)

`Rscript checks/aspa_overlap.R <ASPAs_polygons_v5_2024.shp> <refugia_dir> <outdir>`
against Terauds et al. (2024), Antarctic Specially Protected Areas 2024
Update, doi:10.26179/4qk0-cz71 (119 polygons, 75 ASPAs). A cell counts if
its S2 polygon touches an ASPA polygon, which is generous for ASPAs smaller
than a level 13 cell.

Candidates are the land holdouts scored within ACBR v2 (`pilots/antarctica/acbr_score.R`); sectors only group the rows.

| sector | ice-free L13 cells | touching an ASPA | share | land holdout candidates | touching an ASPA | share |
|---|---|---|---|---|---|---|
| Peninsula | 38,072 | 473 | 0.012 | 10,509 | 19 | 0.002 |
| Weddell | 11,023 | 102 | 0.009 | 216 | 0 | 0 |
| Indian | 15,974 | 195 | 0.012 | 7,405 | 103 | 0.014 |
| W Pacific | 10,615 | 30 | 0.003 | 3,991 | 3 | 0.001 |
| Ross | 56,173 | 707 | 0.013 | 14,457 | 67 | 0.005 |
| Bell-Amundsen | 11,607 | 0 | 0 | 2,441 | 0 | 0 |
| all | 143,464 | 1,507 | 0.011 | 39,019 | 192 | 0.005 |

- 72 of the 75 ASPAs touch ice-free land; about 1% of ice-free cells do.
- Candidate land holdouts are half as likely as ice-free land in general to
  touch an ASPA (0.5% against 1.1%), and much less in the Peninsula (0.2%
  against 1.2%); the Indian sector (Larsemann, Vestfold, PCM coast) is the
  exception at 1.4%. ASPAs sit mostly on coastal sites (bird colonies, moss
  beds), while the holdout candidates lean inland and to the slow-warming
  ranges, so the two select different ground.
- Marine ASPAs (7) touch 21 seasonal sea ice cells and 17 summer open-water
  cells; none of the sea ice holdouts and 2 SST holdouts.
- One ASPA polygon (153) is rebuilt by s2 as its complement; the script
  flips polygons larger than a hemisphere.


## ERA5 summer warming against Antarctic stations

`Rscript checks/era5_station_check.R <ghcn_dir> <era5_out_dir> <outdir>`

GHCN-daily per-station files come from
`https://noaa-ghcn-pds.s3.amazonaws.com/csv/by_station/<ID>.csv` (reachable
from the cloud sessions). Summer (DJF) mean of TAVG, or (TMAX + TMIN) / 2,
with all three months holding at least 20 days; compared over the station's
own summers (at least 12) with the ERA5 level 9 cell holding it.
`step_2000` is the change in the mean ERA5 minus station difference between
summers to 2000 and from 2001.

| region | station | summers | r | station trend | ERA5 trend, same summers | step_2000 |
|---|---|---|---|---|---|---|
| North Victoria Land | Mario Zucchelli | 12 (2009-2026) | 0.86 | +0.22 | +0.78 | |
| North Victoria Land | Cape Phillips AWS | 21 (2002-2026) | 0.34 | -0.62 | +0.44 | |
| North Victoria Land | Priestley Glacier AWS | 19 (2007-2026) | 0.88 | +0.63 | +1.02 | |
| North Victoria Land | Cape Ross AWS | 21 (2002-2026) | 0.60 | +0.45 | +0.26 | |
| South Victoria Land | McMurdo | 24 (1980-2026) | 0.39 | +0.31 | -0.05 | -0.92 |
| Dronning Maud Land | Novolazarevskaya | 39 (1980-2026) | 0.40 | -0.17 | +0.47 | +1.89 |
| Dronning Maud Land | Neumayer | 43 (1983-2026) | 0.68 | +0.02 | +0.56 | +1.38 |
| Dronning Maud Land | Troll | 17 (1995-2025) | 0.66 | -0.62 | +0.11 | |
| Dronning Maud Land | SANAE IV | 16 (1999-2023) | 0.65 | -0.21 | +0.37 | |
| Dronning Maud Land | Kohnen | 13 (2008-2022) | 0.97 | +0.35 | +0.50 | |
| Enderby Land | Syowa | 39 (1985-2026) | 0.88 | -0.11 | -0.10 | -0.03 |
| East Antarctica | Mawson | 47 | 0.85 | -0.06 | +0.02 | +0.17 |
| East Antarctica | Davis | 47 | 0.71 | -0.02 | -0.04 | -0.08 |
| East Antarctica | Mirny | 40 | 0.94 | -0.02 | 0.00 | -0.13 |
| East Antarctica | Casey | 47 | 0.92 | -0.14 | -0.04 | +0.24 |
| Adelie Land | Dumont d'Urville | 32 (1993-2024) | 0.45 | +0.51 | -0.16 | -0.75 |
| Peninsula | Esperanza | 44 | 0.81 | +0.16 | -0.06 | -0.57 |
| Peninsula | Bellingshausen | 37 | 0.92 | -0.02 | +0.01 | +0.12 |
| Peninsula | Rothera | 22 (2001-2025) | 0.91 | -0.10 | -0.06 | |
| Peninsula | Vernadsky | 23 (1986-2026) | 0.81 | -0.01 | +0.07 | +0.25 |

Trends in deg C per decade. Leningradskaya, Maitri, SANAE (old) and Wasa have
fewer than 12 complete summers.

- From East Antarctica round to the Peninsula ERA5 follows the stations
  closely (r 0.7 to 0.94, trends within 0.15 deg C per decade).
- Dronning Maud Land: the ERA5 warming (+0.32 deg C per decade over the
  region's ice-free cells, 1980-2026) is not in the stations. At the two
  long records ERA5 warms by about 0.5 deg C per decade more than the
  station, as a step of 1.4 to 1.9 deg C after 2000 in the ERA5 minus
  station difference, which points to an inhomogeneity in ERA5 there
  rather than a regional change. The shorter records (Troll, SANAE IV)
  agree with that.
- North Victoria Land: the records are short and only start after 2000, so
  the 1980-2026 ERA5 trend cannot be tested. Three of four stations warm,
  but ERA5 runs warmer than the stations by a median 0.5 deg C per decade
  over the same summers. Treat the North Victoria Land warming as likely
  real but overstated.
- Priestley Glacier and Kohnen are inland AWS on ice (summer means of -23
  and -27 deg C); the large mean bias at Priestley (+11 deg C) reflects
  the 0.25 deg ERA5 pixel and elevation, not an error in the trend test.
