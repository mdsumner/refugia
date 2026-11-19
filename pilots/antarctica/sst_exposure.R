## Sea surface temperature exposure south of 60S per S2 level 9 cell (OISST).
##
## Rscript pilots/antarctica/sst_exposure.R <oisst_dir> <outdir> [first_year] [last_year]
##
## <oisst_dir> holds oisst_pix_<year>.rds from sources/oisst_south.R.
##
## 1. Cell sums. Each 0.25 deg pixel is split 3 x 3 so that level 9 cells
##    (about 18 km; a pixel is 7 to 14 km by 28 km here) get area-weighted
##    shares. Per year and cell (sst_L9_<year>.rds, mergeable like the ice
##    sums): w (ocean area, km2) and area-weighted sums of the pixel annual
##    mean SST (all days), the summer SST (Jan-Mar mean over open-water days,
##    at least 30 of them) and the shares of days with ice (all year,
##    Jan-Mar).
##    Gate: the area mean SST south of 60S per year from the cell sums
##    equals the area mean over pixels; the script stops if they differ by
##    more than 1e-9 deg C.
## 2. Per cell: climatology, trend per decade and signal-to-noise of summer
##    (Jan-Mar) and annual SST and of the summer ice share; summer SST
##    velocity (trend over the local gradient of the climatology, km per
##    decade).
## 3. Scored within the five trend.ice sectors on the summer open-water zone
##    (mean Jan-Mar ice share below 0.5). OISST sets SST under ice from the
##    ice concentration, and its ice input steps up by about 12% against the
##    NSIDC CDR from 2005, so all-day SST trends in the ice zone follow that
##    step; the summer metric uses open-water days only.
##    Candidate SST holdout: summer SST trend in the sector's lowest quarter
##    (least warming or a cooling), and either cooling or a slow warming
##    velocity (lowest quarter of the sector's warming cells).

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))
a <- commandArgs(TRUE)
indir <- if (length(a) > 0) a[1] else "data/oisst"
outdir <- if (length(a) > 1) a[2] else "data"
y0 <- if (length(a) > 2) as.integer(a[3]) else 1982L
y1 <- if (length(a) > 3) as.integer(a[4]) else 2025L
lev <- 9L; sub <- 3L
sumdir <- file.path(outdir, "sst_L9")
dir.create(sumdir, recursive = TRUE, showWarnings = FALSE)

ff <- list.files(indir, "^oisst_pix_[0-9]{4}[.]rds$", full.names = TRUE)
yrs <- as.integer(sub("^oisst_pix_([0-9]{4})[.]rds$", "\\1", basename(ff)))
ff <- ff[yrs >= y0 & yrs <= y1]; yrs <- yrs[yrs >= y0 & yrs <= y1]
cat(length(ff), "years", min(yrs), "-", max(yrs), "\n")

## grid: 120 rows (60S to 90S, top row 60.125S) x 1440 columns (-180 to 180)
g <- list(extent = c(xmin = -180, xmax = 180, ymin = -90, ymax = -60),
          dimension = c(ncol = 1440L * sub, nrow = 120L * sub), crs = "EPSG:4326")
mfile <- file.path(sumdir, sprintf("mapping_L%d_sub%d.rds", lev, sub))
m <- if (file.exists(mfile)) readRDS(mfile) else { mm <- build_grid_mapping(g, level = lev); saveRDS(mm, mfile); mm }
idx <- mapping_index(m)
## true area of a sub-pixel (km2) by sub-row, sphere R = 6371.0072 km (authalic)
lat_top <- -60 - (seq_len(120L * sub) - 1) * 0.25 / sub
band <- (6371.0072^2) * (0.25 / sub * pi / 180) *
  abs(sin(lat_top * pi / 180) - sin((lat_top - 0.25 / sub) * pi / 180))
area_sub <- rep(band, each = 1440L * sub)        # row-major, matches the mapping
up <- function(x) x[rep(seq_len(nrow(x)), each = sub), rep(seq_len(ncol(x)), each = sub)]
rowmajor <- function(x) as.vector(t(x))

gate <- list()
for (i in seq_along(ff)) {
  y <- yrs[i]
  of <- file.path(sumdir, sprintf("sst_L%d_%d.rds", lev, y))
  p <- readRDS(ff[i])
  sst <- p$s_sst / p$n_days; sst[p$n_days < 0.9 * p$ndays] <- NA
  jfm <- p$s_sst_open_jfm / p$n_open_jfm; jfm[p$n_open_jfm < 30 | p$n_jfm < 0.9 * 90] <- NA
  icef <- p$n_ice / p$ndays; icef[is.na(sst)] <- NA
  icej <- p$n_ice_jfm / p$n_jfm; icej[p$n_jfm < 0.9 * 90] <- NA
  ## the pixel-level gate reference: area-weighted over native pixels
  pa <- (6371.0072^2) * (0.25 * pi / 180) *
    abs(sin((-60 - (0:119) * 0.25) * pi / 180) - sin((-60.25 - (0:119) * 0.25) * pi / 180))
  A <- matrix(pa, 120, 1440)
  ok <- !is.na(sst)
  gate[[i]] <- data.frame(year = y, area_km2 = sum(A[ok]), mean_sst_pixels = sum((A * sst)[ok]) / sum(A[ok]),
                          mean_ice_share = sum((A * icef)[ok]) / sum(A[ok]), missing_days = p$missing_days)
  if (!file.exists(of)) {
    v <- lapply(list(sst = sst, jfm = jfm, icef = icef, icej = icej), function(x) rowmajor(up(x)))
    w <- area_sub; w[is.na(v$sst)] <- 0
    wj <- area_sub; wj[is.na(v$jfm)] <- 0
    wi <- area_sub; wi[is.na(v$icej)] <- 0
    s <- sum_to_cells(m,
      w = w, s_sst = w * v$sst, ss_sst = w * v$sst^2, s_icef = w * v$icef,
      w_jfm = wj, s_jfm = wj * v$jfm, ss_jfm = wj * v$jfm^2, w_icej = wi, s_icej = wi * v$icej,
      index = idx)
    s$n <- NULL
    s <- s[s$w > 0 | s$w_icej > 0, ]
    s$year <- y
    saveRDS(s, of)
  }
}
d <- do.call(rbind, lapply(list.files(sumdir, "^sst_L9_[0-9]{4}[.]rds$", full.names = TRUE), readRDS))
d <- d[d$year %in% yrs, ]
gate <- do.call(rbind, gate)
gs <- aggregate(cbind(w, s_sst) ~ year, data = d, FUN = sum)
gate$mean_sst_sums <- gs$s_sst[match(gate$year, gs$year)] / gs$w[match(gate$year, gs$year)]
gate$d_sst <- gate$mean_sst_sums - gate$mean_sst_pixels
gate$d_area <- gs$w[match(gate$year, gs$year)] - gate$area_km2
tr <- function(x, t) unname(stats::coef(stats::lm(x ~ t))[2]) * 10
cat(sprintf("gate: max |sums - pixels| %.1e deg C, area %.1e km2; trend %.4f vs %.4f deg C per decade\n",
            max(abs(gate$d_sst)), max(abs(gate$d_area)),
            tr(gate$mean_sst_sums, gate$year), tr(gate$mean_sst_pixels, gate$year)))
write.csv(gate, file.path(outdir, "sst_gate_by_year.csv"), row.names = FALSE)
stopifnot(max(abs(gate$d_sst)) < 1e-9)

## per cell
## a cell-year counts if at least half its usual ocean area has a value
wmax <- tapply(d$w, d$cell, max); d$wmax <- as.vector(wmax[d$cell])
d$ok <- d$w >= 0.5 * d$wmax; d$okj <- d$w_jfm >= 0.5 * d$wmax; d$oki <- d$w_icej >= 0.5 * d$wmax
out <- NULL
for (v in list(c("jfm", "s_jfm", "w_jfm", "okj"), c("sst", "s_sst", "w", "ok"),
               c("icej", "s_icej", "w_icej", "oki"))) {
  k <- d[[v[4]]]
  x <- data.frame(cell = d$cell[k], year = d$year[k], value = d[[v[2]]][k] / d[[v[3]]][k])
  t <- cell_trends(x, yrs)
  t <- t[t$n >= 0.75 * length(yrs), ]
  names(t)[-1] <- paste0(names(t)[-1], "_", v[1])
  out <- if (is.null(out)) t else merge(out, t, by = "cell", all = TRUE)
}
out$velocity_km_decade_jfm <- out$slope_decade_jfm / cell_gradient(out$cell, out$clim_jfm)
ctr <- s2::s2_cell_center(s2::as_s2_cell(out$cell)); out$lon <- s2::s2_x(ctr); out$lat <- s2::s2_y(ctr)
sector_levels <- c("Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen")
out$sector <- as.character(cut(out$lon, c(-180, -130, -60, 20, 90, 160, 180),
                               labels = c("Ross", "Bell-Amundsen", "Weddell", "Indian", "W Pacific", "Ross2"),
                               include.lowest = TRUE))
out$sector[out$sector == "Ross2"] <- "Ross"
out$ccamlr_area <- ifelse(out$lon >= -70 & out$lon < 30, "48", ifelse(out$lon >= 30 & out$lon < 150, "58", "88"))
zone <- is.finite(out$clim_icej) & out$clim_icej < 0.5 & is.finite(out$slope_decade_jfm)
out$summer_open_zone <- zone
out$warming_pct <- NA_real_; out$warm_velocity_pct <- NA_real_
out$warming_pct[zone] <- group_percentile(out$slope_decade_jfm[zone], out$sector[zone])
out$warm_velocity_km_decade <- abs(out$velocity_km_decade_jfm)
out$warm_velocity_km_decade[!(out$slope_decade_jfm > 0)] <- 0
warm <- zone & out$slope_decade_jfm > 0 & is.finite(out$warm_velocity_km_decade)
out$warm_velocity_pct[warm] <- group_percentile(out$warm_velocity_km_decade[warm], out$sector[warm])
out$slow_or_cool <- (zone & out$slope_decade_jfm <= 0) | (warm & out$warm_velocity_pct <= 0.25)
out$sst_refugium <- zone & out$warming_pct <= 0.25 & out$slow_or_cool %in% TRUE
out$sst_refugium[is.na(out$sst_refugium)] <- FALSE
saveRDS(out, file.path(outdir, "sst_exposure_L9.rds"))
write.csv(out, file.path(outdir, "sst_exposure_L9.csv"), row.names = FALSE)

q <- function(x, f = "%.2f") sprintf(paste0(f, " [", f, ", ", f, "]"), stats::median(x, na.rm = TRUE),
                         stats::quantile(x, 0.1, na.rm = TRUE), stats::quantile(x, 0.9, na.rm = TRUE))
z <- out[zone, ]
summ <- do.call(rbind, lapply(split(z, z$sector), function(s) data.frame(
  sector = s$sector[1], cells = nrow(s),
  jfm_clim = q(s$clim_jfm), jfm_trend = q(s$slope_decade_jfm), jfm_snr = q(s$snr_jfm, "%.1f"),
  annual_trend = q(s$slope_decade_sst), summer_ice_trend = q(s$slope_decade_icej, "%.3f"),
  velocity_km_decade = q(s$velocity_km_decade_jfm, "%.0f"),
  warming_share = round(mean(s$slope_decade_jfm > 0, na.rm = TRUE), 2),
  snr2_share = round(mean(abs(s$snr_jfm) >= 2, na.rm = TRUE), 2),
  refugium_cells = sum(s$sst_refugium))))
summ <- summ[match(intersect(sector_levels, summ$sector), summ$sector), ]
print(summ, row.names = FALSE)
write.csv(summ, file.path(outdir, "sst_exposure_summary.csv"), row.names = FALSE)
