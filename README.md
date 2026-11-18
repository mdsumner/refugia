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

- [x] choose test regions: Tasmania (thermal/topographic) and the MacDonnell Ranges IBRA region (arid, hydrological)
- [ ] fetch IBRA 7 region polygons for TAS* and MAC (host blocked from the cloud container; see `pilots/australia/README.md`)
- [ ] S2 registry at levels 10 and 13 over the test region
- [ ] map WOfS and Fractional Cover pixels to level 13 cells
- [ ] per-cell, per-year counts and sums; persistence overall and in 2017-2019
- [ ] AGCD Tmax and precipitation trend and signal-to-noise at level 10
- [ ] score against IBRA; candidate layer (COG) and cell table (parquet)
- [ ] gate: one IBRA subregion's cell-sum wet fraction equals a direct WOfS summary

### Antarctica

- [ ] sea ice: duration and retreat-day trend and signal-to-noise from trend.ice, scored against CCAMLR areas
- [ ] gate: Southern Ocean mean duration trend from cell sums matches a direct per-pixel computation from the trend.ice COGs
- [ ] ocean: SST trend south of 60S from trend.sst sums
- [ ] land: ice-free fraction per cell from the controlledburn rock outcrop burn; exposure from ERA5 summer temperature; scored against ACBRs
- [ ] confirm best current ice-free source with colleagues (see `notes/data_sources.md`)

### Checks

- [ ] candidate overlap with CAPAD, ASPAs, CCAMLR MPAs
- [ ] agreement with published refugia studies (references to verify)
