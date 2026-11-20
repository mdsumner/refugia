## Gate: one IBRA subregion's WOfS wet fraction from the cell sums against a
## direct summary of the WOfS annual rasters.
##
## Rscript sources/wofs_subregion_gate.R <persistence_rds> [sub_code] [first] [last]
##
## <persistence_rds> is wofs_persistence_L13.rds (pilots/australia/
## wofs_persistence.R); sub_code defaults to KIN01 (King, the smallest
## pilot subregion); years default to 1987-2025 as in water_persistence().
##
## The cell path: sum of wet_all and clear_all over the level 13 cells
## assigned to the subregion (cell centre in the polygon).
## Direct path, reading the DEA annual summaries (ga_ls_wo_fq_cyear_3) for
## every tile that touches the subregion:
##   A. pixels whose centre lies in one of those cells, the cell found from
##      the pixel centre with s2 (not the run-length mapping): must equal
##      the cell path exactly.
##   B. pixels whose centre lies inside the subregion polygon: differs from
##      the cell path only by the cells that straddle the boundary; the
##      difference is the representation error of the subregion as cells.

Sys.setenv(PROJ_NETWORK = "OFF", GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR")
if (file.exists("/root/.ccr/ca-bundle.crt")) Sys.setenv(CURL_CA_BUNDLE = "/root/.ccr/ca-bundle.crt")
if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))

a <- commandArgs(TRUE)
pf <- if (length(a) > 0) a[1] else "data/wofs_persistence_L13.rds"
sub <- if (length(a) > 1) a[2] else "KIN01"
years <- if (length(a) > 3) as.integer(a[3]):as.integer(a[4]) else 1987:2025

p <- readRDS(pf)
k <- p$cell[p$ibra_sub %in% sub]
cell_path <- c(wet = sum(p$wet_all[p$ibra_sub %in% sub]), clear = sum(p$clear_all[p$ibra_sub %in% sub]))
lev <- unique(s2::s2_cell_level(s2::as_s2_cell(k)))
stopifnot(length(lev) == 1)
poly <- terra::vect("regions/ibra7/ibra7_subregions_pilot.geojson")
poly <- terra::project(poly[poly$SUB_CODE_7 == sub], "EPSG:3577")

## tiles: every DEA tile that the subregion's cells reach
cb <- s2::s2_cell_polygon(s2::as_s2_cell(k))
bb <- terra::ext(terra::project(terra::vect(s2::s2_as_text(cb), crs = "EPSG:4326"), "EPSG:3577"))
g0 <- dea_tile_grid(0, 0); ts <- g0$extent[["xmax"]] - g0$extent[["xmin"]]
tx <- floor((bb[1] - g0$extent[["xmin"]]) / ts):floor((bb[2] - g0$extent[["xmin"]]) / ts)
ty <- floor((bb[3] - g0$extent[["ymin"]]) / ts):floor((bb[4] - g0$extent[["ymin"]]) / ts)
tiles <- expand.grid(x = tx, y = ty)
cat(sprintf("%s: %d level %d cells, %d candidate tiles\n", sub, length(k), lev, nrow(tiles)))

url <- function(x, y, year, band)
  sprintf(paste0("/vsicurl/https://dea-public-data.s3.ap-southeast-2.amazonaws.com/",
                 "derivative/ga_ls_wo_fq_cyear_3/2-0-0/x%02d/y%02d/%d--P1Y/",
                 "ga_ls_wo_fq_cyear_3_x%02dy%02d_%d--P1Y_final_%s.tif"), x, y, year, x, y, year, band)

tot <- c(wetA = 0, clearA = 0, wetB = 0, clearB = 0, pixA = 0, pixB = 0)
for (i in seq_len(nrow(tiles))) {
  g <- dea_tile_grid(tiles$x[i], tiles$y[i])
  e <- terra::intersect(terra::ext(unname(g$extent)), bb)
  if (is.null(e)) next
  tmpl <- terra::rast(terra::ext(unname(g$extent)), ncols = g$dimension[["ncol"]],
                      nrows = g$dimension[["nrow"]], crs = g$crs)
  w <- terra::crop(tmpl, e, snap = "out")
  xy <- terra::xyFromCell(w, seq_len(terra::ncell(w)))
  ll <- terra::project(xy, from = g$crs, to = "EPSG:4326")
  tok <- unclass(s2::s2_cell_parent(s2::as_s2_cell(s2::s2_lnglat(ll[, 1], ll[, 2])), lev))
  inA <- tok %in% unclass(s2::as_s2_cell(k))
  rm(xy, ll, tok)
  inB <- !is.na(terra::values(terra::rasterize(poly, w, touches = FALSE), mat = FALSE))
  if (!any(inA | inB)) next
  cat(sprintf("tile %s: %d pixels in cells, %d in polygon\n", g$tile, sum(inA), sum(inB)))
  for (yr in years) {
    rd <- function(band) {
      r <- terra::rast(url(tiles$x[i], tiles$y[i], yr, band))
      v <- terra::values(terra::crop(r, w), mat = FALSE)
      v[v == -999] <- NA
      v
    }
    wet <- try(rd("count_wet"), silent = TRUE)
    if (inherits(wet, "try-error")) next
    clear <- rd("count_clear")
    tot <- tot + c(sum(wet[inA], na.rm = TRUE), sum(clear[inA], na.rm = TRUE),
                   sum(wet[inB], na.rm = TRUE), sum(clear[inB], na.rm = TRUE),
                   sum(inA & !is.na(clear)), sum(inB & !is.na(clear)))
  }
}

res <- data.frame(path = c("cell sums", "direct, pixels in the cells (A)", "direct, pixels in the polygon (B)"),
                  wet = c(cell_path[["wet"]], tot[["wetA"]], tot[["wetB"]]),
                  clear = c(cell_path[["clear"]], tot[["clearA"]], tot[["clearB"]]))
res$wet_fraction <- res$wet / res$clear
print(res, row.names = FALSE, digits = 8)
cat(sprintf("gate A (exact): %s\n", if (res$wet[1] == res$wet[2] && res$clear[1] == res$clear[2]) "ok" else "FAILED"))
cat(sprintf("polygon vs cells: wet fraction %.5f vs %.5f (ratio %.4f), clear counts ratio %.4f\n",
            res$wet_fraction[3], res$wet_fraction[1], res$wet_fraction[3] / res$wet_fraction[1],
            res$clear[3] / res$clear[1]))
dir.create("data", showWarnings = FALSE)
write.csv(res, file.path("data", sprintf("wofs_subregion_gate_%s.csv", sub)), row.names = FALSE)
