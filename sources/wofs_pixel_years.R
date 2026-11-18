## Per-pixel count of observed and wet years from WOfS annual summaries,
## summarised to S2 cells.
##
## Rscript sources/wofs_pixel_years.R <outdir> [level] [mapping_dir]
##
## Cell sums dilute a waterhole of a few pixels into its dry surroundings.
## Here each pixel first counts the years it was observed (count_clear >= 1)
## and the years it was wet (count_wet >= 1), over 1987-2025; then per cell we
## count pixels that were wet in at least 90% (and at least 50%) of observed
## years with at least 20 observed years, and pixels ever wet, all within
## the IBRA land mask.
## Output: <outdir>/pixyears_<tile>_L<level>.rds, one per tile, resumable,
## and <outdir>/wetpx_<tile>.rds, the sparse list of land pixels wet in >= 50%
## of 20+ observed years (pixel index in row-major order, obs, wet years),
## which the artificial-water mask (sources/water_mask.R) works on.

Sys.setenv(PROJ_NETWORK = "OFF", GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR")
if (file.exists("/root/.ccr/ca-bundle.crt")) Sys.setenv(CURL_CA_BUNDLE = "/root/.ccr/ca-bundle.crt")
if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))

a <- commandArgs(TRUE)
outdir <- if (length(a) > 0) a[1] else "data/wofs"
lev <- if (length(a) > 1) as.integer(a[2]) else 13L
mapdir <- if (length(a) > 2) a[3] else outdir
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
source("sources/pilot_tiles.R")
years <- 1987:2025
## optional SHARD=k/n env var runs every n-th tile starting at k (1-based)
sh <- Sys.getenv("SHARD")
if (nzchar(sh)) {
  kn <- as.integer(strsplit(sh, "/")[[1]])
  pilot_tiles <- pilot_tiles[seq(kn[1], nrow(pilot_tiles), by = kn[2]), ]
}

## land mask: IBRA covers land only (sea, and estuaries beyond the coast,
## are outside it), so pixels outside every IBRA region are dropped. Without
## it, coastal tiles count the sea as persistent water.
ibra <- terra::project(terra::vect("regions/ibra7/ibra7_regions_pilot.geojson"), "EPSG:3577")
land_mask <- function(m) {
  g <- m$grid
  r <- terra::rast(ncols = g$dimension[["ncol"]], nrows = g$dimension[["nrow"]],
                   xmin = g$extent[["xmin"]], xmax = g$extent[["xmax"]],
                   ymin = g$extent[["ymin"]], ymax = g$extent[["ymax"]], crs = g$crs)
  !is.na(terra::values(terra::rasterize(ibra, r, field = 1), mat = FALSE))
}

wofs_url <- function(x, y, year, band) {
  sprintf(paste0("/vsicurl/https://dea-public-data.s3.ap-southeast-2.amazonaws.com/",
                 "derivative/ga_ls_wo_fq_cyear_3/2-0-0/x%02d/y%02d/%d--P1Y/",
                 "ga_ls_wo_fq_cyear_3_x%02dy%02d_%d--P1Y_final_%s.tif"),
          x, y, year, x, y, year, band)
}
read_band <- function(x, y, year, band) {
  v <- terra::values(terra::rast(wofs_url(x, y, year, band)), mat = FALSE)
  v[v == -999] <- NA
  v
}

for (i in seq_len(nrow(pilot_tiles))) {
  tx <- pilot_tiles$x[i]; ty <- pilot_tiles$y[i]
  tile <- sprintf("x%02dy%02d", tx, ty)
  of <- file.path(outdir, sprintf("pixyears_%s_L%d.rds", tile, lev))
  wf <- file.path(outdir, sprintf("wetpx_%s.rds", tile))
  if (file.exists(of) && file.exists(wf)) next
  mf <- file.path(mapdir, sprintf("mapping_%s_L%d.rds", tile, lev))
  m <- if (file.exists(mf)) readRDS(mf) else build_tile_mapping(tx, ty, level = lev)
  idx <- mapping_index(m)
  obs <- integer(length(idx)); wetyrs <- integer(length(idx)); nyr <- 0L
  for (yr in years) {
    res <- try({
      cl <- read_band(tx, ty, yr, "count_clear"); wt <- read_band(tx, ty, yr, "count_wet")
      o <- !is.na(cl) & cl >= 1
      obs <- obs + o
      wetyrs <- wetyrs + (o & !is.na(wt) & wt >= 1)
      nyr <- nyr + 1L
    }, silent = TRUE)
    if (inherits(res, "try-error")) cat(tile, yr, "FAIL", conditionMessage(attr(res, "condition")), "\n")
  }
  land <- land_mask(m)
  frac <- ifelse(obs > 0, wetyrs / obs, 0)
  ok20 <- land & obs >= 20
  s <- sum_to_cells(m, px_land = as.numeric(land), px_obs20 = as.numeric(ok20),
                    px_wet90 = as.numeric(ok20 & frac >= 0.9),
                    px_wet50 = as.numeric(ok20 & frac >= 0.5),
                    px_ever = as.numeric(land & wetyrs >= 1), index = idx)
  keep <- which(ok20 & frac >= 0.5)
  saveRDS(data.frame(tile = rep(tile, length(keep)), pix = keep, obs = obs[keep],
                     wetyrs = wetyrs[keep], cell = m$cells[idx[keep]]), wf)
  s$tile <- tile; s$region <- pilot_tiles$region[i]; s$years_read <- nyr
  saveRDS(s, of)
  cat(format(Sys.time(), "%H:%M:%S"), tile, "years", nyr, "wet90 px", sum(s$px_wet90), "\n")
}
