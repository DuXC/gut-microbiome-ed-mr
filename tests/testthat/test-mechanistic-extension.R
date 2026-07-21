project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "provenance.R"))
source(file.path(project_root, "R", "download.R"))
source(file.path(project_root, "R", "mechanistic_extension.R"))
source(file.path(project_root, "R", "mechanistic_analysis.R"))
source(file.path(project_root, "R", "mechanistic_gwas.R"))

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
  cis_leads <- read_cytokine_cis_leads(
    file.path(project_root, "config", "cytokine_cis_leads.csv"), mediators
  )
  endothelial_cis <- read_endothelial_cis_regions(
    file.path(project_root, "config", "endothelial_cis_regions.csv"),
    mediators
  )
  expect_equal(nrow(mediators), 49L)
  expect_equal(table(mediators$family)[["cytokine"]], 40L)
  expect_equal(table(mediators$family)[["endothelial"]], 9L)
  expect_equal(nrow(exposures), 5L)
  expect_equal(nrow(cis_leads), 19L)
  expect_equal(sum(cis_leads$het_p < 0.05, na.rm = TRUE), 13L)
  expect_equal(sum(is.na(cis_leads$het_p)), 1L)
  expect_equal(nrow(endothelial_cis), 9L)
  expect_true(all(endothelial_cis$cis_flank_bp == 300000))
  expect_true(all(endothelial_cis$instrument_p == 5e-8))
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

test_that("mechanistic total-effect family retains all five hypotheses", {
  exposures <- read_mechanistic_exposures(
    file.path(project_root, "config", "mechanistic_exposures.csv")
  )
  mr_raw <- data.frame(
    dataset = "microbiome_2026_hunt",
    source_id = exposures$source_id,
    tier = "primary",
    outcome_id = MECHANISTIC_TOTAL_OUTCOME_ID,
    effect_scale = "log_odds",
    method = "mr_wald_ratio",
    method_role = "primary_estimator",
    nsnp = 1L,
    beta = c(0.10, -0.20, 0.05, 0.15, -0.08),
    se = rep(0.10, 5L),
    ci_lower = c(0.10, -0.20, 0.05, 0.15, -0.08) - 1.96 * 0.10,
    ci_upper = c(0.10, -0.20, 0.05, 0.15, -0.08) + 1.96 * 0.10,
    p = c(0.01, 0.04, 0.20, 0.50, 0.80),
    mean_F = 30,
    min_F = 30,
    analysis_status = "estimated",
    error_message = "",
    warning_message = "",
    stringsAsFactors = FALSE
  )
  result <- extract_mechanistic_total_effects(mr_raw, exposures)
  expect_equal(nrow(result), 5L)
  expect_identical(result$family_denominator, rep(5L, 5L))
  expect_equal(result$q, stats::p.adjust(mr_raw$p, "BH", n = 5L))
  expect_false(any(result$fdr_significant))

  missing <- mr_raw[-1L, , drop = FALSE]
  expect_error(
    extract_mechanistic_total_effects(missing, exposures),
    "exactly one frozen"
  )
})

test_that("cytokine target extraction preserves missing rows and verifies cis lead", {
  config <- read_mechanistic_config(
    file.path(project_root, "config", "mechanistic_extension.yml")
  )
  mediators <- read_mechanistic_mediators(
    file.path(project_root, "config", "mechanistic_mediators.csv"), config
  )
  cytokine <- mediators[mediators$mediator_id == "cytokine_CCL11", , drop = FALSE]
  cis <- read_cytokine_cis_leads(
    file.path(project_root, "config", "cytokine_cis_leads.csv"), mediators
  )
  freeze <- utils::read.csv(
    file.path(project_root, "08_qc", "mechanistic_exposure_freeze.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  requests <- cytokine_target_requests(cytokine, freeze, cis)
  lead <- cis[cis$mediator_id == "cytokine_CCL11", , drop = FALSE]
  raw <- data.frame(
    chromosome = "17", base_pair_location = 34161871,
    effect_allele = lead$effect_allele, other_allele = lead$other_allele,
    beta = lead$beta, standard_error = lead$se,
    effect_allele_frequency = 0.25955, p_value = lead$p,
    rsid = lead$lead_snp, stringsAsFactors = FALSE
  )
  normalized <- normalize_cytokine_gwas_rows(raw)
  result <- align_cytokine_target_requests(requests, normalized, cytokine, cis)
  expect_equal(nrow(result), 6L)
  expect_equal(sum(result$extraction_status == "matched"), 1L)
  expect_equal(
    result$build[result$request_role == "mediator_cis_instrument"], "GRCh38"
  )
  expect_equal(
    lead$position_grch37, 32488890
  )
})

test_that("cytokine M-to-Y results retain the frozen 40-test denominator", {
  config <- read_mechanistic_config(
    file.path(project_root, "config", "mechanistic_extension.yml")
  )
  mediators <- read_mechanistic_mediators(
    file.path(project_root, "config", "mechanistic_mediators.csv"), config
  )
  cis <- read_cytokine_cis_leads(
    file.path(project_root, "config", "cytokine_cis_leads.csv"), mediators
  )
  instruments <- cytokine_cis_instrument_table(cis, mediators)
  audit <- data.frame(
    source_id = instruments$source_id,
    reference_id = instruments$reference_id,
    harmonisation_status = "outcome_rsid_missing",
    stringsAsFactors = FALSE
  )
  one <- instruments[1L, , drop = FALSE]
  harmonised <- data.frame(
    source_id = one$source_id, reference_id = one$reference_id,
    beta_exposure = one$beta, se_exposure = one$se,
    beta_outcome_harmonised = 0.02, se_outcome_harmonised = 0.01,
    stringsAsFactors = FALSE
  )
  audit$harmonisation_status[1L] <- "harmonised"
  result <- cytokine_m_to_y_family(
    harmonised, audit, mediators, cis, verified_source_ids = one$source_id
  )
  expect_equal(nrow(result), 40L)
  expect_equal(sum(result$nsnp), 1L)
  expect_true(all(result$family_denominator == 40L))
  expect_equal(sum(result$p_for_fdr == 1), 39L)
  expect_equal(result$source_gwas_verification[1L], "pending")
})

test_that("cytokine X-to-M results retain all 200 hypotheses while incomplete", {
  config <- read_mechanistic_config(
    file.path(project_root, "config", "mechanistic_extension.yml")
  )
  mediators <- read_mechanistic_mediators(
    file.path(project_root, "config", "mechanistic_mediators.csv"), config
  )
  freeze <- utils::read.csv(
    file.path(project_root, "08_qc", "mechanistic_exposure_freeze.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  mediator <- mediators[mediators$mediator_id == "cytokine_CCL11", , drop = FALSE]
  extracts <- data.frame(
    source_id = mediator$source_id,
    request_role = "x_instrument_to_mediator",
    request_id = freeze$exposure_id[1L],
    extraction_status = "matched",
    beta = 0.02, se = 0.01,
    stringsAsFactors = FALSE
  )
  result <- cytokine_x_to_m_family(
    extracts, mediators, freeze, completed_source_ids = mediator$source_id
  )
  expect_equal(nrow(result), 200L)
  expect_equal(sum(result$analysis_status == "estimated_single_instrument"), 1L)
  expect_equal(sum(result$analysis_status == "pending_source_download"), 195L)
  expect_true(all(result$family_denominator == 200L))
  expect_false(any(result$fdr_significant))
  expect_true(all(result$multiplicity_status == "provisional_incomplete_family"))
})

test_that("SCALLOP normalization separates five targets from cis candidates", {
  config <- read_mechanistic_config(
    file.path(project_root, "config", "mechanistic_extension.yml")
  )
  mediators <- read_mechanistic_mediators(
    file.path(project_root, "config", "mechanistic_mediators.csv"), config
  )
  regions <- read_endothelial_cis_regions(
    file.path(project_root, "config", "endothelial_cis_regions.csv"), mediators
  )
  freeze <- utils::read.csv(
    file.path(project_root, "08_qc", "mechanistic_exposure_freeze.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  raw <- data.frame(
    MarkerName = c("10:85639993:C_T", "1:169700000:A_G"),
    Allele1 = c("T", "A"), Allele2 = c("C", "G"),
    Freq1 = c(0.2, 0.3), Effect = c(0.02, 0.5),
    StdErr = c(0.01, 0.05), `P-value` = c(0.04, 1e-20),
    TotalSampleSize = c(10000, 12000),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  normalized <- normalize_scallop_gwas_rows(raw)
  mediator <- mediators[mediators$mediator_id == "endothelial_SELE", , drop = FALSE]
  region <- regions[regions$mediator_id == "endothelial_SELE", , drop = FALSE]
  result <- endothelial_selected_rows(normalized, mediator, region, freeze)
  expect_equal(nrow(result), 6L)
  expect_equal(sum(result$request_role == "x_instrument_to_mediator"), 5L)
  expect_equal(sum(result$extraction_status == "matched"), 1L)
  expect_equal(sum(result$request_role == "mediator_cis_candidate"), 1L)
  expect_equal(result$build[result$request_role == "mediator_cis_candidate"], "GRCh37")
})

test_that("mechanistic zsh supervisor avoids reserved status parameter", {
  supervisor <- readLines(
    file.path(project_root, "scripts", "18_supervise_mechanistic_download.sh"),
    warn = FALSE
  )
  expect_false(any(grepl("^[[:space:]]*status=", supervisor)))
  expect_true(any(grepl("^[[:space:]]*exit_code=", supervisor)))
})
