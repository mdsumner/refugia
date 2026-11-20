## Score Antarctic ice-free land exposure within ACBRs instead of sectors.
##
## Rscript pilots/antarctica/acbr_score.R <acbr_file> <era5_out_dir> [acbr_field]
##
## <acbr_file>: ACBR polygons readable by terra (GeoPackage from
## gadi/aad_layers.sh); <era5_out_dir> holds era5_exposure_L9.rds and
## icefree_exposure_L13.rds from era5_exposure.R. [acbr_field] is the
## attribute holding the region (default: the first field whose name
## contains "ACBR").
##
## The ACBR v1 polygons (Terauds et al. 2012) are themselves ice-free
## outlines labelled by region, drawn from an older outcrop layer than rock
## outcrop v7.3, so the outlines do not match. Each level 13 ice-free cell
## takes the ACBR of the nearest ACBR polygon to its centre (with the
## distance kept), and each level 9 cell takes the ACBR holding most of its
## rock area. The holdout rule is unchanged (era5_exposure.R), with ACBR as
## the reference region; ACBRs with fewer than 8 level 9 cells are not
## scored.

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))
Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
src <- a[1]
dir <- if (length(a) > 1) a[2] else "data"
v <- terra::vect(src)
fld <- if (length(a) > 2) a[3] else grep("acbr", names(v), ignore.case = TRUE, value = TRUE)[1]
stopifnot(!is.na(fld))
cat(nrow(v), "polygons; field", fld, ":", paste(sort(unique(v[[fld, drop = TRUE]])), collapse = " "), "\n")
v <- terra::project(v, "EPSG:4326")
g <- s2::as_s2_geography(terra::geom(v, wkt = TRUE), check = FALSE)
## rebuilding can return the complement of a polygon (ASPA 153 came back as
## the whole globe less the ASPA); flip any that cover more than a hemisphere
flip_big <- function(g) {
  big <- which(s2::s2_area(g) > 2 * pi * 6371010^2)
  for (i in big) g[i] <- s2::s2_difference(s2::as_s2_geography(TRUE), g[i])
  if (length(big)) cat("flipped", length(big), "inverted polygon(s)\n")
  g
}
g <- flip_big(s2::s2_rebuild(g))
lab <- as.character(v[[fld, drop = TRUE]])

c13 <- readRDS(file.path(dir, "icefree_exposure_L13.rds"))
p <- s2::s2_cell_center(s2::as_s2_cell(c13$cell))
k <- s2::s2_closest_feature(p, g)
c13$acbr <- lab[k]
c13$acbr_dist_km <- s2::s2_distance(p, g[k]) / 1000
cat(sprintf("nearest ACBR polygon: median %.2f km, 99th percentile %.1f km, max %.1f km\n",
            stats::median(c13$acbr_dist_km), stats::quantile(c13$acbr_dist_km, 0.99), max(c13$acbr_dist_km)))

o <- readRDS(file.path(dir, "era5_exposure_L9.rds"))
ra <- stats::aggregate(rock_km2 ~ parent9 + acbr, data = c13, FUN = sum)
ra <- ra[order(ra$parent9, -ra$rock_km2), ]
ra <- ra[!duplicated(ra$parent9), ]
o$acbr <- ra$acbr[match(o$cell, ra$parent9)]
zone <- o$icefree %in% TRUE & !is.na(o$acbr)
n <- table(o$acbr[zone]); small <- names(n)[n < 8]
zone <- zone & !(o$acbr %in% small)
o$warming_pct_acbr <- NA_real_; o$warm_velocity_pct_acbr <- NA_real_
o$warming_pct_acbr[zone] <- group_percentile(o$slope_decade_t[zone], o$acbr[zone])
warm <- zone & o$slope_decade_t > 0 & is.finite(o$warm_velocity_km_decade)
o$warm_velocity_pct_acbr[warm] <- group_percentile(o$warm_velocity_km_decade[warm], o$acbr[warm])
slow <- (zone & o$slope_decade_t <= 0) | (warm & o$warm_velocity_pct_acbr <= 0.25)
o$land_refugium_acbr <- zone & o$warming_pct_acbr <= 0.25 & slow %in% TRUE
o$land_refugium_acbr[is.na(o$land_refugium_acbr)] <- FALSE
saveRDS(o, file.path(dir, "era5_exposure_L9.rds"))
c13$land_refugium_acbr <- o$land_refugium_acbr[match(c13$parent9, o$cell)] %in% TRUE
saveRDS(c13, file.path(dir, "icefree_exposure_L13.rds"))
write.csv(c13, file.path(dir, "icefree_exposure_L13.csv"), row.names = FALSE)

q <- function(x, f = "%.2f") sprintf(paste0(f, " [", f, ", ", f, "]"), stats::median(x, na.rm = TRUE),
                         stats::quantile(x, 0.1, na.rm = TRUE), stats::quantile(x, 0.9, na.rm = TRUE))
z <- o[o$icefree %in% TRUE & !is.na(o$acbr), ]
summ <- do.call(rbind, lapply(sort(unique(z$acbr)), function(r) {
  x <- z[z$acbr == r, ]
  data.frame(acbr = r, cells_L9 = nrow(x), rock_km2 = round(sum(x$rock_km2)),
             summer_t = q(x$clim_t, "%.1f"), t_trend = q(x$slope_decade_t),
             snr2_share = round(mean(abs(x$snr_t) >= 2, na.rm = TRUE), 2),
             scored = !(r %in% small), refugium_L9 = sum(x$land_refugium_acbr),
             same_as_sector_rule = sum(x$land_refugium_acbr & x$land_refugium),
             refugium_L13 = sum(c13$land_refugium_acbr[c13$acbr == r]))
}))
print(summ, row.names = FALSE)
write.csv(summ, file.path(dir, "era5_exposure_acbr_summary.csv"), row.names = FALSE)
