test_that("DEA tile grid matches the published tile extents", {
  g <- dea_tile_grid(46, 45)
  expect_equal(unname(g$extent), c(0, 96000, -2592000, -2496000))
  g <- dea_tile_grid(40, 34)
  expect_equal(unname(g$extent), c(-576000, -480000, -3648000, -3552000))
  expect_equal(unname(g$dimension), c(3200, 3200))
})

test_that("sum_to_cells adds values by run index and ignores NA", {
  m <- list(runs = data.frame(row = c(1L, 1L, 2L), start = c(1L, 3L, 1L),
                              end = c(2L, 4L, 4L), cell = c(1L, 2L, 1L)),
            cells = c("a", "b"),
            grid = list(dimension = c(ncol = 4L, nrow = 2L)))
  expect_equal(mapping_index(m), c(1L, 1L, 2L, 2L, 1L, 1L, 1L, 1L))
  v <- c(1, 2, 3, NA, 5, 6, 7, 8)
  s <- sum_to_cells(m, v = v)
  expect_equal(s$v, c(1 + 2 + 5 + 6 + 7 + 8, 3))
  expect_equal(s$n, c(6L, 1L))
})

test_that("grid mapping on a small lon/lat grid puts each pixel centre in its cell", {
  g <- list(extent = c(xmin = 147, xmax = 147.5, ymin = -42.5, ymax = -42),
            dimension = c(ncol = 10L, nrow = 10L), crs = "EPSG:4326")
  m <- build_grid_mapping(g, level = 10L)
  idx <- mapping_index(m)
  expect_length(idx, 100L)
  xc <- rep(147 + (1:10 - 0.5) * 0.05, 10); yc <- rep(-42 - (1:10 - 0.5) * 0.05, each = 10)
  direct <- as.character(s2::s2_cell_parent(s2::as_s2_cell(s2::s2_lnglat(xc, yc)), 10L))
  expect_equal(m$cells[idx], direct)
})
