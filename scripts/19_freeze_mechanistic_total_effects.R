#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "19_freeze_mechanistic_total_effects.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "mechanistic_extension.R"))
source(file.path(project_root, "R", "mechanistic_analysis.R"))

exposure_path <- file.path(project_root, "config", "mechanistic_exposures.csv")
mr_path <- file.path(project_root, "05_results", "tables", "mr_raw.csv")
output_path <- file.path(
  project_root, "05_results", "tables", "mechanistic_x_to_y_total_effects.csv"
)
code_path <- file.path(project_root, "R", "mechanistic_analysis.R")
script_path <- normalizePath(script_path)

exposures <- read_mechanistic_exposures(exposure_path)
mr_raw <- utils::read.csv(
  mr_path, stringsAsFactors = FALSE, check.names = FALSE,
  na.strings = "__CODEX_NO_NA__"
)
result <- extract_mechanistic_total_effects(mr_raw, exposures)
write_csv_atomic(result, output_path)

receipt_files <- c(exposure_path, mr_path, code_path, script_path, output_path)
receipt <- data.frame(
  artifact = sub(paste0("^", project_root, "/"), "", receipt_files),
  sha256 = vapply(receipt_files, function(path) {
    digest::digest(path, algo = "sha256", file = TRUE, serialize = FALSE)
  }, character(1)),
  frozen_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  stringsAsFactors = FALSE
)
write_csv_atomic(
  receipt,
  file.path(project_root, "08_qc", "mechanistic_x_to_y_receipt.csv")
)

message(sprintf(
  "mechanistic X->Y rows=%d estimable=%d FDR=%d min_p=%.6g min_q=%.6g",
  nrow(result), sum(result$analysis_status == "estimated"),
  sum(result$fdr_significant), min(result$p_for_fdr), min(result$q)
))
