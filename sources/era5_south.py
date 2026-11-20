"""ERA5 hourly 2 m temperature south of 60S to per-pixel monthly sums.

python3 -I sources/era5_south.py <outdir> [first_summer] [last_summer] [workers]

Reads the NSF NCAR ERA5 copy on the public AWS bucket (nsf-ncar-era5,
e5.oper.an.sfc 128_167_2t, 0.25 deg, hourly, one netCDF4 file per month) with
HTTP range requests, so only the HDF5 chunks south of 60S are fetched (about
a quarter of each 1.1 GB file). Months are December, January and February of
each austral summer; summer Y is December Y-1 to February Y.

Per month and pixel, written as <outdir>/era5_t2m_<YYYYMM>.bin (float64,
little endian, 4 x 119 x 1440, row 1 at 60.25S, last row 89.75S, column 1 at
180W, columns every 0.25 deg east):
  n      hours with a value
  s_t    sum of 2 m temperature (deg C)
  s_pdd  sum of max(T, 0) (deg C hours; positive degree hours)
  n_pos  hours with T > 0 deg C
The 60S and 90S rows are left out, so every pixel spans 0.25 deg of latitude
(60.125S to 89.875S). Resumable by month. Also writes era5_z_south.bin (surface
geopotential height in m, same grid) once.
"""
import os
import sys
import time
from multiprocessing import Pool

import numpy as np

BASE = "https://nsf-ncar-era5.s3.amazonaws.com"
ROWS = slice(601, 720)  # latitude -60.25 .. -89.75 (index 0 is 90N)
NR, NC = 119, 1440
ROT = np.r_[720:1440, 0:720]  # 0..359.75 -> -180..179.75


def h5open(url):
    import fsspec
    import h5py
    f = fsspec.open(url, block_size=2 ** 21).open()
    return h5py.File(f, "r")


def month_url(ym):
    y, m = int(ym[:4]), int(ym[4:])
    nd = [31, 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28,
          31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
    return (f"{BASE}/e5.oper.an.sfc/{ym}/e5.oper.an.sfc.128_167_2t.ll025sc."
            f"{ym}0100_{ym}{nd:02d}23.nc")


def do_month(args):
    ym, outdir = args
    of = os.path.join(outdir, f"era5_t2m_{ym}.bin")
    if os.path.exists(of):
        return f"{ym} exists"
    for k in range(5):
        try:
            t0 = time.time()
            h = h5open(month_url(ym))
            v = h["VAR_2T"]
            lat = h["latitude"][ROWS]
            assert abs(lat[0] + 60.25) < 1e-9 and abs(lat[-1] + 89.75) < 1e-9
            nt = v.shape[0]
            acc = np.zeros((4, NR, NC))
            for i in range(0, nt, 27):  # the time chunk size
                a = v[i:min(nt, i + 27), ROWS, :].astype(np.float64)
                a = a[:, :, ROT] - 273.15
                ok = np.isfinite(a) & (np.abs(a) < 200)
                a = np.where(ok, a, 0.0)
                acc[0] += ok.sum(0)
                acc[1] += a.sum(0)
                acc[2] += np.maximum(a, 0).sum(0)
                acc[3] += (ok & (a > 0)).sum(0)
            h.close()
            tmp = of + ".tmp"
            acc.astype("<f8").tofile(tmp)
            os.replace(tmp, of)
            return f"{ym} done, {nt} hours, {time.time() - t0:.0f} s"
        except Exception as e:  # network resets: retry
            err = e
            time.sleep(5 * (k + 1))
    return f"{ym} FAILED: {err}"


def do_z(outdir):
    of = os.path.join(outdir, "era5_z_south.bin")
    if os.path.exists(of):
        return
    u = (f"{BASE}/e5.oper.invariant/197901/"
         "e5.oper.invariant.128_129_z.ll025sc.1979010100_1979010100.nc")
    h = h5open(u)
    z = h["Z"][0, ROWS, :][:, ROT] / 9.80665
    z.astype("<f8").tofile(of)


if __name__ == "__main__":
    a = sys.argv[1:]
    outdir = a[0] if a else "data/era5"
    y0 = int(a[1]) if len(a) > 1 else 1980
    y1 = int(a[2]) if len(a) > 2 else 2026
    workers = int(a[3]) if len(a) > 3 else 6
    os.makedirs(outdir, exist_ok=True)
    do_z(outdir)
    months = []
    for y in range(y0, y1 + 1):
        months += [f"{y - 1}12", f"{y}01", f"{y}02"]
    with Pool(workers) as p:
        for r in p.imap_unordered(do_month, [(m, outdir) for m in months]):
            print(r, flush=True)
