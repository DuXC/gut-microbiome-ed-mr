project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "gwas_schema.R"))
source(file.path(project_root, "R", "exposure_candidates.R"))
source(file.path(project_root, "R", "harmonization.R"))
source(file.path(project_root, "R", "reverse_analysis.R"))

test_that("reverse harmonisation aligns microbial outcome effects", {
  exposure <- data.frame(
    reference_id = c("rs1", "rs2"), chr = c("1", "2"), pos = c(10, 20),
    ea = c("A", "A"), oa = c("G", "T"), beta = c(0.1, 0.2),
    se = c(0.01, 0.02), eaf = c(NA, NA), p = c(1e-9, 1e-10),
    n = c(100, 100), build = "GRCh38", F = c(100, 100),
    stringsAsFactors = FALSE
  )
  outcome <- data.frame(
    snp = c("rs1", "rs2"), variant_id = NA_character_,
    variant_key = c("1:11:G:A", "2:21:T:A"), chr = c("1", "2"),
    pos = c(11, 21), ea = c("G", "A"), oa = c("A", "T"),
    beta = c(0.3, 0.4), se = c(0.1, 0.1), z = NA_real_,
    eaf = c(0.7, 0.2), p = c(0.01, 0.01), n = c(1000, 1000),
    build = "GRCh37", ancestry = "EUR", role = "outcome",
    source_id = "microbe", trait = "microbe trait", stringsAsFactors = FALSE
  )
  metadata <- data.frame(
    source_id = "microbe", trait = "microbe trait",
    canonical_trait_id = "taxon:microbe", stringsAsFactors = FALSE
  )
  result <- harmonise_reverse_pair(exposure, outcome, metadata)
  expect_equal(nrow(result$harmonised), 1)
  expect_equal(result$harmonised$reference_id, "rs1")
  expect_equal(result$harmonised$beta_outcome_harmonised, -0.3)
  expect_equal(result$audit$palindromic_excluded, 1)
})
