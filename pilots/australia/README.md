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

IBRA 7 regions and subregions are served at
`https://gis.environment.gov.au/gispubmap/rest/services/ogc_services/IBRA7_Regions/MapServer/0`
(and `IBRA7_Subregions`). That host, the IMAS geoserver and the DCCEEW hub
are refused by the cloud container's network policy, so the polygons need
to be fetched elsewhere or the host allowed.

## Steps

- [ ] IBRA 7 polygons for Tasmanian regions and MAC, with subregions
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
