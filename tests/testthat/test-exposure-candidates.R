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

test_that("completed shards are bound to manifest, schema, and output hashes", {
  path <- tempfile(fileext = ".parquet")
  on.exit(unlink(path), add = TRUE)
  writeLines("fixture", path)
  output_hash <- digest::digest(
    file = path, algo = "sha256", serialize = FALSE
  )
  progress <- data.frame(
    dataset = "microbiome_2026", shard = "1", source_ids = "A;B",
    output_path = path, candidate_rows = "2", p_threshold = "1e-05",
    manifest_sha256 = "manifest", schema_sha256 = "schema",
    output_sha256 = output_hash, completed_at_utc = "2026-07-20T00:00:00Z",
    stringsAsFactors = FALSE
  )

  expect_true(candidate_shard_is_complete(
    progress, "microbiome_2026", 1L, c("A", "B"), path, 1e-5,
    "manifest", "schema"
  ))
  expect_false(candidate_shard_is_complete(
    progress, "microbiome_2026", 1L, c("A", "B"), path, 1e-5,
    "manifest", "changed-schema"
  ))
})
