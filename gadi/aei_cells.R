## Antarctic Ecosystem Inventory rasters (100 m) to S2 cell sums.
##
## Rscript gadi/aei_cells.R <aad_dir> <outdir> [level]
##
## <aad_dir> holds the COGs from gadi/aad_layers.sh (aei_*.tif). Runs on Gadi
## next to the rasters so that only small tables travel (the two
## temperature COGs alone are about 680 MB). Per S2 cell (default level 13):
##   aei_<tier>_L13.csv.gz          cell, class, area_km2  (tier1_meu,
##                                  tier2_habitat, tier3_ecosystem)
##   aei_<variable>_L13.csv.gz      cell, w (area km2), s (area-weighted sum),
##                                  ss (area-weighted sum of squares)
##                                  (MeanTemp_1415_bm, Total_DD_1415_minus5_bm)
##   aei_<tier>_classes.csv         the class table read from the .vat.dbf
## The continuous sums keep only cells holding Tier 1 (ice-free) pixels.
## All are mergeable sums: any union of cells adds exactly; mean = s / w.
##
## Each pixel goes to the cell holding its centre. Pixel area is the true
## area on the sphere for polar stereographic grids (scale factor from the
## latitude of true scale), otherwise the nominal pixel area.

a <- commandArgs(TRUE)
indir <- if (length(a) > 0) a[1] else "aad"
outdir <- if (length(a) > 1) a[2] else file.path(indir, "aei_L13")
level <- if (length(a) > 2) as.integer(a[3]) else 13L
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

pixel_area_km2 <- function(r, xy, lat) {
  res <- terra::res(r)
  p <- terra::crs(r, proj = TRUE)
  if (grepl("+proj=stere", p, fixed = TRUE) && grepl("+lat_0=-90", p, fixed = TRUE)) {
    ts <- as.numeric(sub(".*\\+lat_ts=([-0-9.]+).*", "\\1", p))
    if (!is.finite(ts)) ts <- -90
    ## spherical polar stereographic scale factor, true scale at ts
    k <- (1 + sin(abs(ts) * pi / 180)) / (1 + sin(abs(lat) * pi / 180))
    prod(res) / k^2 / 1e6
  } else rep(prod(res) / 1e6, length(lat))
}

sum_raster <- function(f, kind) {
  r <- terra::rast(f)[[1]]
  b <- terra::blocks(r, n = 4)
  out <- vector("list", b$n)
  terra::readStart(r); on.exit(terra::readStop(r))
  nc <- terra::ncol(r)
  for (i in seq_len(b$n)) {
    v <- terra::readValues(r, b$row[i], b$nrows[i], 1, nc)
    k <- which(is.finite(v))
    if (!length(k)) next
    cellno <- terra::cellFromRowCol(r, b$row[i] + (k - 1) %/% nc, (k - 1) %% nc + 1)
    xy <- terra::xyFromCell(r, cellno)
    ll <- terra::project(xy, from = terra::crs(r), to = "EPSG:4326")
    tok <- as.character(s2::s2_cell_parent(s2::as_s2_cell(s2::s2_lnglat(ll[, 1], ll[, 2])), level))
    w <- pixel_area_km2(r, xy, ll[, 2])
    x <- v[k]
    out[[i]] <- if (kind == "class") {
      key <- paste(tok, x)
      s <- rowsum(w, key)
      data.frame(cell = sub(" .*", "", rownames(s)), class = as.integer(sub(".* ", "", rownames(s))),
                 area_km2 = s[, 1])
    } else {
      s <- rowsum(cbind(w, w * x, w * x * x), tok)
      data.frame(cell = rownames(s), w = s[, 1], s = s[, 2], ss = s[, 3])
    }
    if (i %% 20 == 0) cat(sprintf("  %s block %d/%d\n", basename(f), i, b$n))
  }
  d <- do.call(rbind, out)
  if (kind == "class") {
    s <- rowsum(d$area_km2, paste(d$cell, d$class))
    data.frame(cell = sub(" .*", "", rownames(s)), class = as.integer(sub(".* ", "", rownames(s))),
               area_km2 = s[, 1], row.names = NULL)
  } else {
    s <- rowsum(as.matrix(d[c("w", "s", "ss")]), d$cell)
    data.frame(cell = rownames(s), w = s[, 1], s = s[, 2], ss = s[, 3], row.names = NULL)
  }
}

layers <- list(tier1_meu = "class", tier2_habitat = "class", tier3_ecosystem = "class",
               MeanTemp_1415_bm = "cont", Total_DD_1415_minus5_bm = "cont")
for (nm in names(layers)) {
  f <- file.path(indir, sprintf("aei_%s.tif", nm))
  of <- file.path(outdir, sprintf("aei_%s_L%d.csv.gz", nm, level))
  if (!file.exists(f)) { cat("missing", f, "\n"); next }
  if (file.exists(of)) { cat("have", of, "\n"); next }
  t0 <- Sys.time()
  d <- sum_raster(f, layers[[nm]])
  ## the abiotic rasters cover ice and ocean too; keep the ice-free cells (Tier 1)
  t1f <- file.path(outdir, sprintf("aei_tier1_meu_L%d.csv.gz", level))
  if (layers[[nm]] == "cont" && file.exists(t1f)) {
    keep <- unique(utils::read.csv(t1f)$cell)
    d <- d[d$cell %in% keep, ]
  }
  utils::write.csv(d, gzfile(of), row.names = FALSE)
  tot <- if (layers[[nm]] == "class") sum(d$area_km2) else sum(d$w)
  cat(sprintf("%s: %d rows, %d cells, %.0f km2, %.1f min\n", nm, nrow(d), length(unique(d$cell)), tot,
              as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  if (layers[[nm]] == "class") {
    ct <- try(terra::cats(terra::rast(f))[[1]], silent = TRUE)
    if (!inherits(ct, "try-error") && is.data.frame(ct) && nrow(ct))
      utils::write.csv(ct, file.path(outdir, sprintf("aei_%s_classes.csv", nm)), row.names = FALSE)
  }
}
cat("done:", paste(list.files(outdir), collapse = " "), "\n")
