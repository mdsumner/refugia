## Split persistent-water pixels into artificial and natural, per S2 cell.
##
## Rscript sources/water_mask.R <wofs_dir> [overture_dir] [buffer_m]
##
## Reads <wofs_dir>/wetpx_<tile>.rds (from sources/wofs_pixel_years.R: land
## pixels wet in >= 50% of 20+ observed years) and the artificial water
## polygons from sources/overture_water.py. A pixel is artificial when its
## centre falls within buffer_m (default 60 m, two pixels) of an artificial
## polygon; the buffer absorbs offsets between the mapped outline and the
## Landsat water edge. Hand-checked boxes in regions/water_exclusions.csv
## are applied on top: "exclude" pixels count as artificial, "review" pixels
## stay natural and are counted in px_wet50_review.
##
## Writes <wofs_dir>/wetpx_flagged_L13.rds (one row per wet pixel) and
## <wofs_dir>/water_cells_L13.rds with per-cell counts
## px_wet50_nat, px_wet90_nat, px_wet50_art, px_wet90_art, px_wet50_review.

Sys.setenv(PROJ_NETWORK = "OFF")
if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))
a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data/wofs"
ovdir <- if (length(a) > 1) a[2] else "regions/overture"
buf <- if (length(a) > 2) as.numeric(a[3]) else 60
source("sources/pilot_tiles.R")

art <- lapply(c(tasmania = "tasmania", macdonnell = "macdonnell"), function(r) {
  v <- terra::vect(file.path(ovdir, sprintf("artificial_water_%s.geojson", r)))
  terra::buffer(terra::project(v, "EPSG:3577"), buf)
})

ex <- utils::read.csv(file.path("regions", "water_exclusions.csv"), stringsAsFactors = FALSE)

out <- list()
for (i in seq_len(nrow(pilot_tiles))) {
  tx <- pilot_tiles$x[i]; ty <- pilot_tiles$y[i]; reg <- pilot_tiles$region[i]
  tile <- sprintf("x%02dy%02d", tx, ty)
  f <- file.path(dir, sprintf("wetpx_%s.rds", tile))
  if (!file.exists(f)) { cat(tile, "missing\n"); next }
  w <- readRDS(f)
  if (nrow(w) == 0) next
  g <- dea_tile_grid(tx, ty)
  nc <- g$dimension[["ncol"]]
  row <- (w$pix - 1L) %/% nc + 1L; col <- (w$pix - 1L) %% nc + 1L
  xy <- cbind(g$extent[["xmin"]] + (col - 0.5) * g$res, g$extent[["ymax"]] - (row - 0.5) * g$res)
  p <- terra::vect(xy, crs = "EPSG:3577")
  hit <- terra::relate(p, art[[reg]], "intersects")
  w$artificial <- rowSums(hit) > 0
  ## hand-checked boxes (regions/water_exclusions.csv): "exclude" counts as
  ## artificial, "review" stays natural but is flagged
  w$exclusion <- NA_character_
  if (any(ex$region == reg)) ll <- terra::project(xy, from = "EPSG:3577", to = "EPSG:4326")
  for (j in which(ex$region == reg)) {
    inb <- ll[, 1] >= ex$lon_min[j] & ll[, 1] <= ex$lon_max[j] & ll[, 2] >= ex$lat_min[j] & ll[, 2] <= ex$lat_max[j]
    w$exclusion[inb] <- ex$name[j]
    if (ex$action[j] == "exclude") w$artificial[inb] <- TRUE
  }
  w$review <- w$exclusion %in% ex$name[ex$action == "review"]
  w$frac <- w$wetyrs / w$obs
  w$x <- xy[, 1]; w$y <- xy[, 2]; w$region <- reg
  out[[tile]] <- w
  cat(tile, "wet50 px", nrow(w), "artificial", sum(w$artificial), "\n")
}
w <- do.call(rbind, out); rownames(w) <- NULL
saveRDS(w, file.path(dir, "wetpx_flagged_L13.rds"))
cnt <- function(sel) { z <- tapply(sel, w$cell, sum); z[is.na(z)] <- 0; z }
cells <- sort(unique(w$cell))
s <- data.frame(cell = cells, region = w$region[match(cells, w$cell)],
                px_wet50_nat = as.vector(cnt(!w$artificial)[cells]),
                px_wet90_nat = as.vector(cnt(!w$artificial & w$frac >= 0.9)[cells]),
                px_wet50_art = as.vector(cnt(w$artificial)[cells]),
                px_wet90_art = as.vector(cnt(w$artificial & w$frac >= 0.9)[cells]),
                px_wet50_review = as.vector(cnt(w$review & !w$artificial)[cells]))
saveRDS(s, file.path(dir, "water_cells_L13.rds"))
print(aggregate(cbind(px_wet50_nat, px_wet90_nat, px_wet50_art, px_wet90_art) ~ region,
                data = s, FUN = sum))
