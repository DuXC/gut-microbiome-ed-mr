project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "exposure_candidates.R"))
source(file.path(project_root, "R", "mr_core.R"))

mr_fixture <- function(n = 4L) {
  data.frame(
    beta_exposure = c(0.10, 0.20, 0.15, 0.11)[seq_len(n)],
    se_exposure = rep(0.01, n),
    beta_outcome_harmonised = c(0.03, 0.05, 0.06, 0.02)[seq_len(n)],
    se_outcome_harmonised = rep(0.02, n), F = rep(100, n),
    reference_id = paste0("rs", seq_len(n)), stringsAsFactors = FALSE
  )
}

mr_meta_fixture <- function(effect_scale = "log_odds") {
  list(
    pair_id = "outcome|dataset|source|primary", dataset = "dataset",
    source_id = "source", trait = "trait", tier = "primary",
    outcome_id = "outcome", outcome_ancestry = "EUR",
    analysis_role = "primary_outcome", effect_scale = effect_scale
  )
}

test_that("method selection follows instrument count", {
  expect_equal(mr_methods_for_n(0), "not_estimable")
  expect_equal(mr_methods_for_n(1), "mr_wald_ratio")
  expect_equal(
    mr_methods_for_n(4),
    c(
      "mr_ivw_mre", "mr_weighted_median", "mr_egger_regression", "mr_raps"
    )
  )
  expect_false(can_run_presso(3))
  expect_true(can_run_presso(4))
})

test_that("one SNP produces the standard Wald ratio", {
  result <- run_mr_pair(mr_fixture(1), mr_meta_fixture(), nboot = 20)
  expect_equal(result$estimates$method, "mr_wald_ratio")
  expect_equal(result$estimates$beta, 0.3)
  expect_equal(result$estimates$se, 0.2)
  expect_equal(result$estimates$analysis_status, "estimated")
  expect_equal(result$estimates$or, exp(0.3))
})

test_that("multi-SNP pairs retain primary and robust estimators", {
  result <- run_mr_pair(mr_fixture(4), mr_meta_fixture(), nboot = 50)
  expect_equal(nrow(result$estimates), 4)
  expect_equal(result$estimates$method[[1]], "mr_ivw_mre")
  expect_true(all(result$estimates$analysis_status == "estimated"))
  expect_true(is.finite(result$sensitivity$ivw_Q))
  expect_true(is.finite(result$sensitivity$egger_intercept_p))
  expect_equal(result$sensitivity$presso_status, "deferred_until_post_FDR")
})

test_that("IVW random-effects inference never benefits from underdispersion", {
  x <- mr_fixture(2)
  result <- mr_ivw_mre_constrained(
    x$beta_exposure, x$beta_outcome_harmonised,
    x$se_outcome_harmonised
  )
  fixed_se <- 1 / sqrt(sum(x$beta_exposure^2 / x$se_outcome_harmonised^2))
  expect_true(result$underdispersion_floor_applied)
  expect_equal(result$se, fixed_se)
})

test_that("two-SNP pairs report non-estimable robust methods explicitly", {
  result <- run_mr_pair(mr_fixture(2), mr_meta_fixture(), nboot = 20)
  statuses <- setNames(result$estimates$analysis_status, result$estimates$method)
  expect_equal(statuses[["mr_ivw_mre"]], "estimated")
  expect_equal(statuses[["mr_weighted_median"]], "not_estimable")
  expect_equal(statuses[["mr_egger_regression"]], "not_estimable")
})

test_that("standardized outcomes are never exponentiated as odds ratios", {
  result <- run_mr_pair(
    mr_fixture(1), mr_meta_fixture("standardized_z_per_sqrt_metal_weight"),
    nboot = 20
  )
  expect_false(result$estimates$exponentiable)
  expect_true(is.na(result$estimates$or))
})

test_that("zero-SNP pairs remain represented", {
  result <- run_mr_pair(data.frame(), mr_meta_fixture(), nboot = 20)
  expect_equal(result$estimates$analysis_status, "not_estimable")
  expect_equal(result$estimates$nsnp, 0)
  expect_equal(result$sensitivity$steiger_status, "not_estimable")
})

test_that("MR results are reproducible under pair-derived seeds", {
  first <- run_mr_pair(mr_fixture(4), mr_meta_fixture(), nboot = 30)
  second <- run_mr_pair(mr_fixture(4), mr_meta_fixture(), nboot = 30)
  expect_identical(first$estimates, second$estimates)
})
