# refugia

A framework for identifying climate refugia within Australia and within
Antarctica, with one pilot for each, checked against the biodiversity
literature and protection goals.

A climate refugium is a place where change is buffered relative to its
surroundings, so the conditions a biota depends on persist longer than they
do nearby. The definition is the same on land, at sea and in Antarctica;
only the variable and the spatial grain change. This repo therefore uses one
scoring scheme on a shared S2 cell grid, fed by domain-specific inputs, and
always reports a cell against a reference region.

Pilot results: <https://mdsumner.github.io/refugia/> (built from [`site/`](site/)).

Framework notes: [`notes/framework.md`](notes/framework.md).
First data sources: [`notes/data_sources.md`](notes/data_sources.md).

Built on:

- the [trend family](https://australianantarcticdivision.github.io/trend/)
  (trend.sst, trend.sla, trend.chl, trend.ice): daily records stored as
  mergeable sufficient statistics on S2 cells
- [imos-sor](https://github.com/mdsumner/imos-sor): region sets (EEZ, AMPs,
  IMCRA) and coverage tables, Australia + AAT frame
- [raad.virtualize](https://github.com/mdsumner/raad.virtualize): byte
  reference stores for archival netCDF/HDF5 sources
- [controlledburn](https://www.hypertidy.org/posts/2026-08-19_antarctica-icefree-rasterizing/):
  sparse polygon rasterization, used for the Antarctic ice-free layer

## Metrics

Per cell, each computable from mergeable sums so that any union of cells or
years aggregates exactly:

| metric | measures | refugium signal |
|---|---|---|
| trend | rate of change per decade | low relative to reference region |
| signal-to-noise | trend over interannual sd (time-of-emergence proxy) | low |
| velocity | trend over local spatial gradient (km per decade) | low |
| persistence | fraction of observations in the habitat state, and stability in extreme years | high |

Scores are percentiles within a reference region (IBRA, IMCRA, ACBR, CCAMLR
area). Metrics stay separate so the literature check can say which kind of
refugium each candidate is.

## Spatial units

| use | S2 level | approx. cell |
|---|---|---|
| Australian land, DEA inputs | 13 | ~1 km |
| Australian land, AGCD climate (0.05 deg) | 10 | ~8 km |
| Australian land, fire weather (BARRA-C2 regridded to the AGCD grid) | 10 | ~8 km |
| Antarctic sea ice (NSIDC 25 km) | 9 | ~16 km |
| Antarctic ice-free land | 13 or finer | ~1 km |
| cross-check with trend.* | 5 | ~290 km |

Cell sizes are approximate and will be confirmed from the registry.

## Layout

| path | what |
|---|---|
| `R/` | registry, pixel-to-cell mapping, metrics and scores on sums |
| `sources/` | one script per input (wofs, fc, agcd, trend_ice, icefree, era5) |
| `regions/` | IBRA, CAPAD, ACBR, ASPA, CCAMLR boundaries and coverage tables |
| `pilots/australia/` | DEA terrestrial pilot |
| `pilots/antarctica/` | sea ice, ocean and ice-free land pilot |
| `checks/` | literature and protected-area comparison tables |
| `notes/` | framework, data source notes, decisions |
| `tests/` | gates and unit checks |

Large or regenerable outputs go to `data/` (gitignored) or object storage.

## Task map

### Australia (DEA terrestrial first)

Results and caveats: [`pilots/australia/README.md`](pilots/australia/README.md);
map: `refugia_candidates_map.png` from `pilots/australia/candidate_map.R`.

- [x] choose test regions: Tasmania (thermal/topographic) and the MacDonnell Ranges IBRA region (arid, hydrological)
- [x] IBRA 7 region polygons for the 9 Tasmanian regions and MAC (`regions/ibra7/`)
- [x] pixel-to-cell mapping for the DEA tile grid at level 13 (cells are taken from the mappings; no separate registry)
- [x] WOfS per-cell, per-year sums and per-pixel persistent-water counts, 1987-2025, IBRA land mask
- [x] Fractional Cover green persistence against each pilot's five driest years (AGCD)
- [x] AGCD v1-0-4 Tmax, Tmin and precipitation trend, signal-to-noise and velocity at level 10, 1971-2025 (run on Gadi, `gadi/`)
- [x] artificial-water mask from Overture Maps (OSM) polygons; stricter water flag
- [x] score within IBRA; joined candidate table per level 13 cell (rds/csv) and small-multiple map
- [x] candidate layer as COG and cell table as parquet (see shared outputs below)
- [ ] gate: one IBRA subregion's cell-sum wet fraction equals a direct WOfS summary
- [ ] hand-checked exclusions for unmapped artificial water near Alice Springs
- [ ] Tasmanian replacement for the green flag (dry years are greener there)

### Fire weather (Tasmania first)

Design, inputs and the access probe: [`notes/fire_weather.md`](notes/fire_weather.md).
Daily McArthur FFDI from xclim (as the Australian Climate Service), per cell and fire year
(July to June); first consumer is epicormic (Tasmanian fires, Fern Tree).

- [x] decide the domain, index, grid, sums and metrics (2026-11-26)
- [x] probe BARRA-C2 on public S3: layout, chunking, packing, Tasmania read times (`sources/barra2_probe.py`)
- [ ] choose rain for KBDI (AGCD or BARRA-C2) and where to run (Gadi `ob53` membership, or S3)
- [ ] daily FFDI per pixel (BARRA-C2 Tmax, max wind, min RH from hourly; regridded to AGCD r005), fire years 1980-2025
- [ ] per-cell, per-fire-year sums at level 10: ndays, sum, sumsq, spring sum, days >= 12, 25, 50, mild days
- [ ] gate: cell-sum cumulative FFDI equals a direct per-pixel computation
- [ ] checks: KBDI and drought factor against CEMS `cems-fire-historical-v1`; seasonal FFDI against Harris and Lucas stations; BARRA-R2 against BARRA-C2
- [ ] trend, signal-to-noise, velocity and persistence (overall and in the five worst fire years), scored within IBRA; candidates into the shared schema
- [ ] projections: `kj66` AUST-05i BARPA-R and CCAM, SSP1-2.6 and SSP3-7.0, same code; `toe` added to the metric vocabulary

### Antarctica

- [x] sea ice: daycount, duration, advance and retreat trend, signal-to-noise, velocity and persistence from trend.ice at level 9, scored within the five trend.ice sectors (CCAMLR area carried per cell); see `pilots/antarctica/README.md`
- [x] gate: Southern Ocean mean duration trend from cell sums matches a direct per-pixel computation from the trend.ice COGs
- [x] external check: integrated ice days from the cell sums against NSIDC Sea Ice Index v4 daily extent (anomaly r = 0.99); daycount adjusted for CDR missing days (1984-1986)
- [x] ocean: summer (Jan-Mar) open-water SST trend, signal-to-noise and velocity south of 60S at level 9 from OISST v2.1 pixels (trend.sst sums are level 5 only); gate passes; see `pilots/antarctica/README.md`
- [x] land: ice-free fraction per level 13 cell from the rock outcrop v7.3 polygons (exact spherical intersection, no raster)
- [x] land: exposure from ERA5 summer 2 m temperature (DJF 1980-2026, NSF NCAR copy on AWS) at level 9, scored within sectors; level 13 ice-free cells take their parent's values
- [x] land: scored within ACBR v2 (Terauds 2016, 16 regions); `pilots/antarctica/acbr_score.R`
- [x] check: candidate overlap with ASPAs (2024 layer), `checks/aspa_overlap.R`
- [ ] land: compare with the AADC ice-free layer (Toth and Terauds 2023) and the controlledburn burn
- [ ] confirm best current ice-free source with colleagues (see `notes/data_sources.md`)

### Shared outputs (both domains)

- [x] one long cell schema for every pilot (`R/schema.R`, `pilots/export_cells.R`): `cells_metrics` (domain, source, period, level, cell, lon, lat, region_set, region, variable, metric, value, units) and `cells_flags` (candidate kind per cell), as parquet (`sources/cells_parquet.py`); the candidate rule per domain in `rules.csv`; `bridge_summary.csv` gives cells, candidates and the share of cells with abs(snr) >= 2 per domain
- [x] figures: `pilots/bridge_map.R` (one exhibit, both domains) and `pilots/results_figures.R` (one framed figure each: Australian thermal holdouts with IBRA regions, Antarctic land trend and holdouts with ACBR labels, the rule in both domains, ERA5 against six stations)
- [x] candidate layers as COGs (`pilots/export_cogs.R`): Tasmania and MacDonnell at 250 m in EPSG:3577, Antarctica at 5 km in EPSG:3031 (flags and trends)

Same rule, different variable (`bridge_summary.csv`, 2026-11-20). Exposure
candidates are the favourable quarter of trend and velocity within a
region; snr is that of the main exposure variable:

| domain | kind | level | cells | candidates | median trend per decade | share abs(snr) >= 2 |
|---|---|---|---|---|---|---|
| Australia land | thermal (Tmax) | 10 | 1,521 | 140 | +0.18 deg C | 0.45 |
| Antarctic sea ice | holdout (ice days) | 9 | 47,839 | 7,584 | -1.4 days | 0.05 |
| Southern Ocean | holdout (summer SST) | 9 | 44,862 | 11,004 | +0.015 deg C | 0.02 |
| Antarctic ice-free land | holdout (summer 2 m T, within ACBR v2) | 9 | 3,346 | 803 | +0.06 deg C | 0.15 |

The Australian warming signal has emerged from interannual noise in about
half the cells; in the Antarctic domains it has in 2 to 15%, so there the
candidates are rankings within the noise rather than detected holdouts.

### Checks

- [ ] candidate overlap with CAPAD and CCAMLR MPAs (ASPAs done, see `checks/README.md`)
- [ ] agreement with published refugia studies (references to verify)
