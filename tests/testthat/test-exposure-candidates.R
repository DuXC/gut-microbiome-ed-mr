project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "exposure_candidates.R"))

test_that("candidate shard plans are deterministic within dataset", {
  catalog <- data.frame(
    dataset = c("b", "a", "a", "a"),
    source_id = c("2", "3", "1", "2"),
    stringsAsFactors = FALSE
  )
  plan <- candidate_shard_plan(catalog, shard_size = 2L)

  expect_equal(plan$dataset, c("a", "a", "a", "b"))
  expect_equal(plan$source_id, c("1", "2", "3", "2"))
  expect_equal(plan$shard, c(1, 1, 2, 1))
})

test_that("invalid worker and shard settings fail closed", {
  expect_error(validate_positive_integer(0, "workers"), "positive integer")
  expect_error(validate_positive_integer(1.5, "shard_size"), "positive integer")
  expect_error(
    candidate_shard_plan(
      data.frame(dataset = c("a", "a"), source_id = c("1", "1")),
      shard_size = 1L
    ),
    "duplicate"
  )
})
