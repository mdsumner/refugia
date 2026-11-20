## Map of summer air temperature trend and candidate land holdouts on
## Antarctic ice-free land (level 9).
##
## Rscript pilots/antarctica/era5_map.R <era5_out_dir>
##
## Left: DJF 2 m temperature trend (deg C per decade) on level 9 cells that
## hold ice-free rock. Right: candidate land holdouts, sized by rock area.
## South polar stereographic (EPSG:3031).

Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data"
o <- readRDS(file.path(dir, "era5_exposure_L9.rds"))
xy <- terra::project(cbind(o$lon, o$lat), from = "EPSG:4326", to = "EPSG:3031")
o$x <- xy[, 1] / 1000; o$y <- xy[, 2] / 1000
z <- o[o$icefree %in% TRUE, ]
yr <- range(utils::read.csv(file.path(dir, "era5_gate_by_summer.csv"))$summer)

ink <- "#52514e"; land <- "#e4e3df"
brk <- c(-Inf, -0.3, -0.15, -0.05, 0.05, 0.15, 0.3, Inf)
pal <- c("#104281", "#5598e7", "#9ec5f4", "#f0efec", "#efa3a1", "#e34948", "#9b2a29")
lab <- c("< -0.3", "-0.3 to -0.15", "-0.15 to -0.05", "-0.05 to 0.05", "0.05 to 0.15", "0.15 to 0.3", "> 0.3")
cls <- cut(z$slope_decade_t, brk, labels = FALSE)
cx <- 0.25 + 0.9 * sqrt(z$rock_km2 / max(z$rock_km2))
sector_lines <- function() {
  for (lon in c(-60, 20, 90, 160, -130)) {
    p <- terra::project(cbind(lon, c(-62, -90)), from = "EPSG:4326", to = "EPSG:3031") / 1000
    segments(p[2, 1], p[2, 2], p[1, 1], p[1, 2], col = ink, lwd = 0.4, lty = 3)
  }
}
## coast proxy: every ERA5 level 9 cell colder than -2 deg C in summer (the ice sheet), light grey
ice <- o[o$clim_t < -2 & o$lat < -63, ]
lim <- c(-2900, 2900)
of <- file.path(dir, "era5_icefree_map.png")
png(of, width = 2400, height = 1300, res = 200)
op <- par(mfrow = c(1, 2), mar = c(3.5, 0.5, 2.6, 0.5), bg = "#fcfcfb")
plot(z$x, z$y, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", xlim = lim, ylim = lim)
points(ice$x, ice$y, pch = 15, cex = 0.15, col = land)
sector_lines()
points(z$x, z$y, pch = 16, cex = cx, col = pal[cls])
mtext(sprintf("Ice-free land: summer (DJF) 2 m temperature trend per decade (deg C), %d-%d", yr[1], yr[2]),
      side = 3, line = 0.8, adj = 0, cex = 0.75, font = 2)
legend("bottom", inset = c(0, -0.09), xpd = NA, horiz = TRUE, bty = "n", pch = 16, pt.cex = 1.2,
       col = pal, legend = lab, cex = 0.5, text.col = ink, x.intersp = 1.1, text.width = 640)
plot(z$x, z$y, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", xlim = lim, ylim = lim)
points(ice$x, ice$y, pch = 15, cex = 0.15, col = land)
sector_lines()
r <- z$land_refugium
points(z$x[!r], z$y[!r], pch = 16, cex = cx[!r], col = "#c3c2bd")
points(z$x[r], z$y[r], pch = 16, cex = cx[r], col = "#2a78d6")
mtext(sprintf("Candidate land holdouts: %s of %s cells", format(sum(r), big.mark = ","),
              format(nrow(z), big.mark = ",")), side = 3, line = 0.8, adj = 0, cex = 0.75, font = 2)
mtext("Lowest quarter of the sector's summer warming, and cooling or slow warming velocity. Size: rock area.",
      side = 1, line = 0.6, cex = 0.5, col = ink, adj = 0)
mtext("ERA5 0.25 deg: regional summer climate over each oasis, not the rock surface.",
      side = 1, line = 1.4, cex = 0.5, col = ink, adj = 0)
par(op); invisible(dev.off())
cat("wrote", of, "\n")
