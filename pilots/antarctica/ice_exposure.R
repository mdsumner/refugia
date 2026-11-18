## Sea ice season exposure and persistence per S2 level 9 cell (trend.ice).
##
## Rscript pilots/antarctica/ice_exposure.R <ice_dir> <outdir> [first_year] [last_year]
##
## <ice_dir> holds ice_L9_<year>.rds and direct_pixels.csv from gadi/ice_sums.R.
##
## Annual cell values (area-weighted over the cell):
##   daycount  mean days with ice (all observed area; 0 counts)
##   duration  mean season length, retreat - advance (complete seasons only)
##   advance, retreat  mean day of the ice year (day 1 = Feb 15)
## A season value is used only when complete seasons cover at least half the
## observed area of the cell that year.
##
## Per cell: climatology, trend per decade, signal-to-noise, velocity of the
## daycount (trend over the local gradient of the climatology, km per decade),
## and persistence: the share of years in which the cell had an ice season.
## Scored within the five trend.ice sectors (Weddell 60W-20E, Indian 20E-90E,
## W Pacific 90E-160E, Ross 160E-130W, Bell-Amundsen 130W-60W), on the seasonal
## ice zone only (mean daycount 30-335 days).
##
## Candidate sea ice refugium (holdout): in its sector, daycount trend in the
## top quarter (least loss or a gain), velocity in the lowest quarter, and an
## ice season in at least 90% of years.
##
## Gate: the area mean annual duration and daycount from the cell sums equal
## the plain per-pixel means (direct_pixels.csv), and so do their trends.

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))
a <- commandArgs(TRUE)
indir <- if (length(a) > 0) a[1] else "data/ice_L9"
outdir <- if (length(a) > 1) a[2] else "data"
y0 <- if (length(a) > 2) as.integer(a[3]) else 1979L
y1 <- if (length(a) > 3) as.integer(a[4]) else 2025L

ff <- list.files(indir, "^ice_L9_[0-9]{4}[.]rds$", full.names = TRUE)
d <- do.call(rbind, lapply(ff, readRDS))
d <- d[d$year >= y0 & d$year <= y1, ]
years <- sort(unique(d$year))
cat(length(ff), "files;", length(years), "years", min(years), "-", max(years), ";", length(unique(d$cell)), "cells\n")

## gate: area means from sums vs direct per-pixel means
sub_tot <- aggregate(cbind(w_obs, w_season, s_duration, s_daycount) ~ year, data = d, FUN = sum)
dp <- utils::read.csv(file.path(indir, "direct_pixels.csv"))
gate <- merge(sub_tot, dp, by = "year")
gate$mean_duration_sums <- gate$s_duration / gate$w_season
gate$mean_daycount_sums <- gate$s_daycount / gate$w_obs
gate$d_duration <- gate$mean_duration_sums - gate$mean_duration
gate$d_daycount <- gate$mean_daycount_sums - gate$mean_daycount
gate$d_area <- gate$w_season - gate$npix_season
tr <- function(x, t) unname(stats::coef(stats::lm(x ~ t))[2]) * 10
gate_summary <- data.frame(
  max_abs_diff_duration = max(abs(gate$d_duration)), max_abs_diff_daycount = max(abs(gate$d_daycount)),
  max_abs_diff_season_area_px = max(abs(gate$d_area)),
  trend_duration_sums = tr(gate$mean_duration_sums, gate$year), trend_duration_direct = tr(gate$mean_duration, gate$year),
  trend_daycount_sums = tr(gate$mean_daycount_sums, gate$year), trend_daycount_direct = tr(gate$mean_daycount, gate$year))
print(gate_summary, row.names = FALSE)
write.csv(gate, file.path(outdir, "ice_gate_by_year.csv"), row.names = FALSE)
stopifnot(gate_summary$max_abs_diff_duration < 1e-6, gate_summary$max_abs_diff_daycount < 1e-6)

## annual cell values
ok_season <- d$w_season >= 0.5 * d$w_obs & d$w_season > 0
ann <- function(v, ok, w) data.frame(cell = d$cell[ok], year = d$year[ok], value = d[[v]][ok] / d[[w]][ok])
out <- NULL
for (v in c("daycount", "duration", "advance", "retreat")) {
  x <- if (v == "daycount") ann("s_daycount", d$w_obs > 0, "w_obs") else ann(paste0("s_", v), ok_season, "w_season")
  t <- cell_trends(x, years)
  t <- t[t$n >= 0.75 * length(years), ]
  names(t)[-1] <- paste0(names(t)[-1], "_", v)
  out <- if (is.null(out)) t else merge(out, t, by = "cell", all = TRUE)
}
per <- aggregate(cbind(has = as.numeric(d$w_season > 0.5 * d$w_obs), one = 1) ~ cell,
                 data = data.frame(cell = d$cell, w_season = d$w_season, w_obs = d$w_obs), FUN = sum)
per$season_frac <- per$has / per$one
out <- merge(out, per[c("cell", "season_frac")], by = "cell", all.x = TRUE)
out$velocity_km_decade_daycount <- out$slope_decade_daycount / cell_gradient(out$cell, out$clim_daycount)

ctr <- s2::s2_cell_center(s2::as_s2_cell(out$cell)); out$lon <- s2::s2_x(ctr); out$lat <- s2::s2_y(ctr)
sector_levels <- c("Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen")
out$sector <- as.character(cut(out$lon, c(-180, -130, -60, 20, 90, 160, 180),
                               labels = c("Ross", "Bell-Amundsen", "Weddell", "Indian", "W Pacific", "Ross2")))
out$sector[out$sector == "Ross2"] <- "Ross"
out$ccamlr_area <- ifelse(out$lon >= -70 & out$lon < 30, "48", ifelse(out$lon >= 30 & out$lon < 150, "58", "88"))
siz <- is.finite(out$clim_daycount) & out$clim_daycount >= 30 & out$clim_daycount <= 335
out$seasonal_zone <- siz
out$slope_decade_daycount_pct <- NA_real_; out$velocity_daycount_pct <- NA_real_
out$slope_decade_daycount_pct[siz] <- group_percentile(out$slope_decade_daycount[siz], out$sector[siz])
out$velocity_daycount_pct[siz] <- group_percentile(abs(out$velocity_km_decade_daycount[siz]), out$sector[siz])
out$ice_refugium <- siz & out$slope_decade_daycount_pct >= 0.75 & out$velocity_daycount_pct <= 0.25 &
  out$season_frac >= 0.9
out$ice_refugium[is.na(out$ice_refugium)] <- FALSE
saveRDS(out, file.path(outdir, "ice_exposure_L9.rds"))
write.csv(out, file.path(outdir, "ice_exposure_L9.csv"), row.names = FALSE)

q <- function(x) sprintf("%.1f [%.1f, %.1f]", stats::median(x, na.rm = TRUE),
                         stats::quantile(x, 0.1, na.rm = TRUE), stats::quantile(x, 0.9, na.rm = TRUE))
z <- out[siz, ]
summ <- do.call(rbind, lapply(split(z, z$sector), function(s) data.frame(
  sector = s$sector[1], cells = nrow(s),
  daycount_clim = q(s$clim_daycount), daycount_trend = q(s$slope_decade_daycount),
  duration_trend = q(s$slope_decade_duration), advance_trend = q(s$slope_decade_advance),
  retreat_trend = q(s$slope_decade_retreat), velocity_km_decade = q(s$velocity_km_decade_daycount),
  refugium_cells = sum(s$ice_refugium))))
summ <- summ[match(intersect(sector_levels, summ$sector), summ$sector), ]
print(summ, row.names = FALSE)
write.csv(summ, file.path(outdir, "ice_exposure_summary.csv"), row.names = FALSE)
