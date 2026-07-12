project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "provenance.R"))
source(file.path(project_root, "R", "download.R"))
supervisor_path <- file.path(project_root, "R", "download_supervisor.R")
if (file.exists(supervisor_path)) source(supervisor_path)

test_that("download supervisor module exists", {
  expect_true(file.exists(supervisor_path))
})

test_that("dataset completion requires every exact inventory key", {
  skip_if_not(file.exists(supervisor_path))
  inventory <- data.frame(
    dataset = c("a", "a", "b"),
    source_id = c("1", "2", "3"),
    file_name = c("one.tsv", "two.tsv", "three.tsv"),
    stringsAsFactors = FALSE
  )
  manifest <- data.frame(
    dataset = c("a", "a"),
    source_id = c("1", "2"),
    file_name = c("one.tsv", "two.tsv"),
    stringsAsFactors = FALSE
  )
  expect_true(dataset_receipts_complete("a", inventory, manifest))
  expect_false(dataset_receipts_complete("b", inventory, manifest))
  expect_false(dataset_receipts_complete("missing", inventory, manifest))
})

test_that("lock waiter sleeps for live owner then reclaims dead owner", {
  skip_if_not(file.exists(supervisor_path))
  root <- tempfile("supervisor-lock-")
  dir.create(root)
  lock <- file.path(root, ".download-freeze.lock")
  dir.create(lock)
  writeLines("123-live", file.path(lock, "owner"))
  alive_states <- c(TRUE, TRUE, FALSE)
  sleeps <- numeric()
  reclaimed <- character()

  wait_for_download_lock(
    lock,
    owner_alive = function(owner) {
      value <- alive_states[[1L]]
      alive_states <<- alive_states[-1L]
      value
    },
    sleeper = function(seconds) sleeps <<- c(sleeps, seconds),
    reclaimer = function(path) {
      reclaimed <<- c(reclaimed, path)
      unlink(path, recursive = TRUE)
      invisible(TRUE)
    },
    poll_seconds = 7,
    logger = function(...) invisible(NULL)
  )

  expect_identical(sleeps, c(7, 7))
  expect_identical(reclaimed, lock)
  expect_false(dir.exists(lock))
})

test_that("supervisor runs datasets in order and verifies only after completion", {
  skip_if_not(file.exists(supervisor_path))
  inventory <- data.frame(
    dataset = c("microbiome_2026", "microbiome_2026_hunt"),
    source_id = c("1", "2"),
    file_name = c("one.tsv", "two.tsv"),
    stringsAsFactors = FALSE
  )
  manifest_state <- data.frame(
    dataset = character(), source_id = character(), file_name = character(),
    stringsAsFactors = FALSE
  )
  calls <- character()

  result <- supervise_downloads(
    datasets = c("microbiome_2026", "microbiome_2026_hunt"),
    inventory = inventory,
    manifest_reader = function() manifest_state,
    lock_waiter = function() calls <<- c(calls, "wait"),
    dataset_runner = function(dataset) {
      calls <<- c(calls, paste0("run:", dataset))
      row <- inventory[inventory$dataset == dataset, , drop = FALSE]
      manifest_state <<- rbind(manifest_state, row)
      0L
    },
    final_verifier = function() {
      calls <<- c(calls, "verify")
      TRUE
    },
    logger = function(...) invisible(NULL)
  )

  expect_true(result)
  expect_identical(calls, c(
    "wait", "run:microbiome_2026",
    "wait", "run:microbiome_2026_hunt", "verify"
  ))
})

test_that("supervisor stops before verification on dataset failure", {
  skip_if_not(file.exists(supervisor_path))
  inventory <- data.frame(
    dataset = "microbiome_2026", source_id = "1", file_name = "one.tsv",
    stringsAsFactors = FALSE
  )
  verified <- FALSE
  expect_error(
    supervise_downloads(
      datasets = "microbiome_2026",
      inventory = inventory,
      manifest_reader = function() inventory[FALSE, , drop = FALSE],
      lock_waiter = function() invisible(NULL),
      dataset_runner = function(dataset) 18L,
      final_verifier = function() {
        verified <<- TRUE
        TRUE
      },
      logger = function(...) invisible(NULL)
    ),
    "status 18"
  )
  expect_false(verified)
})
