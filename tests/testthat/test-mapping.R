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
