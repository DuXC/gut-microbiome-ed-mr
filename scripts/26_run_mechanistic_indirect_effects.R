#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "26_run_mechanistic_indirect_effects.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "mechanistic_extension.R"))
source(file.path(project_root, "R", "mechanistic_gwas.R"))
source(file.path(project_root, "R", "mechanistic_analysis.R"))

config <- read_mechanistic_config(
  file.path(project_root, "config", "mechanistic_extension.yml")
)
mediators <- read_mechanistic_mediators(
  file.path(project_root, "config", "mechanistic_mediators.csv"), config
)
freeze <- utils::read.csv(
  file.path(project_root, "08_qc", "mechanistic_exposure_freeze.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
extract_receipt <- utils::read.csv(
  file.path(project_root, "08_qc", "mechanistic_endothelial_extract_inventory.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
extracts <- do.call(rbind, lapply(extract_receipt$output_path, function(path) {
  as.data.frame(arrow::read_parquet(file.path(project_root, path)))
}))

endothelial_x_to_m <- endothelial_x_to_m_family(
  extracts, mediators, freeze
)
endothelial_x_path <- file.path(
  project_root, "05_results", "tables", "mechanistic_endothelial_x_to_m.csv"
)
write_csv_atomic(endothelial_x_to_m, endothelial_x_path)

cytokine_x_to_m <- utils::read.csv(
  file.path(project_root, "05_results", "tables", "mechanistic_cytokine_x_to_m.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
cytokine_m_to_y <- utils::read.csv(
  file.path(project_root, "05_results", "tables", "mechanistic_cytokine_m_to_y.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
endothelial_m_to_y <- utils::read.csv(
  file.path(project_root, "05_results", "tables", "mechanistic_endothelial_m_to_y.csv"),
  stringsAsFactors = FALSE, check.names = FALSE
)
cytokine_indirect <- mechanistic_indirect_family(
  cytokine_x_to_m, cytokine_m_to_y, "cytokine_indirect", 200L,
  "known_partial"
)
endothelial_indirect <- mechanistic_indirect_family(
  endothelial_x_to_m, endothelial_m_to_y, "endothelial_indirect", 45L,
  "possible_unresolved"
)
cytokine_indirect_path <- file.path(
  project_root, "05_results", "tables", "mechanistic_cytokine_indirect.csv"
)
endothelial_indirect_path <- file.path(
  project_root, "05_results", "tables", "mechanistic_endothelial_indirect.csv"
)
write_csv_atomic(cytokine_indirect, cytokine_indirect_path)
write_csv_atomic(endothelial_indirect, endothelial_indirect_path)

receipt <- data.frame(
  family = c("endothelial_x_to_m", "cytokine_indirect", "endothelial_indirect"),
  family_denominator = c(45L, 200L, 45L),
  estimated = c(
    sum(endothelial_x_to_m$analysis_status == "estimated_single_instrument"),
    sum(grepl("^estimated_", cytokine_indirect$analysis_status)),
    sum(grepl("^estimated_", endothelial_indirect$analysis_status))
  ),
  fdr_significant = c(
    sum(endothelial_x_to_m$fdr_significant),
    sum(cytokine_indirect$product_fdr_significant),
    sum(endothelial_indirect$product_fdr_significant)
  ),
  complete_mediation_gates = c(
    NA_integer_, sum(cytokine_indirect$component_fdr_gate &
      cytokine_indirect$product_fdr_significant),
    sum(endothelial_indirect$component_fdr_gate &
      endothelial_indirect$product_fdr_significant)
  ),
  result_sha256 = c(
    digest::digest(endothelial_x_path, algo = "sha256", file = TRUE, serialize = FALSE),
    digest::digest(cytokine_indirect_path, algo = "sha256", file = TRUE, serialize = FALSE),
    digest::digest(endothelial_indirect_path, algo = "sha256", file = TRUE, serialize = FALSE)
  ),
  completed_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  stringsAsFactors = FALSE
)
write_csv_atomic(
  receipt,
  file.path(project_root, "08_qc", "mechanistic_indirect_effect_receipt.csv")
)

decision <- data.frame(
  cytokine_m_to_y_fdr = sum(cytokine_m_to_y$fdr_significant),
  endothelial_m_to_y_fdr = sum(endothelial_m_to_y$fdr_significant),
  cytokine_x_to_m_fdr = sum(cytokine_x_to_m$fdr_significant),
  endothelial_x_to_m_fdr = sum(endothelial_x_to_m$fdr_significant),
  cytokine_complete_mediation_gates = sum(
    cytokine_indirect$component_fdr_gate & cytokine_indirect$product_fdr_significant
  ),
  endothelial_complete_mediation_gates = sum(
    endothelial_indirect$component_fdr_gate & endothelial_indirect$product_fdr_significant
  ),
  colocalization_required = any(c(
    cytokine_indirect$component_fdr_gate,
    endothelial_indirect$component_fdr_gate
  )),
  extension_decision = ifelse(
    any(cytokine_m_to_y$fdr_significant) ||
      any(endothelial_m_to_y$fdr_significant),
    "retain_as_exploratory_pending_source_validity_gates",
    "stop_before_broad_metabolite_or_immune_expansion"
  ),
  completed_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  stringsAsFactors = FALSE
)
write_csv_atomic(
  decision,
  file.path(project_root, "08_qc", "mechanistic_extension_decision.csv")
)
message(sprintf(
  paste(
    "endothelial_x_to_m estimated=%d/45 fdr=%d;",
    "indirect cytokine=%d/200 endothelial=%d/45 complete_gates=%d"
  ),
  sum(endothelial_x_to_m$analysis_status == "estimated_single_instrument"),
  sum(endothelial_x_to_m$fdr_significant),
  sum(cytokine_indirect$product_fdr_significant),
  sum(endothelial_indirect$product_fdr_significant),
  sum(cytokine_indirect$component_fdr_gate & cytokine_indirect$product_fdr_significant) +
    sum(endothelial_indirect$component_fdr_gate &
      endothelial_indirect$product_fdr_significant)
))
