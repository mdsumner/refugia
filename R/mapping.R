## Pixel-to-S2-cell mapping for the DEA 30 m tile grid.
##
## DEA summary products share one grid: EPSG:3577, 30 m pixels, 3200 x 3200
## pixel tiles (96 km) addressed as xNN/yNN from origin (-4416000, -6912000),
## y increasing north. A mapping is built once per tile and reused for every
## year and every product on that grid.
##
## The mapping is stored as runs: for each image row, maximal runs of
## consecutive columns whose pixel centres fall in the same S2 cell. Cells are
## carried as character tokens (never bare s2_cell doubles, see trend.sst).

dea_origin <- c(x = -4416000, y = -6912000)
dea_tile_size <- 96000
dea_res <- 30

#' Grid of one DEA summary tile
#'
#' @param x,y tile indices as in the DEA path (`x46/y45`)
#' @return list with extent (xmin, xmax, ymin, ymax), dimension (ncol, nrow),
#'   resolution and crs
#' @export
dea_tile_grid <- function(x, y) {
  xmin <- dea_origin[["x"]] + dea_tile_size * x
  ymin <- dea_origin[["y"]] + dea_tile_size * y
  n <- as.integer(dea_tile_size / dea_res)
  list(extent = c(xmin = xmin, xmax = xmin + dea_tile_size,
                  ymin = ymin, ymax = ymin + dea_tile_size),
       dimension = c(ncol = n, nrow = n), res = dea_res, crs = "EPSG:3577",
       tile = sprintf("x%02dy%02d", x, y))
}

#' Map the pixels of a DEA tile to S2 cells
#'
#' @param x,y tile indices
#' @param level S2 level
#' @param band_rows rows processed at a time (memory bound)
#' @return list: `runs` (row, start, end, cell; cell indexes `cells`),
#'   `cells` (character tokens, sorted), `grid`, `level`
#' @export
build_tile_mapping <- function(x, y, level = 13L, band_rows = 400L) {
  g <- dea_tile_grid(x, y)
  nc <- g$dimension[["ncol"]]; nr <- g$dimension[["nrow"]]
  xc <- g$extent[["xmin"]] + (seq_len(nc) - 0.5) * g$res
  runs <- vector("list", ceiling(nr / band_rows))
  starts <- seq(1L, nr, by = band_rows)
  for (b in seq_along(starts)) {
    rows <- starts[b]:min(nr, starts[b] + band_rows - 1L)
    yc <- g$extent[["ymax"]] - (rows - 0.5) * g$res
    xy <- cbind(rep(xc, length(rows)), rep(yc, each = nc))
    ll <- terra::project(xy, from = g$crs, to = "EPSG:4326")
    tok <- as.character(s2::s2_cell_parent(
      s2::as_s2_cell(s2::s2_lnglat(ll[, 1], ll[, 2])), level))
    ## runs within each row: a run breaks where the token changes or a row starts
    brk <- c(TRUE, tok[-1L] != tok[-length(tok)])
    brk[seq(1L, length(tok), by = nc)] <- TRUE
    first <- which(brk)
    last <- c(first[-1L] - 1L, length(tok))
    runs[[b]] <- data.frame(row = rows[1L] + (first - 1L) %/% nc,
                            start = (first - 1L) %% nc + 1L,
                            end = (last - 1L) %% nc + 1L,
                            token = tok[first])
  }
  runs <- do.call(rbind, runs)
  cells <- sort(unique(runs$token))
  runs$cell <- match(runs$token, cells)
  runs$token <- NULL
  list(runs = runs, cells = cells, grid = g, level = as.integer(level))
}

#' Dense pixel-to-cell index from a mapping
#'
#' @param mapping output of [build_tile_mapping()]
#' @return integer vector, one element per pixel in row-major order, the
#'   index into `mapping$cells`
#' @export
mapping_index <- function(mapping) {
  r <- mapping$runs
  rep.int(r$cell, r$end - r$start + 1L)
}

#' Sum pixel values into S2 cells
#'
#' @param mapping output of [build_tile_mapping()]
#' @param ... named numeric vectors of pixel values in row-major order (as
#'   from `terra::values(r, mat = FALSE)`), NA values contribute nothing
#' @param index optional precomputed [mapping_index()]
#' @return data frame: cell (token), n (valid pixels of the first input), and
#'   one sum column per input
#' @export
sum_to_cells <- function(mapping, ..., index = mapping_index(mapping)) {
  vals <- list(...)
  npix <- prod(mapping$grid$dimension)
  stopifnot(length(index) == npix, all(lengths(vals) == npix),
            !is.null(names(vals)), all(nzchar(names(vals))))
  out <- data.frame(cell = mapping$cells)
  out$n <- tabulate(index[!is.na(vals[[1L]])], nbins = length(mapping$cells))
  for (nm in names(vals)) {
    v <- vals[[nm]]
    v[is.na(v)] <- 0
    out[[nm]] <- as.vector(rowsum(as.double(v), index, reorder = TRUE))
  }
  out
}
