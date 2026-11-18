## Combine per-tile pixel wet-years summaries into one table per S2 cell.
##
## Rscript pilots/australia/wofs_pixel_summary.R <sums_dir> <outdir>
##
## Cells straddling tile edges add. Columns: px_land (pixels inside IBRA),
## px_obs20 (land pixels with >= 20 observed years), px_wet90 / px_wet50
## (of those, wet in >= 90% / >= 50% of observed years), px_ever.

a <- commandArgs(TRUE)
sums_dir <- if (length(a) > 0) a[1] else "data/wofs"
outdir <- if (length(a) > 1) a[2] else "data"
f <- list.files(sums_dir, "^pixyears_.*_L13[.]rds$", full.names = TRUE)
s <- do.call(rbind, lapply(f, readRDS))
s <- stats::aggregate(cbind(px_land, px_obs20, px_wet90, px_wet50, px_ever) ~ cell + region, data = s, FUN = sum)
ctr <- s2::s2_cell_center(s2::as_s2_cell(s$cell))
s$lon <- s2::s2_x(ctr); s$lat <- s2::s2_y(ctr)
s <- s[s$px_land > 0, ]
saveRDS(s, file.path(outdir, "wofs_pixyears_L13.rds"))
write.csv(s, file.path(outdir, "wofs_pixyears_L13.csv"), row.names = FALSE)
print(do.call(rbind, lapply(split(s, s$region), function(d) data.frame(
  region = d$region[1], cells = nrow(d), cells_wet90 = sum(d$px_wet90 > 0),
  cells_wet50 = sum(d$px_wet50 > 0), px_wet90 = sum(d$px_wet90)))), row.names = FALSE)
