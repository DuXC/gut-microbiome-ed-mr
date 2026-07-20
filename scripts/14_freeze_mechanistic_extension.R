#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "14_freeze_mechanistic_extension.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "mechanistic_extension.R"))

config_path <- file.path(project_root, "config", "mechanistic_extension.yml")
mediator_path <- file.path(project_root, "config", "mechanistic_mediators.csv")
exposure_path <- file.path(project_root, "config", "mechanistic_exposures.csv")
overlap_path <- file.path(project_root, "08_qc", "mechanistic_sample_overlap_matrix.csv")

config <- read_mechanistic_config(config_path)
mediators <- read_mechanistic_mediators(mediator_path, config)
exposures <- read_mechanistic_exposures(exposure_path)
overlap <- read_mechanistic_overlap(overlap_path)

instruments_path <- file.path(
  project_root, "03_data", "processed", "instruments", "instruments.parquet"
)
if (!file.exists(instruments_path)) stop("Missing frozen instrument file", call. = FALSE)
instruments <- arrow::read_parquet(instruments_path, as_data_frame = TRUE)
selected <- instruments[
  instruments$dataset == "microbiome_2026_hunt" &
    instruments$tier == "primary" &
    instruments$source_id %in% exposures$source_id,
  , drop = FALSE
]
counts <- table(selected$source_id)
if (!identical(as.integer(counts[exposures$source_id]), rep(1L, 5L)) ||
    anyNA(selected$F) || any(selected$F <= 10) ||
    anyNA(selected$p) || any(selected$p >= 5e-8) ||
    anyNA(selected$reference_id) || any(!nzchar(selected$reference_id))) {
  stop("Frozen HUNT mechanism instruments do not satisfy the protocol", call. = FALSE)
}

selected <- selected[match(exposures$source_id, selected$source_id), , drop = FALSE]
freeze <- cbind(
  exposures[, c("exposure_id", "source_dataset", "source_id", "module_id", "trait")],
  data.frame(
    reference_id = selected$reference_id,
    chromosome = selected$chr,
    position_grch37 = selected$pos,
    effect_allele = selected$ea,
    other_allele = selected$oa,
    exposure_beta = selected$beta,
    exposure_se = selected$se,
    exposure_p = selected$p,
    F = selected$F,
    stringsAsFactors = FALSE
  )
)

denominators <- data.frame(
  family = names(MECHANISTIC_FAMILY_DENOMINATORS),
  denominator = as.integer(MECHANISTIC_FAMILY_DENOMINATORS),
  method = "BH",
  fdr_alpha = 0.05,
  non_estimable_p = 1.0,
  stringsAsFactors = FALSE
)

freeze_path <- file.path(project_root, "08_qc", "mechanistic_exposure_freeze.csv")
denominator_path <- file.path(project_root, "08_qc", "mechanistic_family_denominators.csv")
write_csv_atomic(freeze, freeze_path)
write_csv_atomic(denominators, denominator_path)

receipt_files <- c(
  config_path, mediator_path, exposure_path, overlap_path, instruments_path,
  freeze_path, denominator_path
)
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
  file.path(project_root, "08_qc", "mechanistic_extension_freeze_receipt.csv")
)

message(sprintf(
  "frozen exposures=%d mediators=%d overlap_rows=%d families=%d",
  nrow(exposures), nrow(mediators), nrow(overlap), nrow(denominators)
))
