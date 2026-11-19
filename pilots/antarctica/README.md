# Antarctic pilot

Sea ice season from trend.ice first, then SST south of 60S, then ice-free land from the controlledburn rock outcrop burn. See the task map in the top-level README.

## Sea ice season (trend.ice, S2 level 9)

1. On Gadi: `qsub -P gv90 -l storage=gdata/jk72 gadi/ice_sums.pbs` (see
   `gadi/README.md`). Per ice year and level 9 cell: area with a season
   record, with no ice, with ice at the end of the ice year, with a complete
   season, and weighted sums and squares of advance, retreat, duration and
   daycount. Pixels are split 5 x 5 so each cell gets an area-weighted share.
2. Here: `Rscript pilots/antarctica/ice_exposure.R <ice_dir> <outdir>`.
   - Daycount is adjusted for missing days (`s_dayadj`): the CDR has
     whole-grid gaps of 13 days in ice year 1984 and 5 to 7 in 1985 and
     1986, which otherwise count as days without ice.
   - Gate: area mean duration and daycount per year from the cell sums equal
     the plain per-pixel means (and so their trends match); the script stops
     if they differ by more than 1e-6 days.
   - Per cell: climatology, trend per decade, signal-to-noise of daycount,
     duration, advance and retreat; daycount velocity (km per decade); share
     of years with an ice season.
   - Scored within the five trend.ice sectors on the seasonal ice zone (mean
     daycount 30-335 days). Candidate holdout: daycount trend in the sector's
     top quarter (least loss), velocity in the lowest quarter, ice season in
     at least 90% of years.

3. External check: `Rscript pilots/antarctica/ice_nsidc_check.R <ice_dir>
   S_seaice_extent_daily_v4.0.csv <outdir>` against NSIDC's Sea Ice Index.

Tested on synthetic COGs on the NSIDC south grid (4 years, a known -30 days
per decade duration trend): the gate matched to 1e-13 and the trend was
recovered.

## Results (Gadi run 2026-11-18, 46 ice years 1979-2025, no 1987)

Updated 2026-11-19 for the missing-day adjustment: the sums were rebuilt in
the cloud from the same COGs (raw sums identical to the Gadi run in every
cell), and the sector table below uses the adjusted daycount.

The job took under 6 minutes (copyq, 2.1 GB memory) and gave 134,335
level 9 ocean cells.

Gate: the area mean duration and daycount per year from the cell sums equal
the plain per-pixel means to 5e-13 days; trends -0.509 (duration) and -0.687
(daycount) days per decade both ways.

Seasonal ice zone, median [10th, 90th percentile] of cells, days per decade:

| sector | cells | mean ice days | daycount trend | duration trend | advance trend | retreat trend | losing share | candidates |
|---|---|---|---|---|---|---|---|---|
| Weddell | 16,077 | 199 | -1.9 [-5.4, 1.7] | -1.9 [-6.4, 0.9] | 1.0 | -1.0 | 0.70 | 2,351 |
| Indian | 9,896 | 170 | -2.7 [-7.6, 1.5] | -2.6 [-8.0, 1.0] | 0.8 | -1.8 | 0.83 | 1,415 |
| W Pacific | 5,042 | 171 | 1.7 [-9.9, 5.9] | -1.2 [-9.4, 3.5] | -0.3 | -1.7 | 0.41 | 959 |
| Ross | 10,752 | 248 | 1.4 [-5.6, 6.1] | 1.1 [-3.4, 5.8] | -0.8 | 0.3 | 0.34 | 1,804 |
| Bell-Amundsen | 6,072 | 179 | -5.6 [-18.9, 3.5] | -5.6 [-17.0, 1.5] | 3.7 | -1.8 | 0.70 | 1,055 |

The pattern is the known one: strong loss in the Bellingshausen and
Amundsen, gain in the western Ross Sea and along the W Pacific coast, mixed
elsewhere.

Scoring change after the first run: velocity is scored only for losing
cells. With plain |velocity| (first run), the top-quarter trends in the Ross
and W Pacific sectors are gains, gains move the isolines fast, and the joint
rule left 19 and 4 candidates there; the same rule gave 423 to 1,027 in the
losing sectors.

Map: `pilots/antarctica/ice_map.R` writes `ice_candidates_map.png` (trend,
and candidate holdouts). Candidates sit in the western Ross Sea, the outer
Amundsen and Bellingshausen pack, a band across the central and eastern
Weddell, and the coastal belt from the Indian to the W Pacific sector.

### Check against the NSIDC Sea Ice Index (v4 daily extent)

Summed over the grid, daycount times true pixel area is the daily extent
integrated over the ice year; divided by the days in the year it is the mean
daily extent, which the Sea Ice Index gives directly (NASA Team only,
every other day before August 1987, interpolated to daily). Outputs:
`ice_nsidc_by_year.csv`, `ice_nsidc_summary.csv`, `ice_nsidc_check.png`.

| daycount | mean extent, trend.ice / SII (million km2) | ratio range | anomaly r | anomaly RMSE (million km2) | trend per decade, trend.ice / SII (million km2) |
|---|---|---|---|---|---|
| raw | 11.87 / 11.53 | 0.989 to 1.045 | 0.985 | 0.089 | -0.092 / -0.072 |
| adjusted for missing days | 11.89 / 11.53 | 1.023 to 1.057 | 0.991 | 0.069 | -0.109 / -0.072 |

- The cell sums track the Sea Ice Index closely; the CDR runs about 3%
  higher, as expected from its larger of NASA Team and Bootstrap.
- With the raw daycount, 1984 fell below the Sea Ice Index (ratio 0.989
  against about 1.04 for its neighbours). The CDR has 13 missing days that
  year in every pixel, counted as days without ice. The adjustment brings
  1984 to 1.025 and 1986 to 1.057, so it under-corrects one year and
  over-corrects the other, but it removes most of the error. In cells
  under ice during the gaps, the raw daycount trend was biased toward less
  loss by up to about 0.5 days per decade. 117 cells became candidates and
  160 dropped out (of about 7,600).
- The trend.ice extent declines faster than the Sea Ice Index (-0.109
  against -0.072 million km2 per decade; -0.125 against -0.090 without
  1984-1986). The ratio falls from about 1.04 in the 1980s to 1.025 in the
  2010s, so this is a drift between the CDR and NASA Team rather than an
  aggregation error. Trends from the CDR are a little more negative than
  from NASA Team.

Caveats:

- Signal-to-noise is low: |snr| >= 2 in 21% of Bell-Amundsen cells and 1-4%
  elsewhere. Candidates rank trends within a sector; most are not
  distinguishable from interannual variability, and the 2016 onward low ice
  years weigh on every trend.
- Percentile flags select a share by construction (top quarter of trends).
- 25 km passive microwave: coastal polynyas and fast ice are not resolved.

## Sea surface temperature south of 60S (OISST v2.1, S2 level 9)

trend.sst holds OISST sums on level 5 cells only (about 290 km), too coarse
next to the sea ice cells, so this reads the daily OISST pixels again from
NOAA's public bucket (the files the raad.virtualize index on source.coop
points to).

1. `Rscript sources/oisst_south.R <oisst_dir> 1982 2025 8`: per calendar
   year and pixel south of 60S, sums of SST over all days, over Jan-Mar,
   and over open-water days (ice concentration below 15%), and ice-day
   counts. About 28 GB read, about 20 minutes from a cloud session; 44
   years, no missing days.
2. `Rscript pilots/antarctica/sst_exposure.R <oisst_dir> <outdir>`: cell
   sums per year (pixels split 3 x 3, true area weights), the gate, and per
   cell climatology, trend, signal-to-noise and velocity of summer SST.
   Summer SST is the Jan-Mar mean over open-water days (at least 30).
   Scored within the sectors on the summer open-water zone (mean Jan-Mar
   ice share below 0.5). Candidate SST holdout: summer SST trend in the
   sector's lowest quarter, and cooling or a warming velocity in the lowest
   quarter of the sector's warming cells.
3. `Rscript pilots/antarctica/sst_map.R <outdir>`: `sst_candidates_map.png`.

Why open-water days: OISST sets SST under ice from its ice concentration,
and its ice input is not homogeneous. Against the NSIDC CDR daycount, the
OISST ice share south of 60S steps up by about 12% in 2005 (ratio 2.10-2.19
for 1982-2004, 2.31-2.63 from 2005), so all-day SST trends in the ice zone
follow that step.

### Results (1982-2025)

Gate: the area mean SST south of 60S per year from the cell sums equals the
pixel area mean to 3e-14 deg C. 44,862 cells in the summer open-water zone.

| sector | cells | summer SST (deg C) | summer SST trend (deg C per decade) | snr | warming share | abs(snr) >= 2 | candidates |
|---|---|---|---|---|---|---|---|
| Weddell | 10,079 | 0.02 | 0.04 [-0.01, 0.09] | 0.4 | 0.85 | 0.02 | 2,308 |
| Indian | 7,173 | 0.73 | 0.03 [-0.02, 0.09] | 0.4 | 0.74 | 0.02 | 1,793 |
| W Pacific | 5,369 | 1.34 | 0.02 [-0.04, 0.12] | 0.2 | 0.66 | 0.03 | 1,342 |
| Ross | 11,634 | 0.11 | 0.01 [-0.06, 0.13] | 0.1 | 0.56 | 0.02 | 2,909 |
| Bell-Amundsen | 10,607 | 1.50 | -0.08 [-0.17, 0.04] | -0.5 | 0.22 | 0.03 | 2,652 |

- Summer surface warming south of 60S is small (area mean +0.04 deg C per
  decade) and indistinguishable from interannual variability almost
  everywhere: abs(snr) >= 2 in 2-3% of cells, so the SST candidates are a
  ranking within the noise rather than detected holdouts.
- The Bellingshausen and Amundsen open ocean cooled in summer, where the
  ice season shortened most; the central Pacific sector and the eastern
  Ross gyre warmed most.
- Open-water days are a sample that changes with the ice: where ice
  lingers longer into summer, the remaining open-water days are fewer and
  later.

## Ice-free land (rock outcrop v7.3, S2 level 13)

`Rscript sources/icefree_cells.R <rock_gpkg> <outdir>` intersects the
25,954 rock outcrop polygons (Burton-Johnson et al., medium resolution v7.3,
from AustralianAntarcticDivision/rema.proc) with the level 13 cells that
cover them, on the sphere, so the area per cell is exact for the polygons
and no dense raster is needed (24 s). Gate: the cell areas sum to the
polygon areas (rel. diff 1e-10). `icefree_summary.R` gives the sector table
and `icefree_map.png` (level 9 shares).

72,201 km2 of outcrop in 143,464 level 13 cells (3,357 level 9 cells):

| sector | rock km2 | share | level 13 cells | cells at least half ice-free | median fraction |
|---|---|---|---|---|---|
| Peninsula | 13,180 | 0.18 | 38,072 | 5,088 | 0.15 |
| Weddell | 5,274 | 0.07 | 11,023 | 3,268 | 0.26 |
| Indian | 10,751 | 0.15 | 15,974 | 6,528 | 0.35 |
| W Pacific | 6,128 | 0.09 | 10,615 | 4,024 | 0.34 |
| Ross | 31,069 | 0.43 | 56,173 | 20,535 | 0.32 |
| Bell-Amundsen | 5,799 | 0.08 | 11,607 | 3,785 | 0.29 |

(Peninsula: north of 75S, 80W to 55W.)

- 72,000 km2 is about three times the published rock outcrop area from
  the high-resolution Landsat classification (about 21,700 km2); the
  medium-resolution polygons are generalised outlines. The AADC ice-free
  layer (Toth and Terauds 2023) is the comparison to make, but
  data.aad.gov.au is not reachable from the cloud sessions.
- No exposure yet: ERA5 summer temperature (or a coastal link to the
  sea ice and SST cells) and the ACBRs are the next inputs.
