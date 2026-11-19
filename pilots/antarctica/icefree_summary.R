## Ice-free land per S2 cell: summary by sector and a map.
##
## Rscript pilots/antarctica/icefree_summary.R <icefree_dir>
##
## <icefree_dir> holds icefree_L13.rds and icefree_L9.rds from
## sources/icefree_cells.R. Sectors as for sea ice and SST (by longitude),
## with the Antarctic Peninsula (north of 75S, 80W to 55W) split out of
## Bell-Amundsen and Weddell since it holds a large share of the outcrop.

Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data"
c13 <- readRDS(file.path(dir, "icefree_L13.rds"))
c9 <- readRDS(file.path(dir, "icefree_L9.rds"))

sector <- function(lon, lat) {
  s <- as.character(cut(lon, c(-180, -130, -60, 20, 90, 160, 180), include.lowest = TRUE,
                        labels = c("Ross", "Bell-Amundsen", "Weddell", "Indian", "W Pacific", "Ross2")))
  s[s == "Ross2"] <- "Ross"
  s[lon >= -80 & lon <= -55 & lat > -75] <- "Peninsula"
  s
}
c13$sector <- sector(c13$lon, c13$lat)
c9$sector <- sector(c9$lon, c9$lat)
lv <- c("Peninsula", "Weddell", "Indian", "W Pacific", "Ross", "Bell-Amundsen")
summ <- do.call(rbind, lapply(lv, function(s) {
  x <- c13[c13$sector == s, ]
  data.frame(sector = s, rock_km2 = round(sum(x$rock_km2)),
             share = round(sum(x$rock_km2) / sum(c13$rock_km2), 3),
             cells_L13 = nrow(x), cells_L13_half_icefree = sum(x$icefree_frac >= 0.5),
             cells_L9 = sum(c9$sector == s),
             median_frac_L13 = round(stats::median(x$icefree_frac), 2))
}))
print(summ, row.names = FALSE)
write.csv(summ, file.path(dir, "icefree_summary.csv"), row.names = FALSE)

xy <- terra::project(cbind(c9$lon, c9$lat), from = "EPSG:4326", to = "EPSG:3031") / 1000
brk <- c(0, 0.01, 0.05, 0.2, 0.5, 1.01)
pal <- c("#d9d4c7", "#b9ab8c", "#8f7a55", "#5e4b2c", "#2e2414")
lab <- c("< 1%", "1-5%", "5-20%", "20-50%", "> 50%")
of <- file.path(dir, "icefree_map.png")
png(of, width = 1400, height = 1400, res = 200)
op <- par(mar = c(2.5, 0.5, 2.2, 0.5), bg = "#fcfcfb")
plot(xy, type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", xlim = c(-2800, 2800), ylim = c(-2600, 2500))
o <- order(c9$icefree_frac)
points(xy[o, ], pch = 15, cex = 0.35, col = pal[cut(c9$icefree_frac[o], brk, labels = FALSE, right = FALSE)])
mtext(sprintf("Rock outcrop v7.3 share of each level 9 cell (%s km2 in all)",
              format(round(sum(c13$rock_km2)), big.mark = ",")), side = 3, line = 0.6, adj = 0, cex = 0.8, font = 2)
legend("bottom", inset = c(0, -0.06), xpd = NA, horiz = TRUE, bty = "n", pch = 15, pt.cex = 1.3,
       col = pal, legend = lab, cex = 0.6, text.col = "#52514e")
par(op); invisible(dev.off())
cat("wrote", of, "\n")
