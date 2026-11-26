"""Probe BARRA-C2 on public S3 for the fire-weather inputs (see notes/fire_weather.md).

    python3 sources/barra2_probe.py [YYYYMM]

For one month (default 202501): per input, the array shape, chunk (block) size, packing and the
time to read the Tasmania pilot box through GDAL's multidimensional /vsis3/ driver, then the
unpacked daily values at the Fern Tree pixel. Needs GDAL's Python bindings (osgeo) and network
access to s3://bom-opendata-climate; no credentials.
"""
import sys
import time

import numpy as np
from osgeo import gdal

gdal.UseExceptions()
for k, v in {"AWS_NO_SIGN_REQUEST": "YES", "AWS_REGION": "ap-southeast-2",
             "GDAL_DISABLE_READDIR_ON_OPEN": "EMPTY_DIR"}.items():
    gdal.SetConfigOption(k, v)

ROOT = ("/vsis3/bom-opendata-climate/BARRA2/output/reanalysis/AUST-04/BOM/ERA5/historical/hres/"
        "BARRA-C2/v1")
VERSION = "v20250528"
TASMANIA = (143.5, 149.0, -44.0, -39.3)      # lon min, lon max, lat min, lat max (as gadi/agcd_sums.R)
FERN_TREE = (147.262, -42.923)
INPUTS = [("day", "tasmax"), ("day", "sfcWindmax"), ("day", "pr"), ("1hr", "hurs")]


def open_var(freq, var, month):
    f = f"{ROOT}/{freq}/{var}/{VERSION}/{var}_AUST-04_ERA5_historical_hres_BOM_BARRA-C2_v1_{freq}_{month}-{month}.nc"
    rg = gdal.OpenEx(f, gdal.OF_MULTIDIM_RASTER).GetRootGroup()
    return rg.OpenMDArray(var), rg.OpenMDArray("lat").ReadAsArray(), rg.OpenMDArray("lon").ReadAsArray()


def main(month="202501"):
    print(f"# BARRA-C2 probe, {month}, {time.strftime('%Y-%m-%d %H:%M')}")
    for freq, var in INPUTS:
        t0 = time.time()
        a, lat, lon = open_var(freq, var, month)
        iy = np.where((lat >= TASMANIA[2]) & (lat <= TASMANIA[3]))[0]
        ix = np.where((lon >= TASMANIA[0]) & (lon <= TASMANIA[1]))[0]
        t1 = time.time()
        box = a.GetView(f"[:,{iy.min()}:{iy.max() + 1},{ix.min()}:{ix.max() + 1}]").ReadAsArray()
        t2 = time.time()
        scale, offset = a.GetScale() or 1.0, a.GetOffset() or 0.0
        py, px = int(np.argmin(abs(lat - FERN_TREE[1]))), int(np.argmin(abs(lon - FERN_TREE[0])))
        pt = a.GetView(f"[:,{py},{px}]").ReadAsArray().astype(float) * scale + offset
        dims = "x".join(str(d.GetSize()) for d in a.GetDimensions())
        print(f"{freq}/{var}: {dims} at {abs(lat[1] - lat[0]):.4f} deg, chunks {a.GetBlockSize()}, "
              f"{(a.GetStructuralInfo() or {}).get('COMPRESS', '?')}, scale {scale:.6g} offset {offset:.6g} "
              f"'{a.GetUnit()}'; open {t1 - t0:.1f} s; Tasmania box {box.shape} in {t2 - t1:.1f} s; "
              f"Fern Tree pixel ({lat[py]:.3f}, {lon[px]:.3f}) min {pt.min():.4g} mean {pt.mean():.4g} "
              f"max {pt.max():.4g}")


if __name__ == "__main__":
    main(*sys.argv[1:2])
