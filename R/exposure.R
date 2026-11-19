#' Annual cell values from AGCD cell sums
#'
#' @param d combined AGCD sums (`gadi/agcd_combine.R`): cell, year, pixdays,
#'   sum, days
#' @param total if TRUE (precipitation) the annual value is the mean daily
#'   value times days in the year, otherwise the mean daily value
#' @return data frame: cell, year, value
#' @export
agcd_annual <- function(d, total = FALSE) {
  v <- d$sum / d$pixdays
  if (total) v <- v * d$days
  data.frame(cell = d$cell, year = d$year, value = v)
}

#' Trend, signal-to-noise and climatology per cell from annual values
#'
#' @param a output of [agcd_annual()]
#' @param years period
#' @return data frame per cell: clim (mean), slope per decade, resid_sd,
#'   snr (total change over the period divided by resid_sd), n years
#' @export
cell_trends <- function(a, years) {
  a <- a[a$year %in% years & is.finite(a$value), ]
  cells <- sort(unique(a$cell))
  f <- factor(a$cell, levels = cells)
  t <- a$year - 2000
  S <- function(v) as.vector(tapply(v, f, sum))
  s <- data.frame(n = S(rep(1, nrow(a))), St = S(t), Stt = S(t * t),
                  Sx = S(a$value), Stx = S(t * a$value), Sxx = S(a$value^2))
  r <- trend_from_sums(s, span = diff(range(years)))
  data.frame(cell = cells, n = s$n, clim = s$Sx / s$n, slope_decade = r$slope * 10,
             resid_sd = r$resid_sd, snr = r$snr)
}

#' Local spatial gradient of a field on S2 cells
#'
#' Least-squares plane through each cell's four edge neighbours (those
#' present), in a local tangent plane in km.
#'
#' @param cells character tokens
#' @param z values
#' @return gradient magnitude in units of z per km (NA with < 2 neighbours)
#' @export
cell_gradient <- function(cells, z) {
  cc <- s2::as_s2_cell(cells)
  ctr <- s2::s2_cell_center(cc)
  lon <- s2::s2_x(ctr); lat <- s2::s2_y(ctr)
  Sxx <- Sxy <- Syy <- Sxz <- Syz <- k <- numeric(length(cells))
  for (e in 0:3) {
    nb <- as.character(s2::s2_cell_edge_neighbour(cc, e))
    j <- match(nb, cells)
    ok <- !is.na(j) & is.finite(z) & is.finite(z[j])
    dlon <- (lon[j] - lon + 540) %% 360 - 180   # across the antimeridian
    dx <- dlon * cos(lat * pi / 180) * 111.195
    dy <- (lat[j] - lat) * 111.195
    dz <- z[j] - z
    dx[!ok] <- 0; dy[!ok] <- 0; dz[!ok] <- 0
    Sxx <- Sxx + dx * dx; Sxy <- Sxy + dx * dy; Syy <- Syy + dy * dy
    Sxz <- Sxz + dx * dz; Syz <- Syz + dy * dz; k <- k + ok
  }
  det <- Sxx * Syy - Sxy^2
  gx <- (Syy * Sxz - Sxy * Syz) / det
  gy <- (Sxx * Syz - Sxy * Sxz) / det
  g <- sqrt(gx^2 + gy^2)
  g[k < 2 | !is.finite(g)] <- NA
  g
}
