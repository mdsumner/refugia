## Combine the per region-var-year AGCD cell sums into one compact file per
## variable, small enough to bring back via git, rsync or an upload.
##
## Rscript gadi/agcd_combine.R <indir> <outdir>
##
## Also prints a check table: files per variable and region, year range, and
## the domain mean of the daily values for the first and last year.
a <- commandArgs(TRUE)
indir <- if (length(a) > 0) a[1] else file.path("/g/data/jk72", Sys.getenv("USER"), "refugia/agcd_L10")
outdir <- if (length(a) > 1) a[2] else indir
f <- list.files(indir, "^agcd_.*_L10[.]rds$", full.names = TRUE)
x <- do.call(rbind, lapply(f, function(p) readRDS(p)[c("cell", "region", "var", "year", "npix", "pixdays", "sum", "sumsq", "days")]))
for (v in unique(x$var)) {
  d <- x[x$var == v, ]
  out <- file.path(outdir, sprintf("agcd_%s_L10_all.rds", v))
  saveRDS(d, out, compress = "xz")
  cat(v, nrow(d), "rows ->", out, round(file.size(out) / 1e6, 1), "MB\n")
}
chk <- do.call(rbind, lapply(split(x, list(x$var, x$region), drop = TRUE), function(d) {
  y0 <- min(d$year); y1 <- max(d$year)
  data.frame(var = d$var[1], region = d$region[1], years = length(unique(d$year)), first = y0, last = y1,
             mean_first = sum(d$sum[d$year == y0]) / sum(d$pixdays[d$year == y0]),
             mean_last = sum(d$sum[d$year == y1]) / sum(d$pixdays[d$year == y1]))
}))
print(chk, row.names = FALSE, digits = 4)
