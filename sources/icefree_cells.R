## Ice-free (rock outcrop) area per S2 cell, straight from the polygons.
##
## Rscript sources/icefree_cells.R <rock_gpkg> <outdir> [level]
##
## <rock_gpkg>  add_rock_outcrop_medium_res_polygon_v7.3.gpkg (Burton-Johnson
##              et al., 25,954 polygons, EPSG:3031), from the zip in
##              AustralianAntarcticDivision/rema.proc 01_rock_classification/
## level        S2 level (default 13, about 1 km)
##
## The controlledburn burn onto the REMA 32 m grid (notes/data_sources.md)
## gives the same quantity through a raster; here each polygon is
## intersected with the S2 cells that cover it on the sphere, so the area is
## exact for the polygons and needs no dense grid. Per cell: rock area (km2),
## cell area (km2), ice-free fraction, number of polygons touching the cell.
## Writes icefree_L<level>.rds/.csv and a parent-level (level - 4) summary.

a <- commandArgs(TRUE)
gpkg <- a[1]
outdir <- if (length(a) > 1) a[2] else "data"
lev <- if (length(a) > 2) as.integer(a[3]) else 13L
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

v <- terra::vect(gpkg)
v <- terra::project(v, "EPSG:4326")
## repair on the sphere: the planar polygons can self-touch once unprojected
g <- s2::as_s2_geography(terra::geom(v, wkt = TRUE), check = FALSE)
g <- s2::s2_rebuild(g)
area_poly <- s2::s2_area(g) / 1e6
cat(length(g), "polygons,", round(sum(area_poly)), "km2 on the sphere\n")

## covering cells at exactly `lev`, then intersection areas, in chunks
cov <- s2::s2_covering_cell_ids(g, min_level = lev, max_level = lev, max_cells = 1e6)
np <- lengths(unclass(cov))
pairs <- data.frame(poly = rep(seq_along(g), np),
                    cell = as.character(unlist(lapply(unclass(cov), function(x) as.character(s2::new_s2_cell(x))))))
cat(nrow(pairs), "polygon-cell pairs\n")
cellpoly <- function(tok) s2::s2_cell_polygon(s2::as_s2_cell(tok))
pairs$area_km2 <- NA_real_
ch <- split(seq_len(nrow(pairs)), ceiling(seq_len(nrow(pairs)) / 20000))
for (k in ch) {
  pairs$area_km2[k] <- s2::s2_area(s2::s2_intersection(g[pairs$poly[k]], cellpoly(pairs$cell[k]))) / 1e6
}
pairs <- pairs[pairs$area_km2 > 0, ]
out <- aggregate(cbind(rock_km2 = area_km2, npoly = 1) ~ cell, data = pairs, FUN = sum)
out$cell_km2 <- s2::s2_area(cellpoly(out$cell)) / 1e6
out$icefree_frac <- pmin(out$rock_km2 / out$cell_km2, 1)
ctr <- s2::s2_cell_center(s2::as_s2_cell(out$cell))
out$lon <- s2::s2_x(ctr); out$lat <- s2::s2_y(ctr)
cat(sprintf("gate: cell sum %.3f km2 vs polygon sum %.3f km2 (rel diff %.1e)\n",
            sum(out$rock_km2), sum(area_poly), sum(out$rock_km2) / sum(area_poly) - 1))
stopifnot(abs(sum(out$rock_km2) / sum(area_poly) - 1) < 1e-6)

saveRDS(out, file.path(outdir, sprintf("icefree_L%d.rds", lev)))
write.csv(out, file.path(outdir, sprintf("icefree_L%d.csv", lev)), row.names = FALSE)

## parent level: mergeable sums of the same
pl <- lev - 4L
out$parent <- as.character(s2::s2_cell_parent(s2::as_s2_cell(out$cell), pl))
p <- aggregate(cbind(rock_km2, ncell = 1) ~ parent, data = out, FUN = sum)
names(p)[1] <- "cell"
p$cell_km2 <- s2::s2_area(cellpoly(p$cell)) / 1e6
p$icefree_frac <- p$rock_km2 / p$cell_km2
ctr <- s2::s2_cell_center(s2::as_s2_cell(p$cell)); p$lon <- s2::s2_x(ctr); p$lat <- s2::s2_y(ctr)
saveRDS(p, file.path(outdir, sprintf("icefree_L%d.rds", pl)))
write.csv(p, file.path(outdir, sprintf("icefree_L%d.csv", pl)), row.names = FALSE)
cat(nrow(out), "level", lev, "cells;", nrow(p), "level", pl, "cells\n")
