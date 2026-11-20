## Export every pilot to the shared cell schema (R/schema.R).
##
## Rscript pilots/export_cells.R <refugia_dir> <outdir>
##
## <refugia_dir> is the project folder layout: refugia_candidates_L13.rds,
## agcd_exposure_L10.rds, ice_out/ice_exposure_L9.rds,
## sst_out/sst_exposure_L9.rds, era5_out/era5_exposure_L9.rds and
## era5_out/icefree_exposure_L13.rds. Writes to <outdir>:
##   cells_metrics.csv  long table, one row per cell, variable and metric
##   cells_flags.csv    long table, one row per cell and candidate kind
##   rules.csv          the candidate rule per domain, in words
##   bridge_summary.csv one row per domain and kind: cells scored, candidates,
##                      share, and how many cells clear |snr| >= 2 on the
##                      main exposure variable
## sources/cells_parquet.py turns the two long tables into parquet.

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))
a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data"
outdir <- if (length(a) > 1) a[2] else file.path(dir, "mvp")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
S <- spec_rows
M <- list(); F <- list()

## Australia, level 10: AGCD exposure
e <- readRDS(file.path(dir, "agcd_exposure_L10.rds"))
M$agcd <- schema_metrics(e, rbind(
  S(c("clim_tmax", "tmax", "clim", "deg C")), S(c("slope_decade_tmax", "tmax", "trend_decade", "deg C")),
  S(c("snr_tmax", "tmax", "snr", "1")), S(c("velocity_km_decade_tmax", "tmax", "velocity_km_decade", "km")),
  S(c("slope_decade_tmax_pct", "tmax", "pct_trend_decade", "1")),
  S(c("velocity_km_decade_tmax_pct", "tmax", "pct_velocity_km_decade", "1")),
  S(c("clim_tmin", "tmin", "clim", "deg C")), S(c("slope_decade_tmin", "tmin", "trend_decade", "deg C")),
  S(c("snr_tmin", "tmin", "snr", "1")), S(c("velocity_km_decade_tmin", "tmin", "velocity_km_decade", "km")),
  S(c("clim_precip", "precip", "clim", "mm")), S(c("slope_decade_precip", "precip", "trend_decade", "mm")),
  S(c("snr_precip", "precip", "snr", "1"))),
  domain = "australia_land", source = "AGCD v1-0-4", period = "1971-2025", level = 10,
  region_set = "IBRA7", region = "ibra")
e$thermal_candidate <- e$thermal_candidate %in% TRUE
F$agcd <- schema_flags(e, c(thermal = "thermal_candidate"), "australia_land", 10, "IBRA7", "ibra")

## Australia, level 13: water and green persistence, joined flags
d <- readRDS(file.path(dir, "refugia_candidates_L13.rds"))
d$px_wet90_nat <- as.double(d$px_wet90_nat); d$px_wet50_nat <- as.double(d$px_wet50_nat)
M$dea <- schema_metrics(d, rbind(
  S(c("wf_all", "water", "persistence", "fraction")), S(c("wf_dry", "water_dry_years", "persistence", "fraction")),
  S(c("px_wet90_nat", "water_wet90_pixels", "extent", "pixels")),
  S(c("px_wet50_nat", "water_wet50_pixels", "extent", "pixels")),
  S(c("g10_all", "green10", "clim", "percent")), S(c("g10_dry_ratio", "green10", "dry_ratio", "1")),
  S(c("g10_trend_decade", "green10", "trend_decade", "percent"))),
  domain = "australia_land", source = "DEA WOfS + Fractional Cover (Landsat)", period = "1987-2025",
  level = 13, region_set = "IBRA7", region = "ibra")
d$green_used <- d$green_refugium & d$green_applies
F$dea <- schema_flags(d, c(water = "water_refugium", green = "green_used", thermal = "thermal_refugium"),
                      "australia_land", 13, "IBRA7", "ibra")

## Antarctica, level 9: sea ice season (seasonal ice zone only)
ice <- readRDS(file.path(dir, "ice_out", "ice_exposure_L9.rds"))
ice <- ice[ice$seasonal_zone %in% TRUE, ]
M$ice <- schema_metrics(ice, rbind(
  S(c("clim_daycount", "ice_days", "clim", "days")), S(c("slope_decade_daycount", "ice_days", "trend_decade", "days")),
  S(c("snr_daycount", "ice_days", "snr", "1")),
  S(c("velocity_km_decade_daycount", "ice_days", "velocity_km_decade", "km")),
  S(c("slope_decade_daycount_pct", "ice_days", "pct_trend_decade", "1")),
  S(c("loss_velocity_pct", "ice_days", "pct_velocity_km_decade", "1")),
  S(c("season_frac", "ice_season", "persistence", "fraction")),
  S(c("slope_decade_duration", "ice_duration", "trend_decade", "days")),
  S(c("slope_decade_advance", "ice_advance", "trend_decade", "days")),
  S(c("slope_decade_retreat", "ice_retreat", "trend_decade", "days"))),
  domain = "antarctic_sea_ice", source = "trend.ice (NSIDC CDR)", period = "1979-2025",
  level = 9, region_set = "trend.ice sector", region = "sector")
F$ice <- schema_flags(ice, c(sea_ice_holdout = "ice_refugium"), "antarctic_sea_ice", 9, "trend.ice sector", "sector")

## Antarctica, level 9: summer open-water SST
sst <- readRDS(file.path(dir, "sst_out", "sst_exposure_L9.rds"))
sst <- sst[sst$summer_open_zone %in% TRUE, ]
M$sst <- schema_metrics(sst, rbind(
  S(c("clim_jfm", "summer_sst", "clim", "deg C")), S(c("slope_decade_jfm", "summer_sst", "trend_decade", "deg C")),
  S(c("snr_jfm", "summer_sst", "snr", "1")),
  S(c("velocity_km_decade_jfm", "summer_sst", "velocity_km_decade", "km")),
  S(c("warming_pct", "summer_sst", "pct_trend_decade", "1")),
  S(c("warm_velocity_pct", "summer_sst", "pct_velocity_km_decade", "1"))),
  domain = "antarctic_ocean", source = "OISST v2.1", period = "1982-2025",
  level = 9, region_set = "trend.ice sector", region = "sector")
F$sst <- schema_flags(sst, c(sst_holdout = "sst_refugium"), "antarctic_ocean", 9, "trend.ice sector", "sector")

## Antarctica, level 9 and 13: ice-free land, ERA5 summer temperature
land <- readRDS(file.path(dir, "era5_out", "era5_exposure_L9.rds"))
land <- land[land$icefree %in% TRUE, ]
M$land <- schema_metrics(land, rbind(
  S(c("clim_t", "summer_t2m", "clim", "deg C")), S(c("slope_decade_t", "summer_t2m", "trend_decade", "deg C")),
  S(c("snr_t", "summer_t2m", "snr", "1")), S(c("velocity_km_decade_t", "summer_t2m", "velocity_km_decade", "km")),
  S(c("warming_pct", "summer_t2m", "pct_trend_decade", "1")),
  S(c("warm_velocity_pct", "summer_t2m", "pct_velocity_km_decade", "1")),
  S(c("clim_pdd", "summer_pdd", "clim", "deg C days")), S(c("slope_decade_pdd", "summer_pdd", "trend_decade", "deg C days")),
  S(c("snr_pdd", "summer_pdd", "snr", "1")), S(c("rock_km2", "icefree", "extent", "km2"))),
  domain = "antarctic_land", source = "ERA5 (NSF NCAR copy) + rock outcrop v7.3", period = "1980-2026",
  level = 9, region_set = "sector (Peninsula split)", region = "sector")
F$land <- schema_flags(land, c(land_holdout = "land_refugium"), "antarctic_land", 9,
                       "sector (Peninsula split)", "sector")
l13 <- readRDS(file.path(dir, "era5_out", "icefree_exposure_L13.rds"))
M$l13 <- schema_metrics(l13, rbind(S(c("rock_km2", "icefree", "extent", "km2")),
                                   S(c("icefree_frac", "icefree", "persistence", "fraction"))),
  domain = "antarctic_land", source = "rock outcrop v7.3", period = "static",
  level = 13, region_set = "sector (Peninsula split)", region = "sector")
F$l13 <- schema_flags(l13, c(land_holdout = "land_refugium"), "antarctic_land", 13,
                      "sector (Peninsula split)", "sector")

metrics <- do.call(rbind, M); rownames(metrics) <- NULL
flags <- do.call(rbind, F); rownames(flags) <- NULL
stopifnot(identical(names(metrics), schema_metrics_cols), identical(names(flags), schema_flags_cols))
write.csv(metrics, file.path(outdir, "cells_metrics.csv"), row.names = FALSE)
write.csv(flags, file.path(outdir, "cells_flags.csv"), row.names = FALSE)

rules <- data.frame(
  domain = c("australia_land", "australia_land", "australia_land", "antarctic_sea_ice", "antarctic_ocean", "antarctic_land"),
  kind = c("thermal", "water", "green", "sea_ice_holdout", "sst_holdout", "land_holdout"),
  level = c(10, 13, 13, 9, 9, 9),
  exposure = c("Tmax trend in the region's lowest quarter AND Tmax velocity in the lowest quarter",
               "(persistence only)",
               "(persistence only)",
               "ice-day trend in the sector's top quarter (least loss) AND (gain OR loss velocity in the lowest quarter)",
               "summer SST trend in the sector's lowest quarter AND (cooling OR warming velocity in the lowest quarter)",
               "summer 2 m temperature trend in the sector's lowest quarter AND (cooling OR warming velocity in the lowest quarter)"),
  persistence = c("(exposure only)",
                  "natural pixel wet in >= 90% of 20+ observed years, or 3 pixels wet in >= 50%",
                  "dry-year green cover ratio in the region's top quarter and green cover above the region median (MacDonnell only)",
                  "ice season in >= 90% of years",
                  "(summer open-water zone)",
                  "ice-free rock present (rock outcrop v7.3)"),
  region_set = c("IBRA7", "IBRA7", "IBRA7", "trend.ice sector", "trend.ice sector", "sector (Peninsula split)"))
write.csv(rules, file.path(outdir, "rules.csv"), row.names = FALSE)

## bridge summary: same quantities for every domain
main <- data.frame(domain = c("australia_land", "antarctic_sea_ice", "antarctic_ocean", "antarctic_land"),
                   variable = c("tmax", "ice_days", "summer_sst", "summer_t2m"),
                   level = c(10, 9, 9, 9))
br <- do.call(rbind, lapply(split(flags, list(flags$domain, flags$kind, flags$level), drop = TRUE), function(x) {
  mv <- main[main$domain == x$domain[1], ]
  sn <- metrics[metrics$domain == x$domain[1] & metrics$variable == mv$variable &
                  metrics$metric == "snr" & metrics$level == mv$level, ]
  tr <- metrics[metrics$domain == x$domain[1] & metrics$variable == mv$variable &
                  metrics$metric == "trend_decade" & metrics$level == mv$level, ]
  data.frame(domain = x$domain[1], kind = x$kind[1], level = x$level[1],
             regions = length(unique(x$region)), cells = nrow(x), candidates = sum(x$flag),
             share = round(mean(x$flag), 3), exposure_variable = mv$variable,
             median_trend_decade = signif(stats::median(tr$value), 3),
             snr2_share = round(mean(abs(sn$value) >= 2), 3))
}))
br <- br[order(match(br$domain, main$domain), br$level), ]
print(br, row.names = FALSE)
write.csv(br, file.path(outdir, "bridge_summary.csv"), row.names = FALSE)
cat(nrow(metrics), "metric rows,", nrow(flags), "flag rows ->", outdir, "\n")
