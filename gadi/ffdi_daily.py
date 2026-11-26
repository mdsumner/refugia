"""Daily McArthur FFDI on the AGCD r005 grid for the Tasmania pilot (notes/fire_weather.md).

    python3 gadi/ffdi_daily.py AGCD_DIR BARRA_DIR OUTDIR [FIRST LAST [SPINUP]]

AGCD_DIR   AGCD version folder holding precip/ and tmax/ (Gadi: /g/data/zv2/agcd/v1-0-4)
BARRA_DIR  BARRA-C2 folder holding day/ and 1hr/ (Gadi: /g/data/ob53/BARRA2/output/reanalysis/
           AUST-04/BOM/ERA5/historical/hres/BARRA-C2/v1)
FIRST LAST fire years, labelled by the June (default 1980 2025): fire year Y runs 1 July Y-1 to
           30 June Y, so a summer is never split
SPINUP     first calendar year of AGCD used to spin up KBDI (default 1970)

1. KBDI and the Griffiths drought factor (xclim, after Finkele et al. 2006, as the Australian
   Climate Service computes them) from AGCD daily precip and tmax, SPINUP to the end of fire year
   LAST. Mean annual rain for KBDI is the AGCD 1981-2010 mean (or the whole span when it does
   not cover 1981-2010). Land pixels only. Cached as OUTDIR/kbdi_df_<SPINUP>_<LAST>.nc.
2. For each fire year not yet written: BARRA-C2 daily tasmax and sfcWindmax, and the minimum of
   hourly hurs per UTC day, interpolated bilinearly to the AGCD grid; FFDI from those and the
   drought factor. Writes OUTDIR/ffdi_fy<YYYY>.nc with ffdi, drought_factor, kbdi, tasmax
   (degC), hursmin (%), sfcwindmax (km/h) and pr (mm/day), float32, compressed, land pixels only
   (BARRA-C2 fx/sftlf >= 50%; AGCD has values over the sea). Resumable.

Days are calendar dates. AGCD stamps a day at 09:00 (rain is the 24 h to 9 am); BARRA-C2 days
are UTC (10 am to 10 am AEST, so the afternoon humidity minimum falls inside one day). The
offsets are under a day and are not corrected.
"""
import datetime as dt
import glob
import os
import sys
import time

import numpy as np
import xarray as xr

try:  # xclim < 1.0
    from xclim.indices import (griffiths_drought_factor, keetch_byram_drought_index,
                               mcarthur_forest_fire_danger_index)
except ImportError:  # xclim >= 1.0
    from xclim.compute.fire import (griffiths_drought_factor, keetch_byram_drought_index,
                                    mcarthur_forest_fire_danger_index)
import xclim

TASMANIA = (143.5, 149.0, -44.0, -39.3)   # lon min, lon max, lat min, lat max (as gadi/agcd_sums.R)
MARGIN = 0.1                               # extra BARRA-C2 border (deg) for interpolation
AGCD_FILE = {"precip": "precip/total/r005/01day/agcd_v1_precip_total_r005_daily_{y}.nc",
             "tmax": "tmax/mean/r005/01day/agcd_v1_tmax_mean_r005_daily_{y}.nc"}


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


def as_dates(da):
    """Daily time stamps (AGCD 09:00, BARRA 12:00) floored to midnight."""
    return da.assign_coords(time=da["time"].dt.floor("D"))


def agcd(agcd_dir, var, years):
    lon0, lon1, lat0, lat1 = TASMANIA
    parts = []
    for y in years:
        ds = xr.open_dataset(os.path.join(agcd_dir, AGCD_FILE[var].format(y=y)))
        parts.append(ds[var].reset_coords(drop=True).sortby("lat")
                     .sel(lat=slice(lat0, lat1), lon=slice(lon0, lon1)).load())
    return as_dates(xr.concat(parts, "time"))


def drought(agcd_dir, barra_dir, outdir, spinup, last):
    path = os.path.join(outdir, f"kbdi_df_{spinup}_{last}.nc")
    if os.path.exists(path):
        return xr.open_dataset(path).load()
    years = range(spinup, last + 1)
    log("AGCD precip and tmax", spinup, "to", last)
    pr = agcd(agcd_dir, "precip", years)
    land = land_mask(barra_dir, dict(lat=pr.lat, lon=pr.lon))   # skip the sea
    pr = pr.where(land).assign_attrs(units="mm/d")
    tx = agcd(agcd_dir, "tmax", years).where(land).assign_attrs(units="degC")
    clim = pr.sel(time=slice("1981-01-01", "2010-12-31"))
    if clim.time.size < 365 * 30:
        clim = pr.sel(time=slice(f"{spinup}-01-01", f"{last - 1}-12-31"))
    pr_annual = (clim.groupby("time.year").sum("time", min_count=1).mean("year")
                 .assign_attrs(units="mm/year"))
    log("KBDI")
    kbdi = keetch_byram_drought_index(pr, tx, pr_annual)
    log("drought factor")
    df = griffiths_drought_factor(pr, kbdi)
    out = xr.Dataset({"pr": pr.astype("float32"), "kbdi": kbdi.astype("float32"),
                      "drought_factor": df.astype("float32"), "pr_annual": pr_annual.astype("float32")})
    out.attrs.update(source="AGCD v1-0-4 precip and tmax", method="xclim keetch_byram_drought_index, "
                     "griffiths_drought_factor (xlim)", xclim=xclim.__version__)
    out.to_netcdf(path + ".part", encoding={v: {"zlib": True, "complevel": 4} for v in out.data_vars})
    os.replace(path + ".part", path)
    return out


def barra_month(barra_dir, freq, var, ym):
    pat = os.path.join(barra_dir, freq, var, "v*",
                       f"{var}_AUST-04_ERA5_historical_hres_BOM_BARRA-C2_v1_{freq}_{ym}-{ym}.nc")
    files = sorted(glob.glob(pat))
    if not files:
        raise FileNotFoundError(pat)
    lon0, lon1, lat0, lat1 = TASMANIA
    # latest version folder; drop the scalar coordinates (height 1.5 m for tasmax and hurs, 10 m
    # for sfcWindmax, crs, model level), which conflict when the variables share one dataset
    with xr.open_dataset(files[-1]) as ds:
        return (ds[var].reset_coords(drop=True).sortby("lat")
                .sel(lat=slice(lat0 - MARGIN, lat1 + MARGIN), lon=slice(lon0 - MARGIN, lon1 + MARGIN))
                .load())


def barra_fire_year(barra_dir, fy):
    months = [f"{fy - 1}{m:02d}" for m in range(7, 13)] + [f"{fy}{m:02d}" for m in range(1, 7)]
    tx, ws, rh = [], [], []
    for ym in months:
        tx.append(barra_month(barra_dir, "day", "tasmax", ym))
        ws.append(barra_month(barra_dir, "day", "sfcWindmax", ym))
        rh.append(barra_month(barra_dir, "1hr", "hurs", ym).resample(time="1D").min())
    tx = as_dates(xr.concat(tx, "time")) - 273.15
    ws = as_dates(xr.concat(ws, "time")) * 3.6
    rh = as_dates(xr.concat(rh, "time"))
    return tx, ws, rh


def land_mask(barra_dir, grid):
    """Land on the AGCD grid: BARRA-C2 land area fraction (fx/sftlf, %) >= 50 after bilinear
    interpolation. AGCD itself has values over the sea, so it cannot be the mask."""
    files = sorted(glob.glob(os.path.join(barra_dir, "fx", "sftlf", "v*",
                                          "sftlf_AUST-04_ERA5_historical_hres_BOM_BARRA-C2_v1.nc")))
    if not files:
        raise FileNotFoundError(os.path.join(barra_dir, "fx", "sftlf"))
    lon0, lon1, lat0, lat1 = TASMANIA
    with xr.open_dataset(files[-1]) as ds:
        f = (ds["sftlf"].reset_coords(drop=True).sortby("lat")
             .sel(lat=slice(lat0 - MARGIN, lat1 + MARGIN), lon=slice(lon0 - MARGIN, lon1 + MARGIN))
             .load())
    return f.interp(**grid, method="linear") >= 50


def main(agcd_dir, barra_dir, outdir, first=1980, last=2025, spinup=1970):
    first, last, spinup = int(first), int(last), int(spinup)
    os.makedirs(outdir, exist_ok=True)
    d = drought(agcd_dir, barra_dir, outdir, spinup, last)
    grid = dict(lat=d.lat, lon=d.lon)
    land = land_mask(barra_dir, grid)
    log(f"land pixels {int(land.sum())} of {land.size}")
    for fy in range(first, last + 1):
        path = os.path.join(outdir, f"ffdi_fy{fy}.nc")
        if os.path.exists(path):
            continue
        t0 = time.time()
        tx, ws, rh = barra_fire_year(barra_dir, fy)
        days = d.time.sel(time=slice(f"{fy - 1}-07-01", f"{fy}-06-30"))
        tx, ws, rh = (v.interp(**grid, method="linear").reindex(time=days) for v in (tx, ws, rh))
        df = d.drought_factor.sel(time=days)
        ffdi = mcarthur_forest_fire_danger_index(df, tx.assign_attrs(units="degC"),
                                                 rh.assign_attrs(units="%"),
                                                 ws.assign_attrs(units="km/h"))
        out = xr.Dataset({"ffdi": ffdi.where(land), "drought_factor": df.where(land),
                          "kbdi": d.kbdi.sel(time=days).where(land),
                          "tasmax": tx.where(land).assign_attrs(units="degC"),
                          "hursmin": rh.where(land).assign_attrs(units="%"),
                          "sfcwindmax": ws.where(land).assign_attrs(units="km/h"),
                          "pr": d.pr.sel(time=days).where(land).assign_attrs(units="mm/d")}).astype("float32")
        out.attrs.update(
            title=f"Daily McArthur FFDI (Mk5), fire year {fy} (1 July {fy - 1} to 30 June {fy})",
            source="BARRA-C2 (BoM) daily tasmax and sfcWindmax, minimum of hourly hurs, bilinear to "
                   "the AGCD r005 grid; drought factor from AGCD v1-0-4 precip and tmax",
            method="xclim mcarthur_forest_fire_danger_index, griffiths_drought_factor, "
                   "keetch_byram_drought_index, as the Australian Climate Service hazard_fire",
            xclim=xclim.__version__, history=f"{dt.date.today()} gadi/ffdi_daily.py (refugia)",
            note="A fire-weather index, not a Fire Danger Rating (AFDRS)")
        enc = {v: {"zlib": True, "complevel": 4} for v in out.data_vars}
        out.to_netcdf(path + ".part", encoding=enc); os.replace(path + ".part", path)
        f = out.ffdi.values
        log(f"fire year {fy}: {np.isfinite(f).sum()} pixel-days, FFDI median {np.nanmedian(f):.1f}, "
            f"99th pct {np.nanpercentile(f, 99):.1f}, max {np.nanmax(f):.1f}; {time.time() - t0:.0f} s")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
