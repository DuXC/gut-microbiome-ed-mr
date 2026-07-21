#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "25_run_endothelial_m_to_y_screen.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "gwas_schema.R"))
source(file.path(project_root, "R", "outcomes.R"))
source(file.path(project_root, "R", "harmonization.R"))
source(file.path(project_root, "R", "mr_core.R"))
source(file.path(project_root, "R", "mechanistic_extension.R"))
source(file.path(project_root, "R", "mechanistic_gwas.R"))
source(file.path(project_root, "R", "mechanistic_analysis.R"))

config <- read_mechanistic_config(
  file.path(project_root, "config", "mechanistic_extension.yml")
)
mediators <- read_mechanistic_mediators(
  file.path(project_root, "config", "mechanistic_mediators.csv"), config
)
endothelial <- mediators[mediators$family == "endothelial", , drop = FALSE]
instrument_path <- file.path(
  project_root, "03_data", "processed", "mechanistic",
  "endothelial_instruments.parquet"
)
instruments <- as.data.frame(arrow::read_parquet(instrument_path))
target_ids <- unique(instruments$reference_id)
if (!length(target_ids)) stop("No endothelial cis instruments are available", call. = FALSE)

finngen_path <- file.path(
  project_root, "03_data", "raw", "finngen_r12",
  "finngen_R12_ERECTILE_DYSFUNCTION", "finngen_R12_ERECTILE_DYSFUNCTION.gz"
)
processed_root <- file.path(
  project_root, "03_data", "processed", "mechanistic", "endothelial_m_to_y"
)
dir.create(processed_root, recursive = TRUE, showWarnings = FALSE)
raw_extract_path <- file.path(processed_root, "finngen_endothelial_cis_matched.tsv")
extract_mechanistic_target_rows(
  finngen_path, target_ids, raw_extract_path,
  awk_script = file.path(project_root, "scripts", "extract_outcome_ids.awk")
)
raw_outcome <- data.table::fread(
  raw_extract_path, data.table = FALSE, check.names = FALSE,
  showProgress = FALSE
)
outcome <- normalize_finngen_outcome(raw_outcome, target_ids)
outcome_path <- file.path(processed_root, "finngen_endothelial_cis.parquet")
write_mechanistic_parquet_atomic(outcome, outcome_path)

primary_parts <- vector("list", nrow(endothelial))
audit_parts <- list()
harmonised_parts <- list()
sensitivity_parts <- list()
for (index in seq_len(nrow(endothelial))) {
  mediator <- endothelial[index, , drop = FALSE]
  mediator_instruments <- instruments[
    instruments$mediator_id == mediator$mediator_id[[1L]], , drop = FALSE
  ]
  harmonised <- mediator_instruments[FALSE, , drop = FALSE]
  if (nrow(mediator_instruments)) {
    harmonisation <- harmonise_one_outcome(
      mediator_instruments, outcome,
      palindromic_maf_max = 0.42, eaf_tolerance = 0.10
    )
    harmonised <- harmonisation$harmonised
    harmonisation$audit$mediator_id <- mediator$mediator_id
    audit_parts[[length(audit_parts) + 1L]] <- harmonisation$audit
    if (nrow(harmonised)) {
      harmonised$mediator_id <- mediator$mediator_id
      harmonised_parts[[length(harmonised_parts) + 1L]] <- harmonised
    }
  }
  meta <- list(
    pair_id = paste0(mediator$mediator_id, "__finngen_r12_ed"),
    dataset = mediator$source_dataset,
    source_id = mediator$source_id,
    trait = mediator$mediator_name,
    tier = "cis_primary",
    outcome_id = MECHANISTIC_TOTAL_OUTCOME_ID,
    outcome_ancestry = "EUR",
    analysis_role = "mechanistic_endothelial_m_to_y",
    effect_scale = "log_odds"
  )
  run <- run_mr_pair(harmonised, meta, nboot = 1000L)
  primary <- run$estimates[run$estimates$method_role == "primary_estimator", , drop = FALSE]
  if (!nrow(primary)) primary <- run$estimates[1L, , drop = FALSE]
  primary_parts[[index]] <- data.frame(
    mediator_id = mediator$mediator_id,
    mediator_name = mediator$mediator_name,
    source_id = mediator$source_id,
    method = primary$method,
    nsnp = primary$nsnp,
    beta = primary$beta,
    se = primary$se,
    ci_lower = primary$ci_lower,
    ci_upper = primary$ci_upper,
    p = primary$p,
    mean_F = primary$mean_F,
    min_F = primary$min_F,
    analysis_status = primary$analysis_status,
    error_message = primary$error_message,
    warning_message = primary$warning_message,
    stringsAsFactors = FALSE
  )
  run$sensitivity$mediator_id <- mediator$mediator_id
  sensitivity_parts[[index]] <- run$sensitivity
}
primary_rows <- do.call(rbind, primary_parts)
result <- finalize_endothelial_m_to_y_family(primary_rows, mediators)
result_path <- file.path(
  project_root, "05_results", "tables", "mechanistic_endothelial_m_to_y.csv"
)
write_csv_atomic(result, result_path)

audit <- if (length(audit_parts)) do.call(rbind, audit_parts) else data.frame()
harmonised <- if (length(harmonised_parts)) do.call(rbind, harmonised_parts) else data.frame()
audit_path <- file.path(processed_root, "harmonisation_audit.parquet")
harmonised_path <- file.path(processed_root, "harmonised.parquet")
write_mechanistic_parquet_atomic(audit, audit_path)
write_mechanistic_parquet_atomic(harmonised, harmonised_path)
write_csv_atomic(
  do.call(rbind, sensitivity_parts),
  file.path(project_root, "08_qc", "mechanistic_endothelial_m_to_y_sensitivity.csv")
)

receipt <- data.frame(
  family = "endothelial_m_to_y",
  family_denominator = 9L,
  clumped_cis_instruments = nrow(instruments),
  mediator_traits_with_instruments = length(unique(instruments$mediator_id)),
  finngen_rsid_matched = length(unique(outcome$rsid)),
  harmonised = nrow(harmonised),
  estimated = sum(result$analysis_status == "estimated"),
  fdr_significant = sum(result$fdr_significant),
  instrument_sha256 = digest::digest(
    instrument_path, algo = "sha256", file = TRUE, serialize = FALSE
  ),
  outcome_extract_sha256 = digest::digest(
    outcome_path, algo = "sha256", file = TRUE, serialize = FALSE
  ),
  harmonised_sha256 = digest::digest(
    harmonised_path, algo = "sha256", file = TRUE, serialize = FALSE
  ),
  result_sha256 = digest::digest(
    result_path, algo = "sha256", file = TRUE, serialize = FALSE
  ),
  completed_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  stringsAsFactors = FALSE
)
write_csv_atomic(
  receipt,
  file.path(project_root, "08_qc", "mechanistic_endothelial_m_to_y_receipt.csv")
)
message(sprintf(
  "endothelial_m_to_y estimated=%d/9 harmonised=%d/%d fdr_significant=%d",
  receipt$estimated, receipt$harmonised, receipt$clumped_cis_instruments,
  receipt$fdr_significant
))
