project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "exposure_candidates.R"))
source(file.path(project_root, "R", "finalize_analysis.R"))

test_that("combined families preserve denominators and reverse labels", {
  forward <- data.frame(
    pair_id = c("f1", "f2"), source_id = c("s1", "s2"),
    p = c(1e-6, NA), q = c(2e-6, NA),
    analysis_status = c("estimated", "not_estimable"),
    fdr_significant = c(TRUE, FALSE), n_forward = c(2L, 2L),
    n_reverse = c(NA_integer_, NA_integer_),
    global_bonferroni_threshold = c(NA, NA),
    global_bonferroni_status = "pending_reverse_family",
    stringsAsFactors = FALSE
  )
  reverse <- data.frame(
    pair_id = "r1", source_id = "o1", p = 0.2, q = 0.2,
    analysis_status = "estimated", fdr_significant = FALSE,
    stringsAsFactors = FALSE
  )
  replication <- data.frame(
    pair_id = c("f1", "f2"), replicated = c(TRUE, FALSE),
    conditional_go_candidate = c(FALSE, FALSE)
  )
  result <- combine_directional_multiplicity(forward, reverse, replication)
  expect_true(all(result$n_forward == 2))
  expect_true(all(result$n_reverse == 1))
  expect_true(all(result$global_bonferroni_threshold == 0.05 / 3))
  expect_true(all(result$global_bonferroni_status == "computed"))
  expect_equal(
    result$evidence_label[result$direction == "reverse"], "exploratory"
  )
  expect_equal(
    result$analysis_role_final[result$direction == "reverse"],
    "reverse_sensitivity"
  )
})

test_that("final receipt binds one decision to named inputs and outputs", {
  directory <- tempfile("final-receipt-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  input_paths <- c(input = file.path(directory, "input.csv"))
  output_paths <- c(
    replication_audit = file.path(directory, "replication.csv"),
    combined_multiplicity = file.path(directory, "combined.csv"),
    analysis_decision = file.path(directory, "decision.csv")
  )
  code_paths <- c(code = file.path(directory, "code.R"))
  writeLines("input", input_paths)
  writeLines("replication", output_paths[["replication_audit"]])
  writeLines("combined", output_paths[["combined_multiplicity"]])
  atomic_write_csv(data.frame(
    decision = "NO-GO", n_forward = 2L, n_reverse = 3L,
    global_bonferroni_threshold = 0.01
  ), output_paths[["analysis_decision"]])
  writeLines("code", code_paths)
  receipt_path <- file.path(directory, "receipt.csv")
  receipt <- write_final_analysis_receipt(
    receipt_path, input_paths, output_paths, code_paths
  )
  expect_equal(receipt$decision, "NO-GO")
  expect_equal(receipt$n_forward, 2)
  expect_equal(receipt$n_reverse, 3)
  expect_match(receipt$input_sha256, "^input=[0-9a-f]{64}$")
  expect_true(file.exists(receipt_path))
})
