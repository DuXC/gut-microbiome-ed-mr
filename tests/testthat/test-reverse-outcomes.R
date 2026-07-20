project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "gwas_schema.R"))
source(file.path(project_root, "R", "exposure_candidates.R"))
source(file.path(project_root, "R", "outcomes.R"))
source(file.path(project_root, "R", "reverse_outcomes.R"))

test_that("reverse-outcome receipts invalidate when dependencies change", {
  directory <- tempfile("reverse-receipt-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  output <- file.path(directory, "x.parquet")
  write_candidate_parquet_atomic(data.frame(x = 1), output)
  hashes <- c(
    instrument_ids_sha256 = "a", manifest_sha256 = "b",
    schema_sha256 = "c", extractor_sha256 = "d"
  )
  receipt <- data.frame(
    output_sha256 = digest::digest(
      file = output, algo = "sha256", serialize = FALSE
    ),
    instrument_ids_sha256 = "a", manifest_sha256 = "b",
    schema_sha256 = "c", extractor_sha256 = "d"
  )
  receipt_path <- file.path(directory, "receipt.csv")
  atomic_write_csv(receipt, receipt_path)
  expect_true(reverse_outcome_receipt_valid(receipt_path, output, hashes))
  changed <- hashes
  changed[["extractor_sha256"]] <- "changed"
  expect_false(reverse_outcome_receipt_valid(receipt_path, output, changed))
})
