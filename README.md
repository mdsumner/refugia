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
- [ ] candidate layer as COG and cell table as parquet
- [ ] gate: one IBRA subregion's cell-sum wet fraction equals a direct WOfS summary
- [ ] hand-checked exclusions for unmapped artificial water near Alice Springs
- [ ] Tasmanian replacement for the green flag (dry years are greener there)

### Antarctica

- [x] sea ice: daycount, duration, advance and retreat trend, signal-to-noise, velocity and persistence from trend.ice at level 9, scored within the five trend.ice sectors (CCAMLR area carried per cell); see `pilots/antarctica/README.md`
- [x] gate: Southern Ocean mean duration trend from cell sums matches a direct per-pixel computation from the trend.ice COGs
- [x] external check: integrated ice days from the cell sums against NSIDC Sea Ice Index v4 daily extent (anomaly r = 0.99); daycount adjusted for CDR missing days (1984-1986)
- [x] ocean: summer (Jan-Mar) open-water SST trend, signal-to-noise and velocity south of 60S at level 9 from OISST v2.1 pixels (trend.sst sums are level 5 only); gate passes; see `pilots/antarctica/README.md`
- [x] land: ice-free fraction per level 13 cell from the rock outcrop v7.3 polygons (exact spherical intersection, no raster)
- [ ] land: exposure from ERA5 summer temperature; scored against ACBRs
- [ ] land: compare with the AADC ice-free layer (Toth and Terauds 2023) and the controlledburn burn
- [ ] confirm best current ice-free source with colleagues (see `notes/data_sources.md`)

### Checks

- [ ] candidate overlap with CAPAD, ASPAs, CCAMLR MPAs
- [ ] agreement with published refugia studies (references to verify)
