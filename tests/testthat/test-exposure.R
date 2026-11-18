test_that("cell_gradient recovers a planar field", {
  g <- list(extent = c(xmin = 146, xmax = 147, ymin = -42.5, ymax = -41.5),
            dimension = c(ncol = 40L, nrow = 40L), crs = "EPSG:4326")
  cells <- build_grid_mapping(g, level = 10L)$cells
  ctr <- s2::s2_cell_center(s2::as_s2_cell(cells))
  lon <- s2::s2_x(ctr); lat <- s2::s2_y(ctr)
  ## 0.01 units per km eastward
  z <- 0.01 * (lon - 146) * cos(-42 * pi / 180) * 111.195
  gr <- cell_gradient(cells, z)
  expect_lt(abs(stats::median(gr, na.rm = TRUE) - 0.01), 0.0005)
})

test_that("cell_trends matches lm per cell", {
  set.seed(2)
  a <- data.frame(cell = rep(c("a", "b"), each = 30), year = rep(1991:2020, 2))
  a$value <- ifelse(a$cell == "a", 0.03, -0.01) * a$year + rnorm(60)
  r <- cell_trends(a, 1991:2020)
  fa <- coef(lm(value ~ year, a[a$cell == "a", ]))[2]
  expect_equal(r$slope_decade[1], unname(fa) * 10)
})
