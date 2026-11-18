#' Sufficient statistics for a linear trend
#'
#' Sums from which an OLS trend, its residual sd and a signal-to-noise ratio
#' can be recovered exactly. Sums of disjoint sets of cells or years add.
#'
#' @param t numeric time; centre it (e.g. year - 2000) so the sums stay well
#'   conditioned, and use the same centring for every cell that will be merged
#' @param x numeric value (e.g. annual mean), NA values are dropped
#' @return named numeric vector: n, St, Stt, Sx, Stx, Sxx
#' @export
trend_sums <- function(t, x) {
  ok <- is.finite(t) & is.finite(x)
  t <- t[ok]; x <- x[ok]
  c(n = length(t), St = sum(t), Stt = sum(t * t),
    Sx = sum(x), Stx = sum(t * x), Sxx = sum(x * x))
}

#' Trend, residual sd and signal-to-noise from sums
#'
#' @param s output of [trend_sums()], or a data frame with those columns
#'   (one row per cell)
#' @param span length of the time range used for signal-to-noise; slope
#'   times span is the total change over the record
#' @return data frame with slope, intercept, resid_sd, snr
#' @export
trend_from_sums <- function(s, span) {
  s <- as.data.frame(as.list(s))
  den <- s$n * s$Stt - s$St^2
  slope <- (s$n * s$Stx - s$St * s$Sx) / den
  intercept <- (s$Sx - slope * s$St) / s$n
  rss <- s$Sxx - intercept * s$Sx - slope * s$Stx
  rss[rss < 0] <- 0  ## rounding
  resid_sd <- sqrt(rss / (s$n - 2))
  data.frame(slope = slope, intercept = intercept,
             resid_sd = resid_sd, snr = slope * span / resid_sd)
}

#' Persistence from counts
#'
#' @param n_state count of observations in the habitat state (wet, green, ice)
#' @param n_clear count of valid observations
#' @return fraction in state, NA where there are no valid observations
#' @export
persistence_from_counts <- function(n_state, n_clear) {
  out <- n_state / n_clear
  out[n_clear == 0] <- NA_real_
  out
}
