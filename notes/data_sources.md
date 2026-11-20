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

Antarctic region layers come from the AADC EDS server, which the cloud
sessions cannot reach; `gadi/aad_layers.sh` fetches them on Gadi. Checked
2026-11-20 (Michael, Gadi, GDAL in the singularity container):

    /vsicurl/https://data.aad.gov.au/eds/api/dataset/6825D031-0752-4F8E-82E4-F4DC3A88C6D6/object/download?prefix=Shapefiles%20from%20Terauds%20et%20al%202012%20DDI%2FACBRs%2FACBRs%20for%20export.shp

opens as a polygon layer of 24,464 features in WGS 84 south polar
stereographic (extent -2661826, -2118970 to 2596665, 2321752). This is ACBR
version 1 (Terauds et al. 2012, 15 regions). Version 2 (Terauds and Lee
2016, 16 regions) is the current definition and should replace it. The same
dataset has ASPA/ASMA layers from October 2011 under
`ASPAs/ERA_ASPA_ASMA_Oct2011/` (`ASMA_points_Aug2011.shp` confirmed; the
ASPA polygons are to be found in that folder). A current ASPA layer would
be better than the 2011 snapshot for the protected-area check.

Current ASPA layer (found by Michael, 2026-11-20): Terauds, A., Wauchope,
H.S., Wen, W. and Lee, J.R. (2024) Antarctic Specially Protected Areas
(Points and Polygons) 2024 Update, Ver. 1, Australian Antarctic Data
Centre, doi:10.26179/4qk0-cz71 (AADC dataset AAS_4296_Updated_ASPAs_2024,
22 files, 2.31 MB). Use its polygon layer for the protected-area overlap;
the point layer marks ASPAs too small to draw.

ACBR and ice-free ecosystem sources (found by Michael on the AADC, 2026-11-20):

- **ACBR v2**: "An update of the Antarctic Conservation Biogeographic
  Regions (ACBRs)", Terauds (2016), AADC record
  AAS_4296_Antarctic_Conservation_Biogeographic_Regions_v2. 16 regions,
  covers all ice-free areas, shapefiles. It supersedes the v1 ACBR shapefile
  in ASAC_3095_Antarctic_Biogeography_shapefiles (Terauds et al. 2012, built
  on the ADD v5 ice-free map), so scoring uses v2; v1 is kept only as the
  record of what `gadi/aad_layers.sh` first fetched.
- **Antarctic Ecosystem Inventory**: Toth, Terauds, Chown et al. (2024),
  AADC record (as given) AAS_4568_The_Antarctic_Ecosystem_Inventory.
  Ice-free land at 100 m in three tiers: 5 major environmental units
  (Tier1_MEUs.tif), 31 habitat complexes (tier 2) and 309 regional
  ecosystems (tier 3), plus abiotic rasters (elevation, slope, rugosity,
  wind, radiation, mean temperature and degree days for 2014-15, precip,
  melt, cloud) and a confidence raster. This is the better ice-free base
  than rock outcrop v7.3 for the pilot: it gives the ice-free footprint and
  habitat context per cell (share of each habitat as a mergeable area sum),
  and the tier 2 habitats are the natural reference regions within an ACBR.
  EDS dataset id cb8c6d56-8a78-4032-a455-cb58cb4bb6de, objects under
  `AADC_4568_2024/`, for example
  `.../object/download?prefix=AADC_4568_2024%2FTIER%201%20Major%20Environmental%20Units%2FTier1_MEUs.tif`
  (and `Tier1_MEUs.tif.vat.dbf`). Fetched on Gadi by `gadi/aad_layers.sh`
  section 4, written as COGs.
