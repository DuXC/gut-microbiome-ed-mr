#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "24_prepare_endothelial_instruments.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "instruments.R"))
source(file.path(project_root, "R", "mechanistic_extension.R"))
source(file.path(project_root, "R", "mechanistic_gwas.R"))

config <- read_mechanistic_config(
  file.path(project_root, "config", "mechanistic_extension.yml")
)
mediators <- read_mechanistic_mediators(
  file.path(project_root, "config", "mechanistic_mediators.csv"), config
)
endothelial <- mediators[mediators$family == "endothelial", , drop = FALSE]
extract_receipt <- utils::read.csv(
  file.path(project_root, "08_qc", "mechanistic_endothelial_extract_inventory.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
if (nrow(extract_receipt) != 9L ||
    !setequal(extract_receipt$mediator_id, endothelial$mediator_id)) {
  stop("Endothelial extraction receipt is incomplete", call. = FALSE)
}
extracts <- do.call(rbind, lapply(extract_receipt$output_path, function(path) {
  as.data.frame(arrow::read_parquet(file.path(project_root, path)))
}))

bim_path <- file.path(
  project_root, "03_data", "raw", "ld_reference_1kg",
  "381efe6a-b527-48cf-813e-bf721d7b772f", "1000G_EUR.bim"
)
bed_path <- file.path(
  project_root, "03_data", "raw", "ld_reference_1kg",
  "a47b7c9d-6d8a-4d0f-aed4-0d1cc156d16b", "1000G_EUR.bed"
)
fam_path <- file.path(
  project_root, "03_data", "raw", "ld_reference_1kg",
  "4cad6cfd-2e69-43ca-ba1c-a66f73d3b219", "1000G_EUR.fam"
)
plink_binary <- file.path(
  project_root, "08_qc", "download_cache", "tools", "plink", "plink"
)
reference_files <- c(bed = bed_path, bim = bim_path, fam = fam_path)
if (!all(file.exists(c(reference_files, plink_binary)))) {
  stop("PLINK or the EUR LD reference is incomplete", call. = FALSE)
}

bim <- read_plink_bim(bim_path)
mapping <- map_endothelial_cis_to_ld_reference(extracts, bim)
mapping_path <- file.path(
  project_root, "08_qc", "mechanistic_endothelial_ld_mapping.csv"
)
write_csv_atomic(mapping$audit, mapping_path)

temporary_reference <- tempfile("mechanistic-eur-reference-")
dir.create(temporary_reference, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(temporary_reference, recursive = TRUE, force = TRUE), add = TRUE)
link_paths <- file.path(
  temporary_reference, paste0("1000G_EUR", c(".bed", ".bim", ".fam"))
)
if (!all(file.symlink(unname(reference_files), link_paths))) {
  stop("Could not create temporary PLINK reference links", call. = FALSE)
}
bfile_prefix <- file.path(temporary_reference, "1000G_EUR")

instrument_parts <- list()
receipt_parts <- vector("list", nrow(endothelial))
for (index in seq_len(nrow(endothelial))) {
  mediator <- endothelial[index, , drop = FALSE]
  candidates <- mapping$mapped[
    mapping$mapped$mediator_id == mediator$mediator_id[[1L]], , drop = FALSE
  ]
  retained_ids <- if (nrow(candidates)) {
    clump_local(
      candidates, requested_ancestry = "EUR", reference_ancestry = "EUR",
      plink_binary = plink_binary, bfile_prefix = bfile_prefix,
      p_threshold = config$mediator_instruments$primary_p,
      r2 = config$mediator_instruments$ld_r2,
      kb = config$mediator_instruments$ld_kb
    )
  } else character()
  retained <- candidates[
    match(retained_ids, candidates$reference_id, nomatch = 0L), , drop = FALSE
  ]
  if (nrow(retained)) {
    instrument_parts[[length(instrument_parts) + 1L]] <- data.frame(
      mediator_id = mediator$mediator_id,
      mediator_name = mediator$mediator_name,
      marker_name = retained$marker_name,
      reference_id = retained$reference_id,
      chr = retained$chr,
      pos = retained$pos,
      ea = retained$ea,
      oa = retained$oa,
      beta = retained$beta,
      se = retained$se,
      eaf = retained$eaf,
      p = retained$p,
      n = retained$n,
      build = retained$build,
      source_id = mediator$source_id,
      trait = mediator$mediator_name,
      dataset = mediator$source_dataset,
      F = retained$F,
      tier = "cis_primary",
      stringsAsFactors = FALSE
    )
  }
  mediator_audit <- mapping$audit[
    mapping$audit$mediator_id == mediator$mediator_id[[1L]], , drop = FALSE
  ]
  receipt_parts[[index]] <- data.frame(
    mediator_id = mediator$mediator_id,
    source_id = mediator$source_id,
    cis_candidates_pre_ld = nrow(mediator_audit),
    uniquely_mapped_to_1kg_eur = sum(
      mediator_audit$mapping_status == "mapped_unique"
    ),
    clumped_primary_instruments = length(retained_ids),
    instrument_status = ifelse(
      length(retained_ids), "available", "not_estimable_no_mapped_clumped_cis_pqtl"
    ),
    stringsAsFactors = FALSE
  )
}
instruments <- if (length(instrument_parts)) {
  do.call(rbind, instrument_parts)
} else data.frame(
  mediator_id = character(), mediator_name = character(), marker_name = character(),
  reference_id = character(), chr = character(), pos = numeric(), ea = character(),
  oa = character(), beta = numeric(), se = numeric(), eaf = numeric(), p = numeric(),
  n = numeric(), build = character(), source_id = character(), trait = character(),
  dataset = character(), F = numeric(), tier = character(),
  stringsAsFactors = FALSE
)
instrument_path <- file.path(
  project_root, "03_data", "processed", "mechanistic",
  "endothelial_instruments.parquet"
)
write_mechanistic_parquet_atomic(instruments, instrument_path)

receipt <- do.call(rbind, receipt_parts)
receipt$family_denominator <- 9L
receipt$instrument_p <- config$mediator_instruments$primary_p
receipt$ld_r2 <- config$mediator_instruments$ld_r2
receipt$ld_kb <- config$mediator_instruments$ld_kb
receipt$reference_ancestry <- "EUR"
receipt$reference_bim_sha256 <- digest::digest(
  bim_path, algo = "sha256", file = TRUE, serialize = FALSE
)
receipt$instrument_path <- sub(paste0("^", project_root, "/"), "", instrument_path)
receipt$instrument_sha256 <- digest::digest(
  instrument_path, algo = "sha256", file = TRUE, serialize = FALSE
)
receipt$mapping_audit_sha256 <- digest::digest(
  mapping_path, algo = "sha256", file = TRUE, serialize = FALSE
)
receipt$plink_version <- paste(
  system2(plink_binary, "--version", stdout = TRUE, stderr = TRUE),
  collapse = " "
)
receipt$completed_at_utc <- format(
  Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
)
write_csv_atomic(
  receipt,
  file.path(project_root, "08_qc", "mechanistic_endothelial_instrument_receipt.csv")
)
message(sprintf(
  "endothelial_instruments mapped=%d/%d clumped=%d mediators=%d/9",
  sum(mapping$audit$mapping_status == "mapped_unique"), nrow(mapping$audit),
  nrow(instruments), length(unique(instruments$mediator_id))
))
