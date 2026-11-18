## Backfill DEA Fractional Cover annual percentiles into S2 cells, per tile-year.
##
## Rscript sources/fc_backfill.R <outdir> [level] [mapping_dir]
##
## For green (pv) cover, the 10th and 50th annual percentiles: the 10th is the
## driest part of the year, so its persistence through dry years marks green
## refugia. Per cell: n (valid land pixels) and sums of each band and its
## square. Pixels outside IBRA land are dropped. Resumable.

Sys.setenv(PROJ_NETWORK = "OFF", GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR")
if (file.exists("/root/.ccr/ca-bundle.crt")) Sys.setenv(CURL_CA_BUNDLE = "/root/.ccr/ca-bundle.crt")
if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))

a <- commandArgs(TRUE)
outdir <- if (length(a) > 0) a[1] else "data/fc"
lev <- if (length(a) > 1) as.integer(a[2]) else 13L
mapdir <- if (length(a) > 2) a[3] else outdir
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
source("sources/pilot_tiles.R")
years <- 1987:2025
bands <- c("pv_pc_10", "pv_pc_50")

fc_url <- function(x, y, year, band) {
  sprintf(paste0("/vsicurl/https://dea-public-data.s3.ap-southeast-2.amazonaws.com/",
                 "derivative/ga_ls_fc_pc_cyear_3/4-0-0/x%02d/y%02d/%d--P1Y/",
                 "ga_ls_fc_pc_cyear_3_x%02dy%02d_%d--P1Y_final_%s.tif"),
          x, y, year, x, y, year, band)
}
ibra <- terra::project(terra::vect("regions/ibra7/ibra7_regions_pilot.geojson"), "EPSG:3577")
land_mask <- function(g) {
  r <- terra::rast(ncols = g$dimension[["ncol"]], nrows = g$dimension[["nrow"]],
                   xmin = g$extent[["xmin"]], xmax = g$extent[["xmax"]],
                   ymin = g$extent[["ymin"]], ymax = g$extent[["ymax"]], crs = g$crs)
  !is.na(terra::values(terra::rasterize(ibra, r, field = 1), mat = FALSE))
}

for (i in seq_len(nrow(pilot_tiles))) {
  tx <- pilot_tiles$x[i]; ty <- pilot_tiles$y[i]
  tile <- sprintf("x%02dy%02d", tx, ty)
  mf <- file.path(mapdir, sprintf("mapping_%s_L%d.rds", tile, lev))
  m <- if (file.exists(mf)) readRDS(mf) else build_tile_mapping(tx, ty, level = lev)
  idx <- mapping_index(m); land <- land_mask(m$grid)
  for (yr in years) {
    sf <- file.path(outdir, sprintf("fc_%s_%d_L%d.rds", tile, yr, lev))
    if (file.exists(sf)) next
    res <- try({
      v <- lapply(bands, function(b) {
        x <- as.numeric(terra::values(terra::rast(fc_url(tx, ty, yr, b)), mat = FALSE))
        x[x == 255 | !land] <- NA
        x
      })
      names(v) <- bands
      s <- do.call(sum_to_cells, c(list(m), v, setNames(lapply(v, function(x) x * x), paste0(bands, "_sq")), list(index = idx)))
      s <- s[s$n > 0, ]
      s$year <- yr; s$tile <- tile; s$region <- pilot_tiles$region[i]
      saveRDS(s, sf)
    }, silent = TRUE)
    cat(format(Sys.time(), "%H:%M:%S"), tile, yr, if (inherits(res, "try-error")) paste("FAIL", conditionMessage(attr(res, "condition"))) else "ok", "\n")
  }
}
