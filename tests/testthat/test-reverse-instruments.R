project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "gwas_schema.R"))
source(file.path(project_root, "R", "exposure_candidates.R"))
source(file.path(project_root, "R", "instruments.R"))
source(file.path(project_root, "R", "outcomes.R"))
source(file.path(project_root, "R", "harmonization.R"))
source(file.path(project_root, "R", "reverse_instruments.R"))

test_that("ED Z/weight candidates retain their explicit standardized scale", {
  x <- data.frame(
    MarkerName = "1:10", CHR = 1, BP = 10, rsID = "rs1",
    Allele1 = "A", Allele2 = "G", Weight = 100, Zscore = 6,
    `P-value` = 1e-9, check.names = FALSE
  )
  result <- normalize_reverse_ed_candidates(x)
  expect_equal(result$beta, 0.6)
  expect_equal(result$se, 0.1)
  expect_equal(result$F, 36)
  expect_equal(result$effect_scale, "standardized_z_per_sqrt_metal_weight")
  expect_equal(result$analysis_role, "reverse_sensitivity")
})

test_that("reverse ED candidates map by rsID, chromosome, and allele set", {
  candidates <- data.frame(
    snp = c("rs1", "rs2", "rs3"), chr = c("1", "2", "3"),
    ea = c("A", "C", "A"), oa = c("G", "T", "C"),
    stringsAsFactors = FALSE
  )
  reference <- data.frame(
    reference_id = c("rs1", "rs2", "rs3"),
    reference_chr = c("1", "2", "4"), reference_pos = 1:3,
    reference_a1 = c("G", "G", "A"), reference_a2 = c("A", "A", "C"),
    stringsAsFactors = FALSE
  )
  result <- map_reverse_ed_to_ld_panel(candidates, reference)
  expect_equal(
    result$reference_mapping_status,
    c("allele_match", "allele_match", "chromosome_mismatch")
  )
  expect_equal(result$reference_id[1:2], c("rs1", "rs2"))
  expect_true(is.na(result$reference_id[[3]]))
})
