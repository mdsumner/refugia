## Summer air temperature exposure of Antarctic ice-free land (ERA5, S2 level 9).
##
## Rscript pilots/antarctica/era5_exposure.R <era5_dir> <icefree_dir> <outdir> [first] [last]
##
## <era5_dir> holds era5_t2m_<YYYYMM>.bin from sources/era5_south.py;
## <icefree_dir> holds icefree_L13.rds and icefree_L9.rds from
## sources/icefree_cells.R. Summer Y is December Y-1 to February Y.
##
## 1. Cell sums. Each 0.25 deg pixel is split 3 x 3 so that level 9 cells get
##    area-weighted shares (as for SST). Per summer and cell
##    (era5_L9/era5_L9_<summer>.rds, mergeable): w (area, km2), area-weighted
##    sums of the pixel summer mean 2 m temperature (and its square), of the
##    summer positive degree days (sum of max(T, 0) over hours / 24) and of
##    the share of hours above 0 deg C.
##    Gate: the area mean summer temperature south of 60S per summer from the
##    cell sums equals the area mean over pixels; the script stops if they
##    differ by more than 1e-9 deg C.
## 2. Per cell: climatology, trend per decade and signal-to-noise of summer
##    mean temperature and of positive degree days; temperature velocity
##    (trend over the local gradient of the climatology, km per decade),
##    computed over all cells south of 60S so that land cells have
##    neighbours.
## 3. Scored within sectors (as icefree_summary.R, Peninsula split out) on the
##    level 9 cells that hold ice-free land. Candidate land holdout, the same
##    rule as for SST: summer temperature trend in the sector's lowest
##    quarter, and either cooling or a slow warming velocity (lowest quarter
##    of the sector's warming cells). Level 13 ice-free cells take the values
##    of their level 9 parent (as the Australian L13 cells take AGCD from
##    level 10).
##
## ERA5 at 0.25 deg is 7 to 14 km by 28 km here; a pixel over an oasis is
## mostly ice, so the values describe the regional summer, not the rock
## surface (macro, not micro, refugia). Sectors stand in for the ACBRs until
## those polygons are added.

if (requireNamespace("pkgload", quietly = TRUE)) pkgload::load_all(quiet = TRUE) else
  invisible(lapply(list.files("R", full.names = TRUE), source))
Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
indir <- if (length(a) > 0) a[1] else "data/era5"
icedir <- if (length(a) > 1) a[2] else "data"
outdir <- if (length(a) > 2) a[3] else "data"
y0 <- if (length(a) > 3) as.integer(a[4]) else 1980L
y1 <- if (length(a) > 4) as.integer(a[5]) else 2026L
lev <- 9L; sub <- 3L; NR <- 119L; NC <- 1440L
sumdir <- file.path(outdir, "era5_L9")
dir.create(sumdir, recursive = TRUE, showWarnings = FALSE)

read_month <- function(ym) {
  f <- file.path(indir, sprintf("era5_t2m_%s.bin", ym))
  if (!file.exists(f)) return(NULL)
  v <- readBin(f, "double", n = 4L * NR * NC, endian = "little")
  ## written C-order (4, NR, NC): fill a matrix row-wise per field
  lapply(1:4, function(k) matrix(v[(k - 1) * NR * NC + seq_len(NR * NC)], NR, NC, byrow = TRUE))
}
read_summer <- function(y) {
  mm <- lapply(c(sprintf("%d12", y - 1), sprintf("%d01", y), sprintf("%d02", y)), read_month)
  if (any(vapply(mm, is.null, TRUE))) return(NULL)
  S <- function(k) Reduce(`+`, lapply(mm, `[[`, k))
  n <- S(1)
  full <- n >= 0.99 * max(n)
  t <- S(2) / n; pdd <- S(3) / 24; pos <- S(4) / n
  t[!full] <- NA; pdd[!full] <- NA; pos[!full] <- NA
  list(t = t, pdd = pdd, pos = pos, hours = max(n))
}

## grid: 119 rows (60.125S to 89.875S, row 1 centred 60.25S) x 1440 columns
## (centres 180W to 179.75E)
g <- list(extent = c(xmin = -180.125, xmax = 179.875, ymin = -89.875, ymax = -60.125),
          dimension = c(ncol = NC * sub, nrow = NR * sub), crs = "EPSG:4326")
mfile <- file.path(sumdir, sprintf("mapping_L%d_sub%d.rds", lev, sub))
m <- if (file.exists(mfile)) readRDS(mfile) else { mm <- build_grid_mapping(g, level = lev); saveRDS(mm, mfile); mm }
idx <- mapping_index(m)
R2 <- 6371.0072^2
lat_top <- -60.125 - (seq_len(NR * sub) - 1) * 0.25 / sub
band <- R2 * (0.25 / sub * pi / 180) * abs(sin(lat_top * pi / 180) - sin((lat_top - 0.25 / sub) * pi / 180))
area_sub <- rep(band, each = NC * sub)
up <- function(x) x[rep(seq_len(nrow(x)), each = sub), rep(seq_len(ncol(x)), each = sub)]
rowmajor <- function(x) as.vector(t(x))
lat_pix <- -60.125 - (0:(NR - 1)) * 0.25
A <- matrix(R2 * (0.25 * pi / 180) * abs(sin(lat_pix * pi / 180) - sin((lat_pix - 0.25) * pi / 180)), NR, NC)

yrs <- integer(0); gate <- list()
for (y in y0:y1) {
  p <- read_summer(y)
  if (is.null(p)) { cat("summer", y, "incomplete, skipped\n"); next }
  yrs <- c(yrs, y)
  ok <- !is.na(p$t)
  gate[[length(gate) + 1]] <- data.frame(summer = y, hours = p$hours, area_km2 = sum(A[ok]),
                                         mean_t_pixels = sum((A * p$t)[ok]) / sum(A[ok]))
  of <- file.path(sumdir, sprintf("era5_L%d_%d.rds", lev, y))
  if (!file.exists(of)) {
    v <- lapply(p[c("t", "pdd", "pos")], function(x) rowmajor(up(x)))
    w <- area_sub; w[is.na(v$t)] <- 0
    s <- sum_to_cells(m, w = w, s_t = w * v$t, ss_t = w * v$t^2, s_pdd = w * v$pdd,
                      ss_pdd = w * v$pdd^2, s_pos = w * v$pos, index = idx)
    s$n <- NULL
    s <- s[s$w > 0, ]
    s$summer <- y
    saveRDS(s, of)
  }
}
cat(length(yrs), "summers", min(yrs), "-", max(yrs), "\n")
d <- do.call(rbind, lapply(file.path(sumdir, sprintf("era5_L%d_%d.rds", lev, yrs)), readRDS))
gate <- do.call(rbind, gate)
gs <- aggregate(cbind(w, s_t) ~ summer, data = d, FUN = sum)
gate$mean_t_sums <- gs$s_t[match(gate$summer, gs$summer)] / gs$w[match(gate$summer, gs$summer)]
gate$d_t <- gate$mean_t_sums - gate$mean_t_pixels
gate$d_area <- gs$w[match(gate$summer, gs$summer)] - gate$area_km2
tr <- function(x, t) unname(stats::coef(stats::lm(x ~ t))[2]) * 10
cat(sprintf("gate: max |sums - pixels| %.1e deg C, area %.1e km2; trend %.4f vs %.4f deg C per decade\n",
            max(abs(gate$d_t)), max(abs(gate$d_area)),
            tr(gate$mean_t_sums, gate$summer), tr(gate$mean_t_pixels, gate$summer)))
write.csv(gate, file.path(outdir, "era5_gate_by_summer.csv"), row.names = FALSE)
stopifnot(max(abs(gate$d_t)) < 1e-9)

## per cell (a cell-summer counts if at least half its usual area has a value)
wmax <- tapply(d$w, d$cell, max); d$ok <- d$w >= 0.5 * as.vector(wmax[d$cell])
out <- NULL
for (v in list(c("t", "s_t"), c("pdd", "s_pdd"), c("pos", "s_pos"))) {
  x <- data.frame(cell = d$cell[d$ok], year = d$summer[d$ok], value = d[[v[2]]][d$ok] / d$w[d$ok])
  t <- cell_trends(x, yrs)
  t <- t[t$n >= 0.75 * length(yrs), ]
  names(t)[-1] <- paste0(names(t)[-1], "_", v[1])
  out <- if (is.null(out)) t else merge(out, t, by = "cell", all = TRUE)
}
out$velocity_km_decade_t <- out$slope_decade_t / cell_gradient(out$cell, out$clim_t)
ctr <- s2::s2_cell_center(s2::as_s2_cell(out$cell)); out$lon <- s2::s2_x(ctr); out$lat <- s2::s2_y(ctr)

sector <- function(lon, lat) {
  s <- as.character(cut(lon, c(-180, -130, -60, 20, 90, 160, 180), include.lowest = TRUE,
                        labels = c("Ross", "Bell-Amundsen", "Weddell", "Indian", "W Pacific", "Ross2")))
  s[s == "Ross2"] <- "Ross"
  s[lon >= -80 & lon <= -55 & lat > -75] <- "Peninsula"
  s
}
sector_levels <- c("Peninsula", "Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen")
out$sector <- sector(out$lon, out$lat)
c9 <- readRDS(file.path(icedir, "icefree_L9.rds"))
c13 <- readRDS(file.path(icedir, "icefree_L13.rds"))
out$rock_km2 <- c9$rock_km2[match(out$cell, c9$cell)]
out$rock_km2[is.na(out$rock_km2)] <- 0
zone <- out$rock_km2 > 0 & is.finite(out$slope_decade_t)
out$icefree <- zone
cat(sum(zone), "of", nrow(c9), "ice-free level 9 cells have an ERA5 series\n")
out$warming_pct <- NA_real_; out$warm_velocity_pct <- NA_real_
out$warming_pct[zone] <- group_percentile(out$slope_decade_t[zone], out$sector[zone])
out$warm_velocity_km_decade <- abs(out$velocity_km_decade_t)
out$warm_velocity_km_decade[!(out$slope_decade_t > 0)] <- 0
warm <- zone & out$slope_decade_t > 0 & is.finite(out$warm_velocity_km_decade)
out$warm_velocity_pct[warm] <- group_percentile(out$warm_velocity_km_decade[warm], out$sector[warm])
out$slow_or_cool <- (zone & out$slope_decade_t <= 0) | (warm & out$warm_velocity_pct <= 0.25)
out$land_refugium <- zone & out$warming_pct <= 0.25 & out$slow_or_cool %in% TRUE
out$land_refugium[is.na(out$land_refugium)] <- FALSE
saveRDS(out, file.path(outdir, "era5_exposure_L9.rds"))
write.csv(out[out$icefree, ], file.path(outdir, "era5_exposure_icefree_L9.csv"), row.names = FALSE)

## level 13 ice-free cells with their parent's exposure
c13$parent9 <- as.character(s2::s2_cell_parent(s2::as_s2_cell(c13$cell), lev))
c13$sector <- sector(c13$lon, c13$lat)
keep <- c("clim_t", "slope_decade_t", "snr_t", "velocity_km_decade_t", "clim_pdd",
          "slope_decade_pdd", "snr_pdd", "clim_pos", "warming_pct", "warm_velocity_pct", "land_refugium")
j <- match(c13$parent9, out$cell)
for (k in keep) c13[[k]] <- out[[k]][j]
c13$land_refugium[is.na(c13$land_refugium)] <- FALSE
saveRDS(c13, file.path(outdir, "icefree_exposure_L13.rds"))
write.csv(c13, file.path(outdir, "icefree_exposure_L13.csv"), row.names = FALSE)

q <- function(x, f = "%.2f") sprintf(paste0(f, " [", f, ", ", f, "]"), stats::median(x, na.rm = TRUE),
                         stats::quantile(x, 0.1, na.rm = TRUE), stats::quantile(x, 0.9, na.rm = TRUE))
z <- out[zone, ]
summ <- do.call(rbind, lapply(intersect(sector_levels, z$sector), function(s) {
  x <- z[z$sector == s, ]; y13 <- c13[c13$sector == s, ]
  data.frame(sector = s, cells_L9 = nrow(x), rock_km2 = round(sum(x$rock_km2)),
             summer_t = q(x$clim_t, "%.1f"), t_trend = q(x$slope_decade_t), t_snr = q(x$snr_t, "%.1f"),
             pdd = q(x$clim_pdd, "%.0f"), pdd_trend = q(x$slope_decade_pdd, "%.1f"),
             velocity_km_decade = q(x$velocity_km_decade_t, "%.0f"),
             warming_share = round(mean(x$slope_decade_t > 0), 2),
             snr2_share = round(mean(abs(x$snr_t) >= 2, na.rm = TRUE), 2),
             refugium_L9 = sum(x$land_refugium),
             refugium_rock_km2 = round(sum(x$rock_km2[x$land_refugium])),
             refugium_L13 = sum(y13$land_refugium, na.rm = TRUE))
}))
print(summ, row.names = FALSE)
write.csv(summ, file.path(outdir, "era5_exposure_summary.csv"), row.names = FALSE)
