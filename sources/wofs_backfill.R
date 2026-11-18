## Backfill WOfS annual wet/clear sums into S2 cells, per tile.
##
## Rscript sources/wofs_backfill.R <outdir> [level]
##
## One mapping per tile (cached as <outdir>/mapping_<tile>_L<level>.rds), then
## one sums file per tile-year (<outdir>/sums_<tile>_<year>_L<level>.rds).
## Rerun to resume: existing outputs are skipped, failures retry next run.

Sys.setenv(PROJ_NETWORK = "OFF", GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR")
if (file.exists("/root/.ccr/ca-bundle.crt")) Sys.setenv(CURL_CA_BUNDLE = "/root/.ccr/ca-bundle.crt")
if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))

a <- commandArgs(TRUE)
outdir <- if (length(a) > 0) a[1] else "data/wofs"
lev <- if (length(a) > 1) as.integer(a[2]) else 13L
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

source("sources/pilot_tiles.R")
tiles <- pilot_tiles
years <- 1986:2025

wofs_url <- function(x, y, year, band) {
  sprintf(paste0("/vsicurl/https://dea-public-data.s3.ap-southeast-2.amazonaws.com/",
                 "derivative/ga_ls_wo_fq_cyear_3/2-0-0/x%02d/y%02d/%d--P1Y/",
                 "ga_ls_wo_fq_cyear_3_x%02dy%02d_%d--P1Y_final_%s.tif"),
          x, y, year, x, y, year, band)
}
read_band <- function(x, y, year, band) {
  r <- terra::rast(wofs_url(x, y, year, band))
  v <- terra::values(r, mat = FALSE)
  v[v == -999] <- NA
  v
}

for (i in seq_len(nrow(tiles))) {
  tx <- tiles$x[i]; ty <- tiles$y[i]
  tile <- sprintf("x%02dy%02d", tx, ty)
  mf <- file.path(outdir, sprintf("mapping_%s_L%d.rds", tile, lev))
  if (file.exists(mf)) m <- readRDS(mf) else { m <- build_tile_mapping(tx, ty, level = lev); saveRDS(m, mf) }
  idx <- mapping_index(m)
  for (yr in years) {
    sf <- file.path(outdir, sprintf("sums_%s_%d_L%d.rds", tile, yr, lev))
    if (file.exists(sf)) next
    res <- try({
      wet <- read_band(tx, ty, yr, "count_wet"); clear <- read_band(tx, ty, yr, "count_clear")
      s <- sum_to_cells(m, wet = wet, clear = clear, index = idx)
      stopifnot(sum(s$wet) == sum(wet, na.rm = TRUE), sum(s$clear) == sum(clear, na.rm = TRUE))
      s$year <- yr; s$tile <- tile; s$region <- tiles$region[i]
      saveRDS(s, sf)
    }, silent = TRUE)
    cat(format(Sys.time(), "%H:%M:%S"), tile, yr, if (inherits(res, "try-error")) paste("FAIL", conditionMessage(attr(res, "condition"))) else "ok", "\n")
  }
}
