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
