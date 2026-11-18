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
recovered. Real results follow once the Gadi job has run.
