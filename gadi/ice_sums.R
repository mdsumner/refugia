## trend.ice ice season COGs to S2 cell sums per ice year (Antarctic pilot).
##
## Rscript gadi/ice_sums.R <outdir> [level] [sub] [base_url]
##
##   <outdir>   one rds per ice year: ice_L<level>_<year>.rds, resumable
##   level      S2 level (default 9, about 18 km)
##   sub        sub-pixels per pixel edge (default 5). The 25 km pixels are
##              larger than level 9 cells, so each pixel is split into
##              sub x sub points of weight 1/sub^2; every cell then gets an
##              area-weighted share and the sums stay mergeable.
##   base_url   default https://projects.pawsey.org.au/aad-derived/trend-ice/iceseason_t15
##              (or a local directory holding the COGs and manifest_t15.csv)
##
## Needs network to Acacia: run on a login node or in copyq (gadi/ice_sums.pbs).
##
## Per cell and ice year (all counts in pixel units, i.e. sub-pixel counts / sub^2):
##   w_obs      area with a computed season record (daycount not NA)
##   w_noice    area with no ice day (daycount 0)
##   w_iceend   area with ice on the last day of the ice year (no retreat)
##   w_season   area with a complete season (advance, retreat and duration valid)
##   s_<v>, ss_<v> for v in advance, retreat, duration (over w_season) and
##   daycount (over w_obs): weighted sums and sums of squares.
## Also <outdir>/direct_pixels.csv: per ice year, the plain per-pixel mean of
## duration and daycount on the native grid, for the gate.

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))

a <- commandArgs(TRUE)
outdir <- if (length(a) > 0) a[1] else "data/ice"
lev <- if (length(a) > 1) as.integer(a[2]) else 9L
sub <- if (length(a) > 2) as.integer(a[3]) else 5L
base <- if (length(a) > 3) a[4] else "https://projects.pawsey.org.au/aad-derived/trend-ice/iceseason_t15"
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

remote <- grepl("^https?://", base)
mf <- if (remote) tempfile(fileext = ".csv") else file.path(base, "manifest_t15.csv")
if (remote) utils::download.file(file.path(base, "manifest_t15.csv"), mf, quiet = TRUE)
man <- utils::read.csv(mf, stringsAsFactors = FALSE)
man <- man[man$status == "ok" & !is.na(man$file) & nzchar(man$file), ]
cat(nrow(man), "ice years:", min(man$year), "-", max(man$year), "\n")

ice_layers <- c("advance", "retreat", "duration", "daycount", "ice_at_start", "ice_at_end", "n_missing")
read_year <- function(f) {
  r <- terra::rast(paste0(if (remote) "/vsicurl/" else "", file.path(base, f)))
  names(r) <- ice_layers
  r
}

## one mapping for all years: the grid is fixed
r0 <- read_year(man$file[1])
g <- list(extent = c(xmin = terra::xmin(r0), xmax = terra::xmax(r0),
                     ymin = terra::ymin(r0), ymax = terra::ymax(r0)),
          dimension = c(ncol = terra::ncol(r0) * sub, nrow = terra::nrow(r0) * sub),
          crs = terra::crs(r0))
mfile <- file.path(outdir, sprintf("mapping_L%d_sub%d.rds", lev, sub))
m <- if (file.exists(mfile)) readRDS(mfile) else {
  t0 <- Sys.time(); mm <- build_grid_mapping(g, level = lev)
  saveRDS(mm, mfile); cat("mapping", length(mm$cells), "cells in",
                          round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "s\n"); mm
}
idx <- mapping_index(m)
w1 <- 1 / sub^2

direct <- list()
for (i in seq_len(nrow(man))) {
  yr <- man$year[i]
  of <- file.path(outdir, sprintf("ice_L%d_%d.rds", lev, yr))
  r <- read_year(man$file[i])
  v <- terra::values(r, mat = TRUE)
  direct[[i]] <- data.frame(year = yr, npix_season = sum(!is.na(v[, "duration"])),
                            mean_duration = mean(v[, "duration"], na.rm = TRUE),
                            npix_obs = sum(!is.na(v[, "daycount"])),
                            mean_daycount = mean(v[, "daycount"], na.rm = TRUE))
  if (file.exists(of)) next
  rs <- terra::disagg(r, sub)
  stopifnot(terra::ncol(rs) == g$dimension[["ncol"]], terra::nrow(rs) == g$dimension[["nrow"]])
  v <- terra::values(rs, mat = TRUE)
  obs <- !is.na(v[, "daycount"])
  season <- !is.na(v[, "advance"]) & !is.na(v[, "retreat"]) & !is.na(v[, "duration"])
  z <- function(x, ok) { x <- as.double(x); x[!ok | is.na(x)] <- 0; x * w1 }
  zz <- function(x, ok) { x <- as.double(x); x[!ok | is.na(x)] <- 0; x * x * w1 }
  s <- sum_to_cells(m,
    w_obs = obs * w1,
    w_noice = (obs & v[, "daycount"] == 0) * w1,
    w_iceend = (obs & v[, "ice_at_end"] %in% 1) * w1,
    w_season = season * w1,
    s_advance = z(v[, "advance"], season), ss_advance = zz(v[, "advance"], season),
    s_retreat = z(v[, "retreat"], season), ss_retreat = zz(v[, "retreat"], season),
    s_duration = z(v[, "duration"], season), ss_duration = zz(v[, "duration"], season),
    s_daycount = z(v[, "daycount"], obs), ss_daycount = zz(v[, "daycount"], obs),
    index = idx)
  s$n <- NULL
  s <- s[s$w_obs > 0, ]
  s$year <- yr
  saveRDS(s, of)
  cat(format(Sys.time(), "%H:%M:%S"), yr, "cells", nrow(s), "season area", round(sum(s$w_season)), "px\n")
}
write.csv(do.call(rbind, direct), file.path(outdir, "direct_pixels.csv"), row.names = FALSE)
cat("done", length(list.files(outdir, "^ice_L")), "years in", outdir, "\n")
