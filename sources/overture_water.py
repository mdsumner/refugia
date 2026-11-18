"""Artificial water polygons for the pilot regions from Overture Maps.

python3 -I sources/overture_water.py <outdir> [release]

Overture base/water (derived from OpenStreetMap) is read straight from the
public bucket s3://overturemaps-us-west-2 with a bbox filter, so only the row
groups over each pilot box are fetched (a few seconds per box).

A polygon is kept as artificial when
  - its class is an artificial one (reservoir, basin, wastewater, canal and
    ditch areas, any human_made feature), or
  - it is an unclassed water or pond polygon that is drawn as a near
    rectangle: area / minimum rotated rectangle >= 0.85 with at most 12
    vertices. Hand-digitised ponds (sewage lagoons, turkey nests, farm dams)
    pass; natural pools traced along rock and sand (Glen Helen, Ormiston
    Gorge) score 0.4-0.6.

Output: <outdir>/artificial_water_<region>.geojson (EPSG:4326) with columns
id, subtype, class, rect, nvert, rule.
"""
import json, os, sys
import pyarrow.compute as pc
import pyarrow.dataset as ds
import pyarrow.fs as pf
from shapely import wkb
from shapely.geometry import mapping

BOXES = {"macdonnell": (129.5, -25.0, 136.5, -22.5), "tasmania": (143.5, -44.0, 149.0, -39.3)}
ART_CLASS = {"reservoir", "basin", "wastewater", "canal", "ditch", "drain", "swimming_pool",
             "reflecting_pool", "fishpond", "fish_pass"}
RECT_MIN, NVERT_MAX = 0.85, 12


def main(outdir, release="2026-10-21.0"):
    os.makedirs(outdir, exist_ok=True)
    proxy = os.environ.get("HTTPS_PROXY")
    kw = {"anonymous": True, "region": "us-west-2"}
    if proxy:
        kw["proxy_options"] = proxy
    if os.path.exists("/root/.ccr/ca-bundle.crt"):
        kw["tls_ca_file_path"] = "/root/.ccr/ca-bundle.crt"
    fs = pf.S3FileSystem(**kw)
    d = ds.dataset(f"overturemaps-us-west-2/release/{release}/theme=base/type=water/",
                   filesystem=fs, format="parquet")
    for name, (x0, y0, x1, y1) in BOXES.items():
        f = ((pc.field("bbox", "xmin") > x0) & (pc.field("bbox", "xmax") < x1) &
             (pc.field("bbox", "ymin") > y0) & (pc.field("bbox", "ymax") < y1))
        t = d.to_table(columns=["id", "subtype", "class", "geometry"], filter=f).to_pylist()
        feats = []
        for r in t:
            g = wkb.loads(r["geometry"])
            if g.geom_type not in ("Polygon", "MultiPolygon"):
                continue
            rect = g.area / g.minimum_rotated_rectangle.area if g.area > 0 else 0.0
            nv = len(g.exterior.coords) - 1 if g.geom_type == "Polygon" else 999
            rule = None
            if r["class"] in ART_CLASS or r["subtype"] == "human_made":
                rule = "class"
            elif r["class"] in ("water", "pond") and rect >= RECT_MIN and nv <= NVERT_MAX:
                rule = "shape"
            if rule:
                feats.append({"type": "Feature", "geometry": mapping(g),
                              "properties": {"id": r["id"], "subtype": r["subtype"], "class": r["class"],
                                             "rect": round(rect, 3), "nvert": nv, "rule": rule}})
        of = os.path.join(outdir, f"artificial_water_{name}.geojson")
        with open(of, "w") as fh:
            json.dump({"type": "FeatureCollection", "features": feats}, fh)
        n_class = sum(f["properties"]["rule"] == "class" for f in feats)
        print(name, "water features", len(t), "artificial", len(feats), "by class", n_class,
              "by shape", len(feats) - n_class, flush=True)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "regions/overture",
         *(sys.argv[2:3]))
