---
title: "Climate refugia framework"
date: 2026-11-18
---

This is the framework as set out at the start of the project. The pilot results are in [Where the climate holdouts are](index.html) and the method summary in the [MVP brief](brief.html).

## Purpose and scope

One framework scores candidate climate refugia on a shared cell grid, with two pilots: Australia (terrestrial, led by Digital Earth Australia) and Antarctica (sea ice and ice-free land). Candidates are then checked against biodiversity literature and protection goals.

- Code lives in the `refugia` repo, built on the trend.\* sufficient-statistics pattern and the imos-sor region sets.
- Raw sources stay where they are (DEA on AWS, raad/NCI mirrors, Pawsey Acacia); raad.virtualize supplies byte-reference access where a source is archival netCDF/HDF5.
- Out of scope for the pilots: species distribution modelling and future-scenario projection. Both are natural follow-ons once observed-record refugia are mapped.

## The common concept

A climate refugium is a place where change is buffered relative to its surroundings, so that the conditions a biota depends on persist longer than they do nearby. That definition is the same on land, at sea and in Antarctica; only the variable and the grain change.

Four distinctions from the literature carry across both pilots:

- **Macro vs micro**: regional-scale buffering (a cool coastline, a persistent sea ice zone) vs local buffering below the climate grid (a gorge, a spring, a cold-air pool, a wind-scoured rock outcrop).
- **Holdout vs stepping stone**: a place that keeps its current conditions vs one that becomes suitable as conditions move, and so links habitat over time.
- **Exposure vs persistence**: low change in a climate variable (temperature, sea ice timing) vs persistence of a habitat state (surface water, green cover, ice-free ground).
- **Relative, not absolute**: a refugium is judged against its region. A cell warming at 0.1 C per decade is a refugium if its neighbours warm at 0.3, not otherwise.

The practical consequence is one scoring scheme (next section) fed by domain-specific inputs, always reported as an anomaly against a reference region.

## Metrics

Four metrics per cell, each computable from mergeable sums, so any union of cells or years aggregates exactly as in trend.sst.

| Metric | What it measures | Computed from | Refugium signal |
| --- | --- | --- | --- |
| Trend | Rate of change of the variable (per decade) | Annual or seasonal means per cell; OLS from n, sum t, sum t2, sum x, sum tx, sum x2 | Low relative to the reference region |
| Signal-to-noise | Trend over interannual standard deviation; a proxy for time of emergence | Same sums plus residual variance | Low: change not yet outside natural variability |
| Climate velocity | Trend divided by the local spatial gradient (km per decade) | Trend field plus neighbour differences on the cell grid | Low: conditions move slowly, or the cell is a sink others move toward |
| Persistence | Fraction of observations in the habitat state, and its stability through extreme years | Counts: n_state over n_clear (WOfS is already this form) | High, especially in drought or low-ice years |

The score is the cell's standing against its reference region (IBRA region, IMCRA province, ACBR or CCAMLR area), as a percentile per metric. A candidate refugium is in the favourable tail on persistence and at least one exposure metric. Keeping the metrics separate, rather than collapsing them early, lets the literature check say which kind of refugium each candidate is.

Reference period: the full observed record of each source, with 1991-2020 as the baseline for anomalies where the record allows.

## Spatial units

S2 cells are the common unit, at a finer level than trend.\*'s level 5 (about 290 km), with region sets layered on top for reference and reporting.

| Use | S2 level | Approx. cell size | Why |
| --- | --- | --- | --- |
| Australian land, DEA inputs | 13 | about 1 km | Aggregates 30 m Landsat pixels while keeping gorges, wetlands and ranges distinct |
| Australian land, climate inputs (AGCD 0.05 deg) | 10 | about 8 km | Matches the climate grid; finer adds no information |
| Antarctic sea ice (NSIDC 25 km) | 9 | about 16 km | Close to the native grid |
| Antarctic ice-free land | 13 or finer | about 1 km | Outcrops are small and scattered |
| Cross-checks with trend.\* | 5 | about 290 km | Parents of the finer cells, so results roll up exactly |

Cell sizes are approximate and vary with latitude; they will be confirmed from the registry when built.

Region sets (reference regions and reporting units):

- **Australia**: IBRA 7 bioregions and subregions, CAPAD protected areas, plus the imos-sor marine sets (EEZ as amended by the Perth Treaty, Australian Marine Parks, IMCRA) for coastal cells.
- **Antarctica**: Antarctic Conservation Biogeographic Regions (ACBRs), Antarctic Specially Protected Areas (ASPAs), CCAMLR statistical areas and MPAs, and the AAT.

## First ports of call

These are the first sources to wire in, by domain. Product names are from memory; each endpoint gets checked when its pilot starts, as imos-sor did for IMOS.

| Domain | Source | Variable | Metric it feeds | Access |
| --- | --- | --- | --- | --- |
| Australia land | DEA Water Observations (WOfS), Landsat 30 m, 1986 on | Wet / clear counts | Persistence (hydrological refugia) | DEA public bucket on AWS, COGs |
| Australia land | DEA Fractional Cover | Green, non-green, bare fractions | Persistence of green cover through droughts | DEA public bucket |
| Australia land | DEA geomedian, Land Cover, Mangroves, Intertidal | Surface state, coastal habitat | Context masks, coastal persistence | DEA public bucket |
| Australia land | BoM AGCD, 0.05 deg daily | Tmax, Tmin, precipitation | Trend, signal-to-noise, velocity | NCI; raad.virtualize candidate |
| Australia land | DEM (SRTM-derived DEM-H, or DEA coastal DEMs) | Elevation, aspect, relief | Microrefugia proxies (cold-air pooling, shading) | GA / NCI |
| Australia coast and sea | trend.sst, IMOS L3S SST, trend.chl | SST, chlorophyll | Trend, signal-to-noise for coastal cells | Existing trend.\* sums, AODN cloud-optimised |
| Antarctica sea ice | trend.ice (NSIDC CDR, Bremen ASI) | Advance, retreat, duration per ice year | Trend and persistence of the ice season | Pawsey Acacia `s3://aad-derived/trend-ice/` |
| Antarctica ocean | trend.sst south of 60S | SST | Trend, signal-to-noise | trend.sst sums |
| Antarctica land | Rock outcrop polygons v7.3 (Burton-Johnson et al.) burned onto the REMA 32 m grid with controlledburn ([post](https://www.hypertidy.org/posts/2026-08-19_antarctica-icefree-rasterizing/)); AADC Ice-free Antarctica (Toth and Terauds 2023) as comparison; best current source to confirm with colleagues | Ice-free extent | Persistence and expansion of ice-free ground | AAD rema.proc on GitHub; AADC DOI 10.26179/7mnh-j215 |
| Antarctica land and air | REMA DEM, ERA5 | Elevation, near-surface temperature | Exposure; microrefugia proxies | PGC, Copernicus / NCI |

One pattern recurs: WOfS and trend.ice already store counts or per-year states, which are mergeable sums. Each source grid still needs a one-off pixel-to-cell mapping in the trend.sst style, but no new statistics design.

## Pilots

Each pilot takes one test region end to end before scaling, with the same gates as trend.sst: a one-region check, a cross-check against a directly computed value, then backfill.

**Australia (DEA terrestrial first)**

1. Test region: Tasmania plus one arid IBRA region, so both wet-temperate and dryland refugia types are exercised.
2. Map WOfS and Fractional Cover pixels to S2 level 13 cells; store per-cell, per-year counts and sums.
3. Persistence: wet fraction and green-cover fraction overall, and in the 2017-2019 drought years against the long-term mean.
4. Exposure: AGCD Tmax and precipitation trend and signal-to-noise at level 10, joined to the level 13 cells as parents.
5. Score against the IBRA region and output a candidate refugia layer (COG plus a parquet table of cell scores).
6. Gate: one IBRA subregion's cell-sum wet fraction equals a direct WOfS summary for the same area.

**Antarctica**

1. Sea ice: trend and signal-to-noise of ice season duration and retreat day from trend.ice, scored against CCAMLR areas.
2. Ocean: SST trend south of 60S from trend.sst sums.
3. Land: ice-free area per cell from the outcrop maps, with ERA5 summer temperature trend as exposure, scored against ACBRs.
4. Output the same candidate layer and table as Australia.
5. Gate: the Southern Ocean mean duration trend from cell sums matches a direct per-pixel computation from the trend.ice COGs.

The Antarctic sea ice part should come first in practice, because trend.ice already holds the per-year values.

## Checking against literature and goals

Candidates are checked three ways: against published refugia maps, against known biodiversity strongholds, and against protection targets. References below are from memory and get verified (and linked) when the check runs.

| Check | Australia | Antarctica |
| --- | --- | --- |
| Concept and method | Keppel et al. 2012 (refugia as safe havens); Morelli et al. 2016 (managing refugia); Ashcroft 2010 | Same framing, plus Lee et al. 2017 on ice-free area expansion |
| Published refugia maps | Reside et al. (NCCARF refugia work, around 2013); arid-zone waterhole studies | Sea ice refugia and krill / penguin habitat studies; ACBR analyses (Terauds and Lee) |
| Biodiversity strongholds | ALA occurrence density for climate-sensitive taxa; threatened species habitat (EPBC) | Penguin colonies, moss and lichen sites, SCAR biodiversity datasets |
| Protection goals | CAPAD coverage of candidates; national 30 by 30 commitment; Kunming-Montreal GBF Targets 3 and 8 | ASPA and CCAMLR MPA coverage of candidates; CCAMLR climate change response work |

The output of the check is a short table per pilot: share of candidate area inside protected areas, agreement with published refugia, and the candidates with no protection and strong signal, which are the most useful finding for policy.

## Repo layout and open questions

The `refugia` repo follows the trend.\* layout: an R package for the cell logic, scripts per source, committed checks, large outputs off-repo.

| Path | What |
| --- | --- |
| `R/` | Registry at levels 9, 10, 13; pixel-to-cell mapping; metric and score functions on sums |
| `sources/` | One script per input (wofs, fc, agcd, trend_ice, ice_free, era5) |
| `regions/` | IBRA, CAPAD, ACBR, ASPA, CCAMLR boundaries and their cell coverage tables |
| `pilots/australia/`, `pilots/antarctica/` | Pilot runs, gates and outputs |
| `checks/` | Literature and protected-area comparison tables |
| `notes/` | This framework, data endpoint notes, decisions |

Open questions (as of 2026-11-18):

- [ ] Australian test region: Tasmania plus one arid IBRA region, or something else?
- [ ] Where do compute and outputs live: Nectar and Pawsey Acacia (as trend.ice), or NCI?
- [ ] Should the Antarctic land component be in the first pilot, or follow the sea ice part?
- [ ] Is the observed record enough for the pilots, with projections (CMIP6, NARCliM) deferred?
