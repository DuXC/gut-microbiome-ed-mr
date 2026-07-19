project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "gwas_schema.R"))
source(file.path(project_root, "R", "instruments.R"))

test_that("primary and exploratory thresholds remain explicit", {
  x <- data.frame(
    snp = c("a", "b"), beta = c(0.1, 0.1), se = c(0.01, 0.02),
    p = c(1e-9, 1e-6)
  )
  expect_equal(select_by_p(x, 5e-8)$snp, "a")
  expect_equal(select_by_p(x, 1e-5)$snp, c("a", "b"))
})

test_that("weak instruments and invalid standard errors are removed", {
  x <- data.frame(
    snp = c("a", "b", "c"), beta = c(0.20, 0.02, 0.1),
    se = c(0.02, 0.02, NA_real_), p = c(1e-9, 1e-9, 1e-9)
  )
  expect_equal(add_f_stat(x)$F, c(100, 1, NA_real_))
  expect_equal(filter_strong_iv(x, min_f = 10)$snp, "a")
})

test_that("traits without primary candidates return a valid empty tier", {
  x <- data.frame(
    snp = "a", beta = 0.1, se = 0.01, p = 1e-6,
    stringsAsFactors = FALSE
  )
  empty <- select_by_p(x, 5e-8)
  expect_equal(nrow(add_f_stat(empty)), 0L)
  expect_equal(nrow(filter_strong_iv(empty, min_f = 10)), 0L)
  expect_true("F" %in% names(filter_strong_iv(empty, min_f = 10)))
})

test_that("reference mapping accepts either exposure allele orientation", {
  candidates <- data.frame(
    variant_key = c("1:10:A:G", "1:20:C:T", "1:30:A:C"),
    ea = c("G", "C", "A"), oa = c("A", "T", "C"),
    build = rep("GRCh37", 3), stringsAsFactors = FALSE
  )
  reference <- data.frame(
    variant_key = c("1:10:A:G", "1:20:C:T"),
    reference_id = c("rs1", "rs2"), reference_ref = c("A", "C"),
    reference_alt = c("G", "T"), reference_build = rep("GRCh37", 2),
    stringsAsFactors = FALSE
  )
  mapped <- map_candidates_to_reference(candidates, reference)
  expect_equal(mapped$reference_id, c("rs1", "rs2", NA_character_))
  expect_equal(
    mapped$reference_allele_relation,
    c("effect_is_alt", "effect_is_ref", NA_character_)
  )
  expect_equal(
    mapped$reference_mapping_status,
    c("allele_key_match", "allele_key_match", "not_in_reference")
  )
})

test_that("genome-build and ancestry mismatches fail closed", {
  candidates <- data.frame(
    variant_key = "1:10:A:G", ea = "G", oa = "A", build = "GRCh38"
  )
  reference <- data.frame(
    variant_key = "1:10:A:G", reference_id = "rs1", reference_ref = "A",
    reference_alt = "G", reference_build = "GRCh37"
  )
  expect_error(
    map_candidates_to_reference(candidates, reference), "genome builds"
  )
  expect_silent(validate_clump_ancestry("EUR", "EUR"))
  expect_error(validate_clump_ancestry("EUR", "AFR"), "Ancestry mismatch")
})

test_that("PLINK clump input is deterministic and unique", {
  x <- data.frame(
    reference_id = c("rs2", "rs1", "rs1", NA_character_),
    p = c(1e-6, 1e-7, 1e-8, 1e-9)
  )
  result <- prepare_clump_input(x)
  expect_equal(result$SNP, c("rs1", "rs2"))
  expect_equal(result$P, c(1e-8, 1e-6))
})

test_that("parallel task plan distributes tiers in complete blocks", {
  tasks <- instrument_task_plan(n_groups = 3L, n_tiers = 2L)
  expect_equal(
    vapply(tasks, `[[`, integer(1), "group_index"),
    c(1L, 2L, 3L, 1L, 2L, 3L)
  )
  expect_equal(
    vapply(tasks, `[[`, integer(1), "tier_index"),
    c(1L, 1L, 1L, 2L, 2L, 2L)
  )
})
