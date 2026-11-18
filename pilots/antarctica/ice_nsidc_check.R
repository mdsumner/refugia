## Check the trend.ice cell sums against NSIDC's Sea Ice Index (G02135).
##
## Rscript pilots/antarctica/ice_nsidc_check.R <ice_dir> <sii_csv> <outdir>
##
## <ice_dir>  ice_L9_<year>.rds from gadi/ice_sums.R
## <sii_csv>  S_seaice_extent_daily_v3.0.csv, from
##            https://noaadata.apps.nsidc.org/NOAA/G02135/south/daily/data/
##
## Summed over the grid, daycount times true pixel area is the daily ice
## extent (concentration >= 15%) integrated over the ice year. Divided by the
## days in the ice year it is the mean daily extent, which the Sea Ice Index
## gives directly. The cell sums carry daycount in pixel units (sub-pixel
## weights), so each cell's s_daycount is scaled by the true area of a 25 km
## pixel at the cell centre latitude (EPSG:3412, true scale at 70S).
##
## The two are not the same product: trend.ice uses the CDR (G02202 v6, the
## larger of NASA Team and Bootstrap concentration, gap-filled daily), the
## Sea Ice Index uses NASA Team alone and is every other day before
## August 1987. So the CDR extent is expected to run higher by a near-constant
## share, with the same interannual anomalies and trend.
##
## Ice year y runs from Feb 15 of year y to Feb 14 of y + 1 (trend.ice
## manifest). Sea Ice Index days are linearly interpolated to daily within
## each ice year; a year is used only if no gap is longer than 3 days.

a <- commandArgs(TRUE)
indir <- if (length(a) > 0) a[1] else "data/ice_L9"
sii_csv <- if (length(a) > 1) a[2] else "data/S_seaice_extent_daily_v3.0.csv"
outdir <- if (length(a) > 2) a[3] else "data"

## trend.ice side: integrated extent per ice year from the cell sums
ff <- list.files(indir, "^ice_L9_[0-9]{4}[.]rds$", full.names = TRUE)
d <- do.call(rbind, lapply(ff, function(f) readRDS(f)[c("cell", "year", "w_obs", "s_daycount")]))
cells <- unique(d$cell)
ctr <- s2::s2_cell_center(s2::as_s2_cell(cells))
## true area of a 25 km pixel at latitude lat on EPSG:3412 (Hughes 1980
## ellipsoid, true scale at 70S): 625 km2 / k^2, k the point scale factor
## (Snyder 1987, eq. 21-32 to 21-35). Checked against terra::cellSize below.
pix_area_km2 <- function(lat) {
  A <- 6378273; e <- sqrt(1 - (1 - 1 / 298.279411123064)^2)
  ff <- function(p) { p <- abs(p) * pi / 180
    list(t = tan(pi / 4 - p / 2) / ((1 - e * sin(p)) / (1 + e * sin(p)))^(e / 2),
         m = cos(p) / sqrt(1 - e^2 * sin(p)^2)) }
  c0 <- ff(70); z <- ff(lat)
  k <- (A * c0$m * z$t / c0$t) / (A * z$m)
  625 / k^2
}
g <- terra::rast(nrows = 332, ncols = 316, xmin = -3950000, xmax = 3950000,
                 ymin = -3950000, ymax = 4350000, crs = "EPSG:3412")
xy <- terra::xyFromCell(g, seq_len(terra::ncell(g)))
ll <- terra::project(xy, from = "EPSG:3412", to = "EPSG:4326")
south <- ll[, 2] <= -55   # the ice zone; terra's estimate drifts to 0.6% further north
rel <- pix_area_km2(ll[south, 2]) / terra::values(terra::cellSize(g, unit = "km"))[south] - 1
area_err <- max(abs(rel))
cat(sprintf("pixel area formula vs terra::cellSize south of 55S: max relative difference %.1e\n", area_err))
stopifnot(area_err < 1e-3)
area <- pix_area_km2(s2::s2_y(ctr))
d$area_km2 <- area[match(d$cell, cells)]
ti <- aggregate(cbind(icedays = s_daycount * area_km2, ocean_km2 = w_obs * area_km2) ~ year,
                data = d, FUN = sum)

## Sea Ice Index side
s <- utils::read.csv(sii_csv, skip = 2, header = FALSE, strip.white = TRUE,
                     col.names = c("Year", "Month", "Day", "Extent", "Missing", "Source"))
s$date <- as.Date(sprintf("%d-%02d-%02d", s$Year, s$Month, s$Day))
s <- s[!is.na(s$Extent) & s$Extent > 0, ]
sii_year <- function(y) {
  days <- seq(as.Date(sprintf("%d-02-15", y)), as.Date(sprintf("%d-02-14", y + 1)), by = "day")
  k <- s[s$date >= days[1] - 3 & s$date <= days[length(days)] + 3, ]
  if (nrow(k) < 2 || min(k$date) > days[1] || max(k$date) < days[length(days)]) return(NULL)
  gap <- max(diff(as.numeric(k$date)))
  e <- stats::approx(as.numeric(k$date), k$Extent * 1e6, xout = as.numeric(days))$y
  data.frame(year = y, ndays = length(days), sii_icedays = sum(e), sii_max_gap = gap)
}
si <- do.call(rbind, lapply(ti$year, sii_year))

cmp <- merge(ti, si, by = "year")
cmp <- cmp[cmp$sii_max_gap <= 3, ]
cmp$cdr_mean_extent_Mkm2 <- cmp$icedays / cmp$ndays / 1e6
cmp$sii_mean_extent_Mkm2 <- cmp$sii_icedays / cmp$ndays / 1e6
cmp$ratio <- cmp$cdr_mean_extent_Mkm2 / cmp$sii_mean_extent_Mkm2
anom <- function(x) x - mean(x)
tr <- function(x, t) unname(stats::coef(stats::lm(x ~ t))[2]) * 10
summ <- data.frame(
  years = nrow(cmp), first = min(cmp$year), last = max(cmp$year),
  cdr_mean_Mkm2 = mean(cmp$cdr_mean_extent_Mkm2), sii_mean_Mkm2 = mean(cmp$sii_mean_extent_Mkm2),
  ratio_mean = mean(cmp$ratio), ratio_min = min(cmp$ratio), ratio_max = max(cmp$ratio),
  cor_anomaly = stats::cor(anom(cmp$cdr_mean_extent_Mkm2), anom(cmp$sii_mean_extent_Mkm2)),
  rmse_anomaly_Mkm2 = sqrt(mean((anom(cmp$cdr_mean_extent_Mkm2) - anom(cmp$sii_mean_extent_Mkm2))^2)),
  cdr_trend_Mkm2_decade = tr(cmp$cdr_mean_extent_Mkm2, cmp$year),
  sii_trend_Mkm2_decade = tr(cmp$sii_mean_extent_Mkm2, cmp$year),
  cdr_trend_pct_decade = 100 * tr(cmp$cdr_mean_extent_Mkm2, cmp$year) / mean(cmp$cdr_mean_extent_Mkm2),
  sii_trend_pct_decade = 100 * tr(cmp$sii_mean_extent_Mkm2, cmp$year) / mean(cmp$sii_mean_extent_Mkm2))
print(format(summ, digits = 4), row.names = FALSE)
write.csv(cmp, file.path(outdir, "ice_nsidc_by_year.csv"), row.names = FALSE)
write.csv(summ, file.path(outdir, "ice_nsidc_summary.csv"), row.names = FALSE)

grDevices::png(file.path(outdir, "ice_nsidc_check.png"), width = 1600, height = 700, res = 150)
op <- graphics::par(mfrow = c(1, 2), mar = c(4.2, 4.2, 2, 1))
graphics::plot(cmp$year, cmp$cdr_mean_extent_Mkm2, type = "b", pch = 19, col = "#1f5fa8",
               ylim = range(c(cmp$cdr_mean_extent_Mkm2, cmp$sii_mean_extent_Mkm2)),
               xlab = "ice year (Feb 15 start)", ylab = "mean daily extent (million km2)",
               main = "Antarctic mean daily sea ice extent")
graphics::lines(cmp$year, cmp$sii_mean_extent_Mkm2, type = "b", pch = 1, col = "#c0392b")
graphics::legend("bottomleft", c("trend.ice cell sums (CDR v6)", "Sea Ice Index v3 (NASA Team)"),
                 col = c("#1f5fa8", "#c0392b"), pch = c(19, 1), lty = 1, bty = "n")
graphics::plot(anom(cmp$sii_mean_extent_Mkm2), anom(cmp$cdr_mean_extent_Mkm2), pch = 19, asp = 1,
               xlab = "Sea Ice Index anomaly (million km2)", ylab = "trend.ice anomaly (million km2)",
               main = sprintf("anomalies, r = %.3f", summ$cor_anomaly))
graphics::abline(0, 1, lty = 2)
graphics::par(op)
invisible(grDevices::dev.off())
cat("wrote", file.path(outdir, c("ice_nsidc_by_year.csv", "ice_nsidc_summary.csv", "ice_nsidc_check.png")), sep = "\n")
