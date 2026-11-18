# Framework

The living version of this framework is a shared document
(https://claude.ai/artifact/HXCqnDydmQ9U1uSVQSa3Je). This file keeps the
parts the code depends on.

## Concept

A climate refugium is a place where change is buffered relative to its
surroundings. Four distinctions carry across both pilots:

- macro vs micro: regional buffering vs local buffering below the climate grid
- holdout vs stepping stone: keeps current conditions vs becomes suitable as conditions move
- exposure vs persistence: low change in a climate variable vs persistence of a habitat state
- relative, not absolute: a cell is judged against its reference region

## Sums

Every metric is built from per-cell, per-period sums so that any union of
cells or years aggregates exactly (the trend.sst pattern).

For an annual series x over years t in a cell (or union of cells), the OLS
trend needs only

    n, St = sum(t), Stt = sum(t^2), Sx = sum(x), Stx = sum(t*x), Sxx = sum(x^2)

    slope     = (n*Stx - St*Sx) / (n*Stt - St^2)
    intercept = (Sx - slope*St) / n
    rss       = Sxx - intercept*Sx - slope*Stx
    resid_sd  = sqrt(rss / (n - 2))
    snr       = slope * (range of t) / resid_sd

Persistence uses counts: `n_state / n_clear` (WOfS already stores this form),
and the same ratio restricted to extreme years (drought years on land, low ice
years at sea).

Velocity is the trend divided by the magnitude of the spatial gradient of the
climatology across neighbouring cells.

## Scores

Per metric, the cell's percentile within its reference region. A candidate
refugium is in the favourable tail on persistence and on at least one exposure
metric. Metrics are kept separate in outputs.

## Decisions

- 2026-11-18: Australia pilot starts with DEA terrestrial; code in this repo;
  S2 levels finer than trend.* level 5 (13 for DEA, 10 for AGCD, 9 for sea ice).
- 2026-11-18: ice-free land starts from the controlledburn rock outcrop burn;
  best current dataset to confirm with colleagues.
