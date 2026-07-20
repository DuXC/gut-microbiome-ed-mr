#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "23_extract_available_endothelial_sources.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "provenance.R"))
source(file.path(project_root, "R", "mechanistic_extension.R"))
source(file.path(project_root, "R", "mechanistic_gwas.R"))

inventory_path <- file.path(
  project_root, "00_admin", "mechanistic_source_inventory.csv"
)
manifest_path <- file.path(project_root, "08_qc", "mechanistic_raw_manifest.csv")
inventory <- read_source_inventory_csv(inventory_path)
validate_source_inventory(inventory, inventory_path)
manifest <- read_manifest_csv(manifest_path)
validate_receipt(manifest, inventory, project_root, verify_files = FALSE)
config <- read_mechanistic_config(
  file.path(project_root, "config", "mechanistic_extension.yml")
)
mediators <- read_mechanistic_mediators(
  file.path(project_root, "config", "mechanistic_mediators.csv"), config
)
endothelial <- mediators[mediators$family == "endothelial", , drop = FALSE]
regions <- read_endothelial_cis_regions(
  file.path(project_root, "config", "endothelial_cis_regions.csv"), mediators
)
exposure_freeze <- utils::read.csv(
  file.path(project_root, "08_qc", "mechanistic_exposure_freeze.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
available <- intersect(
  endothelial$source_id,
  manifest$source_id[manifest$dataset == "scallop_cvd1"]
)
if (!length(available)) {
  message("endothelial_sources_extracted=0 (no receipted SCALLOP files yet)")
  quit(save = "no", status = 0L)
}

output_root <- file.path(
  project_root, "03_data", "processed", "mechanistic", "endothelial_targets"
)
receipts <- lapply(available, function(source_id) {
  mediator <- endothelial[endothelial$source_id == source_id, , drop = FALSE]
  region <- regions[regions$mediator_id == mediator$mediator_id, , drop = FALSE]
  source <- inventory[
    inventory$dataset == "scallop_cvd1" &
      inventory$source_id == source_id, , drop = FALSE
  ]
  receipt <- manifest[
    manifest$dataset == "scallop_cvd1" &
      manifest$source_id == source_id, , drop = FALSE
  ]
  if (nrow(source) != 1L || nrow(receipt) != 1L) {
    stop("SCALLOP inventory or receipt identity is ambiguous", call. = FALSE)
  }
  raw_path <- raw_absolute_path(project_root, receipt$path[[1L]])
  if (!file.exists(raw_path) ||
      as.numeric(file.info(raw_path)$size) != as.numeric(receipt$bytes[[1L]])) {
    stop("Receipted SCALLOP file is missing or truncated", call. = FALSE)
  }
  selected_path <- tempfile("scallop-selected-", fileext = ".tsv")
  on.exit(unlink(selected_path), add = TRUE)
  extract_scallop_mechanistic_rows(
    raw_path, exposure_freeze, region, selected_path,
    awk_script = file.path(
      project_root, "scripts", "extract_scallop_mechanistic.awk"
    )
  )
  raw <- data.table::fread(
    selected_path, data.table = FALSE, check.names = FALSE,
    showProgress = FALSE
  )
  normalized <- normalize_scallop_gwas_rows(raw)
  result <- endothelial_selected_rows(
    normalized, mediator, region, exposure_freeze
  )
  output_path <- file.path(output_root, paste0(source_id, ".parquet"))
  write_mechanistic_parquet_atomic(result, output_path)
  data.frame(
    mediator_id = mediator$mediator_id,
    source_id = source_id,
    raw_path = receipt$path,
    raw_sha256 = receipt$sha256,
    requested_x_rows = 5L,
    matched_x_rows = sum(
      result$request_role == "x_instrument_to_mediator" &
        result$extraction_status == "matched"
    ),
    cis_candidates_pre_ld = sum(
      result$request_role == "mediator_cis_candidate"
    ),
    output_path = sub(paste0("^", project_root, "/"), "", output_path),
    output_sha256 = digest::digest(
      output_path, algo = "sha256", file = TRUE, serialize = FALSE
    ),
    completed_at_utc = format(
      Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    ),
    stringsAsFactors = FALSE
  )
})
receipt <- do.call(rbind, receipts)
write_csv_atomic(
  receipt,
  file.path(project_root, "08_qc", "mechanistic_endothelial_extract_inventory.csv")
)
message(sprintf(
  "endothelial_sources_extracted=%d matched_x_rows=%d cis_candidates_pre_ld=%d",
  nrow(receipt), sum(receipt$matched_x_rows), sum(receipt$cis_candidates_pre_ld)
))
