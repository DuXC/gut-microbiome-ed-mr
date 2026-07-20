project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "exposure_candidates.R"))
source(file.path(project_root, "R", "multiplicity.R"))

test_that("frozen denominator retains non-estimable eligible pairs", {
  registry <- data.frame(
    pair_id = c("a", "b", "c"),
    outcome_id = "finngen_r12_erectile_dysfunction",
    dataset = "microbiome_2026", source_id = c("s1", "s2", "s3"),
    trait = c("t1", "t2", "t3"), tier = "primary",
    requested_instrument_rows = c(1, 1, 1), harmonised_snps = c(1, 0, 1),
    stringsAsFactors = FALSE
  )
  estimates <- data.frame(
    pair_id = c("a", "c"), method = c("mr_wald_ratio", "mr_ivw_mre"),
    nsnp = c(1, 2), beta = c(0.1, 0.2), se = c(0.1, 0.1),
    ci_lower = c(-0.1, 0), ci_upper = c(0.3, 0.4), p = c(0.01, 0.2),
    exponentiable = TRUE, or = c(1.1, 1.2), or_ci_lower = c(0.9, 1),
    or_ci_upper = c(1.3, 1.5), mean_F = 20, min_F = 20,
    analysis_status = "estimated", error_message = "", warning_message = "",
    stringsAsFactors = FALSE
  )
  result <- freeze_forward_primary_family(registry, estimates)
  expect_equal(unique(result$n_forward), 3)
  expect_equal(result$q[result$pair_id == "a"], p.adjust(0.01, "BH", n = 3))
  expect_true(is.na(result$q[result$pair_id == "b"]))
  expect_equal(
    result$analysis_status[result$pair_id == "b"], "not_estimable"
  )
  expect_true(all(result$eligibility_frozen))
})

test_that("unfrozen exploratory and validation rows cannot enter the family", {
  registry <- data.frame(
    pair_id = c("primary", "exploratory", "validation"),
    outcome_id = "finngen_r12_erectile_dysfunction",
    dataset = c("microbiome_2026", "microbiome_2026", "microbiome_2026_hunt"),
    source_id = c("s1", "s2", "s3"), trait = c("t1", "t2", "t3"),
    tier = c("primary", "exploratory", "primary"),
    requested_instrument_rows = 1, harmonised_snps = 1,
    stringsAsFactors = FALSE
  )
  estimates <- data.frame(
    pair_id = registry$pair_id, method = "mr_wald_ratio", nsnp = 1,
    beta = 0.1, se = 0.1, ci_lower = -0.1, ci_upper = 0.3, p = 0.01,
    exponentiable = TRUE, or = 1.1, or_ci_lower = 0.9, or_ci_upper = 1.3,
    mean_F = 20, min_F = 20, analysis_status = "estimated",
    error_message = "", warning_message = "", stringsAsFactors = FALSE
  )
  result <- freeze_forward_primary_family(registry, estimates)
  expect_equal(result$pair_id, "primary")
  expect_equal(result$family, "forward_primary")
})

test_that("invalid P values remain unavailable", {
  expect_equal(adjust_with_frozen_denominator(c(0.01, NA), 3), c(0.03, NA))
  expect_error(adjust_with_frozen_denominator(0.1, 0), "denominator")
})
