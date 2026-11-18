# Australia pilot

Two test regions, chosen 2026-11-18:

- **Tasmania**: thermal and topographic refugia (alpine, rainforest, the
  Wilderness World Heritage Area). Western cloud and terrain shadow will
  thin clear Landsat observations; check `count_clear` before reading `wet`.
- **MacDonnell Ranges** (IBRA region MAC): hydrological refugia (gorges,
  permanent waterholes). Clear skies, so WOfS and Fractional Cover are at
  their most reliable.

## DEA inputs (checked 2026-11-18)

Both read anonymously over HTTPS from
`https://dea-public-data.s3.ap-southeast-2.amazonaws.com/` (or
`s3://dea-public-data`, region ap-southeast-2).

| product | prefix | per tile-year files | years |
|---|---|---|---|
| WOfS annual summary | `derivative/ga_ls_wo_fq_cyear_3/2-0-0/xNN/yNN/YYYY--P1Y/` | `..._final_count_wet.tif`, `_count_clear.tif`, `_frequency.tif` | 1986-2025 |
| Fractional Cover annual percentiles | `derivative/ga_ls_fc_pc_cyear_3/4-0-0/xNN/yNN/YYYY--P1Y/` | `..._final_{bs,npv,pv}_pc_{10,50,90}.tif` | 1987-2025 |

Other WOfS summaries exist beside the calendar-year one:
`ga_ls_wo_fq_myear_3` (multi-year), `ga_ls_wo_fq_nov_mar_3` and
`ga_ls_wo_fq_apr_oct_3` (seasonal).

Tile grid: EPSG:3577, 30 m, 3200 x 3200 px tiles (96 km), internal 800 px
blocks, overviews 2-32, int16 with nodata -999. Tile origin
(-4416000, -6912000), so tile xNN/yNN has

    left   = -4416000 + 96000 * x
    bottom = -6912000 + 96000 * y

WOfS `count_wet` and `count_clear` are already mergeable sums: summed over
the pixels of an S2 cell they give the cell's wet and clear counts exactly,
and summed over years they give any multi-year fraction.

Tiles covering each region's bounding box (from a lon/lat box transformed to
EPSG:3577; the IBRA polygons will trim these):

| region | lon/lat box | tiles x | tiles y | count |
|---|---|---|---|---|
| Tasmania | 143.8 to 148.5 E, 43.7 to 39.5 S | 56-60 | 21-26 | 30 |
| MacDonnell Ranges | 130.0 to 136.0 E, 24.6 to 22.8 S (approximate, wider than MAC) | 43-50 | 44-46 | 24 |

Sample tiles x58/y23 (Tasmania) and x46/y45 (MacDonnell) have all 40 WOfS
years and 39 FC years.

## Region polygons

IBRA 7 regions and subregions for both pilots are in `regions/ibra7/`
(fetched by `regions/fetch_ibra7.py` from the DCCEEW FeatureServer; see
`regions/ibra7/README.md`). Trimmed to the polygons, Tasmania needs 19 DEA
tiles (21 with Wilsons Promontory, FUR01) and MAC needs 12.

## Steps

- [x] IBRA 7 polygons for Tasmanian regions and MAC, with subregions
- [ ] S2 registry at levels 10 and 13 over both regions
- [x] pixel-to-cell mapping for the DEA 30 m tile grid (one per tile, reused for every year and product): `build_tile_mapping()`, gated by `sources/wofs_gate.R`
- [ ] per-cell, per-year WOfS wet/clear sums and FC pv_pc_50 sums
- [ ] persistence overall and in 2017-2019; gate against a direct WOfS summary of one subregion
- [ ] AGCD exposure at level 10

## First gate results (2019, S2 level 13)

`Rscript sources/wofs_gate.R <x> <y> <year> <level>` builds the tile mapping,
sums WOfS `count_wet` and `count_clear` into cells, and checks that every
pixel maps once, that cell sums add to tile totals, and that one cell's sums
match its pixels (with a sample of pixel centres confirmed inside the cell).

| tile | region | runs | cells | mapping time | clear obs per pixel |
|---|---|---|---|---|---|
| x46y45 | MacDonnell | 413,151 | 8,808 | 8.4 s | about 37 |
| x58y23 | Tasmania | 340,722 | 8,977 | 6.8 s | about 12 |

The threefold gap in clear observations is the Tasmanian cloud effect; scores
there should carry `n` and `clear` so low-information cells can be flagged.

PROJ is run with `PROJ_NETWORK=OFF`, so EPSG:3577 to EPSG:4326 uses the
non-grid GDA94 transformation (about 1 m difference, far below the 30 m
pixel and 1 km cell).

## First persistence run (WOfS 1987-2025, level 13)

`Rscript pilots/australia/wofs_persistence.R <sums_dir> <outdir>` over the
backfill (1,237 of 1,240 tile-years; x56y25, x60y22 and x60y23 have no 1986
summary at DEA). Cells are assigned to IBRA regions by centre; FUR is dropped.

| IBRA | cells | water-bearing | candidates | median clear looks per pixel per year |
|---|---|---|---|---|
| MAC | 37,693 | 757 | 45 | 22.6 |
| TWE | 14,590 | 14,573 | 1,762 | 5.5 |
| TSE | 10,386 | 10,274 | 1,318 | 10.1 |
| TCH | 7,284 | 7,272 | 840 | 7.9 |
| TSR | 7,194 | 7,191 | 1,078 | 6.6 |
| BEL | 6,391 | 6,339 | 506 | 9.4 |
| TNS | 6,032 | 6,026 | 924 | 11.1 |
| KIN | 4,198 | 4,144 | 472 | 8.0 |
| TNM | 3,981 | 3,887 | 498 | 17.0 |

Water-bearing: wet fraction over the record at least 1/1180 (one pixel's
worth). Candidate: wet in at least 90% of observed years and in the upper
quarter of its region for wet fraction held through 2017-2019.

Rough check against known MacDonnell waterholes (approximate site
coordinates): Glen Helen and Ormiston Gorge each have a candidate cell within
1 km; Ellery Creek Big Hole is water-bearing but wet in only 16 of 39 years at
cell level; Redbank Gorge, Simpsons Gap and Palm Valley are not detected.

What this shows:

- **MacDonnell works but dilutes small pools.** A 1 km cell averages a
  waterhole of a few pixels into its dry surroundings, and narrow gorge pools
  are often below or shadowed at 30 m. Next: keep the pixel-level maximum
  (or count of persistently wet pixels) per cell beside the sums.
- **Artificial water ranks high.** The top MAC candidate (about 134.0 E,
  23.7 S) is near Alice Springs and is likely ponds, not habitat. Next: mask
  with DEA Waterbodies or land use.
- **Tasmania is not discriminated by water.** Nearly every cell is
  water-bearing (median wet fraction about 1%), from sea in coastal cells and
  dense lakes and drainage. Next: an ocean mask, and lean on the thermal and
  green-cover metrics there, as planned.
- The 2017-2019 dry period is a mainland drought; for Tasmania another
  window should be chosen.

## Persistent-water pixels (WOfS 1987-2025, IBRA land mask)

`sources/wofs_pixel_years.R` counts, per 30 m pixel, the years observed
(count_clear >= 1) and the years wet (count_wet >= 1). Pixels outside IBRA
are dropped, because coastal tiles otherwise count the sea as permanent
water (x56y25 went from 9.8 M to 901 wet-90 pixels with the mask).
`pilots/australia/wofs_pixel_summary.R` gives one row per cell.

| pilot | land cells | cells with a wet-90 pixel | cells with a wet-50 pixel | wet-90 pixels |
|---|---|---|---|---|
| MacDonnell | 38,590 | 47 | 777 | 573 |
| Tasmania | 68,191 | 10,608 | 20,596 | 1,677,670 |

Wet-90: land pixel with at least 20 observed years, wet in at least 90% of
them. Wet-50: the same at 50%.

Known MacDonnell waterholes, pixels within 3 km of approximate site
coordinates:

| site | wet-90 | wet-50 | ever wet |
|---|---|---|---|
| Glen Helen | 11 | 80 | 2,309 |
| Ormiston Gorge | 0 | 13 | 6,961 |
| Ellery Creek Big Hole | 0 | 3 | 9,757 |
| Simpsons Gap | 0 | 4 | 999 |
| Redbank Gorge | 0 | 0 | 3,898 |
| Palm Valley | 0 | 0 | 972 |

Reading:

- The pixel counts separate the permanent pools from the many pixels wet
  after floods ("ever wet"), which the cell sums could not.
- At 30 m, WOfS sees Glen Helen as permanent and Ormiston as wet in most
  years; the narrow or shaded pools at Redbank, Simpsons Gap and Palm Valley
  are below what it resolves. Those need a site list or finer imagery.
- The strongest MacDonnell signal (cells near 133.80 to 133.86 E, 23.73 to
  23.78 S, about 360 of the 573 wet-90 pixels) is just south of Alice
  Springs and is most likely wastewater ponds. A second cluster near
  131.98 E, 23.77 S is unidentified. Artificial water still needs a mask.
- Tasmania has persistent water in 16% of land cells (lakes, reservoirs,
  wetlands), so water marks habitat there but does not single out refugia.

## Climate exposure (AGCD v1-0-4, 1971-2025, S2 level 10)

Cell sums were computed on Gadi (`gadi/agcd_sums.pbs`, then
`gadi/agcd_combine.R`); `pilots/australia/agcd_exposure.R` turns them into
per-cell climatology, trend, signal-to-noise and, for temperature, climate
velocity (trend over local gradient of the climatology), each scored within
its IBRA region. Thermal candidate: lowest quarter of the region for both
the tmax trend and the tmax velocity. Median [10th, 90th percentile]:

| IBRA | cells | tmax trend C/decade | tmin trend C/decade | tmax velocity km/decade | precip % per decade | thermal candidates |
|---|---|---|---|---|---|---|
| MAC | 582 | 0.25 [0.18, 0.31] | 0.17 [0.12, 0.25] | 6.85 [3.23, 20.76] | -1.69 [-4.34, -0.26] | 72 |
| TWE | 228 | 0.16 [0.14, 0.19] | 0.07 [0.05, 0.13] | 2.06 [1.10, 6.12] | -0.98 [-2.65, 0.39] | 22 |
| TSE | 159 | 0.17 [0.13, 0.21] | 0.11 [0.03, 0.21] | 1.87 [0.83, 4.98] | -1.71 [-2.89, -0.69] | 12 |
| TCH | 114 | 0.17 [0.13, 0.21] | 0.05 [0.02, 0.09] | 1.59 [0.67, 4.44] | -1.29 [-2.80, 0.52] | 14 |
| TSR | 114 | 0.20 [0.16, 0.22] | 0.06 [0.02, 0.09] | 1.59 [0.66, 4.27] | -1.06 [-2.20, 0.57] | 9 |
| BEL | 99 | 0.17 [0.12, 0.18] | 0.12 [0.08, 0.16] | 1.24 [0.56, 3.58] | -0.26 [-1.80, 1.65] | 5 |
| TNS | 96 | 0.12 [0.10, 0.15] | 0.12 [0.08, 0.16] | 1.27 [0.71, 3.31] | -1.94 [-2.78, -1.24] | 4 |
| TNM | 66 | 0.18 [0.14, 0.19] | 0.07 [0.04, 0.11] | 2.35 [0.96, 10.60] | -2.14 [-3.56, -1.32] | 2 |
| KIN | 63 | 0.13 [0.10, 0.19] | 0.08 [0.00, 0.10] | 4.15 [2.24, 12.76] | -1.91 [-2.73, -1.45] | 0 |

Reading:

- MacDonnell warms faster (tmax about 0.25 C per decade) and its gentle
  gradients give velocities several times Tasmania's; the ranges themselves
  are where velocity drops.
- In Tasmania the Central Highlands candidates cluster around 146 E, 41.5 to
  41.8 S (Central Plateau and Great Western Tiers), as expected for
  topographic buffering. Tmin warms slowly there (about 0.05 C per decade).
- AGCD is an analysis with a long length scale (250 km for tmax), so trends
  in sparsely stationed country (western Tasmania, much of MAC) are partly
  interpolation; read signal-to-noise and station density beside the trend.
- Rainfall has declined over 1971-2025 in most regions, most in TNM, TNS
  and KIN.

## Green-cover persistence (DEA Fractional Cover, 1988-2025)

`pilots/australia/fc_persistence.R`. Green cover is the annual 10th
percentile of pv (the driest part of each year), compared between the record
and each pilot's five driest years by AGCD rainfall (MacDonnell 1994, 1996,
2002, 2009, 2019; Tasmania 2006, 2008, 2014, 2015, 2017).

| IBRA | cells | median green10 % | median dry-year ratio | median trend % per decade |
|---|---|---|---|---|
| MAC | 37,693 | 7.9 | 0.66 | 0.50 |
| TWE | 14,590 | 57.6 | 1.06 | 2.82 |
| TSE | 10,386 | 44.8 | 1.01 | 1.98 |
| TCH | 7,281 | 48.0 | 1.04 | 2.28 |
| TSR | 7,194 | 59.7 | 1.07 | 2.96 |
| BEL | 6,391 | 54.6 | 1.04 | 2.71 |
| TNS | 6,032 | 57.0 | 1.04 | 2.72 |
| KIN | 4,198 | 57.5 | 1.05 | 1.88 |
| TNM | 3,981 | 34.0 | 0.99 | 1.60 |

- MacDonnell loses a third of its dry-season green cover in dry years, so
  cells that hold it are a real signal.
- Tasmanian green cover is slightly higher in dry years (ratio above 1):
  growth there is limited by light and temperature more than water, so this
  metric does not mark refugia in Tasmania.
- The Tasmanian greening trend (2 to 3 % per decade) may include the
  Landsat 7 to 8 and 9 transition; check against a single-sensor period
  before reading it as change.

## Joined candidates (`pilots/australia/join_candidates.R`)

One row per level 13 cell, with water, green and thermal flags (thermal from
the level 10 parent). Counts are of level 13 cells:

| IBRA | cells | water | green | thermal | water+green | green+thermal | water+thermal | all three |
|---|---|---|---|---|---|---|---|---|
| MAC | 37,693 | 772 | 8,759 | 4,480 | 189 | 446 | 96 | 9 |
| TWE | 14,590 | 3,809 | 1,603 | 1,312 | 308 | 80 | 485 | 30 |
| TSE | 10,386 | 2,548 | 1,741 | 737 | 273 | 101 | 164 | 6 |
| TCH | 7,281 | 2,333 | 1,149 | 912 | 163 | 262 | 103 | 28 |
| TSR | 7,194 | 2,214 | 1,008 | 582 | 252 | 235 | 149 | 66 |
| BEL | 6,391 | 920 | 1,143 | 367 | 49 | 67 | 80 | 3 |
| TNS | 6,032 | 2,206 | 1,128 | 260 | 178 | 18 | 144 | 3 |
| KIN | 4,198 | 943 | 630 | 0 | 77 | 0 | 0 | 0 |
| TNM | 3,981 | 1,550 | 585 | 81 | 245 | 57 | 35 | 20 |

Caveats before reading the overlaps:

- Green and thermal flags are within-region quartiles, so they flag a fixed
  share of each region by construction; they rank, they do not threshold.
- The water flag needs only one wet-50 pixel, which is lax: the nine MAC
  "all three" cells each have one or two such pixels. A stricter flag
  (wet-90, or several wet-50 pixels) and the artificial-water mask come next.
- For Tasmania the green flag should be dropped or replaced (see above), which
  leaves water plus thermal as the meaningful pair there.

## Artificial-water mask and stricter water flag

`sources/overture_water.py` reads Overture Maps base/water (OpenStreetMap
derived, public bucket `s3://overturemaps-us-west-2`, release 2026-10-21.0)
for each pilot box and keeps polygons that are artificial by class
(reservoir, basin, wastewater, canal and ditch areas, pools) or that are
unclassed water or pond polygons drawn as near rectangles (area over minimum
rotated rectangle >= 0.85, at most 12 vertices). `sources/water_mask.R` then
marks each persistent-water pixel (wet in >= 50% of 20+ observed years)
within 60 m of one of those polygons as artificial.

Sources tried and not used: DEA Waterbodies v3 has no artificial attribute
and its pixel-traced outlines do not separate ponds from pools by shape (the
Alice Springs ponds score 0.57-0.74, merged); DEA Land Cover level 3 shows
cultivated and bare classes around both the ponds and Glen Helen. GA, OSM
Overpass and Geofabrik hosts are blocked from the cloud container.

The water flag is now: at least one natural pixel wet in >= 90% of years, or
at least three wet in >= 50%. Cells whose persistent water is all on mapped
artificial water are kept as `water_artificial`.

| IBRA | water | water_artificial | water+green | green+thermal | water+thermal | all three |
|---|---|---|---|---|---|---|
| MAC | 257 | 14 | 98 | 446 | 22 | 0 |
| TWE | 1,848 | 872 | (green not used) | | 250 | |
| TSE | 1,684 | 168 | | | 80 | |
| TCH | 1,846 | 96 | | | 64 | |
| TSR | 1,511 | 39 | | | 96 | |
| BEL | 544 | 21 | | | 46 | |
| TNS | 1,439 | 183 | | | 103 | |
| KIN | 695 | 38 | | | 0 | |
| TNM | 1,183 | 74 | | | 23 | |

`n_kinds` no longer counts the green flag in Tasmania.

Per-pixel totals, MAC: 593 persistent pixels are artificial and 4,757 natural
(wet-90: 188 artificial, 385 natural). The Alice Springs sewage ponds
(133.83-133.86E) are caught. Not caught, because they are not mapped as
artificial: about 200 wet-90 pixels at 133.80-133.81E, 23.75-23.78S, south
west of the ponds (possibly effluent-fed wetland; not verified), and the
cluster at 131.98E, 23.78S (still unidentified). A short hand-checked
exclusion list may be needed for these.

Tasmania: 668,113 persistent pixels are artificial, mostly the hydro storages
(Great Lake, Lake Gordon, Lake Pedder and others mapped as reservoirs), which
include natural lakes raised by dams. Persistent natural water remains in
about 15% of land cells, so water still does not discriminate there.

With the stricter flag no MAC cell is flagged by all three kinds; the nine
earlier ones each rested on one or two wet-50 pixels.

Map: `pilots/australia/candidate_map.R` writes
`refugia_candidates_map.png`, one row per pilot, one panel per kind plus a
panel for cells with two or more kinds.
