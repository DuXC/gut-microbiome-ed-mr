#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "16_download_mechanistic_sources.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "provenance.R"))
source(file.path(project_root, "R", "download.R"))

inventory_path <- file.path(project_root, "00_admin", "mechanistic_source_inventory.csv")
manifest_path <- file.path(project_root, "08_qc", "mechanistic_raw_manifest.csv")
inventory <- read_source_inventory_csv(inventory_path)
validate_source_inventory(inventory, inventory_path)

selected <- select_download_rows(inventory, commandArgs(trailingOnly = TRUE))
reserve_text <- Sys.getenv(
  "GUT_ED_MECHANISTIC_RESERVE_BYTES", unset = as.character(10 * 1024^3)
)
if (!grepl("^[0-9]+$", reserve_text)) {
  stop("GUT_ED_MECHANISTIC_RESERVE_BYTES must be a nonnegative integer", call. = FALSE)
}
lock_path <- file.path(project_root, ".mechanistic-download.lock")
result <- with_download_lock(lock_path, function() {
  download_selected_rows(
    selected, inventory, manifest_path, project_root,
    reserve_bytes = as.numeric(reserve_text), freeze_files = FALSE
  )
})
message(sprintf(
  "selected=%d completed=%d skipped=%d bytes=%s",
  result$selected, result$completed, result$skipped,
  format(result$bytes, scientific = FALSE)
))
