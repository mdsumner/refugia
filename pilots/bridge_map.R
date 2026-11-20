## Bridging exhibit: the thermal holdout rule in both domains, side by side.
##
## Rscript pilots/bridge_map.R <refugia_dir> [outfile]
##
## <refugia_dir> holds agcd_exposure_L10.rds (pilots/australia/agcd_exposure.R)
## and era5_out/era5_exposure_L9.rds with the ACBR scoring
## (pilots/antarctica/acbr_score.R).
##
## Top row: temperature trend per decade on one diverging scale, holdout
## cells outlined: Tasmania and the MacDonnell Ranges (AGCD Tmax, S2 level
## 10, scored within IBRA7) and Antarctic ice-free land (ERA5 summer 2 m
## temperature, S2 level 9, scored within ACBR v2).
## Bottom row: the rule itself, as each cell's trend percentile within its
## region against its velocity percentile; the holdout corner is shaded.
## In Antarctica cooling cells pass on trend alone and sit in the strip
## below the axis.

Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data"
of <- if (length(a) > 1) a[2] else file.path(dir, "mvp", "bridge_exhibit.png")
dir.create(dirname(of), recursive = TRUE, showWarnings = FALSE)

au <- readRDS(file.path(dir, "agcd_exposure_L10.rds"))
an <- readRDS(file.path(dir, "era5_out", "era5_exposure_L9.rds"))
an <- an[an$icefree %in% TRUE & is.finite(an$warming_pct_acbr), ]

ink <- "#52514e"; muted <- "#8a8984"; land <- "#e4e3df"; bg <- "#fcfcfb"; hold <- "#1f1f1d"
brk <- c(-Inf, -0.3, -0.15, -0.05, 0.05, 0.15, 0.3, Inf)
pal <- c("#104281", "#5598e7", "#9ec5f4", "#f0efec", "#efa3a1", "#e34948", "#9b2a29")
lab <- c("< -0.3", "-0.3 to -0.15", "-0.15 to -0.05", "-0.05 to 0.05", "0.05 to 0.15", "0.15 to 0.3", "> 0.3")
col_of <- function(v) pal[cut(v, brk, labels = FALSE)]

cell_poly <- function(cells, crs) {
  w <- s2::s2_as_text(s2::s2_cell_polygon(s2::as_s2_cell(cells)))
  terra::project(terra::vect(w, crs = "EPSG:4326"), crs)
}

au_panel <- function(reg, title) {
  x <- au[au$region == reg, ]
  v <- cell_poly(x$cell, "EPSG:3577")
  h <- x$thermal_candidate %in% TRUE
  terra::plot(v, col = col_of(x$slope_decade_tmax), border = NA, axes = FALSE, mar = NA, add = FALSE,
              legend = FALSE)
  if (any(h)) terra::plot(v[h], col = NA, border = hold, lwd = 1.1, add = TRUE)
  mtext(title, side = 3, line = 0.3, adj = 0, cex = 0.7, font = 2, col = ink)
  mtext(sprintf("%d of %d cells are holdouts", sum(h), nrow(x)), side = 1, line = 0.2, adj = 0,
        cex = 0.55, col = ink)
}

png(of, width = 3000, height = 2000, res = 220)
layout(matrix(c(1, 2, 3, 3, 4, 4, 5, 5), 2, 4, byrow = TRUE), heights = c(1.25, 1))
par(bg = bg, oma = c(1.2, 0, 3.4, 0))

## 1-2. Australia maps
par(mar = c(2.2, 0.5, 1.6, 0.5))
au_panel("tasmania", "Tasmania: Tmax trend")
au_panel("macdonnell", "MacDonnell Ranges: Tmax trend")

## 3. Antarctic map
xy <- terra::project(cbind(an$lon, an$lat), from = "EPSG:4326", to = "EPSG:3031") / 1000
ice <- readRDS(file.path(dir, "era5_out", "era5_exposure_L9.rds"))
ice <- ice[ice$clim_t < -2 & ice$lat < -63, c("lon", "lat")]
ixy <- terra::project(as.matrix(ice), from = "EPSG:4326", to = "EPSG:3031") / 1000
h <- an$land_refugium_acbr %in% TRUE
par(mar = c(2.2, 0.5, 1.6, 0.5))
plot(xy, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", xlim = c(-2700, 2700), ylim = c(-2300, 2300))
points(ixy, pch = 15, cex = 0.12, col = land)
points(xy[!h, , drop = FALSE], pch = 16, cex = 0.45, col = col_of(an$slope_decade_t[!h]))
points(xy[h, , drop = FALSE], pch = 21, cex = 0.6, lwd = 0.7, col = hold, bg = col_of(an$slope_decade_t[h]))
mtext("Antarctic ice-free land: summer (DJF) 2 m temperature trend", side = 3, line = 0.3, adj = 0,
      cex = 0.7, font = 2, col = ink)
mtext(sprintf("%d of %d cells are holdouts (outlined). Dronning Maud Land warming is not in the station records",
              sum(h), nrow(an)), side = 1, line = 0.2, adj = 0, cex = 0.55, col = ink)
mtext("(checks/era5_station_check.R); North Victoria Land warming is real but overstated by ERA5.",
      side = 1, line = 0.9, adj = 0, cex = 0.55, col = ink)

## 4-5. the rule
rule_panel <- function(xp, yp, cool, hl, title, note) {
  par(mar = c(3.6, 3.8, 1.8, 1))
  plot(NA, xlim = c(0, 1), ylim = c(-0.14, 1), xaxs = "i", yaxs = "i", axes = FALSE,
       xlab = "", ylab = "")
  rect(0, 0, 0.25, 0.25, col = "#dfe9f7", border = NA)
  if (any(cool)) rect(0, -0.14, 0.25, -0.02, col = "#dfe9f7", border = NA)
  abline(v = 0.25, h = 0.25, col = muted, lwd = 0.6, lty = 2)
  axis(1, at = c(0, 0.25, 0.5, 0.75, 1), cex.axis = 0.65, col = muted, col.axis = ink, lwd = 0.6)
  axis(2, at = c(0, 0.25, 0.5, 0.75, 1), cex.axis = 0.65, col = muted, col.axis = ink, lwd = 0.6, las = 1)
  if (any(cool)) axis(2, at = -0.08, labels = "cooling", cex.axis = 0.6, col = NA, col.axis = ink, las = 1)
  y <- yp; y[cool] <- stats::runif(sum(cool), -0.13, -0.03)
  points(xp[!hl], y[!hl], pch = 16, cex = 0.35, col = "#c3c2bd")
  points(xp[hl], y[hl], pch = 16, cex = 0.4, col = "#2a78d6")
  title(xlab = "trend percentile within region", line = 2.2, cex.lab = 0.7, col.lab = ink)
  title(ylab = "velocity percentile within region", line = 2.6, cex.lab = 0.7, col.lab = ink)
  mtext(title, side = 3, line = 0.4, adj = 0, cex = 0.7, font = 2, col = ink)
  mtext(note, side = 1, line = 3.1, adj = 0, cex = 0.5, col = ink)
}
set.seed(1)
rule_panel(au$slope_decade_tmax_pct, au$velocity_km_decade_tmax_pct, rep(FALSE, nrow(au)),
           au$thermal_candidate %in% TRUE, "Australia: the rule (IBRA7 regions, S2 level 10)",
           "Ranks the size of the Tmax trend; almost every cell warms, so no cooling strip.")
cool <- an$slope_decade_t <= 0
rule_panel(an$warming_pct_acbr, ifelse(cool, NA, an$warm_velocity_pct_acbr), cool, h,
           "Antarctica: the rule (ACBR v2 regions, S2 level 9)",
           "Cooling cells in the lowest quarter pass on trend alone (strip below the axis).")

mtext("Holdout rule, both domains: warming trend in the lowest quarter of its region, and cooling or the slowest quarter of warming velocity",
      side = 3, outer = TRUE, line = 2.2, adj = 0.02, cex = 0.8, font = 2, col = ink)
par(fig = c(0, 1, 0, 1), new = TRUE, mar = c(0, 0, 0, 0)); plot.new()
legend("top", inset = c(0, 0.022), xpd = NA, horiz = TRUE, bty = "n", pch = 15, pt.cex = 1.3,
       col = pal, legend = paste(lab, "deg C per decade"), cex = 0.6, text.col = ink)
invisible(dev.off())
cat("wrote", of, "\n")
cat(sprintf("Australia: %d cells, %d holdouts, %d cooling; Antarctica: %d cells, %d holdouts, %d cooling\n",
            nrow(au), sum(au$thermal_candidate, na.rm = TRUE), sum(au$slope_decade_tmax < 0, na.rm = TRUE),
            nrow(an), sum(h), sum(cool)))
