## NOAA OISST v2.1 daily (0.25 deg) south of 60S to per-pixel annual sums.
##
## Rscript sources/oisst_south.R <outdir> [first_year] [last_year] [cores]
##
## Reads the daily netCDF files from the public NOAA bucket
## (noaa-cdr-sea-surface-temp-optimum-interpolation-pds, the files that the
## raad.virtualize OISST index on source.coop points to), one at a time into a
## temporary file, and keeps rows south of 60S. Per calendar year and pixel:
##   n_days, s_sst      days with an SST value, sum of SST
##   n_jfm, s_sst_jfm   the same for January to March (late austral summer)
##   n_ice, n_ice_jfm   days with OISST ice concentration >= 15% (all, Jan-Mar)
##   n_open, s_sst_open, n_open_jfm, s_sst_open_jfm
##                      the same SST sums over open-water days only (ice
##                      concentration below 15% or none)
## Written as <outdir>/oisst_pix_<year>.rds: a list of 120 x 1440 matrices
## (row 1 at 60.125S, longitude -180 to 180), resumable by year.
##
## OISST sets SST under sea ice from the ice concentration (near freezing),
## so where there is ice the SST follows the ice record, and the OISST ice
## input is not homogeneous (the ice share south of 60S steps up by about
## 12% against the NSIDC CDR from 2005). The open-water sums avoid both. About 28 GB is read for 1982-2025
## (about 30 to 60 minutes from the cloud sessions).

a <- commandArgs(TRUE)
outdir <- if (length(a) > 0) a[1] else "data/oisst"
y0 <- if (length(a) > 1) as.integer(a[2]) else 1982L
y1 <- if (length(a) > 2) as.integer(a[3]) else 2025L
cores <- if (length(a) > 3) as.integer(a[4]) else 4L
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
base <- "https://noaa-cdr-sea-surface-temp-optimum-interpolation-pds.s3.amazonaws.com/data/v2.1/avhrr"

fetch <- function(day, tf) {
  ym <- format(day, "%Y%m"); ymd <- format(day, "%Y%m%d")
  for (suffix in c("", "_preliminary")) {
    u <- sprintf("%s/%s/oisst-avhrr-v02r01.%s%s.nc", base, ym, ymd, suffix)
    for (k in 1:4) {
      ok <- !inherits(try(utils::download.file(u, tf, mode = "wb", quiet = TRUE), silent = TRUE), "try-error")
      if (ok && file.exists(tf) && file.size(tf) > 1e5) return(TRUE)
      unlink(tf)
      if (k > 1 || suffix == "") Sys.sleep(2 * k)
    }
  }
  FALSE
}

## columns rotated from 0..360 to -180..180
cols <- c(721:1440, 1:720)
read_day <- function(tf) {
  r <- terra::rast(tf)
  nm <- names(r)
  sst <- terra::as.matrix(r[[grep("^sst", nm)]], wide = TRUE)
  ice <- terra::as.matrix(r[[grep("^ice", nm)]], wide = TRUE)
  ## terra gives north-up rows: the last 120 are south of 60S, top one 60.125S
  nr <- nrow(sst)
  keep <- (nr - 119):nr
  list(sst = sst[keep, cols], ice = ice[keep, cols])
}

do_year <- function(y) {
  of <- file.path(outdir, sprintf("oisst_pix_%d.rds", y))
  if (file.exists(of)) return(paste(y, "exists"))
  days <- seq(as.Date(sprintf("%d-01-01", y)), as.Date(sprintf("%d-12-31", y)), by = "day")
  z <- matrix(0, 120, 1440)
  acc <- list(n_days = z, s_sst = z, n_jfm = z, s_sst_jfm = z, n_ice = z, n_ice_jfm = z,
              n_open = z, s_sst_open = z, n_open_jfm = z, s_sst_open_jfm = z)
  tf <- tempfile(pattern = sprintf("oisst_%d_", y), fileext = ".nc")
  missing <- 0L
  for (i in seq_along(days)) {
    if (!fetch(days[i], tf)) { missing <- missing + 1L; next }
    v <- read_day(tf); unlink(tf)
    ok <- !is.na(v$sst)
    acc$n_days <- acc$n_days + ok
    acc$s_sst[ok] <- acc$s_sst[ok] + v$sst[ok]
    ice <- !is.na(v$ice) & v$ice >= 0.15   # ice is a fraction (0-1) despite its "%" unit
    acc$n_ice <- acc$n_ice + ice
    op <- ok & !ice
    acc$n_open <- acc$n_open + op
    acc$s_sst_open[op] <- acc$s_sst_open[op] + v$sst[op]
    if (as.integer(format(days[i], "%m")) <= 3) {
      acc$n_jfm <- acc$n_jfm + ok
      acc$s_sst_jfm[ok] <- acc$s_sst_jfm[ok] + v$sst[ok]
      acc$n_ice_jfm <- acc$n_ice_jfm + ice
      acc$n_open_jfm <- acc$n_open_jfm + op
      acc$s_sst_open_jfm[op] <- acc$s_sst_open_jfm[op] + v$sst[op]
    }
  }
  acc$year <- y; acc$ndays <- length(days); acc$missing_days <- missing
  saveRDS(acc, of)
  sprintf("%d done, %d missing days", y, missing)
}

res <- parallel::mclapply(y0:y1, do_year, mc.cores = cores, mc.preschedule = FALSE)
cat(unlist(res), sep = "\n")
