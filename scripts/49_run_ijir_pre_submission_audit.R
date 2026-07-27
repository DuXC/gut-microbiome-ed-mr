#!/usr/bin/env Rscript

# Targeted pre-submission reproducibility and feasibility audit for IJIR.
# This script does not overwrite frozen primary MR results. It derives audit
# outputs only from frozen or previously versioned inputs.

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") {
  normalizePath(script_file)
} else {
  normalizePath(file.path("scripts", "49_run_ijir_pre_submission_audit.R"))
}
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

suppressPackageStartupMessages({
  library(arrow)
  library(digest)
})

output_dir <- file.path(
  project_root, "05_results", "v0_3_5_pre_submission_audit_20260728"
)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

read_csv <- function(path) {
  utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  )
}

write_csv <- function(x, filename) {
  utils::write.csv(
    x,
    file.path(output_dir, filename),
    row.names = FALSE,
    na = ""
  )
}

rel_path <- function(path) {
  sub(paste0("^", project_root, "/"), "", normalizePath(path))
}

# ---------------------------------------------------------------------------
# 1. METAL Z/sqrt(weight) reconstruction audit
# ---------------------------------------------------------------------------

metal_files <- c(
  ed_2025_eur = file.path(
    project_root, "03_data", "processed", "outcomes", "candidates",
    "ed_2025_eur.parquet"
  ),
  ed_2025_afr = file.path(
    project_root, "03_data", "processed", "outcomes", "candidates",
    "ed_2025_afr.parquet"
  ),
  ed_2025_cross_ancestry = file.path(
    project_root, "03_data", "processed", "outcomes", "candidates",
    "ed_2025_cross_ancestry.parquet"
  )
)

metal_rows <- lapply(names(metal_files), function(outcome_name) {
  dat <- arrow::read_parquet(metal_files[[outcome_name]], as_data_frame = TRUE)
  required <- c(
    "outcome_id", "rsid", "beta", "se", "z", "p", "sample_weight",
    "effect_scale", "sample_size_type"
  )
  if (!all(required %in% names(dat))) {
    stop("Missing required METAL audit fields: ", outcome_name, call. = FALSE)
  }
  expected_beta <- dat$z / sqrt(dat$sample_weight)
  expected_se <- 1 / sqrt(dat$sample_weight)
  reconstructed_z <- dat$beta / dat$se
  reconstructed_p <- 2 * stats::pnorm(-abs(reconstructed_z))
  data.frame(
    outcome_id = dat$outcome_id,
    rsid = dat$rsid,
    z_reported = dat$z,
    weight = dat$sample_weight,
    beta_star = dat$beta,
    se_star = dat$se,
    beta_expected = expected_beta,
    se_expected = expected_se,
    z_reconstructed = reconstructed_z,
    p_reported = dat$p,
    p_reconstructed = reconstructed_p,
    beta_abs_error = abs(dat$beta - expected_beta),
    se_abs_error = abs(dat$se - expected_se),
    z_abs_error = abs(reconstructed_z - dat$z),
    log10_p_abs_error = abs(
      log10(pmax(dat$p, .Machine$double.xmin)) -
        log10(pmax(reconstructed_p, .Machine$double.xmin))
    ),
    weight_definition = paste(
      "variant-specific cumulative METAL effective-sample-size weight;",
      "the source study used effective-sample-size weighted meta-analysis"
    ),
    transformation_scope = "applied per SNP",
    interpretation = paste(
      "screening scale preserving the SNP-level Z statistic and P value;",
      "not a clinical ED log-odds or OR scale"
    ),
    stringsAsFactors = FALSE
  )
})
metal_rows <- do.call(rbind, metal_rows)
write_csv(metal_rows, "metal_weight_transformation_audit.csv")

metal_summary <- do.call(
  rbind,
  lapply(split(metal_rows, metal_rows$outcome_id), function(x) {
    data.frame(
      outcome_id = x$outcome_id[[1L]],
      rows = nrow(x),
      minimum_weight = min(x$weight, na.rm = TRUE),
      maximum_weight = max(x$weight, na.rm = TRUE),
      maximum_beta_abs_error = max(x$beta_abs_error, na.rm = TRUE),
      maximum_se_abs_error = max(x$se_abs_error, na.rm = TRUE),
      maximum_z_abs_error = max(x$z_abs_error, na.rm = TRUE),
      maximum_log10_p_abs_error = max(x$log10_p_abs_error, na.rm = TRUE),
      beta_formula_verified = all(x$beta_abs_error < 1e-12),
      se_formula_verified = all(x$se_abs_error < 1e-12),
      z_identity_verified = all(x$z_abs_error < 1e-12),
      p_consistent_with_reported_rounded_z = all(x$log10_p_abs_error < 0.01),
      note = paste(
        "Small P-value differences may reflect the source file's rounded Z",
        "values; the project beta-star/SE-star ratio reproduces the stored Z."
      ),
      stringsAsFactors = FALSE
    )
  })
)
rownames(metal_summary) <- NULL
write_csv(metal_summary, "metal_weight_transformation_summary.csv")

metal_definition_source <- data.frame(
  field = c(
    "source_publication",
    "weight_definition",
    "effective_sample_size_formula",
    "project_transformation",
    "clinical_interpretation"
  ),
  verified_value = c(
    paste(
      "Wu et al. Genetic insights into the shared etiology of erectile",
      "dysfunction and related traits. Nature Communications (2025)."
    ),
    "cumulative effective-sample-size weight used by METAL",
    "4 / (1/n_cases + 1/n_controls), as defined by the source publication",
    "beta-star=Z/sqrt(W); SE-star=1/sqrt(W), applied per SNP",
    "not an ED log-odds or clinically interpretable OR scale"
  ),
  verification_basis = c(
    "source-study Methods and data release",
    "source-study Methods: meta-analysis weighted by effective sample size",
    "source-study table footnote",
    "R/outcomes.R::normalize_ed_meta_outcome and numerical audit",
    "scale construction and absence of a cohort-level clinical beta"
  ),
  stringsAsFactors = FALSE
)
write_csv(metal_definition_source, "metal_weight_definition_source.csv")

# ---------------------------------------------------------------------------
# 2. Reverse ED instrument construction audit
# ---------------------------------------------------------------------------

reverse_inventory_path <- file.path(
  project_root, "08_qc", "reverse_ed_instrument_inventory.csv"
)
reverse_inventory <- read_csv(reverse_inventory_path)
if (nrow(reverse_inventory) != 1L) {
  stop("Unexpected reverse instrument inventory length", call. = FALSE)
}

reverse_audit <- data.frame(
  step = c(
    "source association scale",
    "genome-wide significance selection",
    "strength filter",
    "candidate variants",
    "1000 Genomes EUR reference availability",
    "allele-matched reference variants",
    "within-exposure clumping",
    "final instruments",
    "association/reference builds",
    "allele harmonization",
    "palindromic policy",
    "multiallelic policy",
    "proxy policy",
    "missing-SNP policy"
  ),
  verified_value = c(
    "METAL Z/sqrt(effective-sample-size weight) screening scale",
    "P<5e-8",
    "F=(beta-star/SE-star)^2>10",
    as.character(reverse_inventory$candidate_snps),
    as.character(reverse_inventory$reference_panel_snps),
    as.character(reverse_inventory$allele_mapped_snps),
    paste0(
      "PLINK clumping r2<", reverse_inventory$r2,
      " within ", format(reverse_inventory$kb, scientific = FALSE),
      " kb, separately for the ED exposure"
    ),
    as.character(reverse_inventory$post_clump_snps),
    "ED associations GRCh38; 1000 Genomes Phase 3 EUR LD reference GRCh37",
    paste(
      "exact rsID plus compatible A/C/G/T alleles across declared builds;",
      "effect directions harmonized to the exposure effect allele"
    ),
    paste(
      "EAF-assisted; MAF<=0.42 in both datasets; exactly one frequency",
      "orientation within absolute EAF tolerance 0.10; otherwise excluded"
    ),
    paste(
      "biallelic A/C/G/T reference variants only; more than one compatible",
      "outcome match is excluded as multiallelic_multiple_matches"
    ),
    "no proxy substitution; exact rsID only",
    paste(
      "variants absent from the LD reference, without a unique compatible",
      "allele match, or absent from an outcome are excluded and recorded"
    )
  ),
  source = c(
    "R/outcomes.R",
    "R/reverse_instruments.R",
    "R/reverse_instruments.R",
    rel_path(reverse_inventory_path),
    rel_path(reverse_inventory_path),
    rel_path(reverse_inventory_path),
    "R/reverse_instruments.R and reverse PLINK logs",
    rel_path(reverse_inventory_path),
    "R/reverse_instruments.R and reverse-instrument receipt",
    "R/harmonization.R",
    "R/harmonization.R",
    "R/reverse_instruments.R and R/harmonization.R",
    "R/harmonization.R",
    "R/reverse_instruments.R and R/harmonization.R"
  ),
  stringsAsFactors = FALSE
)
write_csv(reverse_audit, "reverse_instrument_construction_audit.csv")

# Independently reproduce the locked result counts and family-wise BH values
# from the frozen primary result tables.
forward_frozen_path <- file.path(
  project_root, "05_results", "tables", "mr_multiplicity_forward.csv"
)
reverse_frozen_path <- file.path(
  project_root, "05_results", "tables", "reverse_mr_multiplicity.csv"
)
hunt_summary_path <- file.path(
  project_root, "05_results", "v0_3_20260722",
  "hunt_same_snp_validation_summary.csv"
)
hunt_unique_path <- file.path(
  project_root, "05_results", "v0_3_2_derived_20260723",
  "hunt_same_snp_unique_snp_summary.csv"
)
power_summary_path <- file.path(
  project_root, "05_results", "v0_3_20260722", "power_mde_summary.csv"
)
mechanism_summary_path <- file.path(
  project_root, "05_results", "v0_3_20260722",
  "mechanistic_screening_family_summary.csv"
)

forward_frozen <- read_csv(forward_frozen_path)
reverse_frozen <- read_csv(reverse_frozen_path)
hunt_summary <- read_csv(hunt_summary_path)
hunt_unique <- read_csv(hunt_unique_path)
power_summary <- read_csv(power_summary_path)
mechanism_summary <- read_csv(mechanism_summary_path)
hunt_unique_row <- hunt_unique[
  hunt_unique$analysis == "unique-SNP sensitivity",
  , drop = FALSE
]
if (nrow(hunt_unique_row) != 1L) {
  stop("Unique-SNP HUNT summary row was not identified", call. = FALSE)
}

forward_p_full <- ifelse(
  forward_frozen$analysis_status == "estimated" & is.finite(forward_frozen$p),
  forward_frozen$p,
  1
)
forward_q_recomputed <- stats::p.adjust(forward_p_full, method = "BH")
reverse_p_full <- ifelse(
  reverse_frozen$analysis_status == "estimated" & is.finite(reverse_frozen$p),
  reverse_frozen$p,
  1
)
reverse_q_recomputed <- stats::p.adjust(reverse_p_full, method = "BH")

power_bonf <- power_summary[
  power_summary$alpha_label == "forward_bonferroni_0.05_over_230",
  , drop = FALSE
]
primary_reproduction <- data.frame(
  check = c(
    "forward eligible traits",
    "forward estimable traits",
    "forward nominal rows",
    "forward FDR rows",
    "forward BH q values",
    "reverse tests",
    "reverse estimable tests",
    "reverse nominal rows",
    "reverse FDR rows",
    "reverse BH q values",
    "HUNT exact-label rows",
    "HUNT trait-row concordance",
    "HUNT unique lead rsIDs",
    "HUNT unique-rsID concordance",
    "forward Bonferroni median MDE OR",
    "traits with 80% power for OR=2 at forward Bonferroni alpha",
    "mechanistic FDR rows"
  ),
  observed = c(
    nrow(forward_frozen),
    sum(forward_frozen$analysis_status == "estimated"),
    sum(forward_frozen$analysis_status == "estimated" & forward_frozen$p < 0.05),
    sum(forward_q_recomputed < 0.05),
    max(abs(forward_q_recomputed - forward_frozen$q), na.rm = TRUE),
    nrow(reverse_frozen),
    sum(reverse_frozen$analysis_status == "estimated"),
    sum(reverse_frozen$analysis_status == "estimated" & reverse_frozen$p < 0.05),
    sum(reverse_q_recomputed < 0.05),
    max(abs(reverse_q_recomputed - reverse_frozen$q), na.rm = TRUE),
    hunt_summary$exact_label_forward_traits[[1L]],
    paste0(
      hunt_summary$direction_concordant[[1L]], "/",
      hunt_summary$exact_label_forward_traits[[1L]]
    ),
    hunt_unique_row$denominator[[1L]],
    paste0(
      hunt_unique_row$direction_concordant[[1L]], "/",
      hunt_unique_row$denominator[[1L]]
    ),
    power_bonf$mde_or_median[[1L]],
    power_bonf$traits_power_80_for_or_2_00_or_larger[[1L]],
    sum(mechanism_summary$fdr_significant_tests)
  ),
  expected = c(
    230, 218, 7, 0, 0,
    1572, 1572, 77, 0, 0,
    97, "76/97", 90, "69/90",
    2.893515, 1, 0
  ),
  tolerance_or_rule = c(
    rep("exact", 4),
    "maximum absolute q difference <1e-12",
    rep("exact", 4),
    "maximum absolute q difference <1e-12",
    rep("exact", 4),
    "absolute difference <0.001; manuscript rounds to 2.89",
    "exact",
    "exact"
  ),
  stringsAsFactors = FALSE
)
numeric_observed <- suppressWarnings(as.numeric(primary_reproduction$observed))
numeric_expected <- suppressWarnings(as.numeric(primary_reproduction$expected))
primary_reproduction$pass <- ifelse(
  is.finite(numeric_observed) & is.finite(numeric_expected),
  ifelse(
    grepl("0.001", primary_reproduction$tolerance_or_rule),
    abs(numeric_observed - numeric_expected) < 0.001,
    ifelse(
      grepl("1e-12", primary_reproduction$tolerance_or_rule),
      abs(numeric_observed - numeric_expected) < 1e-12,
      numeric_observed == numeric_expected
    )
  ),
  as.character(primary_reproduction$observed) ==
    as.character(primary_reproduction$expected)
)
write_csv(primary_reproduction, "frozen_primary_reproduction_audit.csv")

# ---------------------------------------------------------------------------
# 3. Alternative-outcome multiplicity and redundancy-aware post hoc audit
# ---------------------------------------------------------------------------

bh_summary_path <- file.path(
  project_root, "05_results", "v0_3_3_derived_20260723",
  "alternative_outcome_bh_summary_v0_3_3.csv"
)
bh_rows_path <- file.path(
  project_root, "05_results", "v0_3_3_derived_20260723",
  "alternative_outcome_bh_fdr_rows_v0_3_3.csv"
)
locus_trait_path <- file.path(
  project_root, "05_results", "v0_3_2_derived_20260723",
  "ed_2025_sensitivity_trait_locus_audit.csv"
)
ld_path <- file.path(
  project_root, "05_results", "v0_3_2_derived_20260723",
  "ed_2025_sensitivity_pairwise_ld_eur.csv"
)

bh_summary <- read_csv(bh_summary_path)
bh_rows <- read_csv(bh_rows_path)
locus_trait <- read_csv(locus_trait_path)
ld <- read_csv(ld_path)

expected_outcomes <- c("ed_2025_eur", "ed_2025_afr", "ed_2025_cross_ancestry")
if (!setequal(bh_summary$outcome_id, expected_outcomes)) {
  stop("Alternative outcome family audit is incomplete", call. = FALSE)
}
if (!all(bh_summary$full_family_denominator == 230L)) {
  stop("Alternative outcome full-family denominator is not 230", call. = FALSE)
}

bh_family_audit <- bh_summary[, c(
  "outcome_id", "outcome_ancestry", "full_family_denominator",
  "estimable_only_denominator", "non_estimable_rows_retained_p1",
  "full_family_fdr_rows", "estimable_only_fdr_rows",
  "full_vs_estimable_fdr_row_set_identical", "non_estimable_handling",
  "includes_finngen", "overlap_with_primary_finngen", "final_evidence_role"
)]
bh_family_audit$family_role <- paste(
  "separate alternative-outcome sensitivity family;",
  "full-family BH is primary for this sensitivity"
)
write_csv(bh_family_audit, "alternative_outcome_bh_family_audit.csv")

eur_ids <- sort(
  bh_rows$source_id[bh_rows$outcome_id == "ed_2025_eur" & bh_rows$full_family_fdr]
)
cross_ids <- sort(
  bh_rows$source_id[
    bh_rows$outcome_id == "ed_2025_cross_ancestry" & bh_rows$full_family_fdr
  ]
)
if (!identical(eur_ids, cross_ids)) {
  stop("EUR and cross-ancestry FDR row sets differ", call. = FALSE)
}

fdr_eur <- bh_rows[
  bh_rows$outcome_id == "ed_2025_eur" & bh_rows$full_family_fdr,
  , drop = FALSE
]
fdr_eur <- merge(
  fdr_eur,
  locus_trait[, c(
    "source_id", "lead_snp", "effect_allele", "other_allele", "eaf",
    "exposure_beta", "exposure_se", "exposure_p", "F_statistic",
    "phenotype_type", "trait_class", "taxonomy_level", "taxonomy_cluster",
    "eur_beta", "eur_se", "eur_p", "eur_q", "cross_beta", "cross_se",
    "cross_p", "cross_q", "afr_beta", "afr_se", "afr_p", "afr_q",
    "afr_analysis_status", "finngen_beta", "finngen_se", "finngen_p",
    "finngen_q", "nearest_gene", "locus_id", "locus_name"
  )],
  by = "source_id",
  all.x = TRUE,
  sort = FALSE
)
fdr_eur <- fdr_eur[match(eur_ids, fdr_eur$source_id), , drop = FALSE]

fdr_eur$exact_estimand_signature <- with(
  fdr_eur,
  paste(
    lead_snp,
    sprintf("%.16g", exposure_beta),
    sprintf("%.16g", exposure_se),
    sprintf("%.16g", exposure_p),
    sprintf("%.16g", eur_beta),
    sprintf("%.16g", eur_se),
    sprintf("%.16g", eur_p),
    sep = "|"
  )
)
fdr_eur$deterministic_source_order <- rank(
  fdr_eur$source_id, ties.method = "first"
)
signature_representative <- tapply(
  fdr_eur$source_id,
  fdr_eur$exact_estimand_signature,
  function(x) sort(x)[[1L]]
)
fdr_eur$exact_estimand_representative <- unname(
  signature_representative[fdr_eur$exact_estimand_signature]
)
fdr_eur$representative_rule <- paste(
  "lexicographically earliest frozen Swedish source_id within an exact",
  "estimand signature; selection is independent of outcome P"
)
fdr_eur$unique_lead_snp_trait_row_count <- ave(
  fdr_eur$source_id, fdr_eur$lead_snp, FUN = length
)
fdr_eur$ld_locus_threshold <- "1000 Genomes Phase 3 EUR pairwise r2>=0.8"
fdr_eur$locus_level_p_or_q <- NA_real_
fdr_eur$locus_inference <- paste(
  "descriptive compression only; no formal locus-level P or q because",
  "correlated, non-identical trait-SNP estimands were not combined"
)
write_csv(fdr_eur, "alternative_outcome_redundancy_audit.csv")

snp_counts <- aggregate(source_id ~ lead_snp, data = fdr_eur, FUN = length)
names(snp_counts)[2L] <- "trait_rows"
snp_counts <- snp_counts[order(-snp_counts$trait_rows, snp_counts$lead_snp), ]
rownames(snp_counts) <- NULL
write_csv(snp_counts, "alternative_outcome_unique_snp_compression.csv")

if (
  nrow(ld) != 3L ||
    !all(ld$population == "1000GENOMES:phase_3:EUR") ||
    !all(ld$r2 >= 0.8)
) {
  stop("European LD compression criteria are not satisfied", call. = FALSE)
}
ld_summary <- data.frame(
  eur_fdr_trait_rows = length(eur_ids),
  cross_ancestry_fdr_trait_rows = length(cross_ids),
  identical_eur_cross_row_sets = identical(eur_ids, cross_ids),
  unique_lead_snps = length(unique(fdr_eur$lead_snp)),
  unique_ld_defined_loci = 1L,
  locus_name = "chr2q21 LCT/MCM6 lactase-persistence region",
  snps = paste(sort(unique(fdr_eur$lead_snp)), collapse = ";"),
  minimum_pairwise_eur_r2 = min(ld$r2),
  maximum_pairwise_eur_r2 = max(ld$r2),
  ld_reference = "1000 Genomes Phase 3 EUR via Ensembl REST pairwise-LD endpoint",
  ld_threshold = 0.8,
  interpretation = paste(
    "Eight trait-level associations correspond to three highly correlated",
    "single-variant estimands in one region; they are not eight independent",
    "microbial findings. No locus-level P or q was computed."
  ),
  stringsAsFactors = FALSE
)
write_csv(ld_summary, "alternative_outcome_ld_compression_summary.csv")

# Re-audit the frozen primary Peptococcaceae nested exact-estimand cluster.
primary_results_path <- file.path(
  project_root, "05_results", "v0_3_20260722",
  "multiplicity_sensitivity_trait_results.csv"
)
primary_results <- read_csv(primary_results_path)
peptococcaceae <- primary_results[
  grepl("Peptococc", primary_results$trait, fixed = TRUE),
  c(
    "source_id", "trait", "instrument_signature", "beta", "se", "p", "q",
    "exact_group_id", "exact_group_members",
    "nested_taxonomic_lineage_verified", "signal_cluster"
  ),
  drop = FALSE
]
peptococcaceae <- peptococcaceae[order(peptococcaceae$source_id), ]
peptococcaceae$deterministic_representative <- peptococcaceae$source_id[[1L]]
peptococcaceae$representative_rule <- paste(
  "earliest frozen Swedish source_id; selection independent of outcome P"
)
write_csv(peptococcaceae, "primary_peptococcaceae_nested_cluster_audit.csv")

# ---------------------------------------------------------------------------
# 4. Steiger feasibility and multi-SNP diagnostic implementation audit
# ---------------------------------------------------------------------------

power_path <- file.path(
  project_root, "05_results", "v0_3_20260722", "power_mde_trait_results.csv"
)
diagnostic_path <- file.path(
  project_root, "05_results", "v0_3_20260722",
  "forward_diagnostic_trigger_status.csv"
)
method_path <- file.path(
  project_root, "05_results", "v0_3_20260722",
  "forward_all_method_results.csv"
)

power <- read_csv(power_path)
power_nominal <- power[power$alpha_label == "nominal_0.05", c(
  "source_id", "phenotype", "exposure_scale", "nsnp", "r2",
  "r2_prevalence_scenario_min", "r2_prevalence_scenario_max",
  "source_reported_prevalence"
)]
primary_base <- primary_results[, c(
  "pair_id", "source_id", "trait", "nsnp", "p", "q", "analysis_status"
)]
diagnostic <- read_csv(diagnostic_path)

steiger <- merge(primary_base, power_nominal, by = "source_id", all.x = TRUE)
steiger <- merge(
  steiger,
  diagnostic[, c("pair_id", "steiger_status", "steiger_reason")],
  by = "pair_id",
  all.x = TRUE
)
steiger$nominal_forward_association <- is.finite(steiger$p) & steiger$p < 0.05
steiger$exposure_r2_used_for_feasibility_audit <- steiger$r2
steiger$outcome_r2 <- NA_real_
steiger$inferred_direction <- NA_character_
steiger$steiger_p <- NA_real_
steiger$revised_steiger_status <- "not_estimable"
steiger$revised_steiger_reason <- ifelse(
  steiger$analysis_status != "estimated",
  paste(
    "primary MR pair not estimable; absence of a Steiger result is not",
    "directional support"
  ),
  ifelse(
    grepl("presence", steiger$phenotype, ignore.case = TRUE),
    paste(
      "binary-outcome population prevalence was not defined and microbial",
      "presence requires a liability-scale approximation; outcome R2 and a",
      "valid Steiger P value were therefore not computed"
    ),
    paste(
      "binary-outcome population prevalence was not defined; outcome R2 and",
      "a valid Steiger P value were therefore not computed"
    )
  )
)
steiger$interpretation <- paste(
  "not estimable is not evidence supporting the exposure-to-outcome direction"
)
steiger <- steiger[order(steiger$source_id), ]
write_csv(steiger, "steiger_feasibility_audit.csv")

methods <- read_csv(method_path)
status_count <- function(method_name, status_name) {
  sum(
    methods$method == method_name & methods$analysis_status == status_name,
    na.rm = TRUE
  )
}
diag_rows <- list(
  data.frame(
    diagnostic = "Cochran Q",
    minimum_snps = 2L,
    estimated = sum(is.finite(diagnostic$ivw_Q)),
    not_estimable = sum(!is.finite(diagnostic$ivw_Q)),
    failed_to_converge = 0L,
    not_triggered_under_original_candidate_rule = 0L,
    operational_note = paste(
      "reported only for multi-SNP IVW estimands; single-SNP Wald ratios have",
      "no heterogeneity degrees of freedom"
    )
  ),
  data.frame(
    diagnostic = "MR-Egger intercept",
    minimum_snps = 3L,
    estimated = sum(is.finite(diagnostic$egger_intercept)),
    not_estimable = sum(!is.finite(diagnostic$egger_intercept)),
    failed_to_converge = 0L,
    not_triggered_under_original_candidate_rule = 0L,
    operational_note = "not applicable to single-SNP Wald ratios"
  ),
  data.frame(
    diagnostic = "Weighted median",
    minimum_snps = 3L,
    estimated = status_count("mr_weighted_median", "estimated"),
    not_estimable = status_count("mr_weighted_median", "not_estimable"),
    failed_to_converge = status_count("mr_weighted_median", "failed"),
    not_triggered_under_original_candidate_rule = 0L,
    operational_note = "estimated only where the implementation requirements were met"
  ),
  data.frame(
    diagnostic = "MR-Egger slope",
    minimum_snps = 3L,
    estimated = status_count("mr_egger_regression", "estimated"),
    not_estimable = status_count("mr_egger_regression", "not_estimable"),
    failed_to_converge = status_count("mr_egger_regression", "failed"),
    not_triggered_under_original_candidate_rule = 0L,
    operational_note = "estimated only where the implementation requirements were met"
  ),
  data.frame(
    diagnostic = "MR-RAPS",
    minimum_snps = 2L,
    estimated = status_count("mr_raps", "estimated"),
    not_estimable = status_count("mr_raps", "not_estimable"),
    failed_to_converge = status_count("mr_raps", "failed"),
    not_triggered_under_original_candidate_rule = 0L,
    operational_note = paste(
      "one failed fit is described as failed to converge and retained as a",
      "recorded failure"
    )
  ),
  data.frame(
    diagnostic = "MR-PRESSO",
    minimum_snps = 4L,
    estimated = 0L,
    not_estimable = sum(diagnostic$nsnp < 4L),
    failed_to_converge = 0L,
    not_triggered_under_original_candidate_rule = sum(diagnostic$nsnp >= 4L),
    operational_note = paste(
      "candidate-triggered in the frozen framework; no trait met the original",
      "corrected candidate trigger"
    )
  ),
  data.frame(
    diagnostic = "Leave-one-out",
    minimum_snps = 3L,
    estimated = 0L,
    not_estimable = sum(diagnostic$nsnp < 3L),
    failed_to_converge = 0L,
    not_triggered_under_original_candidate_rule = sum(diagnostic$nsnp >= 3L),
    operational_note = paste(
      "candidate-triggered in the frozen framework; unavailable for all seven",
      "single-SNP nominal forward associations"
    )
  )
)
diagnostic_audit <- do.call(rbind, diag_rows)
rownames(diagnostic_audit) <- NULL
write_csv(diagnostic_audit, "forward_diagnostic_implementation_audit.csv")

mr_raps_failure <- methods[
  methods$method == "mr_raps" & methods$analysis_status == "failed",
  c(
    "source_id", "trait", "nsnp", "analysis_status", "error_message",
    "warning_message"
  ),
  drop = FALSE
]
if (nrow(mr_raps_failure)) {
  mr_raps_failure$reporting_phrase <- paste(
    "failed to converge and was retained as a recorded failure"
  )
}
write_csv(mr_raps_failure, "mr_raps_recorded_failures.csv")

# ---------------------------------------------------------------------------
# 5. Colocalization feasibility and analysis-role audit
# ---------------------------------------------------------------------------

coloc_audit <- data.frame(
  component = c(
    "regional microbial exposure summary statistics",
    "regional 2025 EUR ED summary statistics",
    "genome build and alleles",
    "ED allele frequency",
    "ED likelihood/effect scale",
    "ancestry-matched LD",
    "final decision"
  ),
  availability = c(
    "available for the relevant Swedish microbial traits",
    "available as METAL Z scores and cumulative effective-sample-size weights",
    "available but requires GRCh37/GRCh38 cross-build harmonization",
    "not supplied in the processed 2025 ED release",
    paste(
      "screening statistic available; not a validated clinical log-odds",
      "estimate for conventional binary-outcome coloc"
    ),
    "1000 Genomes Phase 3 EUR available",
    "formal regional colocalization not performed"
  ),
  implication = c(
    "necessary but not sufficient",
    "necessary but not sufficient",
    "technically possible with explicit validation",
    "prevents reliable case-control likelihood specification",
    paste(
      "Z-only methods would add unvalidated scale and LD assumptions in this",
      "submission revision"
    ),
    "external-reference LD would add approximation",
    paste(
      "exact-rsID annotation raises pleiotropy concerns but cannot establish",
      "a shared causal variant or microbial mediation"
    )
  ),
  stringsAsFactors = FALSE
)
write_csv(coloc_audit, "colocalization_feasibility_audit.csv")

analysis_role_audit <- data.frame(
  analysis = c(
    "primary eligibility and instrument rules",
    "FinnGen primary forward MR",
    "reverse MR",
    "complete BH families",
    "source-study-wide sensitivity",
    "estimable-only and nested-signal sensitivity",
    "HUNT exact-label same-SNP design",
    "bounded mechanistic families",
    "power/MDE analysis",
    "known-overlap evidence classification",
    "2025 FDR-row trait compression",
    "unique lead-SNP compression",
    "cross-trait European-LD compression",
    "Ensembl/GWAS Catalog/OpenGWAS exact-rsID annotation",
    "pre-submission Steiger feasibility audit"
  ),
  final_role = c(
    rep("defined before association screening", 10),
    rep("targeted post hoc explanatory audit", 4),
    "supplementary diagnostic feasibility audit added at revision"
  ),
  changes_primary_result = FALSE,
  stringsAsFactors = FALSE
)
write_csv(analysis_role_audit, "analysis_role_classification_audit.csv")

# ---------------------------------------------------------------------------
# 6. Mechanistic exposure traceability and data-independence definition
# ---------------------------------------------------------------------------

mechanistic_exposure_path <- file.path(
  project_root, "config", "mechanistic_exposures.csv"
)
mechanistic_freeze_path <- file.path(
  project_root, "08_qc", "mechanistic_exposure_freeze.csv"
)
mechanistic_exposures <- read_csv(mechanistic_exposure_path)
mechanistic_freeze <- read_csv(mechanistic_freeze_path)
mechanistic_trace <- merge(
  mechanistic_exposures,
  mechanistic_freeze,
  by = intersect(names(mechanistic_exposures), names(mechanistic_freeze)),
  all.x = TRUE
)
mechanistic_trace$selection_basis <- paste(
  "biological rationale plus one clumped HUNT genome-wide-significant",
  "F>10 instrument; selected without reference to ED association P values"
)
mechanistic_trace$freeze_record <- paste(
  "01_protocol/mechanistic_extension_v0_2.md;",
  "08_qc/mechanistic_extension_freeze_receipt.csv"
)
mechanistic_trace$primary_result_triggered <- "no"
mechanistic_trace$supplement_location <- paste(
  "Supplementary Data: mechanistic instrument inventory and full screening",
  "families"
)
write_csv(mechanistic_trace, "mechanistic_five_function_traceability.csv")

independence_definition <- data.frame(
  label = c("none_known", "possible_unresolved", "known_partial"),
  operational_definition = c(
    paste(
      "no identified cohort contribution shared between the component GWAS",
      "after source-cohort review"
    ),
    paste(
      "cohort lists or participant-level overlap could not be resolved",
      "sufficiently to exclude overlap"
    ),
    "a named cohort or source component is shared"
  ),
  screening_use = c(
    "eligible for higher evidence classification if all other criteria pass",
    "screening/sensitivity only",
    "screening/sensitivity only"
  ),
  mediation_compatible = c(
    "possible only if component FDR, direction, colocalization, and pleiotropy criteria also pass",
    "no",
    "no"
  ),
  stringsAsFactors = FALSE
)
write_csv(independence_definition, "acceptable_data_independence_definition.csv")

# ---------------------------------------------------------------------------
# 7. Receipt
# ---------------------------------------------------------------------------

input_files <- unique(c(
  unname(metal_files),
  reverse_inventory_path,
  forward_frozen_path,
  reverse_frozen_path,
  hunt_summary_path,
  hunt_unique_path,
  power_summary_path,
  mechanism_summary_path,
  bh_summary_path,
  bh_rows_path,
  locus_trait_path,
  ld_path,
  primary_results_path,
  power_path,
  diagnostic_path,
  method_path,
  mechanistic_exposure_path,
  mechanistic_freeze_path,
  script_path,
  file.path(project_root, "R", "outcomes.R"),
  file.path(project_root, "R", "reverse_instruments.R"),
  file.path(project_root, "R", "harmonization.R"),
  file.path(project_root, "01_protocol", "mechanistic_extension_v0_2.md")
))
receipt <- data.frame(
  artifact = vapply(input_files, rel_path, character(1)),
  sha256 = vapply(input_files, function(path) {
    digest::digest(path, algo = "sha256", file = TRUE, serialize = FALSE)
  }, character(1)),
  role = "input_or_code",
  stringsAsFactors = FALSE
)

output_files <- list.files(output_dir, full.names = TRUE)
output_receipt <- data.frame(
  artifact = vapply(output_files, rel_path, character(1)),
  sha256 = vapply(output_files, function(path) {
    digest::digest(path, algo = "sha256", file = TRUE, serialize = FALSE)
  }, character(1)),
  role = "derived_audit_output",
  stringsAsFactors = FALSE
)
receipt <- rbind(receipt, output_receipt)
write_csv(receipt, "pre_submission_audit_receipt.csv")

message(
  "IJIR pre-submission audit complete: ",
  rel_path(output_dir),
  " (", length(list.files(output_dir)), " outputs)"
)
