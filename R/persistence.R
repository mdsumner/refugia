#' Combine per tile-year cell sums into one table per cell and year
#'
#' Cells that straddle tile edges appear in more than one tile; their sums
#' add.
#'
#' @param files paths of `sums_<tile>_<year>_L<level>.rds` from
#'   `sources/wofs_backfill.R`
#' @return data frame: cell, year, n, wet, clear
#' @export
combine_cell_sums <- function(files) {
  s <- do.call(rbind, lapply(files, function(f) {
    x <- readRDS(f)
    x[c("cell", "year", "n", "wet", "clear")]
  }))
  stats::aggregate(cbind(n, wet, clear) ~ cell + year, data = s, FUN = sum)
}

#' Water persistence metrics per cell
#'
#' @param s output of [combine_cell_sums()]
#' @param years years forming the record
#' @param dry years forming the dry period compared with the record
#' @param min_clear minimum clear observations for a cell-year to count
#' @return data frame per cell: clear and wet totals, wet fraction over the
#'   record (`wf_all`) and the dry period (`wf_dry`), their ratio
#'   (`dry_ratio`), number of years with any wet observation
#'   (`years_wet`) out of years with enough clear observations
#'   (`years_obs`), and the trend of annual wet fraction (per decade) with
#'   its signal-to-noise
#' @export
water_persistence <- function(s, years = 1987:2025, dry = 2017:2019, min_clear = 10) {
  s <- s[s$year %in% years, ]
  ok <- s$clear >= min_clear
  by_cell <- function(v, keep = rep(TRUE, nrow(s))) {
    tapply(v[keep], factor(s$cell[keep], levels = cells), sum)
  }
  cells <- sort(unique(s$cell))
  out <- data.frame(cell = cells,
                    clear_all = as.vector(by_cell(s$clear)),
                    wet_all = as.vector(by_cell(s$wet)))
  d <- s$year %in% dry
  out$clear_dry <- as.vector(by_cell(s$clear, d)); out$clear_dry[is.na(out$clear_dry)] <- 0
  out$wet_dry <- as.vector(by_cell(s$wet, d)); out$wet_dry[is.na(out$wet_dry)] <- 0
  out$wf_all <- persistence_from_counts(out$wet_all, out$clear_all)
  out$wf_dry <- persistence_from_counts(out$wet_dry, out$clear_dry)
  out$dry_ratio <- out$wf_dry / out$wf_all
  out$years_obs <- as.vector(by_cell(as.integer(ok)))
  out$years_wet <- as.vector(by_cell(as.integer(ok & s$wet > 0)))
  ## trend of annual wet fraction from sums, time centred on 2000
  t <- s$year - 2000
  x <- ifelse(ok, s$wet / s$clear, NA)
  k <- ok
  tr <- data.frame(n = as.vector(by_cell(rep(1, nrow(s)), k)),
                   St = as.vector(by_cell(t, k)), Stt = as.vector(by_cell(t * t, k)),
                   Sx = as.vector(by_cell(x, k)), Stx = as.vector(by_cell(t * x, k)),
                   Sxx = as.vector(by_cell(x * x, k)))
  tr[is.na(tr)] <- 0
  f <- suppressWarnings(trend_from_sums(tr, span = diff(range(years))))
  out$wf_trend_decade <- f$slope * 10
  out$wf_trend_snr <- f$snr
  out
}

#' Assign S2 cells to polygons by cell centre
#'
#' @param cells character cell tokens
#' @param polygons path or terra SpatVector of polygons in EPSG:4326
#' @param field attribute to return
#' @return character vector, NA for cells outside every polygon
#' @export
cells_in_polygons <- function(cells, polygons, field) {
  v <- if (inherits(polygons, "SpatVector")) polygons else terra::vect(polygons)
  ctr <- s2::s2_cell_center(s2::as_s2_cell(cells))
  pts <- terra::vect(cbind(s2::s2_x(ctr), s2::s2_y(ctr)), crs = "EPSG:4326")
  e <- terra::extract(v[, field], pts)
  e <- e[!duplicated(e$id.y), ]
  e[[field]][order(e$id.y)]
}

#' Percentile of a value within groups
#'
#' @param x numeric
#' @param group grouping (e.g. IBRA region)
#' @return percentile in 0..1 within each group, NA where x is NA
#' @export
group_percentile <- function(x, group) {
  out <- rep(NA_real_, length(x))
  for (g in unique(group[!is.na(group)])) {
    i <- which(group == g & is.finite(x))
    if (length(i)) out[i] <- (rank(x[i], ties.method = "average") - 0.5) / length(i)
  }
  out
}
