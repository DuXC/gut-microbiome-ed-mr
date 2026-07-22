#!/usr/bin/env Rscript

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_library <- file.path(
  project_root, "renv", "library", "macos", "R-4.6",
  "aarch64-apple-darwin25.4.0"
)
if (dir.exists(local_library)) .libPaths(c(local_library, .libPaths()))

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(digest)
})
source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "exposure_candidates.R"))

input_root <- file.path(project_root, "05_results", "tables")
output_root <- file.path(project_root, "05_results", "v0_3_20260722")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

read_result <- function(stem) {
  fread(file.path(input_root, paste0("mechanistic_", stem, ".csv")))
}
write_result <- function(x, filename) {
  path <- file.path(output_root, filename)
  atomic_write_csv(as.data.frame(x), path)
  path
}

freeze <- fread(file.path(project_root, "08_qc", "mechanistic_exposure_freeze.csv"))
cytokine_leads <- fread(file.path(project_root, "config", "cytokine_cis_leads.csv"))
endothelial <- as.data.table(read_parquet(file.path(
  project_root, "03_data", "processed", "mechanistic",
  "endothelial_instruments.parquet"
)))

exposure_ledger <- freeze[, .(
  exposure_id,
  exposure_instrument_snp = reference_id,
  exposure_effect_allele = toupper(effect_allele),
  exposure_other_allele = toupper(other_allele),
  exposure_eaf = NA_real_, exposure_instrument_beta = exposure_beta,
  exposure_instrument_se = exposure_se, exposure_instrument_p = exposure_p,
  exposure_instrument_F = F
)]

# EAF for the five HUNT functional instruments comes from the frozen instrument
# table rather than being inferred from the exposure freeze.
all_instruments <- as.data.table(read_parquet(file.path(
  project_root, "03_data", "processed", "instruments", "instruments.parquet"
)))
hunt_eaf <- all_instruments[
  dataset == "microbiome_2026_hunt" & tier == "primary" &
    source_id %in% freeze$source_id,
  .(source_id, reference_id, eaf)
]
exposure_ledger <- merge(
  exposure_ledger,
  freeze[, .(exposure_id, source_id, reference_id)],
  by = "exposure_id", all.x = TRUE, sort = FALSE
)
exposure_ledger <- merge(
  exposure_ledger, hunt_eaf,
  by = c("source_id", "reference_id"), all.x = TRUE, sort = FALSE
)
exposure_ledger[, exposure_eaf := eaf]
exposure_ledger[, c("source_id", "reference_id", "eaf") := NULL]
if (nrow(exposure_ledger) != 5L || any(!is.finite(exposure_ledger$exposure_eaf))) {
  stop("The five frozen mechanistic exposures lack complete EAF data", call. = FALSE)
}

cytokine_ledger <- cytokine_leads[, .(
  mediator_id,
  mediator_instrument_snp = lead_snp,
  mediator_effect_allele = toupper(effect_allele),
  mediator_other_allele = toupper(other_allele),
  mediator_eaf = eaf, mediator_instrument_beta = beta,
  mediator_instrument_se = se, mediator_instrument_p = p,
  mediator_instrument_F = (beta / se)^2,
  mediator_source_heterogeneity_i2 = het_i2,
  mediator_source_heterogeneity_p = het_p,
  mediator_source_heterogeneity_status = heterogeneity_sensitivity_status
)]
endothelial_ledger <- endothelial[order(reference_id), .(
  mediator_instrument_snp = paste(reference_id, collapse = ";"),
  mediator_effect_allele = paste(toupper(ea), collapse = ";"),
  mediator_other_allele = paste(toupper(oa), collapse = ";"),
  mediator_eaf = paste(format(eaf, digits = 12, trim = TRUE), collapse = ";"),
  mediator_instrument_beta = paste(
    format(beta, digits = 12, trim = TRUE), collapse = ";"
  ),
  mediator_instrument_se = paste(
    format(se, digits = 12, trim = TRUE), collapse = ";"
  ),
  mediator_instrument_p = paste(
    format(p, digits = 12, scientific = TRUE, trim = TRUE), collapse = ";"
  ),
  mediator_instrument_F = paste(
    format(F, digits = 12, trim = TRUE), collapse = ";"
  ),
  mediator_source_heterogeneity_i2 = NA_real_,
  mediator_source_heterogeneity_p = NA_real_,
  mediator_source_heterogeneity_status = "not_reported_for_this_panel"
), by = mediator_id]
mediator_ledger <- rbindlist(
  list(cytokine_ledger, endothelial_ledger), use.names = TRUE, fill = TRUE
)

blank_common <- function(n) {
  data.table(
    exposure_id = rep(NA_character_, n), exposure_trait = rep(NA_character_, n),
    mediator_id = rep(NA_character_, n), mediator_name = rep(NA_character_, n),
    outcome_id = rep(NA_character_, n), overlap_class = rep(NA_character_, n),
    beta = rep(NA_real_, n), se = rep(NA_real_, n), p = rep(NA_real_, n),
    q = rep(NA_real_, n), analysis_status = rep(NA_character_, n),
    evidence_label = rep(NA_character_, n)
  )
}

make_common <- function(x, family) {
  z <- blank_common(nrow(x))
  z[, `:=`(
    family = family,
    family_denominator = as.integer(x$family_denominator),
    row_in_family = seq_len(nrow(x))
  )]
  z
}

xy <- read_result("x_to_y_total_effects")
xy_common <- make_common(xy, "mechanistic_x_to_y")
xy_common[, `:=`(
  exposure_id = xy$exposure_id, exposure_trait = xy$trait,
  outcome_id = xy$outcome_id, overlap_class = "none_known",
  beta = xy$beta, se = xy$se, p = xy$p, q = xy$q,
  analysis_status = xy$analysis_status, evidence_label = xy$evidence_label
)]

cy_my <- read_result("cytokine_m_to_y")
cy_my_common <- make_common(cy_my, "cytokine_m_to_y")
cy_my_common[, `:=`(
  mediator_id = cy_my$mediator_id, mediator_name = cy_my$mediator_name,
  outcome_id = cy_my$outcome_id, overlap_class = cy_my$outcome_overlap_class,
  beta = cy_my$beta, se = cy_my$se, p = cy_my$p, q = cy_my$q,
  analysis_status = cy_my$analysis_status, evidence_label = cy_my$evidence_label
)]

en_my <- read_result("endothelial_m_to_y")
en_my_common <- make_common(en_my, "endothelial_m_to_y")
en_my_common[, `:=`(
  mediator_id = en_my$mediator_id, mediator_name = en_my$mediator_name,
  outcome_id = en_my$outcome_id, overlap_class = en_my$outcome_overlap_class,
  beta = en_my$beta, se = en_my$se, p = en_my$p, q = en_my$q,
  analysis_status = en_my$analysis_status, evidence_label = en_my$evidence_label
)]

cy_xm <- read_result("cytokine_x_to_m")
cy_xm_common <- make_common(cy_xm, "cytokine_x_to_m")
cy_xm_common[, `:=`(
  exposure_id = cy_xm$exposure_id, exposure_trait = cy_xm$exposure_trait,
  mediator_id = cy_xm$mediator_id, mediator_name = cy_xm$mediator_name,
  overlap_class = cy_xm$x_m_overlap_class,
  beta = cy_xm$beta, se = cy_xm$se, p = cy_xm$p, q = cy_xm$q,
  analysis_status = cy_xm$analysis_status, evidence_label = cy_xm$evidence_label
)]

en_xm <- read_result("endothelial_x_to_m")
en_xm_common <- make_common(en_xm, "endothelial_x_to_m")
en_xm_common[, `:=`(
  exposure_id = en_xm$exposure_id, exposure_trait = en_xm$exposure_trait,
  mediator_id = en_xm$mediator_id, mediator_name = en_xm$mediator_name,
  overlap_class = en_xm$x_m_overlap_class,
  beta = en_xm$beta, se = en_xm$se, p = en_xm$p, q = en_xm$q,
  analysis_status = en_xm$analysis_status, evidence_label = en_xm$evidence_label
)]

cy_ind <- read_result("cytokine_indirect")
cy_ind_common <- make_common(cy_ind, "cytokine_indirect")
cy_ind_common[, `:=`(
  exposure_id = cy_ind$exposure_id, exposure_trait = cy_ind$exposure_trait,
  mediator_id = cy_ind$mediator_id, mediator_name = cy_ind$mediator_name,
  outcome_id = "finngen_r12_erectile_dysfunction",
  overlap_class = cy_ind$overlap_class,
  beta = cy_ind$indirect_beta, se = cy_ind$indirect_se,
  p = cy_ind$p, q = cy_ind$q,
  analysis_status = cy_ind$analysis_status, evidence_label = cy_ind$evidence_label
)]

en_ind <- read_result("endothelial_indirect")
en_ind_common <- make_common(en_ind, "endothelial_indirect")
en_ind_common[, `:=`(
  exposure_id = en_ind$exposure_id, exposure_trait = en_ind$exposure_trait,
  mediator_id = en_ind$mediator_id, mediator_name = en_ind$mediator_name,
  outcome_id = "finngen_r12_erectile_dysfunction",
  overlap_class = en_ind$overlap_class,
  beta = en_ind$indirect_beta, se = en_ind$indirect_se,
  p = en_ind$p, q = en_ind$q,
  analysis_status = en_ind$analysis_status, evidence_label = en_ind$evidence_label
)]

full <- rbindlist(list(
  xy_common, cy_my_common, en_my_common, cy_xm_common, en_xm_common,
  cy_ind_common, en_ind_common
), use.names = TRUE, fill = TRUE)
full <- merge(full, exposure_ledger, by = "exposure_id", all.x = TRUE, sort = FALSE)
full <- merge(full, mediator_ledger, by = "mediator_id", all.x = TRUE, sort = FALSE)

full[, test_id := fifelse(
  !is.na(exposure_id) & !is.na(mediator_id),
  paste(exposure_id, mediator_id, sep = "__"),
  fifelse(!is.na(exposure_id), exposure_id, mediator_id)
)]
combine_pair <- function(a, b) {
  mapply(function(x, y) {
    values <- c(x, y)
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values)) paste(values, collapse = ";") else NA_character_
  }, as.character(a), as.character(b), USE.NAMES = FALSE)
}
full[, instrument_snps := fifelse(
  family %in% c("cytokine_indirect", "endothelial_indirect"),
  combine_pair(exposure_instrument_snp, mediator_instrument_snp),
  fifelse(family %in% c("cytokine_m_to_y", "endothelial_m_to_y"),
          mediator_instrument_snp, exposure_instrument_snp)
)]
full[, effect_alleles := fifelse(
  family %in% c("cytokine_indirect", "endothelial_indirect"),
  combine_pair(exposure_effect_allele, mediator_effect_allele),
  fifelse(family %in% c("cytokine_m_to_y", "endothelial_m_to_y"),
          mediator_effect_allele, exposure_effect_allele)
)]
full[, other_alleles := fifelse(
  family %in% c("cytokine_indirect", "endothelial_indirect"),
  combine_pair(exposure_other_allele, mediator_other_allele),
  fifelse(family %in% c("cytokine_m_to_y", "endothelial_m_to_y"),
          mediator_other_allele, exposure_other_allele)
)]
full[, eafs := fifelse(
  family %in% c("cytokine_indirect", "endothelial_indirect"),
  combine_pair(exposure_eaf, mediator_eaf),
  ifelse(
    family %in% c("cytokine_m_to_y", "endothelial_m_to_y"),
    as.character(mediator_eaf), as.character(exposure_eaf)
  )
)]
full[, F_statistics := fifelse(
  family %in% c("cytokine_indirect", "endothelial_indirect"),
  combine_pair(exposure_instrument_F, mediator_instrument_F),
  ifelse(
    family %in% c("cytokine_m_to_y", "endothelial_m_to_y"),
    as.character(mediator_instrument_F), as.character(exposure_instrument_F)
  )
)]
full[, p_for_family := fifelse(is.finite(p), p, 1)]
full[, fdr_significant := is.finite(q) & q < 0.05]
setorder(full, family, row_in_family)

expected <- data.table(
  family = c(
    "mechanistic_x_to_y", "cytokine_m_to_y", "endothelial_m_to_y",
    "cytokine_x_to_m", "endothelial_x_to_m", "cytokine_indirect",
    "endothelial_indirect"
  ),
  expected_rows = c(5L, 40L, 9L, 200L, 45L, 200L, 45L)
)
observed <- full[, .(observed_rows = .N), by = family]
count_audit <- merge(expected, observed, by = "family", all.x = TRUE, sort = FALSE)
if (any(count_audit$expected_rows != count_audit$observed_rows) ||
    nrow(full) != 544L || sum(full$fdr_significant) != 0L) {
  stop("Mechanistic family completeness or FDR freeze drifted", call. = FALSE)
}

family_summary <- full[, .(
  planned_tests = .N,
  estimable_tests = sum(is.finite(p)),
  nominal_p_lt_0_05 = sum(is.finite(p) & p < 0.05),
  fdr_significant_tests = sum(fdr_significant),
  minimum_p = if (any(is.finite(p))) min(p, na.rm = TRUE) else NA_real_,
  minimum_q = min(q, na.rm = TRUE),
  non_estimable_tests = sum(!is.finite(p))
), by = family]

# Predefined cytokine source-heterogeneity sensitivity. Source meta-GWAS
# heterogeneity P<0.05 excludes that paper-classified cis lead; excluded and
# otherwise non-estimable rows remain in the complete family at P=1.
excluded_cytokines <- cytokine_leads[
  is.finite(het_p) & het_p < 0.05, mediator_id
]
cy_my_het <- merge(
  copy(cy_my),
  cytokine_leads[, .(
    mediator_id, source_heterogeneity_i2 = het_i2,
    source_heterogeneity_p = het_p,
    source_heterogeneity_rule = heterogeneity_sensitivity_status
  )],
  by = "mediator_id", all.x = TRUE, sort = FALSE
)
cy_my_het[, sensitivity_excluded := mediator_id %in% excluded_cytokines]
cy_my_het[, sensitivity_p_for_fdr := fifelse(
  sensitivity_excluded | !is.finite(p), 1, p
)]
cy_my_het[, sensitivity_q := p.adjust(
  sensitivity_p_for_fdr, method = "BH", n = 40L
)]
cy_my_het[, sensitivity_fdr_significant :=
            !sensitivity_excluded & is.finite(p) & sensitivity_q < 0.05]
cy_my_het[, sensitivity_analysis_status := fifelse(
  sensitivity_excluded,
  "excluded_source_meta_gwas_heterogeneity_p_lt_0_05",
  fifelse(is.finite(p), "retained_estimated", "retained_non_estimable")
)]

cy_ind_het <- merge(
  copy(cy_ind),
  cytokine_leads[, .(
    mediator_id, source_heterogeneity_i2 = het_i2,
    source_heterogeneity_p = het_p,
    source_heterogeneity_rule = heterogeneity_sensitivity_status
  )],
  by = "mediator_id", all.x = TRUE, sort = FALSE
)
cy_ind_het[, sensitivity_excluded := mediator_id %in% excluded_cytokines]
cy_ind_het[, sensitivity_p_for_fdr := fifelse(
  sensitivity_excluded | !is.finite(p), 1, p
)]
cy_ind_het[, sensitivity_q := p.adjust(
  sensitivity_p_for_fdr, method = "BH", n = 200L
)]
cy_ind_het[, sensitivity_fdr_significant :=
             !sensitivity_excluded & is.finite(p) & sensitivity_q < 0.05]
cy_ind_het[, sensitivity_analysis_status := fifelse(
  sensitivity_excluded,
  "excluded_mediator_source_meta_gwas_heterogeneity_p_lt_0_05",
  fifelse(is.finite(p), "retained_estimated", "retained_non_estimable")
)]

ccl11_my <- cy_my_het[mediator_id == "cytokine_CCL11", .(
  row_type = "mediator_to_ED", exposure_id = NA_character_,
  mediator_id, mediator_name, beta, se, p, q,
  source_heterogeneity_i2, source_heterogeneity_p,
  source_heterogeneity_rule, sensitivity_excluded,
  sensitivity_p_for_fdr, sensitivity_q, sensitivity_fdr_significant,
  sensitivity_analysis_status
)]
ccl11_ind <- cy_ind_het[mediator_id == "cytokine_CCL11", .(
  row_type = "indirect_effect", exposure_id,
  mediator_id, mediator_name, beta = indirect_beta, se = indirect_se, p, q,
  source_heterogeneity_i2, source_heterogeneity_p,
  source_heterogeneity_rule, sensitivity_excluded,
  sensitivity_p_for_fdr, sensitivity_q, sensitivity_fdr_significant,
  sensitivity_analysis_status
)]
ccl11_sensitivity <- rbindlist(list(ccl11_my, ccl11_ind), use.names = TRUE)
if (nrow(ccl11_sensitivity) != 6L ||
    !all(ccl11_sensitivity$sensitivity_excluded) ||
    any(ccl11_sensitivity$sensitivity_fdr_significant)) {
  stop("CCL11 source-heterogeneity sensitivity is incomplete", call. = FALSE)
}

full_path <- write_result(full, "mechanistic_screening_full_enriched.csv")
summary_path <- write_result(family_summary, "mechanistic_screening_family_summary.csv")
count_path <- write_result(count_audit, "mechanistic_screening_count_audit.csv")
cy_my_het_path <- write_result(
  cy_my_het, "mechanistic_cytokine_m_to_y_source_heterogeneity_sensitivity.csv"
)
cy_ind_het_path <- write_result(
  cy_ind_het, "mechanistic_cytokine_indirect_source_heterogeneity_sensitivity.csv"
)
ccl11_path <- write_result(
  ccl11_sensitivity, "mechanistic_ccl11_source_heterogeneity_sensitivity.csv"
)

input_paths <- c(
  file.path("05_results", "tables", paste0("mechanistic_", c(
    "x_to_y_total_effects", "cytokine_m_to_y", "endothelial_m_to_y",
    "cytokine_x_to_m", "endothelial_x_to_m", "cytokine_indirect",
    "endothelial_indirect"
  ), ".csv")),
  "08_qc/mechanistic_exposure_freeze.csv",
  "08_qc/mechanistic_full_validation_receipt.csv",
  "config/cytokine_cis_leads.csv",
  "03_data/processed/mechanistic/endothelial_instruments.parquet",
  "03_data/processed/instruments/instruments.parquet",
  "scripts/30_build_mechanistic_enriched_v0_3.R"
)
output_paths <- c(
  full_path, summary_path, count_path, cy_my_het_path, cy_ind_het_path,
  ccl11_path
)
receipt <- rbindlist(list(
  data.table(
    role = "input", artifact = input_paths,
    sha256 = vapply(file.path(project_root, input_paths), digest,
                    character(1), file = TRUE, algo = "sha256",
                    serialize = FALSE)
  ),
  data.table(
    role = "output", artifact = basename(output_paths),
    sha256 = vapply(output_paths, digest, character(1), file = TRUE,
                    algo = "sha256", serialize = FALSE)
  )
))
receipt[, completed_at_utc := format(
  Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
)]
receipt_path <- write_result(receipt, "mechanistic_enriched_v0_3_receipt.csv")

cat(sprintf(
  paste0(
    "Mechanistic v0.3 enrichment complete: %d rows across %d families; ",
    "%d non-estimable rows; %d FDR signals; %d cytokine cis leads excluded ",
    "in the source-heterogeneity sensitivity.\n"
  ),
  nrow(full), uniqueN(full$family), sum(!is.finite(full$p)),
  sum(full$fdr_significant), length(excluded_cytokines)
))
