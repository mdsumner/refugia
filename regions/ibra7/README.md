# IBRA 7 polygons for the Australian pilot

Fetched 2026-11-18 by `regions/fetch_ibra7.py` (run from the repository
root with `python3 -I regions/fetch_ibra7.py`; standard library only).

- `ibra7_regions_pilot.geojson`: 10 IBRA 7 regions
- `ibra7_subregions_pilot.geojson`: 13 IBRA 7 subregions of those regions

Source: IBRA version 7, DCCEEW, CC BY 4.0, from the ArcGIS REST
FeatureServer layers

    https://gis.environment.gov.au/gispubmap/rest/services/ogc_services/IBRA7_Regions/FeatureServer/0
    https://gis.environment.gov.au/gispubmap/rest/services/ogc_services/IBRA7_Subregions/FeatureServer/0

The MapServer layers of the same name answer queries with null geometry;
use the FeatureServer.

Geometry is EPSG:4326 as reprojected by the server (`outSR=4326`), full
service resolution, coordinates rounded to 6 decimal places. Attribute
fields are the service's own (`REG_CODE_7`, `REG_NAME_7`, `SUB_CODE_7`,
`SUB_NAME_7`, `HECTARES`). Geodesic areas of the polygons agree with
`HECTARES` to within 0.25 percent.

## Regions

| pilot | REG_CODE_7 | region | subregions |
|---|---|---|---|
| Tasmania | BEL | Ben Lomond | BEL01 |
| Tasmania | FUR | Furneaux | FUR01 Wilsons Promontory, FUR02 Flinders |
| Tasmania | KIN | King | KIN01 |
| Tasmania | TCH | Tasmanian Central Highlands | TCH01 |
| Tasmania | TNM | Tasmanian Northern Midlands | TNM01 |
| Tasmania | TNS | Tasmanian Northern Slopes | TNS01 |
| Tasmania | TSE | Tasmanian South East | TSE01 |
| Tasmania | TSR | Tasmanian Southern Ranges | TSR01 |
| Tasmania | TWE | Tasmanian West | TWE01 |
| MacDonnell Ranges | MAC | MacDonnell Ranges | MAC01 McDonnell, MAC02 Watarrka, MAC03 Hartz Range |

FUR01 (Wilsons Promontory) is on the Victorian mainland. Drop it with
`SUB_CODE_7 != "FUR01"` for a Tasmania-only footprint.

## DEA tiles (EPSG:3577, 96 km) intersecting the polygons

- Tasmania without FUR01 (lon 143.819 to 148.499, lat -43.860 to -39.192),
  19 tiles: x56/y25, x56/y26, x57/y22-25, x58/y21-24, x59/y21-24, x59/y26,
  x60/y22-25
- Tasmania with FUR01 (north to lat -38.778), 21 tiles: the above plus
  x58/y26 and x59/y27
- MacDonnell Ranges (lon 131.187 to 135.468, lat -24.580 to -22.957),
  12 tiles: x45/y44-45, x46/y44-45, x47/y44-46, x48/y45-46, x49/y44-46
