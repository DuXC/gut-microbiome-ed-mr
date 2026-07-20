project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "provenance.R"))
source(file.path(project_root, "R", "download.R"))
source(file.path(project_root, "R", "mechanistic_extension.R"))

test_that("mechanistic configuration and frozen registries are internally consistent", {
  config <- read_mechanistic_config(
    file.path(project_root, "config", "mechanistic_extension.yml")
  )
  mediators <- read_mechanistic_mediators(
    file.path(project_root, "config", "mechanistic_mediators.csv"), config
  )
  exposures <- read_mechanistic_exposures(
    file.path(project_root, "config", "mechanistic_exposures.csv")
  )
  overlap <- read_mechanistic_overlap(
    file.path(project_root, "08_qc", "mechanistic_sample_overlap_matrix.csv")
  )
  expect_equal(nrow(mediators), 49L)
  expect_equal(table(mediators$family)[["cytokine"]], 40L)
  expect_equal(table(mediators$family)[["endothelial"]], 9L)
  expect_equal(nrow(exposures), 5L)
  expect_true(any(overlap$overlap_class == "known_partial"))
})
test_that("GWAS Catalog harmonized URLs use the correct thousand-accession block", {
  expect_identical(
    gwas_catalog_block("GCST90428399"),
    "GCST90428001-GCST90429000"
  )
  urls <- gwas_harmonised_urls(
    "GCST90428399",
    "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics"
  )
  expect_match(urls$data, "/GCST90428399/harmonised/GCST90428399\\.h\\.tsv\\.gz$")
  expect_identical(urls$metadata, paste0(urls$data, "-meta.yaml"))
  expect_error(gwas_catalog_block("GCST123"), "eight digits")
})

test_that("registry tampering is rejected before remote access", {
  config <- read_mechanistic_config(
    file.path(project_root, "config", "mechanistic_extension.yml")
  )
  registry <- read_mechanistic_mediators(
    file.path(project_root, "config", "mechanistic_mediators.csv"), config
  )
  registry$source_id[[1L]] <- "GCST90428400"
  expect_error(
    validate_mechanistic_mediators(registry, config),
    "49 unique sources|accession range"
  )
})

test_that("mechanistic source datasets are approved by provenance validation", {
  inventory <- data.frame(
    dataset = c("cytokines_2025_meta", "scallop_cvd1"),
    source_id = c("GCST90428399", "SELE"),
    file_name = c("GCST90428399.h.tsv.gz", "SELE.txt.gz"),
    source_url = c(
      paste0(
        "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/",
        "GCST90428001-GCST90429000/GCST90428399/harmonised/",
        "GCST90428399.h.tsv.gz"
      ),
      "https://zenodo.org/api/records/2615265/files/SELE.txt.gz/content"
    ),
    expected_bytes = c(10, 20),
    ancestry = c("EUR", "EUR"),
    genome_build = c("GRCh38", "GRCh37"),
    license = c("GWAS Catalog CC0", "CC BY 2.0"),
    overlap_note = c("known partial", "possible unresolved"),
    cohort_membership = c("YFS_FINRISK;SCALLOP;deCODE", "SCALLOP_CVD_I_13_cohorts"),
    known_overlap_datasets = c("", ""),
    replication_role = c(
      "mechanistic_mediator_screen_known_partial_overlap",
      "mechanistic_endothelial_mediator_screen"
    ),
    resolved_at_utc = c("2026-07-21T00:00:00Z", "2026-07-21T00:00:00Z"),
    checksum_algorithm = c("md5", "md5"),
    expected_checksum = c(strrep("a", 32), strrep("b", 32)),
    stringsAsFactors = FALSE
  )
  expect_invisible(validate_source_inventory(inventory))
})

test_that("NAS hash-only download mode does not claim filesystem immutability", {
  payload <- "mediator\n"
  checksum_path <- tempfile()
  writeChar(payload, checksum_path, eos = NULL)
  checksum <- unname(tools::md5sum(checksum_path))
  unlink(checksum_path)
  inventory <- data.frame(
    dataset = "cytokines_2025_meta",
    source_id = "GCST90428399",
    file_name = "GCST90428399.h.tsv.gz",
    source_url = paste0(
      "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/",
      "GCST90428001-GCST90429000/GCST90428399/harmonised/",
      "GCST90428399.h.tsv.gz"
    ),
    expected_bytes = as.numeric(nchar(payload, type = "bytes")),
    ancestry = "EUR",
    genome_build = "GRCh38",
    license = "GWAS Catalog CC0",
    overlap_note = "known partial",
    cohort_membership = "YFS_FINRISK;SCALLOP;deCODE",
    known_overlap_datasets = "",
    replication_role = "mechanistic_mediator_screen_known_partial_overlap",
    resolved_at_utc = "2026-07-21T00:00:00Z",
    checksum_algorithm = "md5",
    expected_checksum = checksum,
    stringsAsFactors = FALSE
  )
  root <- tempfile("mechanistic-download-")
  dir.create(root)
  manifest <- file.path(root, "manifest.csv")
  runner <- function(command, args) {
    output <- args[[match("--output", args) + 1L]]
    writeChar(payload, output, eos = NULL)
    0L
  }
  result <- download_inventory_row(
    inventory, inventory, manifest, root, runner = runner,
    freeze_files = FALSE
  )
  expect_identical(result$status, "completed")
  receipt <- read_manifest_csv(manifest)
  expect_invisible(validate_receipt(
    receipt, inventory, root, verify_files = TRUE, verify_frozen = FALSE
  ))
})
