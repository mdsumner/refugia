# Fire weather

A third land variable for the Australian pilot, Tasmania first: is the
weather that lets forests burn changing, where has the change emerged from
year-to-year noise, and which cells hold on to mild fire weather? Same sums,
same metrics, same scoring within IBRA as the AGCD exposure pilot. Decided
2026-11-26 (see `framework.md`).

The first consumer is epicormic, a site on Tasmanian fires for landowners
and volunteer brigade training around Fern Tree (kunanyi/Mount Wellington).
It reads the cell tables; slope-scale and hourly work for Fern Tree (wind on
high-danger hours, case-study days) stays there, not here. Background and
sources: epicormic `notes/fern-tree-fire-weather-and-modelling.md`.

## Index

McArthur Forest Fire Danger Index (FFDI, Mk5) from
[xclim](https://xclim.readthedocs.io) (Apache-2.0):
`keetch_byram_drought_index` (KBDI, from daily rain, Tmax and annual mean
rain), then `griffiths_drought_factor`, then
`mcarthur_forest_fire_danger_index` (drought factor, daily Tmax, daily
minimum RH, daily maximum 10 m wind). These are the functions the
Australian Climate Service uses for its CMIP6 fire-weather layers
([AusClimateService/hazard_fire](https://github.com/AusClimateService/hazard_fire),
no licence, so not copied; read 2026-11-26), so observed and projected
series come from the same code.

- Call it a fire-weather index, never a rating. The current Fire Danger
  Ratings use the AFDRS Fire Behaviour Index, which has no open historical
  archive and is fuel-specific; FFDI and FBI thresholds do not convert.
- Daily FFDI from daily extremes overstates co-occurrence (Tmax, minimum RH
  and maximum wind need not fall in the same hour; BoM report BRR-116 calls
  this "can be misleading"). Kept because the projections only have daily
  extremes; trends and percentiles within a cell are less affected than
  absolute values.

## Inputs

Observed, fire years 1980 to 2025 (BARRA2 starts January 1979; KBDI needs
spin-up):

| input | source | note |
|---|---|---|
| daily Tmax | BARRA-C2 `day/tasmax` | K, packed (scale and offset in the file) |
| daily max 10 m wind | BARRA-C2 `day/sfcWindmax` | m/s, to km/h for FFDI |
| daily min RH | BARRA-C2 `1hr/hurs`, minimum per local day | no `day/hursmin` is published; the hourly read dominates the cost |
| daily rain and Tmax for KBDI and DF | AGCD v1-0-4 `precip` and `tmax` | decided 2026-11-26: observed, and KBDI spins up from 1970, before BARRA2 starts |

Grid: BARRA-C2 is 0.04 deg; regrid to the AGCD 0.05 deg r005 grid (bilinear
for Tmax, RH and wind; rain is AGCD's own). Land is BARRA-C2 `fx/sftlf` >= 50%
after interpolation: AGCD has values over the sea, so it cannot be the mask. The bias-adjusted projections
(`AUST-05i`) are on that grid too, so observed and projected FFDI share the
level 10 mapping already built for AGCD (`gadi/agcd_sums.R`).

Projected, 1960 to 2099: NCI `kj66` bias-adjusted CORDEX-CMIP6 `AUST-05i`
daily `tasmax`, `pr`, `hursmin`, `sfcWindmax` for BARPA-R and CCAM,
SSP1-2.6 and SSP3-7.0 (UQ-DEC has no corrected wind). Compare with the
National Climate Risk Assessment layers in `/g/data/ia39/ncra/bushfire/`
and McGloin et al. 2026 (npj Natural Hazards, doi:10.1038/s44304-026-00193-9).

## Sums per cell and fire year

Fire year = July to June, labelled by the June (2019 = July 2018 to June
2019), so a summer is never split. Per pixel, then summed to level 10 cells
with `sum_to_cells()`, all additive:

- `ndays`, `sum`, `sumsq` of daily FFDI (cumulative FFDI is `sum`)
- `spring_n`, `spring_sum` (September to November; spring is where
  south-east Tasmanian change shows first)
- `n_ge12`, `n_ge25`, `n_ge50`: days at or above the old High, Very High and
  Severe category bounds. Fixed thresholds keep counts mergeable; local
  percentiles would need a second pass over a baseline. Severe (50) is rare
  in south-east Tasmania (Hobart about 0.2 days a year), so 12 and 25 carry
  the signal.
- `n_mild`: days below 12; persistence of mild fire weather is the
  refugium state

## Metrics

From the annual series per cell (`R/sums.R`), into the shared vocabulary:

| metric | from | refugium reading |
|---|---|---|
| `clim` | mean annual cumulative FFDI, days >= 25 | context |
| `trend_decade`, `snr` | annual cumulative and spring FFDI, days >= 25 | low trend relative to region |
| `velocity_km_decade` | cumulative FFDI trend over its spatial gradient | low |
| `persistence` | `n_mild / ndays`, overall and in the region's five worst fire years | high |
| `toe` (new, projections only) | first year the projected change exceeds 1 and 2 baseline interannual sd and stays | late |

`toe` needs adding to `schema_metric_vocab`. Noise for signal-to-noise is
each run's own baseline interannual sd, not the spread between models
(McGloin's stippled ratio is model agreement). Expect low snr: published
work finds interannual variability (ENSO, SAM, IOD) still larger than the
trend in observed FFDI (Harris and Lucas 2019).

A fire-weather refugium is a cell in the favourable quarter of its IBRA
region for trend or velocity and for persistence, as for the thermal
candidates. Wet forest like Fern Tree's is a conditional refugium: it
protects in ordinary years and becomes fuel in extreme ones, so the
worst-years persistence is the number that matters there.

## Scale

Level 10 cells (about 8 km) and a 4.4 km reanalysis describe regional fire
weather, not slope, aspect or gully scale. Fern Tree falls in one or two
cells. Validate against stations 094087 (kunanyi summit, 1260 m; BoM warns
its wind record is sometimes badly affected) and 094029 (Hobart, Ellerslie
Road).

## Gates and checks

1. Cell-sum annual cumulative FFDI over Tasmania equals a direct per-pixel
   computation (as for WOfS, sea ice and SST).
2. KBDI and drought factor against Copernicus CEMS `cems-fire-historical-v1`
   (0.25 deg, daily, 1940 on); seasonal FFDI against the Harris and Lucas
   station set (Mendeley Data `xf5bv3hcvw`, 1973-2017, CC BY 4.0).
3. BARRA-R2 (12 km) against BARRA-C2 for the same years.

## Access probe (2026-11-26, checked)

`sources/barra2_probe.py`, from a cloud session against public S3:

- `s3://bom-opendata-climate/BARRA2/output/reanalysis/AUST-04/BOM/ERA5/historical/hres/BARRA-C2/v1/{day,1hr}/<var>/v20250528/`,
  one netCDF per month, `197901` to `202601`, no credentials
  (`AWS_NO_SIGN_REQUEST=YES`, region `ap-southeast-2`). Daily variables
  include `tasmax`, `tasmin`, `pr`, `sfcWind`, `sfcWindmax`, `hurs` (daily
  mean only), `wsgsmax`; hourly include `hurs`, `tas`, `uas`, `vas`,
  `sfcWindmax`, `flashrate`.
- Grid 1018 x 1298 at 0.04 deg, DEFLATE, values packed with scale and
  offset. Daily `tasmax` is about 35 MB a month for the whole domain.
- Chunks: daily `[2, 318, 412]`, hourly `hurs` `[12, 130, 168]` (time,
  lat, lon).
- Tasmania box (143.5 to 149 E, 44 to 39.3 S; 117 x 138 pixels) read
  through GDAL multidimensional `/vsis3/`: about 6 to 10 s per month per
  daily variable, 118 s per month for hourly `hurs`. Over 47 years that is
  about 4 hours for the three daily inputs and 18 hours for `hurs` from a
  single process; on Gadi (`/g/data/ob53`, needs membership) it is a local
  read.
- Fern Tree pixel (42.930 S, 147.260 E), January 2025: daily Tmax 288.2 to
  302.3 K (15 to 29 C); daily max wind 2.8 to 10.9 m/s (10 to 39 km/h);
  rain mean 1.1e-05 kg m-2 s-1, times 86400 = 0.96 mm/day (about 30 mm for
  the month, wettest day 9.8 mm); hourly RH 30.1 to 99.6%.

## One-year test (2026-11-26)

`gadi/ffdi_daily.py` and `gadi/ffdi_sums.R`, unchanged, on Tasmania-sized
copies laid out as on Gadi: AGCD 2022-2025 from NCI THREDDS (OPeNDAP) and
BARRA-C2 July 2024 to June 2025 from S3, KBDI spun up from 2022, xclim
1.0.1 (imports from `xclim.compute.fire`; older xclim from `xclim.indices`).

- 2,965 land pixels of 10,545 in the box; 1,082,225 pixel-days.
- FFDI recomputed by hand from Noble et al. (1980) with the drought factor,
  Tmax, minimum RH and wind in km/h matches xclim to 0.0000.
- Input ranges: Tmax -1.3 to 37.9 C, minimum RH 13 to 100%, max wind 4.6
  to 118 km/h, drought factor 0 to 10, rain 0 to 193 mm/day.
- Tasmania: FFDI median 2.5, 99th percentile 15.1, maximum 43.1. Highest
  mean FFDI and most days >= 12 in the Midlands and Derwent Valley, lowest
  in the west, as expected.
- Fern Tree pixel (42.900 S, 147.250 E): mean 3.6, maximum 20.6 on
  2025-03-20 (26.4 C, 23% RH, 29 km/h, DF 7.6), 13 days >= 12, none >= 25;
  1,246 mm of rain over the fire year.
- Gate: per-cell sums over 1,092 level 10 cells equal the direct pixel totals
  for npix, ndays, sum, sumsq, spring sum and every count (largest relative
  difference 1.5e-15).
- Sizes: 23 MB per fire year; 32 MB of KBDI cache for four years (about
  450 MB for 1970-2025).

## Gadi probe (2026-11-26)

`bash gadi/ffdi_probe.sh` on a Gadi login node:

- Projects gv90, jk72, zv2, ob53 and xp65 all joined.
- BARRA-C2 at the default path under `/g/data/ob53`: day/tasmax,
  day/sfcWindmax and 1hr/hurs v20250528, 571 monthly files each, 197901 to
  202607; fx/sftlf v20240516.
- AGCD v1-0-4 precip 1900-2025 and tmax 1910-2025, so the 1970 spin-up is
  covered. Fire year 2026 (July 2025 to June 2026) has BARRA-C2 but waits
  for an AGCD 2026 file, so LAST stays 2025.
- Python: xp65 `conda/analysis3` has xclim 0.61.1 and xarray 2026.1.0; the
  GDAL container has no xclim, so stage 1 uses xp65 (the default).

The one-year test rerun locally with xclim 0.61.1 and xarray 2026.1.0
(imports from `xclim.indices`) gives output identical to the 1.0.1 run:
every variable in `kbdi_df_2022_2025.nc` and `ffdi_fy2025.nc` has the same
missing-value pattern and a largest absolute difference of 0. xclim returns
`ffdi` as (lat, lon, time); terra reads that file correctly (the Fern Tree
pixel through terra, as `gadi/ffdi_sums.R` reads it, gives the same maximum
of 20.62 on 2025-03-20 and 13 days >= 12 as xarray).

## Open decisions

- Decided 2026-11-26: AGCD rain (and Tmax) for KBDI and the drought factor;
  run on Gadi (`gadi/ffdi_probe.sh`, `gadi/ffdi.pbs`, see `gadi/README.md`).
- Whether a Fern Tree-only hourly FFDI (exact co-occurrence) belongs in
  epicormic as the local check on the daily index (proposed: yes).
