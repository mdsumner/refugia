test_that("trend from sums matches lm", {
  set.seed(1)
  t <- 1981:2024
  x <- 0.02 * t + rnorm(length(t))
  fit <- lm(x ~ t)
  r <- trend_from_sums(trend_sums(t, x), span = diff(range(t)))
  expect_equal(r$slope, unname(coef(fit)[2]))
  expect_equal(r$intercept, unname(coef(fit)[1]))
  expect_equal(r$resid_sd, summary(fit)$sigma)
})

test_that("sums of disjoint sets add", {
  t <- 1:20; x <- sin(t)
  a <- trend_sums(t[1:10], x[1:10]); b <- trend_sums(t[11:20], x[11:20])
  expect_equal(a + b, trend_sums(t, x))
})
