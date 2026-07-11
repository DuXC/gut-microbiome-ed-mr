project_root <- normalizePath(testthat::test_path("..", ".."))

test_that("each required analysis package is available", {
  required <- c(
    "targets", "tarchetypes", "testthat", "data.table", "arrow", "yaml",
    "jsonlite", "digest", "httr2", "rvest", "xml2", "TwoSampleMR",
    "ieugwasr", "genetics.binaRies", "MRPRESSO", "mr.raps",
    "MendelianRandomization", "coloc", "susieR", "MVMR", "ggplot2",
    "patchwork", "rtracklayer", "quarto", "BiocManager"
  )

  for (package in required) {
    expect_true(
      requireNamespace(package, quietly = TRUE),
      info = sprintf("required package is missing: %s", package)
    )
  }
})

test_that("Quarto CLI is available and reports a version", {
  quarto <- Sys.which("quarto")
  expect_true(nzchar(quarto), info = "quarto executable is not on PATH")

  version <- system2(quarto, "--version", stdout = TRUE, stderr = TRUE)
  expect_null(attr(version, "status"))
  expect_match(version[[1]], "^[0-9]+\\.[0-9]+\\.[0-9]+")
})

test_that("project PLINK is the pinned executable", {
  toolchain <- new.env(parent = globalenv())
  sys.source(file.path(project_root, "R", "toolchain.R"), envir = toolchain)
  path <- toolchain$plink_path(project_root)
  expected_path <- file.path(
    project_root, "08_qc", "download_cache", "tools", "plink", "plink"
  )

  expect_identical(normalizePath(path), normalizePath(expected_path))
  expect_true(file.exists(path), info = path)
  expect_identical(file.access(path, mode = 1), structure(0L, names = path))
  expect_identical(toolchain$plink_sha256(path), toolchain$PLINK_SHA256)
  expect_identical(toolchain$plink_version(path), toolchain$PLINK_VERSION)
  expect_identical(toolchain$verify_plink(path), normalizePath(path))
})

test_that("lockfile contains required records and pinned MR-PRESSO", {
  lock <- jsonlite::fromJSON(
    file.path(project_root, "renv.lock"),
    simplifyVector = FALSE
  )
  required <- c(
    "targets", "tarchetypes", "testthat", "data.table", "arrow", "yaml",
    "jsonlite", "digest", "httr2", "rvest", "xml2", "TwoSampleMR",
    "ieugwasr", "genetics.binaRies", "MRPRESSO", "mr.raps",
    "MendelianRandomization", "coloc", "susieR", "MVMR", "ggplot2",
    "patchwork", "rtracklayer", "quarto", "BiocManager"
  )

  for (package in required) {
    expect_true(
      package %in% names(lock$Packages),
      info = sprintf("required lockfile record is missing: %s", package)
    )
  }
  expect_identical(
    lock$Packages$MRPRESSO$RemoteSha,
    "3e3c92d7eda6dce0d1d66077373ec0f7ff4f7e87"
  )
  expect_identical(
    lock$Packages$genetics.binaRies$RemoteSha,
    "2fcd3ee3088b729c7eb34cf2aac9dc2e04fe4412"
  )
})

test_that("bootstrap requires explicit refresh mode to create a lockfile", {
  bootstrap <- new.env(parent = globalenv())
  sys.source(file.path(project_root, "R", "bootstrap.R"), envir = bootstrap)

  expect_identical(bootstrap$bootstrap_mode(character(), TRUE), "restore")
  expect_identical(
    bootstrap$bootstrap_mode("--refresh-lock", TRUE),
    "refresh"
  )
  expect_identical(
    bootstrap$bootstrap_mode("--refresh-lock", FALSE),
    "refresh"
  )
  expect_error(
    bootstrap$bootstrap_mode(character(), FALSE),
    "renv.lock is missing.*--refresh-lock"
  )
})
