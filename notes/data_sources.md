# First data sources

Product names below are from the framework draft (2026-11-18). Each endpoint
is to be checked when its pilot starts, as imos-sor did for IMOS. Entries
marked "checked" have been read from a source page.

## Australia, land

| source | variable | feeds | access |
|---|---|---|---|
| DEA Water Observations (WOfS), Landsat 30 m, 1986 on | wet / clear counts | persistence (hydrological refugia) | DEA public bucket on AWS, COGs |
| DEA Fractional Cover | green, non-green, bare fractions | persistence of green cover through droughts | DEA public bucket |
| DEA geomedian, Land Cover, Mangroves, Intertidal | surface state, coastal habitat | context masks, coastal persistence | DEA public bucket |
| BoM AGCD, 0.05 deg daily | Tmax, Tmin, precipitation | trend, signal-to-noise, velocity | NCI; raad.virtualize candidate |
| DEM (SRTM-derived DEM-H, or DEA coastal DEMs) | elevation, aspect, relief | microrefugia proxies | GA / NCI |

## Australia, coast and sea

| source | variable | feeds | access |
|---|---|---|---|
| trend.sst, IMOS L3S SST, trend.chl | SST, chlorophyll | trend, signal-to-noise for coastal cells | trend.* sums, AODN cloud-optimised |

## Antarctica, sea ice and ocean

| source | variable | feeds | access |
|---|---|---|---|
| trend.ice (NSIDC CDR, Bremen ASI) | advance, retreat, duration per ice year | trend and persistence of the ice season | Pawsey Acacia `s3://aad-derived/trend-ice/` (endpoint https://projects.pawsey.org.au) |
| trend.sst south of 60S | SST | trend, signal-to-noise | trend.sst sums are level 5 only; used OISST v2.1 daily pixels from `s3://noaa-cdr-sea-surface-temp-optimum-interpolation-pds` (public, reachable from cloud sessions) |

## Antarctica, ice-free land (checked)

From the hypertidy posts
[Rasterizing ice-free Antarctica](https://www.hypertidy.org/posts/2026-08-19_antarctica-icefree-rasterizing/)
(2026-08-19) and
[Writing controlledburn output in parallel](https://www.hypertidy.org/posts/2026-09-03_controlled-burn/)
(2026-09-03).

- **Rock outcrop polygons**: "Medium resolution vector polygons of Antarctic
  rock outcrop - VERSION 7.3" (Burton-Johnson et al.), 25,954 polygons, file
  `add_rock_outcrop_medium_res_polygon_v7.3.gpkg`, read via

      /vsizip/{/vsicurl/https://github.com/AustralianAntarcticDivision/rema.proc/raw/refs/heads/master/01_rock_classification/Medium_resolution_vector_polygons_of_Antarctic_rock_outcrop_-_VERSION_7.3.zip}/Medium resolution vector polygons of Antarctic rock outcrop - VERSION 7.3/add_rock_outcrop_medium_res_polygon_v7.3.gpkg

- **Target grid**: REMA 32 m mosaic (170318 x 182568), grid spec from
  `/vsicurl/https://raw.githubusercontent.com/mdsumner/rema-ovr/main/rema-vrt/32m_dem_tiles.vrt`.
- **Method**: `controlledburn::burn()` in `approx` or `coverage` mode gives a
  sparse run-length table (about 27 MB, 99.8% empty); written to Zarr in
  parallel (2048 px chunks, ZSTD) and optionally translated to COG.
- **Comparison layer**: AADC "Ice-free Antarctica" (Toth and Terauds 2023),
  https://doi.org/10.26179/7mnh-j215, 100 m GeoTIFF, values 0-3, a union of
  outcrop layers from imagery spanning 1960-2020.

For this repo the burn output does not need a dense raster at all: the
run-length table (or the coverage mode output) can be summed directly into
S2 cells to give ice-free fraction per cell, which is a mergeable sum like
the trend.* statistics.

Caveats from the posts: the polygons are "medium resolution", coarser than
the 32 m grid; controlledburn is pre-release; approx and coverage modes
differ in about 0.3% of cells in the sample tile.

Open: best current ice-free dataset, to confirm with colleagues (Michael,
2026-11-18). The rock outcrop layer is a static map, so persistence and
expansion of ice-free ground over time needs a dated source (or the
1960-2020 Toth and Terauds union by epoch, if it carries dates).

## Region sets

| domain | sets |
|---|---|
| Australia | IBRA 7 regions and subregions, CAPAD, plus imos-sor EEZ (Perth Treaty), AMPs, IMCRA for coastal cells |
| Antarctica | ACBRs, ASPAs, CCAMLR statistical areas and MPAs, AAT |
