## Water persistence per S2 level 13 cell for the Australian pilot.
##
## Rscript pilots/australia/wofs_persistence.R <sums_dir> <outdir>
##
## Reads the WOfS backfill sums, combines tiles, computes persistence metrics,
## assigns IBRA regions and subregions by cell centre, scores each metric as a
## percentile within its IBRA region, and flags candidate hydrological refugia.

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))

a <- commandArgs(TRUE)
sums_dir <- if (length(a) > 0) a[1] else "data/wofs"
outdir <- if (length(a) > 1) a[2] else "data"
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(sums_dir, pattern = "^sums_.*_L13[.]rds$", full.names = TRUE)
cat(length(files), "tile-years\n")
s <- combine_cell_sums(files)
p <- water_persistence(s)

p$ibra <- cells_in_polygons(p$cell, "regions/ibra7/ibra7_regions_pilot.geojson", "REG_CODE_7")
p$ibra_sub <- cells_in_polygons(p$cell, "regions/ibra7/ibra7_subregions_pilot.geojson", "SUB_CODE_7")
p <- p[!is.na(p$ibra) & p$ibra != "FUR", ]  # FUR = Wilsons Promontory, mainland Victoria
ctr <- s2::s2_cell_center(s2::as_s2_cell(p$cell))
p$lon <- s2::s2_x(ctr); p$lat <- s2::s2_y(ctr)
p$pilot <- ifelse(p$ibra == "MAC", "macdonnell", "tasmania")

## water-bearing cells: at least the equivalent of 1 of ~1180 pixels wet on
## every clear look over the record
water <- is.finite(p$wf_all) & p$wf_all >= 1 / 1180
p$water <- water
p$dry_ratio_pct <- NA_real_
p$dry_ratio_pct[water] <- group_percentile(p$dry_ratio[water], p$ibra[water])
p$years_wet_pct <- NA_real_
p$years_wet_pct[water] <- group_percentile(p$years_wet[water] / p$years_obs[water], p$ibra[water])

## candidate hydrological refugia: wet in nearly every observed year, and in
## the upper quarter of the region for holding water through 2017-2019
p$candidate <- water & p$years_wet >= 0.9 * p$years_obs & p$dry_ratio_pct >= 0.75

saveRDS(p, file.path(outdir, "wofs_persistence_L13.rds"))
write.csv(p, file.path(outdir, "wofs_persistence_L13.csv"), row.names = FALSE)

summ <- do.call(rbind, lapply(split(p, p$ibra), function(d) data.frame(
  ibra = d$ibra[1], cells = nrow(d), water = sum(d$water), candidates = sum(d$candidate),
  median_clear_per_year = stats::median(d$clear_all / d$years_obs / 1180, na.rm = TRUE))))
print(summ, row.names = FALSE)
write.csv(summ, file.path(outdir, "wofs_persistence_summary.csv"), row.names = FALSE)
