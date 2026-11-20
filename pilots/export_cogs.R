## Candidate layers as Cloud Optimized GeoTIFFs, one per pilot region.
##
## Rscript pilots/export_cogs.R <mvp_dir>
##
## Reads cells_flags.csv and cells_metrics.csv from pilots/export_cells.R.
## Each output pixel takes the value of the S2 cell that holds its centre,
## so the raster is an exact view of the cell table at that resolution (no
## polygon rasterization, nothing breaks at the antimeridian).
##   australia_tasmania_L13.tif, australia_macdonnell_L13.tif
##       EPSG:3577, 250 m; bands water, green, thermal (0/1, 255 off the
##       pilot), n_kinds
##   antarctica_L9.tif
##       EPSG:3031, 5 km, 60S to the pole; bands sea_ice_holdout,
##       sst_holdout, land_holdout (0/1, 255 off the scored zone)
##   antarctica_trends_L9.tif
##       EPSG:3031, 5 km, float32; ice_days, summer_sst and summer_t2m
##       trend per decade

Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data/mvp"
fl <- utils::read.csv(file.path(dir, "cells_flags.csv"), stringsAsFactors = FALSE)
me <- utils::read.csv(file.path(dir, "cells_metrics.csv"), stringsAsFactors = FALSE)

cell_lookup <- function(r, level) {
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  ll <- terra::project(xy, from = terra::crs(r), to = "EPSG:4326")
  as.character(s2::s2_cell_parent(s2::as_s2_cell(s2::s2_lnglat(ll[, 1], ll[, 2])), level))
}
write_cog <- function(r, of, datatype) {
  terra::writeRaster(r, of, filetype = "COG", datatype = datatype, overwrite = TRUE,
                     gdal = c("COMPRESS=DEFLATE", "OVERVIEW_RESAMPLING=NEAREST"))
  cat("wrote", of, "\n")
}
flag_band <- function(tok, x, kind) {
  y <- x[x$kind == kind, ]
  v <- as.integer(y$flag == "TRUE" | y$flag == TRUE)[match(tok, y$cell)]
  v[is.na(v)] <- 255L
  v
}

## Australia
au <- fl[fl$domain == "australia_land" & fl$level == 13, ]
boxes <- list(tasmania = au[au$region != "MAC", ], macdonnell = au[au$region == "MAC", ])
for (nm in names(boxes)) {
  x <- boxes[[nm]]
  xy <- terra::project(cbind(x$lon, x$lat), from = "EPSG:4326", to = "EPSG:3577")
  e <- c(floor(min(xy[, 1]) / 1000) * 1000 - 2000, ceiling(max(xy[, 1]) / 1000) * 1000 + 2000,
         floor(min(xy[, 2]) / 1000) * 1000 - 2000, ceiling(max(xy[, 2]) / 1000) * 1000 + 2000)
  r <- terra::rast(terra::ext(e), resolution = 250, crs = "EPSG:3577")
  tok <- cell_lookup(r, 13L)
  bands <- lapply(c("water", "green", "thermal"), function(k) flag_band(tok, x, k))
  nk <- Reduce(`+`, lapply(bands, function(b) ifelse(b == 1L, 1L, 0L)))
  nk[bands[[1]] == 255L] <- 255L
  out <- terra::rast(r, nlyrs = 4)
  terra::values(out) <- cbind(bands[[1]], bands[[2]], bands[[3]], nk)
  names(out) <- c("water", "green", "thermal", "n_kinds")
  terra::NAflag(out) <- 255
  write_cog(out, file.path(dir, sprintf("australia_%s_L13.tif", nm)), "INT1U")
}

## Antarctica
r <- terra::rast(terra::ext(-3700000, 3700000, -3700000, 3700000), resolution = 5000, crs = "EPSG:3031")
tok <- cell_lookup(r, 9L)
an <- fl[fl$level == 9 & fl$domain %in% c("antarctic_sea_ice", "antarctic_ocean", "antarctic_land"), ]
kinds <- c("sea_ice_holdout", "sst_holdout", "land_holdout")
out <- terra::rast(r, nlyrs = 3)
terra::values(out) <- do.call(cbind, lapply(kinds, function(k) flag_band(tok, an, k)))
names(out) <- kinds
terra::NAflag(out) <- 255
write_cog(out, file.path(dir, "antarctica_L9.tif"), "INT1U")

vars <- c(ice_days = "antarctic_sea_ice", summer_sst = "antarctic_ocean", summer_t2m = "antarctic_land")
out <- terra::rast(r, nlyrs = 3)
terra::values(out) <- do.call(cbind, lapply(names(vars), function(v) {
  y <- me[me$domain == vars[[v]] & me$level == 9 & me$variable == v & me$metric == "trend_decade", ]
  y$value[match(tok, y$cell)]
}))
names(out) <- paste0(names(vars), "_trend_decade")
write_cog(out, file.path(dir, "antarctica_trends_L9.tif"), "FLT4S")
