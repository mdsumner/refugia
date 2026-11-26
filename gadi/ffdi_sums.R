## Daily FFDI (gadi/ffdi_daily.py) to S2 cell sums per fire year, Tasmania pilot.
##
## Rscript gadi/ffdi_sums.R <indir> <outdir> [level]
##
## <indir> holds ffdi_fy<YYYY>.nc (fire year YYYY = 1 July YYYY-1 to 30 June YYYY). For each
## file, per cell: npix (land pixels) and the sums over pixels of ndays (valid pixel-days),
## sum and sumsq of daily FFDI, spring_n and spring_sum (September to November), n_ge12,
## n_ge25, n_ge50 (days at or above the old High, Very High and Severe bounds) and n_mild
## (days below 12). Annual cell means, trends and persistence follow exactly from these sums
## (R/sums.R). One rds per fire year in <outdir>, resumable. The mapping is built once, from
## the files' own grid (the AGCD r005 grid cropped to Tasmania).

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))

a <- commandArgs(TRUE)
stopifnot(length(a) >= 2)
indir <- a[1]; outdir <- a[2]
lev <- if (length(a) > 2) as.integer(a[3]) else 10L
files <- sort(list.files(indir, "^ffdi_fy[0-9]{4}[.]nc$", full.names = TRUE))
stopifnot(length(files) > 0)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
cat(length(files), "fire years in", indir, "\n")

m <- NULL
for (f in files) {
  fy <- as.integer(sub("^ffdi_fy([0-9]{4})[.]nc$", "\\1", basename(f)))
  out <- file.path(outdir, sprintf("ffdi_tasmania_fy%d_L%d.rds", fy, lev))
  if (file.exists(out)) next
  r <- terra::rast(f, subds = "ffdi")
  g <- list(extent = c(xmin = terra::xmin(r), xmax = terra::xmax(r), ymin = terra::ymin(r), ymax = terra::ymax(r)),
            dimension = c(ncol = terra::ncol(r), nrow = terra::nrow(r)), crs = "EPSG:4326")
  if (is.null(m)) { m <- build_grid_mapping(g, level = lev); idx <- mapping_index(m) }
  stopifnot(isTRUE(all.equal(unname(m$grid$extent), unname(g$extent))), all(m$grid$dimension == g$dimension))
  dates <- as.Date(terra::time(r))
  stopifnot(length(dates) == terra::nlyr(r), !anyNA(dates))
  v <- terra::values(r, mat = TRUE)  # pixels (row-major) x days
  ok <- is.finite(v)
  v0 <- v; v0[!ok] <- 0
  spring <- as.integer(format(dates, "%m")) %in% 9:11
  ndays <- rowSums(ok)
  land <- ifelse(ndays > 0, ndays, NA_real_)   # first input: npix counts land pixels only
  s <- sum_to_cells(m, ndays = land, sum = rowSums(v0), sumsq = rowSums(v0 * v0),
                    spring_n = rowSums(ok[, spring, drop = FALSE]),
                    spring_sum = rowSums(v0[, spring, drop = FALSE]),
                    n_ge12 = rowSums(ok & v >= 12), n_ge25 = rowSums(ok & v >= 25),
                    n_ge50 = rowSums(ok & v >= 50), n_mild = rowSums(ok & v < 12), index = idx)
  names(s)[names(s) == "n"] <- "npix"
  s <- s[s$npix > 0, ]
  s$fire_year <- fy; s$days <- length(dates); s$region <- "tasmania"
  saveRDS(s, out)
  cat(format(Sys.time(), "%H:%M:%S"), "fire year", fy, "days", length(dates), "cells", nrow(s),
      "mean FFDI", round(sum(s$sum) / sum(s$ndays), 2), "\n")
}
