## AGCD daily 0.05 deg to S2 cell sums per year, for the pilot regions.
##
## Rscript gadi/agcd_sums.R <glob> <var> <outdir> [level]
##
##   <glob>  shell glob for one variable's yearly files, quoted, e.g.
##           "/g/data/zv2/agcd/v1-0-3/tmax/mean/r005/01day/*.nc" (path to confirm)
##   <var>   variable name inside the files (e.g. tmax, tmin, precip)
##
## For each region and year: per cell, npix (pixels), pixdays (valid pixel-days), sum and sum of
## squares of the daily values. Annual cell means and trends follow from
## these sums exactly (R/sums.R). One rds per region-var-year in <outdir>,
## resumable. The mapping is built once per region on the cropped grid.

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))

a <- commandArgs(TRUE)
stopifnot(length(a) >= 3)
files <- sort(Sys.glob(a[1])); var <- a[2]; outdir <- a[3]
lev <- if (length(a) > 3) as.integer(a[4]) else 10L
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
stopifnot(length(files) > 0)
cat(length(files), "files for", var, "\n")

regions <- list(tasmania = c(143.5, 149, -44, -39.3), macdonnell = c(129.5, 136.5, -25, -22.5))
maps <- list()

for (f in files) {
  yr <- as.integer(sub(".*([12][0-9]{3})[^0-9]*[.]nc$", "\\1", basename(f)))
  if (is.na(yr)) { cat("no year in", f, "\n"); next }
  todo <- names(regions)[!file.exists(file.path(outdir, sprintf("agcd_%s_%s_%d_L%d.rds", var, names(regions), yr, lev)))]
  if (!length(todo)) next
  r <- tryCatch(terra::rast(f, subds = var), error = function(e) terra::rast(f))
  for (rg in todo) {
    rc <- terra::crop(r, terra::ext(regions[[rg]]))
    g <- list(extent = c(xmin = terra::xmin(rc), xmax = terra::xmax(rc), ymin = terra::ymin(rc), ymax = terra::ymax(rc)),
              dimension = c(ncol = terra::ncol(rc), nrow = terra::nrow(rc)), crs = "EPSG:4326")
    if (is.null(maps[[rg]])) maps[[rg]] <- build_grid_mapping(g, level = lev)
    m <- maps[[rg]]
    stopifnot(isTRUE(all.equal(unname(m$grid$extent), unname(g$extent))), all(m$grid$dimension == g$dimension))
    v <- terra::values(rc, mat = TRUE)  # pixels x days, row-major pixels
    ok <- is.finite(v)
    v[!ok] <- 0
    s <- sum_to_cells(m, pixdays = rowSums(ok), sum = rowSums(v), sumsq = rowSums(v * v))
    names(s)[names(s) == "n"] <- "npix"
    s$days <- ncol(v); s$year <- yr; s$var <- var; s$region <- rg
    saveRDS(s, file.path(outdir, sprintf("agcd_%s_%s_%d_L%d.rds", var, rg, yr, lev)))
    cat(format(Sys.time(), "%H:%M:%S"), var, rg, yr, "days", ncol(v), "cells", nrow(s), "\n")
  }
}
