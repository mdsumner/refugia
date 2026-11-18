## Green-cover persistence per S2 level 13 cell from DEA Fractional Cover.
##
## Rscript pilots/australia/fc_persistence.R <fc_dir> <agcd_dir> <outdir>
##
## pv_pc_10 is each pixel's 10th percentile of green cover in a year, the
## driest part of that year. Per cell: mean pv_pc_10 over 1988-2025, the same
## over the region's five driest years (lowest annual AGCD rainfall, regional
## mean), their ratio, and the trend per decade. Scored within IBRA region.
## Candidate green refugium: upper quarter of its region for the dry-year
## ratio, and green10 over the record at or above the region median.

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))
a <- commandArgs(TRUE)
fc_dir <- if (length(a) > 0) a[1] else "data/fc_L13"
agcd_dir <- if (length(a) > 1) a[2] else "data/agcd_L10"
outdir <- if (length(a) > 2) a[3] else "data"
years <- 1988:2025

## dry years per pilot from AGCD rainfall
pr <- readRDS(file.path(agcd_dir, "agcd_precip_L10_all.rds"))
pr <- pr[pr$year %in% years, ]
reg <- stats::aggregate(cbind(sum, pixdays) ~ region + year, data = pr, FUN = sum)
reg$mm <- reg$sum / reg$pixdays * 365.25
dry <- lapply(split(reg, reg$region), function(d) sort(d$year[order(d$mm)][1:5]))
print(dry)

f <- list.files(fc_dir, "^fc_.*_L13[.]rds$", full.names = TRUE)
x <- do.call(rbind, lapply(f, function(p) readRDS(p)[c("cell", "year", "region", "n", "pv_pc_10", "pv_pc_50")]))
x <- x[x$year %in% years, ]
## cell-years across tiles add
key <- paste(x$cell, x$year, x$region)
s <- rowsum(as.matrix(x[c("n", "pv_pc_10", "pv_pc_50")]), key, reorder = FALSE)
k <- !duplicated(key)
x <- data.frame(x[k, c("cell", "year", "region")], s, row.names = NULL)
x$isdry <- mapply(function(r, y) y %in% dry[[r]], x$region, x$year)

cells <- sort(unique(x$cell)); fc <- factor(x$cell, levels = cells)
S <- function(v) as.vector(tapply(v, fc, sum))
out <- data.frame(cell = cells,
                  region = x$region[match(cells, x$cell)],
                  n_all = S(x$n), g10_all = S(x$pv_pc_10) / S(x$n), g50_all = S(x$pv_pc_50) / S(x$n),
                  g10_dry = S(ifelse(x$isdry, x$pv_pc_10, 0)) / S(ifelse(x$isdry, x$n, 0)))
out$g10_dry_ratio <- out$g10_dry / out$g10_all
ann <- data.frame(cell = x$cell, year = x$year, value = x$pv_pc_10 / x$n)
tr <- cell_trends(ann, years)
out$g10_trend_decade <- tr$slope_decade[match(out$cell, tr$cell)]
out$g10_snr <- tr$snr[match(out$cell, tr$cell)]

out$ibra <- cells_in_polygons(out$cell, "regions/ibra7/ibra7_regions_pilot.geojson", "REG_CODE_7")
out <- out[!is.na(out$ibra) & out$ibra != "FUR", ]
out$g10_dry_ratio_pct <- group_percentile(out$g10_dry_ratio, out$ibra)
med <- tapply(out$g10_all, out$ibra, stats::median, na.rm = TRUE)
out$green_candidate <- out$g10_dry_ratio_pct >= 0.75 & out$g10_all >= med[out$ibra]
saveRDS(out, file.path(outdir, "fc_persistence_L13.rds"))
summ <- do.call(rbind, lapply(split(out, out$ibra), function(d) data.frame(
  ibra = d$ibra[1], cells = nrow(d), g10_median = round(stats::median(d$g10_all, na.rm = TRUE), 1),
  dry_ratio_median = round(stats::median(d$g10_dry_ratio, na.rm = TRUE), 3),
  g10_trend_median = round(stats::median(d$g10_trend_decade, na.rm = TRUE), 2),
  green_candidates = sum(d$green_candidate, na.rm = TRUE))))
print(summ, row.names = FALSE)
write.csv(summ, file.path(outdir, "fc_persistence_summary.csv"), row.names = FALSE)
