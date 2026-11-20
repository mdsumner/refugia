## Overlap of Antarctic candidate cells with Antarctic Specially Protected Areas.
##
## Rscript checks/aspa_overlap.R <aspa_polygons> <refugia_dir> <outdir>
##
## <aspa_polygons>: ASPAs_polygons_v5_2024.shp from Terauds et al. (2024)
## Antarctic Specially Protected Areas (Points and Polygons) 2024 Update,
## doi:10.26179/4qk0-cz71 (119 polygons, 74 ASPAs counted by number below;
## each carries Marine and ACBR attributes). <refugia_dir> holds
## era5_out/icefree_exposure_L13.rds, ice_out/ice_exposure_L9.rds and
## sst_out/sst_exposure_L9.rds.
##
## A cell counts as in an ASPA if its S2 cell polygon intersects an ASPA
## polygon (exact, on the sphere). Many ASPAs are smaller than a level 13
## cell (about 1.5 km2), so this is generous: "touches an ASPA", not "lies
## inside one".
##
## Writes aspa_cells_L13.csv (ice-free cells touching an ASPA, with the ASPA
## numbers), aspa_overlap_land.csv (per sector: ice-free cells, candidates,
## share of each touching an ASPA) and aspa_overlap_marine.csv (sea ice and
## SST holdouts against marine ASPAs).

Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
src <- a[1]
dir <- if (length(a) > 1) a[2] else "data"
outdir <- if (length(a) > 2) a[3] else "data"
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

v <- terra::project(terra::vect(src), "EPSG:4326")
asp <- as.data.frame(v)
## rebuilding can return the complement of a polygon (ASPA 153 came back as
## the whole globe less the ASPA); flip any that cover more than a hemisphere
flip_big <- function(g) {
  big <- which(s2::s2_area(g) > 2 * pi * 6371010^2)
  for (i in big) g[i] <- s2::s2_difference(s2::as_s2_geography(TRUE), g[i])
  if (length(big)) cat("flipped", length(big), "inverted polygon(s)\n")
  g
}
g <- flip_big(s2::s2_rebuild(s2::as_s2_geography(terra::geom(v, wkt = TRUE), check = FALSE)))
cat(nrow(asp), "ASPA polygons,", length(unique(asp$ASPA_No)), "ASPAs,",
    sum(asp$Marine == 1, na.rm = TRUE), "marked marine\n")

touch <- function(cells, gg) {
  poly <- s2::s2_cell_polygon(s2::as_s2_cell(cells))
  hit <- s2::s2_intersects_matrix(poly, gg)
  hit
}

## land: level 13 ice-free cells
c13 <- readRDS(file.path(dir, "era5_out", "icefree_exposure_L13.rds"))
hit <- touch(c13$cell, g)
c13$aspa <- vapply(hit, function(i) paste(sort(unique(asp$ASPA_No[i])), collapse = " "), "")
c13$in_aspa <- lengths(hit) > 0
write.csv(c13[c13$in_aspa, c("cell", "lon", "lat", "sector", "rock_km2", "icefree_frac",
                             "land_refugium", "aspa")],
          file.path(outdir, "aspa_cells_L13.csv"), row.names = FALSE)
aspa_hit <- sort(unique(unlist(lapply(hit, function(i) asp$ASPA_No[i]))))
cat(length(aspa_hit), "of", length(unique(asp$ASPA_No)), "ASPAs touch an ice-free level 13 cell\n")

lv <- c("Peninsula", "Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen")
land <- do.call(rbind, lapply(c(lv, "all"), function(s) {
  x <- if (s == "all") c13 else c13[c13$sector == s, ]
  r <- x$land_refugium %in% TRUE
  data.frame(sector = s, cells = nrow(x), rock_km2 = round(sum(x$rock_km2)),
             cells_in_aspa = sum(x$in_aspa), share_in_aspa = round(mean(x$in_aspa), 4),
             candidates = sum(r), candidates_in_aspa = sum(x$in_aspa & r),
             candidate_share_in_aspa = round(mean(x$in_aspa[r]), 4),
             aspas = length(unique(unlist(strsplit(x$aspa[x$in_aspa], " ")))))
}))
print(land, row.names = FALSE)
write.csv(land, file.path(outdir, "aspa_overlap_land.csv"), row.names = FALSE)

## marine: level 9 sea ice and SST holdouts against ASPAs marked marine
gm <- g[asp$Marine %in% 1]
marine <- do.call(rbind, lapply(list(
  list("sea_ice_holdout", file.path(dir, "ice_out", "ice_exposure_L9.rds"), "seasonal_zone", "ice_refugium"),
  list("sst_holdout", file.path(dir, "sst_out", "sst_exposure_L9.rds"), "summer_open_zone", "sst_refugium")),
  function(k) {
    x <- readRDS(k[[2]]); x <- x[x[[k[[3]]]] %in% TRUE, ]
    h <- lengths(touch(x$cell, gm)) > 0
    r <- x[[k[[4]]]] %in% TRUE
    data.frame(kind = k[[1]], cells = nrow(x), cells_touching_marine_aspa = sum(h),
               candidates = sum(r), candidates_touching_marine_aspa = sum(h & r))
  }))
print(marine, row.names = FALSE)
write.csv(marine, file.path(outdir, "aspa_overlap_marine.csv"), row.names = FALSE)
