# Antarctic pilot

Sea ice season from trend.ice first, then SST south of 60S, then ice-free land from the controlledburn rock outcrop burn. See the task map in the top-level README.

## Sea ice season (trend.ice, S2 level 9)

1. On Gadi: `qsub -P gv90 -l storage=gdata/jk72 gadi/ice_sums.pbs` (see
   `gadi/README.md`). Per ice year and level 9 cell: area with a season
   record, with no ice, with ice at the end of the ice year, with a complete
   season, and weighted sums and squares of advance, retreat, duration and
   daycount. Pixels are split 5 x 5 so each cell gets an area-weighted share.
2. Here: `Rscript pilots/antarctica/ice_exposure.R <ice_dir> <outdir>`.
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

Tested on synthetic COGs on the NSIDC south grid (4 years, a known -30 days
per decade duration trend): the gate matched to 1e-13 and the trend was
recovered. 
## Results (Gadi run 2026-11-18, 46 ice years 1979-2025, no 1987)

The job took under 6 minutes (copyq, 2.1 GB memory) and gave 134,335
level 9 ocean cells.

Gate: the area mean duration and daycount per year from the cell sums equal
the plain per-pixel means to 5e-13 days; trends -0.509 (duration) and -0.687
(daycount) days per decade both ways.

Seasonal ice zone, median [10th, 90th percentile] of cells, days per decade:

| sector | cells | mean ice days | daycount trend | duration trend | advance trend | retreat trend | losing share | candidates |
|---|---|---|---|---|---|---|---|---|
| Weddell | 16,085 | 199 | -1.7 [-5.2, 2.0] | -1.9 [-6.4, 0.9] | 1.0 | -1.0 | 0.66 | 2,323 |
| Indian | 9,906 | 170 | -2.4 [-7.5, 1.8] | -2.6 [-8.0, 1.0] | 0.8 | -1.8 | 0.81 | 1,458 |
| W Pacific | 5,051 | 171 | 1.9 [-9.7, 6.2] | -1.2 [-9.4, 3.5] | -0.3 | -1.7 | 0.40 | 961 |
| Ross | 10,776 | 248 | 1.7 [-5.2, 6.4] | 1.1 [-3.4, 5.8] | -0.8 | 0.3 | 0.31 | 1,817 |
| Bell-Amundsen | 6,084 | 179 | -5.4 [-18.4, 3.7] | -5.6 [-17.0, 1.5] | 3.7 | -1.8 | 0.69 | 1,068 |

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

Caveats:

- Signal-to-noise is low: |snr| >= 2 in 21% of Bell-Amundsen cells and 1-4%
  elsewhere. Candidates rank trends within a sector; most are not
  distinguishable from interannual variability, and the 2016 onward low ice
  years weigh on every trend.
- Percentile flags select a share by construction (top quarter of trends).
- 25 km passive microwave: coastal polynyas and fast ice are not resolved.
