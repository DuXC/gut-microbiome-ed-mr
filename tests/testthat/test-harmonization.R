project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "gwas_schema.R"))
source(file.path(project_root, "R", "exposure_candidates.R"))
source(file.path(project_root, "R", "harmonization.R"))

instrument_fixture <- function(ea = "A", oa = "G", eaf = 0.2) {
  data.frame(
    reference_id = "rs1", chr = "1", pos = 10, ea = ea, oa = oa,
    beta = 0.2, se = 0.1, eaf = eaf, p = 0.01, n = 1000,
    build = "GRCh37", source_id = "GCST1", trait = "trait",
    dataset = "microbiome_2026", F = 4, tier = "exploratory",
    stringsAsFactors = FALSE
  )
}

outcome_fixture <- function(
  ea = "A", oa = "G", beta = 0.3, eaf = 0.2, rsid = "rs1"
) {
  data.frame(
    outcome_id = "outcome", ancestry = "EUR", build = "GRCh38",
    rsid = rsid, chr = "1", pos = 11, ea = ea, oa = oa,
    beta = beta, se = 0.1, p = 0.01, eaf = eaf,
    effect_scale = "log_odds", analysis_role = "primary_outcome",
    stringsAsFactors = FALSE
  )
}

test_that("non-palindromic swaps flip the outcome association", {
  result <- harmonise_one_outcome(
    instrument_fixture(), outcome_fixture(ea = "G", oa = "A")
  )
  expect_equal(nrow(result$harmonised), 1)
  expect_equal(result$harmonised$allele_relation, "swapped")
  expect_equal(result$harmonised$beta_outcome_harmonised, -0.3)
  expect_equal(result$audit$harmonisation_status, "harmonised")
})

test_that("strand complements harmonise without mixing coordinates", {
  result <- harmonise_one_outcome(
    instrument_fixture(), outcome_fixture(ea = "T", oa = "C")
  )
  expect_equal(result$harmonised$allele_relation, "strand_same")
  expect_equal(result$harmonised$beta_outcome_harmonised, 0.3)
  expect_equal(
    result$harmonised$matching_basis,
    "rsID_and_alleles_across_declared_builds"
  )
})

test_that("palindromic variants require informative concordant frequencies", {
  retained <- harmonise_one_outcome(
    instrument_fixture(ea = "A", oa = "T", eaf = 0.1),
    outcome_fixture(ea = "A", oa = "T", eaf = 0.12)
  )
  expect_equal(nrow(retained$harmonised), 1)
  expect_equal(
    retained$harmonised$allele_relation, "palindromic_frequency_same"
  )
  excluded <- harmonise_one_outcome(
    instrument_fixture(ea = "A", oa = "T", eaf = 0.49),
    outcome_fixture(ea = "A", oa = "T", eaf = 0.48)
  )
  expect_equal(nrow(excluded$harmonised), 0)
  expect_equal(excluded$audit$harmonisation_status, "palindromic_high_maf")
})

test_that("multiallelic outcome rows select the allele-compatible record", {
  outcome <- rbind(
    outcome_fixture(ea = "A", oa = "G", beta = 0.3),
    outcome_fixture(ea = "T", oa = "G", beta = 2)
  )
  result <- harmonise_one_outcome(instrument_fixture(), outcome)
  expect_equal(nrow(result$harmonised), 1)
  expect_equal(result$harmonised$beta_outcome_harmonised, 0.3)
  expect_equal(result$audit$matched_outcome_rows, 2)
  expect_equal(result$audit$allele_compatible_rows, 1)
})

test_that("missing rsIDs and allele mismatches remain explicit", {
  missing <- harmonise_one_outcome(
    instrument_fixture(), outcome_fixture(rsid = "rs2")
  )
  expect_equal(missing$audit$harmonisation_status, "outcome_rsid_missing")
  mismatch <- harmonise_one_outcome(
    instrument_fixture(), outcome_fixture(ea = "A", oa = "C")
  )
  expect_equal(mismatch$audit$harmonisation_status, "allele_mismatch")
})
