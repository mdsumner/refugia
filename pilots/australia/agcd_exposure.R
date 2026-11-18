## Climate exposure per S2 level 10 cell from AGCD (1971-2025).
##
## Rscript pilots/australia/agcd_exposure.R <agcd_dir> <outdir>
##
## Per cell and variable: climatology, trend per decade, signal-to-noise, and
## for temperature the climate velocity (trend over local spatial gradient of
## the climatology, km per decade). Each metric is scored as a percentile
## within the cell's IBRA region (by cell centre). A candidate thermal refugium
## is in the lowest quarter of its region for both the tmax trend and the tmax
## velocity.

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))
a <- commandArgs(TRUE)
indir <- if (length(a) > 0) a[1] else "data/agcd_L10"
outdir <- if (length(a) > 1) a[2] else "data"
years <- 1971:2025

out <- NULL
for (v in c("tmax", "tmin", "precip")) {
  d <- readRDS(file.path(indir, sprintf("agcd_%s_L10_all.rds", v)))
  for (rg in unique(d$region)) {
    dd <- d[d$region == rg, ]
    tr <- cell_trends(agcd_annual(dd, total = v == "precip"), years)
    tr$velocity_km_decade <- if (v == "precip") NA_real_ else
      tr$slope_decade / cell_gradient(tr$cell, tr$clim)
    tr$var <- v; tr$region <- rg
    out <- rbind(out, tr)
  }
}
w <- reshape(out[c("cell", "region", "var", "clim", "slope_decade", "snr", "velocity_km_decade")],
             idvar = c("cell", "region"), timevar = "var", direction = "wide", sep = "_")
ctr <- s2::s2_cell_center(s2::as_s2_cell(w$cell)); w$lon <- s2::s2_x(ctr); w$lat <- s2::s2_y(ctr)
w$ibra <- cells_in_polygons(w$cell, "regions/ibra7/ibra7_regions_pilot.geojson", "REG_CODE_7")
w <- w[!is.na(w$ibra) & w$ibra != "FUR", ]
## precip relative trend, % of climatology per decade
w$precip_rel_decade <- 100 * w$slope_decade_precip / w$clim_precip
for (m in c("slope_decade_tmax", "velocity_km_decade_tmax", "slope_decade_tmin", "velocity_km_decade_tmin"))
  w[[paste0(m, "_pct")]] <- group_percentile(abs(w[[m]]), w$ibra)
w$thermal_candidate <- w$slope_decade_tmax_pct <= 0.25 & w$velocity_km_decade_tmax_pct <= 0.25
saveRDS(w, file.path(outdir, "agcd_exposure_L10.rds"))
write.csv(w, file.path(outdir, "agcd_exposure_L10.csv"), row.names = FALSE)
q <- function(x) sprintf("%.2f [%.2f, %.2f]", stats::median(x, na.rm = TRUE), stats::quantile(x, 0.1, na.rm = TRUE), stats::quantile(x, 0.9, na.rm = TRUE))
summ <- do.call(rbind, lapply(split(w, w$ibra), function(d) data.frame(
  ibra = d$ibra[1], cells = nrow(d),
  tmax_trend = q(d$slope_decade_tmax), tmin_trend = q(d$slope_decade_tmin),
  tmax_velocity = q(d$velocity_km_decade_tmax), precip_rel = q(d$precip_rel_decade),
  thermal_candidates = sum(d$thermal_candidate, na.rm = TRUE))))
print(summ, row.names = FALSE)
write.csv(summ, file.path(outdir, "agcd_exposure_summary.csv"), row.names = FALSE)
