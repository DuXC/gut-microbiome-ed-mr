#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "17_mechanistic_download_status.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "provenance.R"))

inventory_path <- file.path(project_root, "00_admin", "mechanistic_source_inventory.csv")
manifest_path <- file.path(project_root, "08_qc", "mechanistic_raw_manifest.csv")
inventory <- read_source_inventory_csv(inventory_path)
validate_source_inventory(inventory, inventory_path)
manifest <- read_manifest_csv(manifest_path)
validate_receipt(manifest, inventory, project_root, verify_files = FALSE)

receipt_keys <- manifest_key(manifest)
status <- lapply(seq_len(nrow(inventory)), function(index) {
  source <- inventory[index, , drop = FALSE]
  relative <- safe_raw_relative_path(source)
  final <- raw_absolute_path(project_root, relative)
  part <- paste0(final, ".part")
  key <- inventory_key(source)
  expected <- as.numeric(source$expected_bytes[[1L]])
  final_bytes <- if (file.exists(final) && !dir.exists(final)) {
    as.numeric(file.info(final)$size)
  } else 0
  part_bytes <- if (file.exists(part) && !dir.exists(part)) {
    as.numeric(file.info(part)$size)
  } else 0
  completed <- key %in% receipt_keys && identical(final_bytes, expected)
  data.frame(
    dataset = source$dataset[[1L]],
    source_id = source$source_id[[1L]],
    file_name = source$file_name[[1L]],
    expected_bytes = expected,
    completed = completed,
    final_bytes = final_bytes,
    part_bytes = part_bytes,
    stringsAsFactors = FALSE
  )
})
status <- do.call(rbind, status)

verified_bytes <- sum(status$expected_bytes[status$completed])
partial_bytes <- sum(pmin(status$part_bytes, status$expected_bytes))
unreceipted_final_bytes <- sum(
  pmin(status$final_bytes[!status$completed], status$expected_bytes[!status$completed])
)
present_bytes <- verified_bytes + partial_bytes + unreceipted_final_bytes
total_bytes <- sum(status$expected_bytes)
active <- status[status$part_bytes > 0, , drop = FALSE]

cat(sprintf(
  paste0(
    "receipted_files=%d/%d receipted_gib=%.3f partial_gib=%.3f ",
    "present_gib=%.3f/%.3f percent=%.2f\n"
  ),
  sum(status$completed), nrow(status), verified_bytes / 1024^3,
  partial_bytes / 1024^3, present_bytes / 1024^3, total_bytes / 1024^3,
  100 * present_bytes / total_bytes
))
if (nrow(active)) {
  for (index in seq_len(nrow(active))) {
    cat(sprintf(
      "partial %s/%s %.3f/%.3f GiB\n",
      active$dataset[[index]], active$file_name[[index]],
      active$part_bytes[[index]] / 1024^3,
      active$expected_bytes[[index]] / 1024^3
    ))
  }
}
