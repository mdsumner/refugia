## Maps of summer SST trend and candidate SST holdouts south of 60S (level 9).
##
## Rscript pilots/antarctica/sst_map.R <sst_out_dir>
##
## Left: Jan-Mar open-water SST trend (deg C per decade), blue for cooling, red for
## warming. Right: candidate holdouts over the summer open-water zone.
## South polar stereographic (EPSG:3031), sector boundaries as dashed lines.

Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data"
o <- readRDS(file.path(dir, "sst_exposure_L9.rds"))
xy <- terra::project(cbind(o$lon, o$lat), from = "EPSG:4326", to = "EPSG:3031")
o$x <- xy[, 1] / 1000; o$y <- xy[, 2] / 1000
z <- o[o$summer_open_zone %in% TRUE, ]

ink <- "#52514e"; land <- "#e4e3df"
brk <- c(-Inf, -0.3, -0.15, -0.05, 0.05, 0.15, 0.3, Inf)
pal <- c("#104281", "#5598e7", "#9ec5f4", "#f0efec", "#efa3a1", "#e34948", "#9b2a29")
lab <- c("< -0.3", "-0.3 to -0.15", "-0.15 to -0.05", "-0.05 to 0.05", "0.05 to 0.15", "0.15 to 0.3", "> 0.3")
cls <- cut(z$slope_decade_jfm, brk, labels = FALSE)

sector_lines <- function() {
  for (lon in c(-60, 20, 90, 160, -130)) {
    p <- terra::project(cbind(lon, c(-60, -60)), from = "EPSG:4326", to = "EPSG:3031") / 1000
    q <- terra::project(cbind(lon, c(-75, -75)), from = "EPSG:4326", to = "EPSG:3031") / 1000
    segments(q[1, 1], q[1, 2], p[1, 1], p[1, 2], col = ink, lwd = 0.6, lty = 2)
  }
  lp <- data.frame(name = c("Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen"),
                   lon = c(-20, 55, 125, -165, -95))
  t <- terra::project(cbind(lp$lon, -58), from = "EPSG:4326", to = "EPSG:3031") / 1000
  text(t[, 1], t[, 2], lp$name, cex = 0.7, col = "#0b0b0b")
}
lim <- c(-3700, 3700)
of <- file.path(dir, "sst_candidates_map.png")
png(of, width = 2400, height = 1300, res = 200)
op <- par(mfrow = c(1, 2), mar = c(3.5, 0.5, 2.6, 0.5), bg = "#fcfcfb")
plot(z$x, z$y, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", xlim = lim, ylim = lim)
points(o$x, o$y, pch = 15, cex = 0.2, col = land)
points(z$x, z$y, pch = 15, cex = 0.2, col = pal[cls])
sector_lines()
mtext(sprintf("Summer (Jan-Mar, open water) SST, trend per decade (deg C), %d-%d", 1982, 2025),
      side = 3, line = 0.8, adj = 0, cex = 0.8, font = 2)
legend("bottom", inset = c(0, -0.09), xpd = NA, horiz = TRUE, bty = "n", pch = 15, pt.cex = 1.3,
       col = pal, legend = lab, cex = 0.5, text.col = ink, x.intersp = 1.1, text.width = 820)
plot(z$x, z$y, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", xlim = lim, ylim = lim)
points(z$x, z$y, pch = 15, cex = 0.2, col = land)
r <- z$sst_refugium
points(z$x[r], z$y[r], pch = 15, cex = 0.25, col = "#2a78d6")
sector_lines()
mtext(sprintf("Candidate SST holdouts: %s cells", format(sum(r), big.mark = ",")),
      side = 3, line = 0.8, adj = 0, cex = 0.8, font = 2)
mtext("Lowest quarter of the sector's summer SST trend, and cooling or slow warming.",
      side = 1, line = 0.6, cex = 0.5, col = ink, adj = 0)
mtext("Grey: open water in summer (Jan-Mar ice share < 0.5). Left, grey beyond the colours: summer ice.",
      side = 1, line = 1.4, cex = 0.5, col = ink, adj = 0)
par(op); invisible(dev.off())
cat("wrote", of, "\n")
