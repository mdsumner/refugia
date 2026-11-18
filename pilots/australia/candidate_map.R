## Small-multiple maps of refugium candidates per pilot region.
##
## Rscript pilots/australia/candidate_map.R <dir> [outdir]
##
## One row per pilot region, one panel per kind (water, green cover, thermal)
## plus a panel for cells flagged by two or more kinds. Each panel shows one
## colour on grey land, so no colour mixing is needed. Water panels also show
## cells whose persistent water is all mapped artificial water, in muted ink.
## Cells are drawn as squares at their centres in EPSG:3577.

Sys.setenv(PROJ_NETWORK = "OFF")
a <- commandArgs(TRUE)
dir <- if (length(a) > 0) a[1] else "data"
outdir <- if (length(a) > 1) a[2] else dir
d <- readRDS(file.path(dir, "refugia_candidates_L13.rds"))
ibra <- terra::project(terra::vect("regions/ibra7/ibra7_regions_pilot.geojson"), "EPSG:3577")
xy <- terra::project(cbind(d$lon, d$lat), from = "EPSG:4326", to = "EPSG:3577")
d$x <- xy[, 1]; d$y <- xy[, 2]
d$region <- ifelse(d$ibra == "MAC", "MacDonnell Ranges (MAC)", "Tasmania (9 IBRA regions)")

col <- c(land = "#e4e3df", ink = "#52514e", muted = "#a3a29c",
         water = "#2a78d6", green = "#eb6834", thermal = "#1baf7a", multi = "#0b0b0b")
panels <- list(
  list(title = "Persistent natural water", sel = "water_refugium", col = col[["water"]]),
  list(title = "Green cover held in dry years", sel = "green_refugium", col = col[["green"]]),
  list(title = "Low warming and low velocity", sel = "thermal_refugium", col = col[["thermal"]]),
  list(title = "Two or more kinds", sel = "multi", col = col[["multi"]]))
d$multi <- d$n_kinds >= 2

of <- file.path(outdir, "refugia_candidates_map.png")
png(of, width = 2400, height = 1500, res = 200)
op <- par(mfrow = c(2, 4), mar = c(0.5, 0.5, 2.8, 0.5), oma = c(2.2, 0, 0.5, 0), bg = "#fcfcfb")
for (reg in c("Tasmania (9 IBRA regions)", "MacDonnell Ranges (MAC)")) {
  r <- d[d$region == reg, ]
  ib <- ibra[ibra$REG_CODE_7 %in% unique(r$ibra)]
  ## square symbol sized to about 1 km at the plotted scale
  for (p in panels) {
    plot(range(r$x), range(r$y), type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "")
    points(r$x, r$y, pch = 15, cex = 0.18, col = col[["land"]])
    if (p$sel == "water_refugium") {
      s <- r$water_artificial
      points(r$x[s], r$y[s], pch = 15, cex = 0.3, col = col[["muted"]])
    }
    s <- r[[p$sel]]
    used <- p$sel != "green_refugium" || any(r$green_applies)
    points(r$x[s], r$y[s], pch = 15, cex = 0.3, col = if (used) p$col else col[["muted"]])
    terra::lines(ib, col = col[["ink"]], lwd = 0.4)
    mtext(sprintf("%s: %s cells%s", p$title, format(sum(s), big.mark = ","),
                  if (used) "" else " (not used here)"), side = 3,
          line = 0.4, cex = 0.62, col = "#0b0b0b", adj = 0)
    if (identical(p, panels[[1]])) mtext(reg, side = 3, line = 1.4, cex = 0.8, font = 2, adj = 0)
  }
}
mtext(paste("S2 level 13 cells (about 1 km). Grey: land cells in the region. Water panel, light grey:",
            "persistent water on mapped artificial water only. Lines: IBRA 7 regions."),
      side = 1, outer = TRUE, line = 0.8, cex = 0.55, col = col[["ink"]], adj = 0.01)
par(op); dev.off()
cat("wrote", of, "\n")
