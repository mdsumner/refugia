## Join water, green-cover and thermal metrics into one table per S2 level 13
## cell, with the level 10 parent carrying the AGCD exposure.
##
## Rscript pilots/australia/join_candidates.R <dir>
##
## Reads from <dir>: wofs_persistence_L13.rds, wofs_pixyears_L13.rds,
## fc_persistence_L13.rds, agcd_exposure_L10.rds. Writes
## refugia_candidates_L13.rds/.csv and a per-IBRA overlap summary.
## water_refugium: at least one land pixel wet in >= 50% of 20+ observed years.
## Artificial water is not yet masked.

a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data"
w <- readRDS(file.path(dir, "wofs_persistence_L13.rds"))
px <- readRDS(file.path(dir, "wofs_pixyears_L13.rds"))
g <- readRDS(file.path(dir, "fc_persistence_L13.rds"))
e <- readRDS(file.path(dir, "agcd_exposure_L10.rds"))

d <- g[c("cell", "ibra", "g10_all", "g10_dry_ratio", "g10_trend_decade", "green_candidate")]
pxa <- stats::aggregate(cbind(px_land, px_obs20, px_wet90, px_wet50, px_ever) ~ cell, data = px, FUN = sum)
d <- merge(d, pxa, by = "cell", all.x = TRUE)
d <- merge(d, w[c("cell", "wf_all", "wf_dry", "years_wet", "years_obs")], by = "cell", all.x = TRUE)
d$parent10 <- as.character(s2::s2_cell_parent(s2::as_s2_cell(d$cell), 10L))
ee <- e[c("cell", "clim_tmax", "slope_decade_tmax", "velocity_km_decade_tmax", "slope_decade_tmin",
          "precip_rel_decade", "thermal_candidate")]
names(ee)[1] <- "parent10"
d <- merge(d, ee, by = "parent10", all.x = TRUE)
ctr <- s2::s2_cell_center(s2::as_s2_cell(d$cell)); d$lon <- s2::s2_x(ctr); d$lat <- s2::s2_y(ctr)
d$water_refugium <- !is.na(d$px_wet50) & d$px_wet50 > 0
d$green_refugium <- d$green_candidate %in% TRUE
d$thermal_refugium <- d$thermal_candidate %in% TRUE
d$n_kinds <- d$water_refugium + d$green_refugium + d$thermal_refugium
d$green_candidate <- d$thermal_candidate <- NULL
saveRDS(d, file.path(dir, "refugia_candidates_L13.rds"))
write.csv(d, file.path(dir, "refugia_candidates_L13.csv"), row.names = FALSE)
summ <- do.call(rbind, lapply(split(d, d$ibra), function(x) data.frame(
  ibra = x$ibra[1], cells = nrow(x), water = sum(x$water_refugium), green = sum(x$green_refugium),
  thermal = sum(x$thermal_refugium), water_green = sum(x$water_refugium & x$green_refugium),
  green_thermal = sum(x$green_refugium & x$thermal_refugium),
  water_thermal = sum(x$water_refugium & x$thermal_refugium), all_three = sum(x$n_kinds == 3))))
print(summ, row.names = FALSE)
write.csv(summ, file.path(dir, "refugia_candidates_summary.csv"), row.names = FALSE)
