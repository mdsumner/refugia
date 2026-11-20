## Antarctic Ecosystem Inventory per S2 level 13 cell: ice-free comparison and
## habitat make-up of the land holdout candidates.
##
## Rscript pilots/antarctica/aei_summary.R <aei_dir> <era5_out_dir> <outdir>
##
## <aei_dir> holds aei_tier{1,2,3}_*_L13.csv.gz from gadi/aei_cells.R (and,
## when present, aei_<tier>_classes.csv with class names);
## <era5_out_dir> holds icefree_exposure_L13.rds and era5_exposure_L9.rds
## (with acbr from acbr_score.R).
##
## 1. Ice-free area per ACBR: inventory (Tier 1 area) against rock outcrop
##    v7.3, and the cells each has that the other lacks. Inventory cells take
##    the ACBR of their level 9 parent where that parent holds outcrop.
## 2. Habitat make-up (Tier 2): share of inventory area in each habitat over
##    all ice-free cells and over the land holdout candidates (scored within
##    ACBR), and the ratio of the two (enrichment), within each ACBR and
##    overall. Habitat class numbers are labelled from the class table when
##    available.
## 3. Per cell: number of Tier 2 habitats and Tier 3 ecosystems present.

a <- commandArgs(TRUE)
aei <- if (length(a) > 0) a[1] else "data/aei"
e5 <- if (length(a) > 1) a[2] else "data/era5_out"
outdir <- if (length(a) > 2) a[3] else "data/aei_out"
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
rd <- function(n) utils::read.csv(file.path(aei, n), stringsAsFactors = FALSE)
t1 <- rd("aei_tier1_meu_L13.csv.gz"); t2 <- rd("aei_tier2_habitat_L13.csv.gz"); t3 <- rd("aei_tier3_ecosystem_L13.csv.gz")
lab <- function(tier, cls) {
  f <- file.path(aei, sprintf("aei_%s_classes.csv", tier))
  if (!file.exists(f)) return(as.character(cls))
  ct <- utils::read.csv(f, stringsAsFactors = FALSE)
  nm <- ct[[2]][match(cls, ct[[1]])]
  ifelse(is.na(nm), as.character(cls), paste(cls, nm))
}

c13 <- readRDS(file.path(e5, "icefree_exposure_L13.rds"))
o9 <- readRDS(file.path(e5, "era5_exposure_L9.rds"))
cand_col <- if ("land_refugium_acbr" %in% names(c13)) "land_refugium_acbr" else "land_refugium"

## 1. ice-free comparison
A <- tapply(t1$area_km2, t1$cell, sum)
cells <- data.frame(cell = names(A), aei_km2 = as.vector(A))
cells <- merge(cells, c13[c("cell", "rock_km2", "acbr", cand_col)], by = "cell", all = TRUE)
cells$aei_km2[is.na(cells$aei_km2)] <- 0
cells$rock_km2[is.na(cells$rock_km2)] <- 0
p9 <- as.character(s2::s2_cell_parent(s2::as_s2_cell(cells$cell), 9L))
miss <- is.na(cells$acbr)
cells$acbr[miss] <- o9$acbr[match(p9[miss], o9$cell)]
cells$acbr[is.na(cells$acbr)] <- "(none)"
cells$cand <- cells[[cand_col]] %in% TRUE
cmp <- do.call(rbind, lapply(c(sort(unique(cells$acbr)), "all"), function(r) {
  x <- if (r == "all") cells else cells[cells$acbr == r, ]
  data.frame(acbr = r, aei_km2 = round(sum(x$aei_km2)), rock_v73_km2 = round(sum(x$rock_km2)),
             ratio = round(sum(x$aei_km2) / sum(x$rock_km2), 2),
             cells_both = sum(x$aei_km2 > 0 & x$rock_km2 > 0),
             cells_aei_only = sum(x$aei_km2 > 0 & x$rock_km2 == 0),
             aei_only_km2 = round(sum(x$aei_km2[x$rock_km2 == 0])),
             cells_rock_only = sum(x$aei_km2 == 0 & x$rock_km2 > 0),
             rock_only_km2 = round(sum(x$rock_km2[x$aei_km2 == 0])))
}))
print(cmp, row.names = FALSE)
utils::write.csv(cmp, file.path(outdir, "aei_vs_rock_by_acbr.csv"), row.names = FALSE)

## 2. habitat make-up, all ice-free vs candidates
t2$acbr <- cells$acbr[match(t2$cell, cells$cell)]
t2$cand <- cells$cand[match(t2$cell, cells$cell)] %in% TRUE
comp <- function(x) {
  all <- tapply(x$area_km2, x$class, sum)
  cn <- tapply(x$area_km2[x$cand], factor(x$class[x$cand], levels = names(all)), sum)
  cn[is.na(cn)] <- 0
  data.frame(habitat = lab("tier2_habitat", as.integer(names(all))), area_km2 = round(as.vector(all), 1),
             share = round(as.vector(all) / sum(all), 4),
             cand_km2 = round(as.vector(cn), 1), cand_share = round(as.vector(cn) / max(sum(cn), 1e-9), 4),
             enrichment = round((as.vector(cn) / max(sum(cn), 1e-9)) / (as.vector(all) / sum(all)), 2))
}
hab <- comp(t2); hab <- hab[order(-hab$area_km2), ]
utils::write.csv(hab, file.path(outdir, "aei_habitat_candidates_all.csv"), row.names = FALSE)
cat("\nTier 2 habitats, all ACBRs (top 15 by area):\n"); print(utils::head(hab, 15), row.names = FALSE)
byr <- do.call(rbind, lapply(sort(setdiff(unique(t2$acbr), c("(none)", NA))), function(r)
  cbind(acbr = r, comp(t2[t2$acbr %in% r, ]))))
utils::write.csv(byr, file.path(outdir, "aei_habitat_candidates_by_acbr.csv"), row.names = FALSE)

## 3. habitat and ecosystem richness per cell
rich <- merge(stats::aggregate(class ~ cell, t2, function(v) length(unique(v))),
              stats::aggregate(class ~ cell, t3, function(v) length(unique(v))), by = "cell", all = TRUE)
names(rich) <- c("cell", "n_habitats", "n_ecosystems")
rich <- merge(rich, cells[c("cell", "aei_km2", "rock_km2", "acbr", "cand")], by = "cell", all.x = TRUE)
utils::write.csv(rich, gzfile(file.path(outdir, "aei_cells_L13.csv.gz")), row.names = FALSE)
cat(sprintf("\nmean habitats per cell: candidates %.2f, other ice-free cells %.2f\n",
            mean(rich$n_habitats[rich$cand %in% TRUE], na.rm = TRUE),
            mean(rich$n_habitats[!(rich$cand %in% TRUE)], na.rm = TRUE)))
