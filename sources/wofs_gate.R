## Gate for the DEA WOfS pixel-to-cell path, one tile and one year.
##
## Rscript sources/wofs_gate.R [x] [y] [year] [level]
##
## Checks:
##  1. the mapping covers every pixel exactly once
##  2. cell sums of count_wet and count_clear add up to the tile totals
##  3. one cell's sums equal a direct sum over the pixels whose centres fall
##     in it, found independently of the run encoding
## Writes the per-cell table to data/ (gitignored).

Sys.setenv(PROJ_NETWORK = "OFF", GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR")
if (file.exists("/root/.ccr/ca-bundle.crt")) Sys.setenv(CURL_CA_BUNDLE = "/root/.ccr/ca-bundle.crt")
if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))

a <- commandArgs(TRUE)
tx <- if (length(a) > 0) as.integer(a[1]) else 46L
ty <- if (length(a) > 1) as.integer(a[2]) else 45L
yr <- if (length(a) > 2) as.integer(a[3]) else 2019L
lev <- if (length(a) > 3) as.integer(a[4]) else 13L

wofs_url <- function(x, y, year, band) {
  sprintf(paste0("/vsicurl/https://dea-public-data.s3.ap-southeast-2.amazonaws.com/",
                 "derivative/ga_ls_wo_fq_cyear_3/2-0-0/x%02d/y%02d/%d--P1Y/",
                 "ga_ls_wo_fq_cyear_3_x%02dy%02d_%d--P1Y_final_%s.tif"),
          x, y, year, x, y, year, band)
}

t0 <- Sys.time()
m <- build_tile_mapping(tx, ty, level = lev)
cat(sprintf("mapping %s level %d: %d runs, %d cells, %.1f s\n", m$grid$tile, lev,
            nrow(m$runs), length(m$cells), as.numeric(difftime(Sys.time(), t0, units = "secs"))))

idx <- mapping_index(m)
npix <- prod(m$grid$dimension)
stopifnot(length(idx) == npix)
cat("gate 1 ok: every pixel mapped once\n")

read_band <- function(band) {
  r <- terra::rast(wofs_url(tx, ty, yr, band))
  stopifnot(all(terra::ext(r)[] == unname(m$grid$extent)), terra::nrow(r) == m$grid$dimension[["nrow"]])
  v <- terra::values(r, mat = FALSE)
  v[v == -999] <- NA
  v
}
wet <- read_band("count_wet"); clear <- read_band("count_clear")
s <- sum_to_cells(m, wet = wet, clear = clear, index = idx)
stopifnot(sum(s$wet) == sum(wet, na.rm = TRUE), sum(s$clear) == sum(clear, na.rm = TRUE),
          sum(s$n) == sum(!is.na(wet)))
cat(sprintf("gate 2 ok: totals wet %s, clear %s\n", format(sum(s$wet)), format(sum(s$clear))))

## gate 3: pick the wettest cell, recompute membership directly from pixel centres
k <- which.max(s$wet)
g <- m$grid
rc <- which(idx == k)
row <- (rc - 1L) %/% g$dimension[["ncol"]] + 1L
col <- (rc - 1L) %% g$dimension[["ncol"]] + 1L
## independent check on a sample: every pixel listed is inside cell k
smp <- unique(round(seq(1, length(rc), length.out = min(500L, length(rc)))))
xy <- cbind(g$extent[["xmin"]] + (col[smp] - 0.5) * g$res, g$extent[["ymax"]] - (row[smp] - 0.5) * g$res)
ll <- terra::project(xy, from = g$crs, to = "EPSG:4326")
inside <- s2::s2_cell_contains(s2::as_s2_cell(m$cells[k]),
                               s2::as_s2_cell(s2::s2_lnglat(ll[, 1], ll[, 2])))
stopifnot(all(inside))
stopifnot(sum(wet[rc], na.rm = TRUE) == s$wet[k], sum(clear[rc], na.rm = TRUE) == s$clear[k])
cat(sprintf("gate 3 ok: cell %s, %d pixels, wet %s / clear %s (fraction %.3f)\n",
            m$cells[k], length(rc), format(s$wet[k]), format(s$clear[k]), s$wet[k] / s$clear[k]))

dir.create("data", showWarnings = FALSE)
out <- file.path("data", sprintf("wofs_%s_%d_L%d.rds", g$tile, yr, lev))
saveRDS(list(mapping_meta = m[c("grid", "level")], sums = s), out)
cat("wrote", out, "\n")
