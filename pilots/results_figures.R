## Figures for the results document: one file per figure, each panel framed.
##
## Rscript pilots/results_figures.R <refugia_dir> [ghcn_dir] [outdir]
##
## <refugia_dir>: agcd_exposure_L10.rds, era5_out/ (era5_exposure_L9.rds with
## ACBR scoring, era5_L9/ per-summer sums). [ghcn_dir]: GHCN-daily station
## files as for checks/era5_station_check.R (the station figure is skipped
## when absent). Writes to <outdir> (default <refugia_dir>/results):
##   fig_australia_thermal.png  Tmax trend and thermal holdouts, Tasmania and
##                              the MacDonnell Ranges, with IBRA regions
##   fig_antarctic_land.png     summer temperature trend and land holdouts
##                              on ice-free land, ACBRs labelled
##   fig_rule.png               the holdout rule in both domains
##   fig_station_check.png      ERA5 against station summers at six stations

Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data"
gdir <- if (length(a) > 1) a[2] else "data/ghcn"
outdir <- if (length(a) > 2) a[3] else file.path(dir, "results")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

ink <- "#2b2b29"; muted <- "#8a8984"; land <- "#e9e8e4"; bg <- "#fcfcfb"; panel <- "#ffffff"
frame <- "#c9c8c3"; blue <- "#2a78d6"
ttl <- function(t, sub = NULL) {
  mtext(t, side = 3, line = if (is.null(sub)) 0.5 else 1.3, adj = 0, cex = 0.95, font = 2, col = ink)
  if (!is.null(sub)) mtext(sub, side = 3, line = 0.3, adj = 0, cex = 0.72, col = ink)
}
panel_bg <- function() { u <- par("usr"); rect(u[1], u[3], u[2], u[4], col = panel, border = NA) }
panel_frame <- function() { u <- par("usr"); rect(u[1], u[3], u[2], u[4], col = NA, border = frame, lwd = 1, xpd = NA) }
cell_poly <- function(cells, crs) {
  w <- s2::s2_as_text(s2::s2_cell_polygon(s2::as_s2_cell(cells)))
  terra::project(terra::vect(w, crs = "EPSG:4326"), crs)
}
scalebar <- function(km) {
  u <- par("usr"); x0 <- u[1] + 0.05 * (u[2] - u[1]); y0 <- u[3] + 0.06 * (u[4] - u[3])
  segments(x0, y0, x0 + km * 1000, y0, col = ink, lwd = 2, lend = 1)
  text(x0 + km * 500, y0, sprintf("%d km", km), pos = 3, cex = 0.7, col = ink, offset = 0.3)
}

## ---- 1. Australia: Tmax trend and thermal holdouts ------------------------
au <- readRDS(file.path(dir, "agcd_exposure_L10.rds"))
ibra <- terra::project(terra::vect("regions/ibra7/ibra7_regions_pilot.geojson"), "EPSG:3577")
abrk <- c(0, 0.12, 0.15, 0.18, 0.21, 0.25, Inf)
apal <- c("#fde9e0", "#f9c9b6", "#f2a084", "#e56f55", "#c8402f", "#8f1d16")
alab <- c("< 0.12", "0.12 to 0.15", "0.15 to 0.18", "0.18 to 0.21", "0.21 to 0.25", "> 0.25")
au_panel <- function(reg, title, km) {
  x <- au[au$region == reg, ]
  v <- cell_poly(x$cell, "EPSG:3577")
  ib <- ibra[ibra$REG_CODE_7 %in% unique(x$ibra)]
  e <- terra::ext(ib); px <- 0.06 * (e[2] - e[1]); py <- 0.08 * (e[4] - e[3])
  plot(NA, xlim = c(e[1] - px, e[2] + px), ylim = c(e[3] - py, e[4] + py), asp = 1, axes = FALSE,
       xlab = "", ylab = "", xaxs = "i", yaxs = "i")
  panel_bg()
  terra::plot(v, col = apal[cut(x$slope_decade_tmax, abrk, labels = FALSE)], border = NA, add = TRUE)
  terra::plot(ib, col = NA, border = "#6f6e6a", lwd = 0.7, add = TRUE)
  h <- x$thermal_candidate %in% TRUE
  if (any(h)) {
    hv <- terra::aggregate(v[h])
    terra::plot(hv, col = "#2a78d655", border = "#0f3f86", lwd = 1.6, add = TRUE)
  }
  ctr <- terra::crds(terra::centroids(ib, inside = TRUE))
  text(ctr[, 1], ctr[, 2], ib$REG_CODE_7, cex = 0.62, col = ink, font = 2)
  scalebar(km); panel_frame()
  ttl(title, sprintf("%d of %d cells are thermal holdouts (blue outline)", sum(h), nrow(x)))
}
png(file.path(outdir, "fig_australia_thermal.png"), width = 2600, height = 1500, res = 220)
layout(matrix(c(1, 2, 3, 3), 2, 2, byrow = TRUE), widths = c(1, 1.75), heights = c(1, 0.11))
par(bg = bg, mar = c(0.8, 0.8, 3, 0.8), oma = c(0, 0.4, 0.2, 0.4))
au_panel("tasmania", "Tasmania", 100)
au_panel("macdonnell", "MacDonnell Ranges", 100)
par(mar = c(0, 0, 0, 0)); plot.new()
legend("center", horiz = TRUE, bty = "n", pch = 15, pt.cex = 2, col = apal, legend = alab, cex = 0.8,
       text.col = ink, title = "Tmax trend, deg C per decade, 1971-2025 (AGCD, S2 level 10 cells). Letters: IBRA regions.",
       title.col = ink, title.adj = 0)
invisible(dev.off())

## ---- 2. Antarctic ice-free land ------------------------------------------
o <- readRDS(file.path(dir, "era5_out", "era5_exposure_L9.rds"))
P <- function(lon, lat) terra::project(cbind(lon, lat), from = "EPSG:4326", to = "EPSG:3031") / 1000
ice <- o[o$clim_t < -2 & o$lat < -63, ]; ixy <- P(ice$lon, ice$lat)
an <- o[o$icefree %in% TRUE & is.finite(o$warming_pct_acbr), ]
xy <- P(an$lon, an$lat)
h <- an$land_refugium_acbr %in% TRUE
brk <- c(-Inf, -0.3, -0.15, -0.05, 0.05, 0.15, 0.3, Inf)
pal <- c("#104281", "#5598e7", "#9ec5f4", "#d9d8d3", "#efa3a1", "#e34948", "#9b2a29")
lab <- c("< -0.3", "-0.3 to -0.15", "-0.15 to -0.05", "-0.05 to 0.05", "0.05 to 0.15", "0.15 to 0.3", "> 0.3")
short <- c("North Victoria Land" = "North Victoria Land", "South Victoria Land" = "South Victoria Land",
           "Transantarctic Mountains" = "Transantarctic Mts", "Dronning Maud Land" = "Dronning Maud Land",
           "Enderby Land" = "Enderby Land", "Prince Charles Mountains" = "Prince Charles Mts",
           "East Antarctica" = "East Antarctica", "Adelie Land" = "Adelie Land",
           "Marie Byrd Land" = "Marie Byrd Land", "Ellsworth Mountains" = "Ellsworth Mts",
           "North-west Antarctic Peninsula" = "NW Peninsula", "South Antarctic Peninsula" = "S Peninsula")
acbr_labels <- function() {
  for (r in names(short)) {
    k <- an$acbr %in% r
    c0 <- c(stats::median(xy[k, 1]), stats::median(xy[k, 2]))
    ang <- atan2(c0[2], c0[1]); rad <- max(sqrt(sum(c0^2)) + 420, 2350)
    if (r %in% c("Transantarctic Mountains", "Ellsworth Mountains")) rad <- sqrt(sum(c0^2))
    p <- rad * c(cos(ang), sin(ang))
    if (r == "Transantarctic Mountains") p <- c0 + c(-560, 130)
    if (r == "Ellsworth Mountains") p <- c0 + c(-470, -150)
    if (r == "South Victoria Land") p <- p + c(520, -60)
    if (r == "North Victoria Land") p <- p + c(-300, -120)
    if (r == "South Antarctic Peninsula") p <- p + c(-150, -250)
    segments(c0[1], c0[2], p[1], p[2], col = muted, lwd = 0.5)
    text(p[1], p[2], short[[r]], cex = 0.62, col = ink, xpd = NA,
         pos = if (abs(cos(atan2(p[2] - c0[2], p[1] - c0[1]))) > 0.5) (if (p[1] > c0[1]) 4 else 2) else
           (if (p[2] > c0[2]) 3 else 1), offset = 0.2)
  }
}
base <- function() {
  plot(NA, asp = 1, axes = FALSE, xlab = "", ylab = "", xlim = c(-3500, 3500), ylim = c(-2750, 2750),
       xaxs = "i", yaxs = "i")
  panel_bg(); points(ixy, pch = 15, cex = 0.2, col = land)
}
png(file.path(outdir, "fig_antarctic_land.png"), width = 2800, height = 1500, res = 220)
layout(matrix(c(1, 2, 3, 3), 2, 2, byrow = TRUE), heights = c(1, 0.1))
par(bg = bg, mar = c(0.8, 0.8, 3, 0.8), oma = c(0, 0.4, 0.2, 0.4))
base()
points(xy, pch = 16, cex = 0.5, col = pal[cut(an$slope_decade_t, brk, labels = FALSE)])
acbr_labels(); panel_frame()
ttl("Summer temperature trend on ice-free land", "ERA5 DJF 2 m temperature, 1980-2026, cells holding rock (S2 level 9)")
base()
points(xy[!h, , drop = FALSE], pch = 16, cex = 0.45, col = "#b9b8b3")
points(xy[h, , drop = FALSE], pch = 16, cex = 0.6, col = blue)
acbr_labels(); panel_frame()
ttl(sprintf("Land holdouts: %s of %s cells", format(sum(h), big.mark = ","), format(nrow(an), big.mark = ",")),
    "Blue: lowest quarter of its ACBR for warming, and cooling or slow velocity. Grey: other ice-free cells")
par(mar = c(0, 0, 0, 0)); plot.new()
legend("left", horiz = TRUE, bty = "n", pch = 16, pt.cex = 1.8, col = pal, legend = lab, cex = 0.75,
       text.col = ink, title = "deg C per decade", title.col = ink, title.adj = 0, inset = 0.01)
invisible(dev.off())

## ---- 3. the rule ----------------------------------------------------------
rule_panel <- function(xp, yp, cool, hl, title, sub) {
  plot(NA, xlim = c(0, 1), ylim = c(-0.16, 1), xaxs = "i", yaxs = "i", axes = FALSE, xlab = "", ylab = "")
  panel_bg()
  rect(0, 0, 0.25, 0.25, col = "#dfe9f7", border = NA)
  if (any(cool)) { rect(0, -0.16, 0.25, -0.02, col = "#dfe9f7", border = NA); abline(h = -0.01, col = frame) }
  segments(0.25, -0.16, 0.25, 1, col = muted, lty = 2); segments(0, 0.25, 1, 0.25, col = muted, lty = 2)
  axis(1, at = c(0, 0.25, 0.5, 0.75, 1), labels = c("0", "25%", "50%", "75%", "100%"), cex.axis = 0.75,
       col = frame, col.axis = ink)
  axis(2, at = c(0, 0.25, 0.5, 0.75, 1), labels = c("0", "25%", "50%", "75%", "100%"), cex.axis = 0.75,
       col = frame, col.axis = ink, las = 1)
  if (any(cool)) axis(2, at = -0.09, labels = "cooling", cex.axis = 0.7, col = NA, col.axis = ink, las = 1)
  y <- yp; y[cool] <- stats::runif(sum(cool), -0.15, -0.03)
  points(xp[!hl], y[!hl], pch = 16, cex = 0.45, col = "#bdbcb7")
  points(xp[hl], y[hl], pch = 16, cex = 0.5, col = blue)
  title(xlab = "warming trend, rank within region", line = 2.3, cex.lab = 0.8, col.lab = ink)
  title(ylab = "warming velocity, rank within region", line = 3, cex.lab = 0.8, col.lab = ink)
  panel_frame(); ttl(title, sub)
}
png(file.path(outdir, "fig_rule.png"), width = 2600, height = 1250, res = 220)
par(mfrow = c(1, 2), bg = bg, mar = c(3.6, 4.4, 3.2, 1.2), oma = c(0, 0, 0.2, 0.4))
set.seed(1)
ha <- au$thermal_candidate %in% TRUE
rule_panel(au$slope_decade_tmax_pct, au$velocity_km_decade_tmax_pct, rep(FALSE, nrow(au)), ha,
           sprintf("Australia: %d of %s cells (%.0f%%)", sum(ha), format(nrow(au), big.mark = ","), 100 * mean(ha)),
           "Tmax, within IBRA regions. Every cell is warming")
cool <- an$slope_decade_t <= 0
rule_panel(an$warming_pct_acbr, ifelse(cool, NA, an$warm_velocity_pct_acbr), cool, h,
           sprintf("Antarctic ice-free land: %d of %s cells (%.0f%%)", sum(h), format(nrow(an), big.mark = ","), 100 * mean(h)),
           sprintf("Summer 2 m temperature, within ACBRs. %d cells are cooling (strip)", sum(cool)))
invisible(dev.off())

## ---- 4. station check -----------------------------------------------------
st <- data.frame(
  id = c("AYM00089002", "AYM00089512", "AYM00089662", "AYM00089564", "AYM00089611", "AYM00089050"),
  name = c("Neumayer", "Novolazarevskaya", "Mario Zucchelli", "Mawson", "Casey", "Bellingshausen"),
  region = c("Dronning Maud Land", "Dronning Maud Land", "North Victoria Land", "East Antarctica",
             "East Antarctica", "Peninsula"),
  lat = c(-70.67, -70.77, -74.70, -67.60, -66.28, -62.18), lon = c(-8.25, 11.83, 164.10, 62.87, 110.52, -58.88))
if (all(file.exists(file.path(gdir, paste0(st$id, ".csv"))))) {
  station_summers <- function(id) {
    d <- read.csv(file.path(gdir, paste0(id, ".csv")), stringsAsFactors = FALSE)
    d <- d[d$ELEMENT %in% c("TAVG", "TMAX", "TMIN") & (is.na(d$Q_FLAG) | d$Q_FLAG == ""), ]
    w <- reshape(d[c("DATE", "ELEMENT", "DATA_VALUE")], idvar = "DATE", timevar = "ELEMENT", direction = "wide")
    g <- function(k) { v <- w[[paste0("DATA_VALUE.", k)]]; if (is.null(v)) rep(NA_real_, nrow(w)) else v / 10 }
    t <- g("TAVG"); mm <- (g("TMAX") + g("TMIN")) / 2; t[is.na(t)] <- mm[is.na(t)]
    y <- w$DATE %/% 10000; m <- (w$DATE %/% 100) %% 100
    ok <- is.finite(t) & m %in% c(12, 1, 2); sy <- ifelse(m == 12, y + 1, y)
    mon <- merge(aggregate(list(t = t[ok]), list(summer = sy[ok], m = m[ok]), mean),
                 aggregate(list(n = t[ok]), list(summer = sy[ok], m = m[ok]), length))
    mon <- mon[mon$n >= 20, ]
    s <- aggregate(list(t = mon$t, k = rep(1, nrow(mon))), list(summer = mon$summer), sum)
    s <- s[s$k == 3, ]; data.frame(summer = s$summer, t_station = s$t / 3)
  }
  st$cell <- as.character(s2::s2_cell_parent(s2::as_s2_cell(s2::s2_lnglat(st$lon, st$lat)), 9L))
  ef <- sort(list.files(file.path(dir, "era5_out", "era5_L9"), "^era5_L9_[0-9]{4}\\.rds$", full.names = TRUE))
  es <- do.call(rbind, lapply(ef, function(f) {
    x <- readRDS(f); x <- x[x$cell %in% st$cell, ]; data.frame(cell = x$cell, summer = x$summer, t_era5 = x$s_t / x$w)
  }))
  png(file.path(outdir, "fig_station_check.png"), width = 2800, height = 1500, res = 220)
  par(mfrow = c(2, 3), bg = bg, mar = c(2.6, 3.6, 3.4, 1), oma = c(1.6, 0, 0.2, 0.4))
  for (i in seq_len(nrow(st))) {
    j <- merge(station_summers(st$id[i]), es[es$cell == st$cell[i], ], by = "summer")
    j$a_s <- j$t_station - mean(j$t_station); j$a_e <- j$t_era5 - mean(j$t_era5)
    plot(NA, xlim = c(1980, 2026), ylim = c(-3.2, 3.2), axes = FALSE, xlab = "", ylab = "")
    panel_bg(); abline(h = 0, col = frame)
    axis(1, at = seq(1980, 2020, 10), cex.axis = 0.8, col = frame, col.axis = ink)
    axis(2, at = -3:3, cex.axis = 0.8, col = frame, col.axis = ink, las = 1)
    fs <- stats::lm(a_s ~ summer, j); fe <- stats::lm(a_e ~ summer, j)
    lines(j$summer, stats::fitted(fs), col = ink, lwd = 1, lty = 2)
    lines(j$summer, stats::fitted(fe), col = "#e34948", lwd = 1, lty = 2)
    lines(j$summer, j$a_s, col = ink, lwd = 1.6); points(j$summer, j$a_s, pch = 16, cex = 0.6, col = ink)
    lines(j$summer, j$a_e, col = "#e34948", lwd = 1.6); points(j$summer, j$a_e, pch = 16, cex = 0.6, col = "#e34948")
    panel_frame()
    ttl(sprintf("%s (%s)", st$name[i], st$region[i]),
        sprintf("per decade: station %+.2f, ERA5 %+.2f deg C; r = %.2f", stats::coef(fs)[2] * 10,
                stats::coef(fe)[2] * 10, stats::cor(j$a_s, j$a_e)))
    if (i == 1) legend("topleft", bty = "n", lwd = 1.6, col = c(ink, "#e34948"), legend = c("station", "ERA5 cell"),
                       cex = 0.8, text.col = ink)
    if (i %in% c(1, 4)) title(ylab = "summer anomaly, deg C", line = 2.4, cex.lab = 0.8, col.lab = ink)
  }
  mtext("Summer (DJF) mean temperature, anomaly from each series' own mean over the summers both have. Dashed: linear trends.",
        side = 1, outer = TRUE, line = 0.4, adj = 0.02, cex = 0.65, col = ink)
  invisible(dev.off())
} else cat("station files missing, skipped fig_station_check.png\n")
cat("wrote", paste(list.files(outdir, "^fig_"), collapse = " "), "\n")
