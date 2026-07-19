project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "gwas_schema.R"))
source(file.path(project_root, "R", "outcomes.R"))

test_that("outcome part suffixes must be contiguous from aa", {
  expect_silent(validate_outcome_part_sequence(c(
    "ed_eur_meta_aa.gz", "ed_eur_meta_ab.gz", "ed_eur_meta_ac.gz"
  )))
  expect_error(
    validate_outcome_part_sequence(c(
      "ed_eur_meta_aa.gz", "ed_eur_meta_ac.gz"
    )),
    "contiguous"
  )
  expect_error(outcome_part_code("ed_eur_meta.gz"), "lacks")
})

test_that("binary outcome assembly restores one valid gzip stream", {
  directory <- tempfile("outcome-parts-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  complete <- file.path(directory, "complete.gz")
  connection <- gzfile(complete, open = "wt")
  writeLines(c("header", "row1", "row2"), connection)
  close(connection)
  bytes <- readBin(complete, what = "raw", n = file.info(complete)$size)
  breaks <- floor(c(0, length(bytes) / 3, 2 * length(bytes) / 3, length(bytes)))
  parts <- file.path(directory, paste0(
    "ed_eur_meta_", c("aa", "ab", "ac"), ".gz"
  ))
  for (i in seq_along(parts)) {
    writeBin(bytes[(breaks[[i]] + 1L):breaks[[i + 1L]]], parts[[i]])
  }
  output <- file.path(directory, "assembled.gz")
  expect_silent(assemble_binary_parts(parts, output, block_size = 7L))
  expect_true(gzip_is_valid(output))
  expect_equal(readLines(gzfile(output), warn = FALSE), c("header", "row1", "row2"))
})

test_that("assembly rejects a non-gzip first part", {
  directory <- tempfile("bad-outcome-parts-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  parts <- file.path(directory, c("ed_afr_meta_aa.gz", "ed_afr_meta_ab.gz"))
  writeBin(charToRaw("not gzip"), parts[[1L]])
  writeBin(charToRaw("continuation"), parts[[2L]])
  expect_error(
    assemble_binary_parts(parts, file.path(directory, "assembled.gz")),
    "gzip header"
  )
})

test_that("METAL Z scores are converted to an explicit standardized scale", {
  x <- data.frame(
    MarkerName = "1:10", CHR = 1, BP = 10, rsID = "rs1",
    Allele1 = "a", Allele2 = "g", Weight = 100, Zscore = 2,
    `P-value` = 0.05, check.names = FALSE
  )
  result <- normalize_ed_meta_outcome(
    x, "ed_2025_eur", "EUR", cases = 20, controls = 80
  )
  expect_equal(result$beta, 0.2)
  expect_equal(result$se, 0.1)
  expect_equal(result$effect_scale, "standardized_z_per_sqrt_metal_weight")
  expect_equal(result$total_n, 100)
})

test_that("FinnGen rows expand only requested rsIDs and retain log-odds scale", {
  x <- data.frame(
    `#chrom` = 1, pos = 10, ref = "G", alt = "A",
    rsids = "rs1,rs2", nearest_genes = "GENE", pval = 0.01,
    mlogp = 2, beta = 0.2, sebeta = 0.1, af_alt = 0.3,
    af_alt_cases = 0.31, af_alt_controls = 0.29,
    check.names = FALSE
  )
  result <- normalize_finngen_outcome(x, wanted_ids = "rs2")
  expect_equal(result$rsid, "rs2")
  expect_equal(result$ea, "A")
  expect_equal(result$oa, "G")
  expect_equal(result$effect_scale, "log_odds")
  expect_equal(result$total_n, 218158)
})

test_that("FinnGen retains auditable allele-specific rows at multiallelic rsIDs", {
  x <- data.frame(
    `#chrom` = c(1, 1), pos = c(10, 10), ref = c("G", "G"),
    alt = c("A", "T"), rsids = c("rs1", "rs1"),
    nearest_genes = c("GENE", "GENE"), pval = c(0.01, 0.2),
    mlogp = c(2, 0.7), beta = c(0.2, -0.1), sebeta = c(0.1, 0.2),
    af_alt = c(0.3, 0.02), af_alt_cases = c(0.31, 0.02),
    af_alt_controls = c(0.29, 0.02), check.names = FALSE
  )
  result <- normalize_finngen_outcome(x, wanted_ids = "rs1")
  expect_equal(nrow(result), 2)
  expect_equal(result$ea, c("A", "T"))
  expect_equal(result$rsid, c("rs1", "rs1"))
})

test_that("streaming outcome extraction writes only requested rows", {
  directory <- tempfile("outcome-extract-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  input <- file.path(directory, "outcome.gz")
  connection <- gzfile(input, open = "wt")
  writeLines(c(
    "CHR\tBP\trsID\tZscore",
    "1\t10\trs1\t1.0",
    "1\t20\trs2\t2.0"
  ), connection)
  close(connection)
  ids <- file.path(directory, "ids.txt")
  writeLines("rs2", ids)
  output <- file.path(directory, "matched.tsv")
  expect_silent(extract_outcome_rows(
    input, ids, output,
    awk_script = file.path(project_root, "scripts", "extract_outcome_ids.awk")
  ))
  result <- data.table::fread(output, data.table = FALSE)
  expect_equal(result$rsID, "rs2")
})
