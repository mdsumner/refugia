## ERA5 summer warming against Antarctic station records (GHCN-daily).
##
## Rscript checks/era5_station_check.R <ghcn_dir> <era5_out_dir> <outdir>
##
## <ghcn_dir> holds GHCN-daily per-station files <ID>.csv from
## https://noaa-ghcn-pds.s3.amazonaws.com/csv/by_station/<ID>.csv (reachable
## from the cloud sessions); <era5_out_dir> holds era5_L9/era5_L9_<summer>.rds
## and era5_exposure_L9.rds from pilots/antarctica/era5_exposure.R.
##
## Summer Y is December Y-1 to February Y, as for ERA5. Daily temperature is
## TAVG, or (TMAX + TMIN) / 2 where TAVG is missing. A month counts with at
## least 20 days, a summer with all three months; the summer mean is the mean
## of the three monthly means. A station is compared over its own complete
## summers (at least 12) with the ERA5 level 9 cell holding it: mean bias,
## correlation of the summer series, and the OLS trend per decade of each
## over the same summers, and the shift in the ERA5 minus station difference
## between summers to 2000 and from 2001 (a step points to an inhomogeneity
## in one of the two series). The ERA5 trend over all summers 1980-2026 (as
## scored) is listed too.
##
## ERA5 at 0.25 deg mixes ice and ocean around a coastal station, so a bias
## of a few degrees is expected; the trend and year-to-year agreement are
## the test.

a <- commandArgs(TRUE)
gdir <- if (length(a) > 0) a[1] else "data/ghcn"
e5 <- if (length(a) > 1) a[2] else "data/era5_out"
outdir <- if (length(a) > 2) a[3] else "data/station_out"
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

st <- read.csv(text = "id,name,region,lat,lon
AYM00089662,Mario Zucchelli (Terra Nova Bay),North Victoria Land,-74.70,164.10
AYM00089661,Cape Phillips AWS,North Victoria Land,-73.06,169.60
AYM00089659,Priestley Glacier AWS,North Victoria Land,-74.33,163.15
AYM00089657,Leningradskaya,North Victoria Land,-69.50,159.38
AYM00089666,Cape Ross AWS,North Victoria Land,-76.72,163.00
AYM00089664,McMurdo,South Victoria Land,-77.85,166.67
AYM00089512,Novolazarevskaya,Dronning Maud Land,-70.77,11.83
AYM00089514,Maitri,Dronning Maud Land,-70.77,11.73
AYM00089504,Troll,Dronning Maud Land,-72.02,2.53
AYM00089001,SANAE (old),Dronning Maud Land,-70.30,-2.35
AYM00089004,SANAE IV,Dronning Maud Land,-71.67,-2.83
AYM00089002,Neumayer,Dronning Maud Land,-70.67,-8.25
AYM00089016,Wasa,Dronning Maud Land,-73.05,-13.42
AYM00089507,Kohnen,Dronning Maud Land,-75.00,0.07
AYM00089532,Syowa,Enderby Land,-69.00,39.58
AYM00089564,Mawson,East Antarctica,-67.60,62.87
AYM00089571,Davis,East Antarctica,-68.58,77.95
AYM00089592,Mirny,East Antarctica,-66.55,93.02
AYM00089611,Casey,East Antarctica,-66.28,110.52
AYM00089642,Dumont d'Urville,Adelie Land,-66.67,140.02
AYM00088963,Esperanza,Peninsula,-63.40,-56.98
AYM00089050,Bellingshausen,Peninsula,-62.18,-58.88
AYM00089062,Rothera,Peninsula,-67.57,-68.12
AYM00089063,Vernadsky,Peninsula,-65.25,-64.27", stringsAsFactors = FALSE)
## positions from ghcnd-stations.txt (rounded); ids with no file are skipped
st <- st[file.exists(file.path(gdir, paste0(st$id, ".csv"))), ]

station_summers <- function(id) {
  d <- read.csv(file.path(gdir, paste0(id, ".csv")), stringsAsFactors = FALSE)
  d <- d[d$ELEMENT %in% c("TAVG", "TMAX", "TMIN") & (is.na(d$Q_FLAG) | d$Q_FLAG == ""), ]
  if (!nrow(d)) return(NULL)
  w <- reshape(d[c("DATE", "ELEMENT", "DATA_VALUE")], idvar = "DATE", timevar = "ELEMENT", direction = "wide")
  g <- function(k) { v <- w[[paste0("DATA_VALUE.", k)]]; if (is.null(v)) rep(NA_real_, nrow(w)) else v / 10 }
  t <- g("TAVG"); mm <- (g("TMAX") + g("TMIN")) / 2
  t[is.na(t)] <- mm[is.na(t)]
  y <- w$DATE %/% 10000; m <- (w$DATE %/% 100) %% 100
  ok <- is.finite(t) & m %in% c(12, 1, 2)
  sy <- ifelse(m == 12, y + 1, y)
  mon <- aggregate(list(t = t[ok]), list(summer = sy[ok], m = m[ok]), mean)
  cnt <- aggregate(list(n = t[ok]), list(summer = sy[ok], m = m[ok]), length)
  mon <- merge(mon, cnt)
  mon <- mon[mon$n >= 20, ]
  s <- aggregate(list(t = mon$t, k = rep(1, nrow(mon))), list(summer = mon$summer), sum)
  s <- s[s$k == 3, ]
  data.frame(summer = s$summer, t_station = s$t / 3)
}

## ERA5 per-summer cell means for the cells holding the stations
st$cell <- as.character(s2::s2_cell_parent(s2::as_s2_cell(s2::s2_lnglat(st$lon, st$lat)), 9L))
ef <- sort(list.files(file.path(e5, "era5_L9"), "^era5_L9_[0-9]{4}\\.rds$", full.names = TRUE))
es <- do.call(rbind, lapply(ef, function(f) {
  x <- readRDS(f); x <- x[x$cell %in% st$cell, ]
  data.frame(cell = x$cell, summer = x$summer, t_era5 = x$s_t / x$w)
}))
o9 <- readRDS(file.path(e5, "era5_exposure_L9.rds"))

slope <- function(y, x) unname(stats::coef(stats::lm(y ~ x))[2]) * 10
res <- do.call(rbind, lapply(seq_len(nrow(st)), function(i) {
  s <- station_summers(st$id[i])
  e <- es[es$cell == st$cell[i], c("summer", "t_era5")]
  j <- if (is.null(s)) NULL else merge(s, e, by = "summer")
  n <- if (is.null(j)) 0L else nrow(j)
  k <- match(st$cell[i], o9$cell)
  base <- data.frame(st[i, c("id", "name", "region", "lat", "lon", "cell")],
                     era5_slope_1980_2026 = round(o9$slope_decade_t[k], 2),
                     era5_snr_1980_2026 = round(o9$snr_t[k], 2), summers = n)
  if (n < 12) return(cbind(base, first = NA, last = NA, t_station = NA, bias = NA, r = NA,
                           slope_station = NA, slope_era5_same = NA, slope_diff = NA, step_2000 = NA))
  dd <- j$t_era5 - j$t_station
  pre <- j$summer <= 2000; post <- j$summer >= 2001
  cbind(base, first = min(j$summer), last = max(j$summer),
        t_station = round(mean(j$t_station), 2),
        bias = round(mean(j$t_era5 - j$t_station), 2),
        r = round(stats::cor(j$t_station, j$t_era5), 2),
        slope_station = round(slope(j$t_station, j$summer), 2),
        slope_era5_same = round(slope(j$t_era5, j$summer), 2),
        slope_diff = round(slope(dd, j$summer), 2),
        step_2000 = if (sum(pre) >= 5 && sum(post) >= 5) round(mean(dd[post]) - mean(dd[pre]), 2) else NA)
}))
print(res[c("name", "region", "summers", "first", "last", "bias", "r", "slope_station",
            "slope_era5_same", "slope_diff", "step_2000", "era5_slope_1980_2026")], row.names = FALSE)
write.csv(res, file.path(outdir, "era5_station_check.csv"), row.names = FALSE)

## per region: median over stations with a comparison
ok <- is.finite(res$r)
reg <- do.call(rbind, lapply(unique(res$region[ok]), function(r) {
  x <- res[ok & res$region == r, ]
  data.frame(region = r, stations = nrow(x), median_r = stats::median(x$r),
             median_slope_station = stats::median(x$slope_station),
             median_slope_era5_same = stats::median(x$slope_era5_same),
             median_slope_diff = stats::median(x$slope_diff),
             median_step_2000 = stats::median(x$step_2000, na.rm = TRUE),
             median_era5_slope_1980_2026 = stats::median(x$era5_slope_1980_2026))
}))
cat("\nby region (medians over stations):\n"); print(reg, row.names = FALSE, digits = 2)
write.csv(reg, file.path(outdir, "era5_station_check_by_region.csv"), row.names = FALSE)
