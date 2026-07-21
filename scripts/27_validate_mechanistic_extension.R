#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "27_validate_mechanistic_extension.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "provenance.R"))
source(file.path(project_root, "R", "mechanistic_extension.R"))

inventory_path <- file.path(project_root, "00_admin", "mechanistic_source_inventory.csv")
manifest_path <- file.path(project_root, "08_qc", "mechanistic_raw_manifest.csv")
inventory <- read_source_inventory_csv(inventory_path)
manifest <- read_manifest_csv(manifest_path)
validate_source_inventory(inventory, inventory_path)
validate_receipt(
  manifest, inventory, project_root,
  verify_files = TRUE, verify_frozen = FALSE
)
if (nrow(inventory) != 49L || nrow(manifest) != 49L ||
    sum(manifest$bytes) != 15658798006) {
  stop("Mechanistic raw inventory is not the frozen 49-file payload", call. = FALSE)
}
partial_files <- list.files(
  file.path(project_root, "03_data", "raw"),
  pattern = "[.]part$", recursive = TRUE, full.names = TRUE
)
if (length(partial_files)) stop("Partial mechanistic downloads remain", call. = FALSE)

result_paths <- c(
  x_to_y = "05_results/tables/mechanistic_x_to_y_total_effects.csv",
  cytokine_m_to_y = "05_results/tables/mechanistic_cytokine_m_to_y.csv",
  cytokine_x_to_m = "05_results/tables/mechanistic_cytokine_x_to_m.csv",
  endothelial_m_to_y = "05_results/tables/mechanistic_endothelial_m_to_y.csv",
  endothelial_x_to_m = "05_results/tables/mechanistic_endothelial_x_to_m.csv",
  cytokine_indirect = "05_results/tables/mechanistic_cytokine_indirect.csv",
  endothelial_indirect = "05_results/tables/mechanistic_endothelial_indirect.csv"
)
expected_rows <- c(5L, 40L, 200L, 9L, 45L, 200L, 45L)
results <- lapply(result_paths, function(path) {
  absolute <- file.path(project_root, path)
  if (!file.exists(absolute)) stop("Missing mechanistic result: ", path, call. = FALSE)
  utils::read.csv(absolute, stringsAsFactors = FALSE, check.names = FALSE)
})
observed_rows <- vapply(results, nrow, integer(1))
if (!identical(unname(observed_rows), unname(expected_rows))) {
  stop("Mechanistic result denominators drifted", call. = FALSE)
}
fdr_count <- vapply(results, function(result) {
  field <- intersect(
    c("fdr_significant", "product_fdr_significant"), names(result)
  )
  if (length(field) != 1L) stop("Result lacks one FDR field", call. = FALSE)
  sum(as.logical(result[[field]]), na.rm = TRUE)
}, integer(1))
if (any(fdr_count != 0L)) {
  stop("A mechanistic FDR result changed from the frozen stopping state", call. = FALSE)
}
decision_path <- file.path(project_root, "08_qc", "mechanistic_extension_decision.csv")
decision <- utils::read.csv(
  decision_path, stringsAsFactors = FALSE, check.names = FALSE
)
if (nrow(decision) != 1L || isTRUE(decision$colocalization_required) ||
    decision$extension_decision !=
      "stop_before_broad_metabolite_or_immune_expansion") {
  stop("Mechanistic extension decision is inconsistent", call. = FALSE)
}
receipt <- data.frame(
  raw_files_verified = nrow(manifest),
  raw_bytes_verified = sum(manifest$bytes),
  raw_gib_verified = sum(manifest$bytes) / 1024^3,
  upstream_checksum = "md5",
  local_checksum = "sha256",
  result_families_verified = length(results),
  result_rows_verified = sum(observed_rows),
  total_fdr_signals = sum(fdr_count),
  colocalization_required = FALSE,
  extension_decision = decision$extension_decision,
  decision_sha256 = digest::digest(
    decision_path, algo = "sha256", file = TRUE, serialize = FALSE
  ),
  completed_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  stringsAsFactors = FALSE
)
write_csv_atomic(
  receipt,
  file.path(project_root, "08_qc", "mechanistic_full_validation_receipt.csv")
)
message(sprintf(
  "mechanistic_validation_ok raw=%d files %.3f GiB result_rows=%d fdr=%d",
  receipt$raw_files_verified, receipt$raw_gib_verified,
  receipt$result_rows_verified, receipt$total_fdr_signals
))
