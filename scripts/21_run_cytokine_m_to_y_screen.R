#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "21_run_cytokine_m_to_y_screen.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "provenance.R"))
source(file.path(project_root, "R", "gwas_schema.R"))
source(file.path(project_root, "R", "outcomes.R"))
source(file.path(project_root, "R", "harmonization.R"))
source(file.path(project_root, "R", "mechanistic_extension.R"))
source(file.path(project_root, "R", "mechanistic_gwas.R"))
source(file.path(project_root, "R", "mechanistic_analysis.R"))

config <- read_mechanistic_config(
  file.path(project_root, "config", "mechanistic_extension.yml")
)
mediators <- read_mechanistic_mediators(
  file.path(project_root, "config", "mechanistic_mediators.csv"), config
)
cis_leads <- read_cytokine_cis_leads(
  file.path(project_root, "config", "cytokine_cis_leads.csv"), mediators
)
instruments <- cytokine_cis_instrument_table(cis_leads, mediators)

finngen_path <- file.path(
  project_root, "03_data", "raw", "finngen_r12",
  "finngen_R12_ERECTILE_DYSFUNCTION", "finngen_R12_ERECTILE_DYSFUNCTION.gz"
)
processed_root <- file.path(
  project_root, "03_data", "processed", "mechanistic", "cytokine_m_to_y"
)
dir.create(processed_root, recursive = TRUE, showWarnings = FALSE)
raw_extract_path <- file.path(processed_root, "finngen_cytokine_cis_matched.tsv")
extract_mechanistic_target_rows(
  finngen_path, cis_leads$lead_snp, raw_extract_path,
  awk_script = file.path(project_root, "scripts", "extract_outcome_ids.awk")
)
raw_outcome <- data.table::fread(
  raw_extract_path, data.table = FALSE, check.names = FALSE,
  showProgress = FALSE
)
outcome <- normalize_finngen_outcome(raw_outcome, cis_leads$lead_snp)
outcome_path <- file.path(processed_root, "finngen_cytokine_cis.parquet")
write_mechanistic_parquet_atomic(outcome, outcome_path)

harmonisation <- harmonise_one_outcome(
  instruments, outcome, palindromic_maf_max = 0.42, eaf_tolerance = 0.10
)
harmonised_path <- file.path(processed_root, "harmonised.parquet")
audit_path <- file.path(processed_root, "harmonisation_audit.parquet")
write_mechanistic_parquet_atomic(harmonisation$harmonised, harmonised_path)
write_mechanistic_parquet_atomic(harmonisation$audit, audit_path)

extract_receipt_path <- file.path(
  project_root, "08_qc", "mechanistic_cytokine_extract_inventory.csv"
)
verified_source_ids <- if (file.exists(extract_receipt_path)) {
  extract_receipt <- utils::read.csv(
    extract_receipt_path, stringsAsFactors = FALSE, check.names = FALSE
  )
  extract_receipt$source_id[extract_receipt$cis_lead_verified == "yes"]
} else character()
result <- cytokine_m_to_y_family(
  harmonisation$harmonised, harmonisation$audit, mediators, cis_leads,
  verified_source_ids = verified_source_ids
)
result_path <- file.path(
  project_root, "05_results", "tables", "mechanistic_cytokine_m_to_y.csv"
)
write_csv_atomic(result, result_path)

main_manifest <- read_manifest_csv(file.path(project_root, "MANIFEST.csv"))
finngen_receipt <- main_manifest[
  main_manifest$dataset == "finngen_r12" &
    main_manifest$source_id == "finngen_R12_ERECTILE_DYSFUNCTION", , drop = FALSE
]
if (nrow(finngen_receipt) != 1L) {
  stop("FinnGen receipt is missing from the main manifest", call. = FALSE)
}
receipt <- data.frame(
  family = "cytokine_m_to_y",
  family_denominator = 40L,
  paper_classified_cis_leads = 19L,
  finngen_rsid_matched = length(unique(outcome$rsid)),
  harmonised = nrow(harmonisation$harmonised),
  estimated = sum(result$nsnp == 1L),
  fdr_significant = sum(result$fdr_significant),
  verified_cis_source_files = length(unique(verified_source_ids)),
  all_cis_source_files_verified = length(unique(verified_source_ids)) == 19L,
  finngen_raw_sha256 = finngen_receipt$sha256,
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
  file.path(project_root, "08_qc", "mechanistic_cytokine_m_to_y_receipt.csv")
)
message(sprintf(
  "cytokine_m_to_y estimated=%d/40 harmonised=%d/19 fdr_significant=%d",
  receipt$estimated, receipt$harmonised, receipt$fdr_significant
))
