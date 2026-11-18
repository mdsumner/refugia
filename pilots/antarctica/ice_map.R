## Maps of sea ice season trend and candidate refugia (S2 level 9 cells).
##
## Rscript pilots/antarctica/ice_map.R <ice_out_dir>
##
## Left: daycount trend (days with ice per decade, 1979-2025), red for loss,
## blue for gain, grey midpoint. Right: candidate holdout cells over the
## seasonal ice zone. South polar stereographic (EPSG:3031); sector
## boundaries as radial lines. Land and the perennial pack are blank.

Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data"
o <- readRDS(file.path(dir, "ice_exposure_L9.rds"))
xy <- terra::project(cbind(o$lon, o$lat), from = "EPSG:4326", to = "EPSG:3031")
o$x <- xy[, 1] / 1000; o$y <- xy[, 2] / 1000
z <- o[o$seasonal_zone %in% TRUE, ]

ink <- "#52514e"; land <- "#e4e3df"
brk <- c(-Inf, -15, -8, -4, -1, 1, 4, 8, 15, Inf)
pal <- c("#9b2a29", "#c13a39", "#e34948", "#efa3a1", "#f0efec", "#9ec5f4", "#5598e7", "#256abf", "#104281")
lab <- c("< -15", "-15 to -8", "-8 to -4", "-4 to -1", "-1 to 1", "1 to 4", "4 to 8", "8 to 15", "> 15")
cls <- cut(z$slope_decade_daycount, brk, labels = FALSE)

sector_lines <- function() {
  for (lon in c(-60, 20, 90, 160, -130)) {
    p <- terra::project(cbind(lon, c(-60, -50)), from = "EPSG:4326", to = "EPSG:3031") / 1000
    q <- terra::project(cbind(lon, c(-75, -60)), from = "EPSG:4326", to = "EPSG:3031") / 1000
    segments(q[1, 1], q[1, 2], p[2, 1], p[2, 2], col = ink, lwd = 0.6, lty = 2)
  }
  lp <- data.frame(name = c("Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen"),
                   lon = c(-20, 55, 125, -165, -95))
  t <- terra::project(cbind(lp$lon, -52.5), from = "EPSG:4326", to = "EPSG:3031") / 1000
  text(t[, 1], t[, 2], lp$name, cex = 0.7, col = "#0b0b0b")
}
lim <- c(-4600, 4600)
of <- file.path(dir, "ice_candidates_map.png")
png(of, width = 2400, height = 1300, res = 200)
op <- par(mfrow = c(1, 2), mar = c(3.5, 0.5, 2.6, 0.5), bg = "#fcfcfb")
plot(z$x, z$y, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", xlim = lim, ylim = lim)
points(z$x, z$y, pch = 15, cex = 0.2, col = pal[cls])
sector_lines()
mtext("Days with sea ice, trend per decade, 1979-2025", side = 3, line = 0.8, adj = 0, cex = 0.8, font = 2)
legend("bottom", inset = c(0, -0.09), xpd = NA, horiz = TRUE, bty = "n", pch = 15, pt.cex = 1.3,
       col = pal, legend = lab, cex = 0.5, text.col = ink, x.intersp = 1.1, text.width = 650)
plot(z$x, z$y, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", xlim = lim, ylim = lim)
points(z$x, z$y, pch = 15, cex = 0.2, col = land)
r <- z$ice_refugium
points(z$x[r], z$y[r], pch = 15, cex = 0.25, col = "#2a78d6")
sector_lines()
mtext(sprintf("Candidate sea ice holdouts: %s cells", format(sum(r), big.mark = ",")),
      side = 3, line = 0.8, adj = 0, cex = 0.8, font = 2)
mtext(paste("Top quarter of the sector's daycount trend, ice season in 90% of years, no loss or slow loss.",
            "Grey: seasonal ice zone (mean 30-335 ice days)."), side = 1, line = 1.2, cex = 0.5, col = ink, adj = 0)
par(op); dev.off()
cat("wrote", of, "\n")
