"""Fetch IBRA 7 region and subregion polygons for the Australian pilot.

Source: Interim Biogeographic Regionalisation for Australia (IBRA) version 7,
Department of Climate Change, Energy, the Environment and Water (DCCEEW),
served by the ArcGIS REST FeatureServer endpoints (the MapServer layers
of the same name return attributes only, with null geometry)

  https://gis.environment.gov.au/gispubmap/rest/services/ogc_services/IBRA7_Regions/FeatureServer/0
  https://gis.environment.gov.au/gispubmap/rest/services/ogc_services/IBRA7_Subregions/FeatureServer/0

Licence: CC BY 4.0 (Commonwealth of Australia, DCCEEW).

Geometry is requested in EPSG:4326 (outSR=4326) at full service resolution
(no maxAllowableOffset), coordinates rounded to 6 decimal places (about
0.1 m), written as GeoJSON, one file per layer, with the
service attribute fields kept as is.

Pilot regions:
  Tasmania: every IBRA region in the state (TAS_CODES)
  MacDonnell Ranges: MAC

Run from the repository root (standard library only):

  python3 -I regions/fetch_ibra7.py

Writes regions/ibra7/ibra7_regions_pilot.geojson and
regions/ibra7/ibra7_subregions_pilot.geojson.
"""

import json
import os
import sys
import urllib.parse
import urllib.request

BASE = "https://gis.environment.gov.au/gispubmap/rest/services/ogc_services"
TAS_CODES = ["BEL", "FUR", "KIN", "TCH", "TNM", "TNS", "TSE", "TSR", "TWE"]
PILOT_CODES = TAS_CODES + ["MAC"]
LAYERS = {
    "regions": ("IBRA7_Regions", "REG_CODE_7,REG_NAME_7,HECTARES"),
    "subregions": ("IBRA7_Subregions",
                   "SUB_CODE_7,SUB_NAME_7,REG_CODE_7,REG_NAME_7,HECTARES"),
}
PAGE = 5
DIGITS = 6  # decimal degrees kept, about 0.1 m


def query(service, fields, offset):
    where = "REG_CODE_7 IN ({})".format(
        ",".join("'{}'".format(c) for c in PILOT_CODES))
    params = {
        "where": where,
        "outFields": fields,
        "returnGeometry": "true",
        "outSR": "4326",
        "orderByFields": "OBJECTID",
        "resultOffset": str(offset),
        "resultRecordCount": str(PAGE),
        "f": "geojson",
    }
    url = "{}/{}/FeatureServer/0/query?{}".format(
        BASE, service, urllib.parse.urlencode(params))
    with urllib.request.urlopen(url, timeout=300) as r:
        return json.load(r)


def rnd(x):
    if isinstance(x, list):
        return [rnd(v) for v in x]
    return round(x, DIGITS)


def fetch(service, fields):
    feats = []
    while True:
        d = query(service, fields, len(feats))
        got = d.get("features", [])
        feats.extend(got)
        if len(got) < PAGE:
            break
    for f in feats:
        f.pop("id", None)
        f["geometry"]["coordinates"] = rnd(f["geometry"]["coordinates"])
    feats.sort(key=lambda f: (f["properties"]["REG_CODE_7"],
                              f["properties"].get("SUB_CODE_7", "")))
    return {"type": "FeatureCollection", "features": feats}


def main(outdir="regions/ibra7"):
    os.makedirs(outdir, exist_ok=True)
    for name, (service, fields) in LAYERS.items():
        fc = fetch(service, fields)
        codes = sorted({f["properties"]["REG_CODE_7"] for f in fc["features"]})
        missing = sorted(set(PILOT_CODES) - set(codes))
        if missing:
            sys.exit("{}: missing regions {}".format(name, missing))
        path = os.path.join(outdir, "ibra7_{}_pilot.geojson".format(name))
        with open(path, "w", encoding="ascii") as fh:
            json.dump(fc, fh, ensure_ascii=True, separators=(",", ":"))
            fh.write("\n")
        print("{}: {} features -> {}".format(name, len(fc["features"]), path))


if __name__ == "__main__":
    main(*sys.argv[1:])
