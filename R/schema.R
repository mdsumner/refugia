## One output schema for every domain.
##
## Each pilot writes its own wide per-cell table. For sharing and for the
## cross-domain comparison, they are reshaped into two long tables with the
## same columns everywhere:
##
## metrics: domain, source, period, level, cell, lon, lat, region_set,
##          region, variable, metric, value, units
## flags:   domain, level, cell, lon, lat, region_set, region, kind, flag
##
## `metric` is one of a fixed vocabulary so that the same refugium logic can
## be read across domains: clim, trend_decade, snr, velocity_km_decade,
## persistence, dry_ratio, extent, and pct_<metric> for a within-region
## percentile. `kind` names the candidate type (water, green, thermal,
## sea_ice_holdout, sst_holdout, land_holdout).

schema_metrics_cols <- c("domain", "source", "period", "level", "cell", "lon", "lat",
                         "region_set", "region", "variable", "metric", "value", "units")
schema_flags_cols <- c("domain", "level", "cell", "lon", "lat", "region_set", "region", "kind", "flag")
schema_metric_vocab <- c("clim", "trend_decade", "snr", "velocity_km_decade", "persistence",
                         "dry_ratio", "extent")

#' Reshape a wide per-cell table to the long metrics schema
#'
#' @param d wide table with columns cell, lon, lat and the region column
#' @param spec data frame: column, variable, metric, units (one row per
#'   column of `d` to carry)
#' @param domain,source,period,level,region_set labels for every row
#' @param region name of the region column in `d`
#' @return data frame with [schema_metrics_cols]
#' @export
schema_metrics <- function(d, spec, domain, source, period, level, region_set, region) {
  stopifnot(all(spec$column %in% names(d)))
  base <- sub("^pct_", "", spec$metric)
  stopifnot(all(base %in% schema_metric_vocab))
  out <- lapply(seq_len(nrow(spec)), function(i) {
    v <- d[[spec$column[i]]]
    k <- is.finite(v)
    if (!any(k)) return(NULL)
    data.frame(domain = domain, source = source, period = period, level = as.integer(level),
               cell = as.character(d$cell[k]), lon = d$lon[k], lat = d$lat[k],
               region_set = region_set, region = as.character(d[[region]][k]),
               variable = spec$variable[i], metric = spec$metric[i], value = as.double(v[k]),
               units = spec$units[i])
  })
  do.call(rbind, out)
}

#' Reshape candidate flags to the long flags schema
#'
#' @param d wide table with cell, lon, lat, the region column and logical flag
#'   columns
#' @param flags named character: names are kinds, values are columns of `d`
#' @param domain,level,region_set,region as [schema_metrics()]
#' @return data frame with [schema_flags_cols]
#' @export
schema_flags <- function(d, flags, domain, level, region_set, region) {
  do.call(rbind, lapply(names(flags), function(k) {
    data.frame(domain = domain, level = as.integer(level), cell = as.character(d$cell),
               lon = d$lon, lat = d$lat, region_set = region_set,
               region = as.character(d[[region]]), kind = k, flag = d[[flags[[k]]]] %in% TRUE)
  }))
}

#' Spec helper
#'
#' @param ... rows as c(column, variable, metric, units)
#' @return data frame for [schema_metrics()]
#' @export
spec_rows <- function(...) {
  x <- do.call(rbind, list(...))
  data.frame(column = x[, 1], variable = x[, 2], metric = x[, 3], units = x[, 4])
}
