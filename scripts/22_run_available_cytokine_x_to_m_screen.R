#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "22_run_available_cytokine_x_to_m_screen.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "mechanistic_extension.R"))
source(file.path(project_root, "R", "mechanistic_analysis.R"))

config <- read_mechanistic_config(
  file.path(project_root, "config", "mechanistic_extension.yml")
)
mediators <- read_mechanistic_mediators(
  file.path(project_root, "config", "mechanistic_mediators.csv"), config
)
exposure_freeze <- utils::read.csv(
  file.path(project_root, "08_qc", "mechanistic_exposure_freeze.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
extract_receipt <- utils::read.csv(
  file.path(project_root, "08_qc", "mechanistic_cytokine_extract_inventory.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
extracts <- do.call(rbind, lapply(extract_receipt$output_path, function(path) {
  as.data.frame(arrow::read_parquet(file.path(project_root, path)))
}))
result <- cytokine_x_to_m_family(
  extracts, mediators, exposure_freeze,
  completed_source_ids = extract_receipt$source_id
)
result_path <- file.path(
  project_root, "05_results", "tables", "mechanistic_cytokine_x_to_m.csv"
)
write_csv_atomic(result, result_path)
receipt <- data.frame(
  family = "cytokine_x_to_m",
  family_denominator = 200L,
  completed_mediator_sources = length(unique(extract_receipt$source_id)),
  family_complete = length(unique(extract_receipt$source_id)) == 40L,
  estimated = sum(result$analysis_status == "estimated_single_instrument"),
  target_missing = sum(
    result$analysis_status == "not_estimable_instrument_missing_in_mediator_gwas"
  ),
  pending = sum(result$analysis_status == "pending_source_download"),
  provisional_fdr_signals = sum(result$provisional_fdr_signal),
  final_fdr_significant = sum(result$fdr_significant),
  result_sha256 = digest::digest(
    result_path, algo = "sha256", file = TRUE, serialize = FALSE
  ),
  completed_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  stringsAsFactors = FALSE
)
write_csv_atomic(
  receipt,
  file.path(project_root, "08_qc", "mechanistic_cytokine_x_to_m_receipt.csv")
)
message(sprintf(
  "cytokine_x_to_m estimated=%d/200 pending=%d provisional_fdr=%d complete=%s",
  receipt$estimated, receipt$pending, receipt$provisional_fdr_signals,
  receipt$family_complete
))
