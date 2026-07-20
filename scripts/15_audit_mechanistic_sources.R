#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "15_audit_mechanistic_sources.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "provenance.R"))
source(file.path(project_root, "R", "mechanistic_extension.R"))

config <- read_mechanistic_config(
  file.path(project_root, "config", "mechanistic_extension.yml")
)
registry <- read_mechanistic_mediators(
  file.path(project_root, "config", "mechanistic_mediators.csv"), config
)
resolved <- resolve_mechanistic_sources(registry, config)
validate_source_inventory(resolved$inventory)

inventory_path <- file.path(
  project_root, "00_admin", "mechanistic_source_inventory.csv"
)
write_source_inventory_atomic(
  resolved$inventory, inventory_path,
  dataset_order = c("cytokines_2025_meta", "scallop_cvd1")
)
write_csv_atomic(
  resolved$metadata,
  file.path(project_root, "08_qc", "mechanistic_source_metadata.csv")
)

summary <- aggregate(
  expected_bytes ~ dataset, resolved$inventory,
  function(value) c(files = length(value), bytes = sum(value))
)
summary <- data.frame(
  dataset = summary$dataset,
  files = summary$expected_bytes[, "files"],
  expected_bytes = summary$expected_bytes[, "bytes"],
  expected_gib = summary$expected_bytes[, "bytes"] / 1024^3,
  all_http_200 = vapply(summary$dataset, function(dataset) {
    all(resolved$metadata$http_status[
      resolved$metadata$source_dataset == dataset
    ] == 200L)
  }, logical(1)),
  resolved_at_utc = unique(resolved$inventory$resolved_at_utc)[[1L]],
  stringsAsFactors = FALSE
)
write_csv_atomic(
  summary,
  file.path(project_root, "08_qc", "mechanistic_source_audit_summary.csv")
)

audit_files <- c(
  inventory_path,
  file.path(project_root, "08_qc", "mechanistic_source_metadata.csv"),
  file.path(project_root, "08_qc", "mechanistic_source_audit_summary.csv")
)
audit_receipt <- data.frame(
  artifact = sub(paste0("^", project_root, "/"), "", audit_files),
  sha256 = vapply(audit_files, function(path) {
    digest::digest(path, algo = "sha256", file = TRUE, serialize = FALSE)
  }, character(1)),
  audited_at_utc = unique(resolved$inventory$resolved_at_utc)[[1L]],
  stringsAsFactors = FALSE
)
write_csv_atomic(
  audit_receipt,
  file.path(project_root, "08_qc", "mechanistic_source_audit_receipt.csv")
)

message(sprintf(
  "audited files=%d expected_gib=%.3f",
  nrow(resolved$inventory), sum(resolved$inventory$expected_bytes) / 1024^3
))
