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
  library(TwoSampleMR)
  library(yaml)
})

source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "gwas_schema.R"))
source(file.path(project_root, "R", "exposure_candidates.R"))
source(file.path(project_root, "R", "instruments.R"))
source(file.path(project_root, "R", "mr_core.R"))

output_root <- file.path(project_root, "05_results", "v0_3_20260722")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
workers <- suppressWarnings(as.integer(Sys.getenv("V03_ANALYSIS_WORKERS", "4")))
if (is.na(workers) || workers < 1L) {
  stop("V03_ANALYSIS_WORKERS must be a positive integer", call. = FALSE)
}

write_output <- function(x, name) {
  path <- file.path(output_root, name)
  atomic_write_csv(as.data.frame(x), path)
  path
}

trait_category <- function(trait) {
  fcase(
    grepl("alpha diversity", trait, ignore.case = TRUE), "diversity",
    grepl("microbiome function", trait, ignore.case = TRUE), "function",
    grepl("species", trait, ignore.case = TRUE), "species",
    default = "higher_taxa"
  )
}

source_threshold <- function(category) {
  fcase(
    category == "diversity", 1.7e-8,
    category == "function", 4.3e-10,
    default = 5.4e-11
  )
}

metadata <- fread(file.path(project_root, "08_qc", "exposure_metadata_catalog.csv"))[
  dataset == "microbiome_2026"
]
metadata[, phenotype_category := trait_category(trait)]
metadata[, source_study_threshold := source_threshold(phenotype_category)]
if (nrow(metadata) != 1572L || anyDuplicated(metadata$source_id)) {
  stop("The Swedish source catalog must contain 1,572 unique traits", call. = FALSE)
}

threshold_ledger <- unique(metadata[, .(
  phenotype_category, source_study_threshold
)])
threshold_ledger[, source_article_doi := "10.1038/s41588-026-02512-2"]
threshold_ledger[, source_definition := fcase(
  phenotype_category == "diversity",
  "conventional genome-wide threshold divided by three alpha-diversity metrics",
  phenotype_category == "function",
  "conventional genome-wide threshold divided by 117 functional modules",
  phenotype_category %in% c("species", "higher_taxa"),
  "conventional genome-wide threshold divided by 921 species; the source applied the same threshold to higher taxa"
)]
threshold_ledger[, display_order := match(
  phenotype_category, c("diversity", "species", "higher_taxa", "function")
)]
setorder(threshold_ledger, display_order)
threshold_ledger[, display_order := NULL]
threshold_ledger_path <- write_output(
  threshold_ledger, "source_study_threshold_ledger.csv"
)

# Source-study-wide instrument reconstruction and re-clumping -----------------
candidate_root <- file.path(
  project_root, "03_data", "processed", "exposure_candidates", "microbiome_2026"
)
candidates <- as.data.table(read_exposure_candidate_shards(candidate_root))
reference_map_path <- file.path(
  project_root, "08_qc", "download_cache", "ld_reference_high_density",
  "candidate_pvar_matches_chr_normalized.tsv"
)
reference_map <- read_reference_variant_map(reference_map_path, build = "GRCh37")
candidates <- as.data.table(map_candidates_to_reference(
  as.data.frame(candidates), reference_map, reference_build = "GRCh37"
))
candidates <- merge(
  candidates,
  metadata[, .(source_id, phenotype_category, source_study_threshold)],
  by = "source_id", all.x = TRUE, sort = FALSE
)
if (anyNA(candidates$source_study_threshold)) {
  stop("Could not assign a source-study threshold to every candidate", call. = FALSE)
}
candidates <- as.data.table(add_f_stat(as.data.frame(candidates)))
candidates[, below_source_threshold := p < source_study_threshold]
candidates[, strong_at_source_threshold := below_source_threshold & F > 10]
candidates[, mapped_at_source_threshold :=
  strong_at_source_threshold & reference_mapping_status == "allele_key_match"]

strict_mapped <- candidates[mapped_at_source_threshold == TRUE]
eligible_ids <- unique(strict_mapped$source_id)
plink_binary <- file.path(
  project_root, "08_qc", "download_cache", "tools", "plink", "plink"
)
bfile_prefix <- file.path(
  project_root, "03_data", "processed", "ld_reference_high_density",
  "eur_candidate_chr_normalized_v2"
)

clump_one <- function(source) {
  x <- strict_mapped[source_id == source]
  threshold <- unique(x$source_study_threshold)
  if (length(threshold) != 1L) {
    stop("Non-unique source threshold for ", source, call. = FALSE)
  }
  retained_ids <- clump_local(
    as.data.frame(x), requested_ancestry = "EUR", reference_ancestry = "EUR",
    plink_binary = plink_binary, bfile_prefix = bfile_prefix,
    p_threshold = threshold, r2 = 0.001, kb = 10000
  )
  retained <- x[match(retained_ids, reference_id), nomatch = 0L]
  retained[, sensitivity_tier := "source_study_wide"]
  retained
}

strict_parts <- if (.Platform$OS.type == "unix" && workers > 1L) {
  parallel::mclapply(
    eligible_ids, clump_one, mc.cores = workers, mc.preschedule = FALSE
  )
} else {
  lapply(eligible_ids, clump_one)
}
failed <- vapply(strict_parts, inherits, logical(1), what = "try-error")
if (any(failed)) {
  stop(
    "Source-study-wide clumping failed: ",
    paste(as.character(strict_parts[failed]), collapse = " | "), call. = FALSE
  )
}
strict_instruments <- rbindlist(strict_parts, use.names = TRUE, fill = TRUE)
setorder(strict_instruments, source_id, p, reference_id)

strict_inventory <- merge(
  metadata[, .(
    source_id, trait, phenotype_category, source_study_threshold
  )],
  candidates[, .(
    candidate_rows_below_threshold = sum(below_source_threshold),
    strong_rows_below_threshold = sum(strong_at_source_threshold),
    mapped_rows_below_threshold = sum(mapped_at_source_threshold)
  ), by = source_id],
  by = "source_id", all.x = TRUE, sort = FALSE
)
for (column in c(
  "candidate_rows_below_threshold", "strong_rows_below_threshold",
  "mapped_rows_below_threshold"
)) set(strict_inventory, which(is.na(strict_inventory[[column]])), column, 0L)
post_counts <- strict_instruments[, .(
  post_clump_snps = .N,
  min_F = min(F), mean_F = mean(F), min_exposure_p = min(p)
), by = source_id]
strict_inventory <- merge(
  strict_inventory, post_counts, by = "source_id", all.x = TRUE, sort = FALSE
)
strict_inventory[is.na(post_clump_snps), post_clump_snps := 0L]
strict_inventory[, eligibility_status := fcase(
  candidate_rows_below_threshold == 0L, "no_variant_below_source_threshold",
  strong_rows_below_threshold == 0L, "no_strong_variant_below_source_threshold",
  mapped_rows_below_threshold == 0L, "no_reference_mapped_variant",
  post_clump_snps == 0L, "no_variant_after_reclumping",
  default = "eligible"
)]
setorder(strict_inventory, source_id)

strict_instrument_columns <- c(
  "source_id", "trait", "phenotype_category", "source_study_threshold",
  "reference_id", "variant_key", "chr", "pos", "ea", "oa", "eaf",
  "beta", "se", "p", "F", "n", "build", "ancestry",
  "reference_ref", "reference_alt", "reference_allele_relation",
  "sensitivity_tier"
)
strict_instruments_path <- write_output(
  strict_instruments[, ..strict_instrument_columns],
  "source_study_wide_instruments.csv"
)
strict_inventory_path <- write_output(
  strict_inventory, "source_study_wide_instrument_inventory.csv"
)

original_instruments <- as.data.table(read_parquet(file.path(
  project_root, "03_data", "processed", "instruments", "instruments.parquet"
)))[dataset == "microbiome_2026" & tier == "primary"]
strict_keys <- paste(strict_instruments$source_id, strict_instruments$reference_id)
primary_keys <- paste(original_instruments$source_id, original_instruments$reference_id)
if (length(setdiff(strict_keys, primary_keys))) {
  stop(
    "Re-clumping selected an instrument absent from the frozen primary harmonisation",
    call. = FALSE
  )
}

finngen_harmonised <- as.data.table(read_parquet(file.path(
  project_root, "03_data", "processed", "harmonised",
  "finngen_r12_erectile_dysfunction.parquet"
)))[dataset == "microbiome_2026" & tier == "primary"]
finngen_harmonised[, strict_key := paste(source_id, reference_id)]
strict_harmonised <- finngen_harmonised[
  strict_key %in% strict_keys & harmonisation_status == "harmonised"
]

run_strict_pair <- function(source) {
  meta_row <- strict_inventory[source_id == source]
  data <- strict_harmonised[source_id == source]
  meta <- list(
    pair_id = paste0("source_study_wide|", source),
    dataset = "microbiome_2026",
    source_id = source,
    trait = meta_row$trait[[1L]],
    tier = "source_study_wide_sensitivity",
    outcome_id = "finngen_r12_erectile_dysfunction",
    outcome_ancestry = "Finnish",
    analysis_role = "source_study_wide_sensitivity",
    effect_scale = "log_odds"
  )
  run_mr_pair(as.data.frame(data), meta, nboot = 1000L)
}

strict_eligible_ids <- strict_inventory[
  eligibility_status == "eligible", source_id
]
strict_runs <- lapply(strict_eligible_ids, run_strict_pair)
strict_method_results <- rbindlist(
  lapply(strict_runs, `[[`, "estimates"), use.names = TRUE, fill = TRUE
)
strict_sensitivity <- rbindlist(
  lapply(strict_runs, `[[`, "sensitivity"), use.names = TRUE, fill = TRUE
)
strict_primary <- strict_method_results[
  method %in% c("mr_wald_ratio", "mr_ivw_mre", "not_estimable")
]
if (nrow(strict_primary) != length(strict_eligible_ids)) {
  stop("Strict sensitivity did not yield one primary row per eligible trait", call. = FALSE)
}
strict_primary[, p_for_fdr := fifelse(
  analysis_status == "estimated" & is.finite(p), p, 1
)]
strict_primary[, q := p.adjust(p_for_fdr, method = "BH")]
strict_primary[, fdr_significant := q < 0.05]
strict_primary[, family_denominator := .N]
setorder(strict_primary, p_for_fdr, source_id)

strict_method_path <- write_output(
  strict_method_results, "source_study_wide_mr_method_results.csv"
)
strict_primary_path <- write_output(
  strict_primary, "source_study_wide_mr_primary_results.csv"
)
strict_sensitivity_path <- write_output(
  strict_sensitivity, "source_study_wide_mr_sensitivity_status.csv"
)
strict_summary <- data.table(
  source_catalog_traits = nrow(strict_inventory),
  eligible_traits = length(strict_eligible_ids),
  retained_instrument_rows = nrow(strict_instruments),
  estimable_traits = sum(strict_primary$analysis_status == "estimated"),
  non_estimable_traits = sum(strict_primary$analysis_status != "estimated"),
  nominal_p_lt_0_05 = sum(strict_primary$p_for_fdr < 0.05),
  minimum_p = min(strict_primary$p_for_fdr),
  minimum_q = min(strict_primary$q),
  fdr_significant = sum(strict_primary$fdr_significant),
  conclusion = "No source-study-wide sensitivity association met BH-FDR 5%"
)
strict_summary_path <- write_output(
  strict_summary, "source_study_wide_sensitivity_summary.csv"
)

# Power and minimum detectable odds ratios ------------------------------------
forward_family <- fread(file.path(
  project_root, "05_results", "tables", "mr_multiplicity_forward.csv"
))
estimable_ids <- forward_family[analysis_status == "estimated", source_id]
power_rows <- finngen_harmonised[
  source_id %in% estimable_ids & harmonisation_status == "harmonised"
]

prevalence_from_metadata <- function(source) {
  meta_row <- metadata[source_id == source]
  if (!nrow(meta_row)) return(NA_real_)
  path <- meta_row$metadata_path[[1L]]
  if (!file.exists(path)) return(NA_real_)
  content <- yaml::read_yaml(path)
  notes <- content$author_notes %||% ""
  match <- regexec("Prevalence:([0-9.]+)", notes, perl = TRUE)
  parts <- regmatches(notes, match)[[1L]]
  if (length(parts) != 2L) NA_real_ else as.numeric(parts[[2L]])
}
prevalence_lookup <- data.table(
  source_id = unique(power_rows$source_id)
)
prevalence_lookup[, source_reported_prevalence := vapply(
  source_id, prevalence_from_metadata, numeric(1)
)]
power_rows <- merge(
  power_rows, prevalence_lookup, by = "source_id", all.x = TRUE, sort = FALSE
)
power_rows[, phenotype := fifelse(
  grepl("presence", trait, ignore.case = TRUE), "presence",
  fifelse(grepl("alpha diversity", trait, ignore.case = TRUE),
          "RIN_standardized_diversity", "RIN_standardized_abundance")
)]
if (any(power_rows$phenotype == "presence" &
        !is.finite(power_rows$source_reported_prevalence))) {
  stop("A presence phenotype lacks source-reported prevalence", call. = FALSE)
}

liability_r2 <- function(beta, eaf, n, sample_prevalence, population_prevalence) {
  ncase <- max(1, round(n * sample_prevalence))
  ncontrol <- max(1, round(n - ncase))
  r <- TwoSampleMR::get_r_from_lor(
    lor = beta, af = eaf, ncase = ncase, ncontrol = ncontrol,
    prevalence = population_prevalence, model = "logit", correction = FALSE
  )
  as.numeric(r)^2
}

power_rows[, `:=`(
  prevalence_scenario_low = fifelse(
    phenotype == "presence", pmax(0.01, source_reported_prevalence - 0.10), NA_real_
  ),
  prevalence_scenario_high = fifelse(
    phenotype == "presence", pmin(0.99, source_reported_prevalence + 0.10), NA_real_
  ),
  r2_beta_eaf_standardized = 2 * eaf_exposure * (1 - eaf_exposure) *
    beta_exposure^2,
  r2_F_partial_approximation = F / (F + n_exposure - 2)
)]
power_rows[, r2_primary := fifelse(
  phenotype == "presence",
  mapply(
    liability_r2, beta_exposure, eaf_exposure, n_exposure,
    source_reported_prevalence, source_reported_prevalence
  ),
  r2_beta_eaf_standardized
)]
power_rows[, r2_prevalence_low := fifelse(
  phenotype == "presence",
  mapply(
    liability_r2, beta_exposure, eaf_exposure, n_exposure,
    source_reported_prevalence, prevalence_scenario_low
  ),
  r2_primary
)]
power_rows[, r2_prevalence_high := fifelse(
  phenotype == "presence",
  mapply(
    liability_r2, beta_exposure, eaf_exposure, n_exposure,
    source_reported_prevalence, prevalence_scenario_high
  ),
  r2_primary
)]
power_rows[, r2_method := fifelse(
  phenotype == "presence",
  paste0(
    "Lee et al. liability-scale approximation from log-odds beta, EAF, ",
    "approximate case count N*reported prevalence, and reported prevalence"
  ),
  "2*EAF*(1-EAF)*beta^2 for a source RIN-standardized phenotype"
)]

power_input_columns <- c(
  "source_id", "trait", "phenotype", "reference_id", "ea_exposure",
  "oa_exposure", "eaf_exposure", "beta_exposure", "se_exposure",
  "p_exposure", "F", "n_exposure", "source_reported_prevalence",
  "prevalence_scenario_low", "prevalence_scenario_high",
  "r2_beta_eaf_standardized", "r2_F_partial_approximation", "r2_primary",
  "r2_prevalence_low", "r2_prevalence_high", "r2_method"
)
power_inputs_path <- write_output(
  power_rows[, ..power_input_columns], "power_mde_instrument_inputs.csv"
)

power_trait <- power_rows[, .(
  trait = trait[[1L]], phenotype = phenotype[[1L]],
  exposure_scale = if (phenotype[[1L]] == "presence") {
    "one SD on an approximate microbial-presence liability scale"
  } else {
    "one source-defined RIN-standardized unit"
  },
  nsnp = .N,
  r2 = sum(r2_primary),
  r2_prevalence_scenario_min = min(sum(r2_prevalence_low),
                                   sum(r2_prevalence_high)),
  r2_prevalence_scenario_max = max(sum(r2_prevalence_low),
                                   sum(r2_prevalence_high)),
  r2_F_partial_approximation = sum(r2_F_partial_approximation),
  min_F = min(F), median_F = median(F), mean_F = mean(F),
  source_reported_prevalence = source_reported_prevalence[[1L]]
), by = source_id]

mrnd_power <- function(or, r2, alpha, cases = 2886, controls = 215272) {
  n <- cases + controls
  k <- cases / n
  b01 <- k * (or / (1 + k * (or - 1)) - 1)
  residual_variance <- k * (1 - k) - b01^2
  if (!is.finite(residual_variance) || residual_variance <= 0 || r2 <= 0) {
    return(NA_real_)
  }
  ncp <- n * r2 * b01^2 / residual_variance
  critical <- qchisq(1 - alpha, df = 1)
  pchisq(critical, df = 1, ncp = ncp, lower.tail = FALSE)
}

mde_or <- function(r2, alpha, target_power = 0.80) {
  if (!is.finite(r2) || r2 <= 0) return(NA_real_)
  objective <- function(log_or) {
    mrnd_power(exp(log_or), r2 = r2, alpha = alpha) - target_power
  }
  # The observed-scale binary-outcome approximation becomes invalid only at
  # extreme ORs where its residual variance is non-positive. Find the first
  # finite 80%-power crossing rather than evaluating one arbitrary extreme OR.
  log_grid <- seq(0, log(100), length.out = 2049L)
  objective_grid <- vapply(log_grid, objective, numeric(1))
  crossing <- which(is.finite(objective_grid) & objective_grid >= 0)[1L]
  if (is.na(crossing) || crossing <= 1L) return(NA_real_)
  lower <- max(which(seq_along(log_grid) < crossing &
                       is.finite(objective_grid) & objective_grid < 0))
  exp(uniroot(
    objective, interval = c(log_grid[[lower]], log_grid[[crossing]]),
    tol = 1e-10
  )$root)
}

alpha_definitions <- data.table(
  alpha_label = c(
    "nominal_0.05", "forward_bonferroni_0.05_over_230",
    "global_bonferroni_0.05_over_1802"
  ),
  alpha = c(0.05, 0.05 / 230, 0.05 / (230 + 1572))
)
power_long <- rbindlist(lapply(seq_len(nrow(alpha_definitions)), function(i) {
  rows <- copy(power_trait)
  rows[, alpha_label := alpha_definitions$alpha_label[[i]]]
  rows[, alpha := alpha_definitions$alpha[[i]]]
  rows[, mde_or_higher := vapply(r2, mde_or, numeric(1), alpha = alpha[[1L]])]
  rows[, mde_or_lower := 1 / mde_or_higher]
  rows[, mde_or_higher_scenario_low := vapply(
    r2_prevalence_scenario_min, mde_or, numeric(1), alpha = alpha[[1L]]
  )]
  rows[, mde_or_higher_scenario_high := vapply(
    r2_prevalence_scenario_max, mde_or, numeric(1), alpha = alpha[[1L]]
  )]
  rows[, achieved_power_check := mapply(
    mrnd_power, mde_or_higher, r2, MoreArgs = list(alpha = alpha[[1L]])
  )]
  rows
}))
if (any(!is.finite(power_long$mde_or_higher)) ||
    any(!is.finite(power_long$mde_or_higher_scenario_low)) ||
    any(!is.finite(power_long$mde_or_higher_scenario_high))) {
  stop("At least one MDE was not estimable under the stated approximation",
       call. = FALSE)
}
if (any(abs(power_long$achieved_power_check - 0.80) > 1e-5, na.rm = TRUE)) {
  stop("MDE root solving did not reproduce 80% power", call. = FALSE)
}
power_long[, alpha_order := match(alpha_label, alpha_definitions$alpha_label)]
setorder(power_long, alpha_order, source_id)
power_long[, alpha_order := NULL]
power_trait_path <- write_output(power_long, "power_mde_trait_results.csv")

power_summary <- power_long[, .(
  estimable_traits = .N,
  r2_median = median(r2), r2_q1 = quantile(r2, 0.25),
  r2_q3 = quantile(r2, 0.75), r2_min = min(r2), r2_max = max(r2),
  mde_or_median = median(mde_or_higher),
  mde_or_q1 = quantile(mde_or_higher, 0.25),
  mde_or_q3 = quantile(mde_or_higher, 0.75),
  mde_or_min = min(mde_or_higher), mde_or_max = max(mde_or_higher),
  traits_power_80_for_or_1_20_or_larger = sum(mde_or_higher <= 1.20),
  traits_power_80_for_or_1_50_or_larger = sum(mde_or_higher <= 1.50),
  traits_power_80_for_or_2_00_or_larger = sum(mde_or_higher <= 2.00)
), by = .(alpha_label, alpha)]
power_summary_path <- write_output(power_summary, "power_mde_summary.csv")

# Multiplicity sensitivities and unique taxonomic signal clusters --------------
signature_rows <- finngen_harmonised[
  harmonisation_status == "harmonised" & source_id %in% forward_family$source_id
]
signature_rows[, row_signature := paste(
  reference_id, ea_exposure, oa_exposure,
  format(beta_exposure, digits = 16, scientific = TRUE),
  format(se_exposure, digits = 16, scientific = TRUE),
  format(beta_outcome_harmonised, digits = 16, scientific = TRUE),
  format(se_outcome_harmonised, digits = 16, scientific = TRUE), sep = "|"
)]
instrument_signatures <- signature_rows[order(reference_id), .(
  instrument_signature = paste(row_signature, collapse = ";")
), by = source_id]

meta_notes <- vapply(metadata$metadata_path, function(path) {
  if (!file.exists(path)) return("")
  as.character(yaml::read_yaml(path)$author_notes %||% "")
}, character(1))
lineage <- metadata[, .(source_id, trait, author_notes = meta_notes)]
lineage[, focal_label := sub(
  ".*\\(([^,)]*).*", "\\1", trait, perl = TRUE
)]
lineage[, focal_normalized := tolower(gsub("[^a-z0-9]+", " ", focal_label))]
lineage[, lineage_normalized := tolower(gsub("[^a-z0-9]+", " ", author_notes))]

multiplicity <- merge(
  as.data.table(forward_family), instrument_signatures,
  by = "source_id", all.x = TRUE, sort = FALSE
)
multiplicity <- merge(
  multiplicity, lineage[, .(source_id, focal_normalized, lineage_normalized)],
  by = "source_id", all.x = TRUE, sort = FALSE
)
multiplicity[, p_for_primary_family := fifelse(is.finite(p), p, 1)]
multiplicity[, q_primary_recomputed := p.adjust(
  p_for_primary_family, method = "BH", n = 230
)]
multiplicity[, q_estimable_only := NA_real_]
multiplicity[is.finite(p), q_estimable_only := p.adjust(p, method = "BH")]
multiplicity[, exact_key := fifelse(
  is.finite(p),
  paste(
    instrument_signature,
    format(beta, digits = 16, scientific = TRUE),
    format(se, digits = 16, scientific = TRUE),
    format(p, digits = 16, scientific = TRUE), sep = "||"
  ),
  paste0("non_estimable||", source_id)
)]

nested_group_status <- function(rows) {
  if (nrow(rows) < 2L) return(FALSE)
  labels <- unique(trimws(rows$focal_normalized))
  labels <- labels[nzchar(labels)]
  if (length(labels) != nrow(rows)) return(FALSE)
  any(vapply(rows$lineage_normalized, function(note) {
    all(vapply(labels, grepl, logical(1), x = note, fixed = TRUE))
  }, logical(1)))
}
exact_audit <- multiplicity[, .(
  members = .N,
  nested_taxonomic_lineage_verified = nested_group_status(.SD),
  member_source_ids = paste(source_id, collapse = ";"),
  member_traits = paste(trait, collapse = " | ")
), by = exact_key]
exact_audit[, exact_group_id := paste0(
  "exact_", substr(vapply(exact_key, digest, character(1),
                           algo = "xxhash64", serialize = FALSE), 1L, 12L)
)]
multiplicity <- merge(
  multiplicity,
  exact_audit[, .(
    exact_key, exact_group_id, exact_group_members = members,
    nested_taxonomic_lineage_verified
  )],
  by = "exact_key", all.x = TRUE, sort = FALSE
)
multiplicity[, signal_cluster := fifelse(
  exact_group_members > 1L & nested_taxonomic_lineage_verified,
  exact_group_id, paste0("trait_", source_id)
)]
cluster_family <- multiplicity[, .(
  representative_source_id = source_id[[1L]],
  representative_trait = trait[[1L]],
  cluster_members = .N,
  member_source_ids = paste(source_id, collapse = ";"),
  p_for_fdr = p_for_primary_family[[1L]],
  nested_taxonomic_cluster = any(nested_taxonomic_lineage_verified)
), by = signal_cluster]
cluster_family[, q_unique_signal_cluster := p.adjust(p_for_fdr, method = "BH")]
cluster_family[, unique_cluster_denominator := .N]
multiplicity <- merge(
  multiplicity,
  cluster_family[, .(
    signal_cluster, q_unique_signal_cluster, unique_cluster_denominator,
    cluster_members
  )],
  by = "signal_cluster", all.x = TRUE, sort = FALSE
)
setorder(multiplicity, p_for_primary_family, source_id)
setorder(exact_audit, -members, exact_group_id)
setorder(cluster_family, p_for_fdr, signal_cluster)

if (any(abs(
  multiplicity[is.finite(q), q] -
    multiplicity[is.finite(q), q_primary_recomputed]
) > 1e-12)) {
  stop("Recomputed frozen-family BH q values do not match the frozen results",
       call. = FALSE)
}
pepto <- multiplicity[source_id %in% c(
  "GCST90671709", "GCST90671773", "GCST90671803"
)]
if (uniqueN(pepto$signal_cluster) != 1L ||
    !all(pepto$nested_taxonomic_lineage_verified)) {
  stop("The Peptococcaceae/Peptococcales/Peptococcia cluster was not recovered",
       call. = FALSE)
}

multiplicity_path <- write_output(
  multiplicity, "multiplicity_sensitivity_trait_results.csv"
)
cluster_path <- write_output(
  cluster_family, "multiplicity_unique_signal_clusters.csv"
)
exact_audit_path <- write_output(
  exact_audit, "multiplicity_exact_duplicate_audit.csv"
)
multiplicity_summary <- data.table(
  analysis = c(
    "primary_frozen_family", "estimable_only_BH", "unique_signal_cluster_BH"
  ),
  denominator = c(
    230L, sum(is.finite(multiplicity$p)), uniqueN(multiplicity$signal_cluster)
  ),
  minimum_q = c(
    min(multiplicity$q_primary_recomputed),
    min(multiplicity$q_estimable_only, na.rm = TRUE),
    min(cluster_family$q_unique_signal_cluster)
  ),
  fdr_significant = c(
    sum(multiplicity$q_primary_recomputed < 0.05),
    sum(multiplicity$q_estimable_only < 0.05, na.rm = TRUE),
    sum(cluster_family$q_unique_signal_cluster < 0.05)
  ),
  interpretation = c(
    "prespecified primary analysis; non-estimable tests retained as P=1",
    "sensitivity restricted to the 218 estimable tests",
    "sensitivity collapsing only exact instrument/effect duplicates verified as taxonomically nested"
  )
)
multiplicity_summary_path <- write_output(
  multiplicity_summary, "multiplicity_sensitivity_summary.csv"
)

# Known-overlap 2025 ED outcome sensitivity analyses ---------------------------
pair_registry <- fread(file.path(
  project_root, "05_results", "tables", "mr_pair_registry.csv"
))
mr_raw <- fread(file.path(project_root, "05_results", "tables", "mr_raw.csv"))
target_outcomes <- c("ed_2025_eur", "ed_2025_afr", "ed_2025_cross_ancestry")
outcome_registry <- pair_registry[
  dataset == "microbiome_2026" & tier == "primary" &
    outcome_id %in% target_outcomes
]
outcome_primary <- mr_raw[
  dataset == "microbiome_2026" & tier == "primary" &
    outcome_id %in% target_outcomes &
    method %in% c("mr_wald_ratio", "mr_ivw_mre")
]
outcome_results <- merge(
  outcome_registry, outcome_primary,
  by = c(
    "pair_id", "dataset", "source_id", "trait", "tier", "outcome_id",
    "outcome_ancestry", "analysis_role", "effect_scale"
  ),
  all.x = TRUE, sort = FALSE
)
outcome_results[is.na(method), `:=`(
  method = "not_estimable", nsnp = 0L, analysis_status = "not_estimable"
)]
outcome_results[, p_for_fdr := fifelse(is.finite(p), p, 1)]
outcome_results[, q_230 := p.adjust(p_for_fdr, method = "BH", n = 230),
                by = outcome_id]
outcome_results[, fdr_significant := q_230 < 0.05]
setorder(outcome_results, outcome_id, p_for_fdr, source_id)
outcome_results_path <- write_output(
  outcome_results, "ed_2025_known_overlap_sensitivity_results.csv"
)
outcome_summary <- outcome_results[, .(
  family_denominator = .N,
  estimable = sum(analysis_status == "estimated"),
  non_estimable = sum(analysis_status != "estimated"),
  nominal_p_lt_0_05 = sum(p_for_fdr < 0.05),
  minimum_p = min(p_for_fdr), minimum_q = min(q_230),
  fdr_significant = sum(fdr_significant),
  effect_scale = effect_scale[[1L]],
  overlap_class = "known overlap with FinnGen; sensitivity only"
), by = .(outcome_id, outcome_ancestry)]
outcome_summary_path <- write_output(
  outcome_summary, "ed_2025_known_overlap_sensitivity_summary.csv"
)

# HUNT evidence-level audit for the two nominal exact-label traits -------------
hunt_same_snp <- fread(file.path(output_root, "hunt_same_snp_validation.csv"))
hunt_inventory <- fread(file.path(
  project_root, "05_results", "tables", "instrument_inventory.csv"
))[dataset == "microbiome_2026_hunt"]
replication_map <- fread(file.path(
  project_root, "08_qc", "exposure_replication_map.csv"
))
nominal_exact <- forward_family[
  is.finite(p) & p < 0.05 & source_id %in% hunt_same_snp$discovery_source_id
]
hunt_audit <- merge(
  nominal_exact[, .(
    discovery_source_id = source_id, discovery_trait = trait,
    discovery_mr_beta = beta, discovery_mr_se = se, discovery_mr_p = p,
    discovery_mr_or = or, discovery_mr_or_ci_lower = or_ci_lower,
    discovery_mr_or_ci_upper = or_ci_upper, discovery_fdr_q = q
  )],
  replication_map[, .(
    discovery_source_id, hunt_source_id = replication_source_id,
    hunt_trait = replication_trait
  )],
  by = "discovery_source_id", all.x = TRUE, sort = FALSE
)
inventory_wide <- dcast(
  hunt_inventory[source_id %in% hunt_audit$hunt_source_id],
  source_id + trait ~ tier,
  value.var = c("p_threshold", "candidate_snps", "post_clump_snps",
                "min_f", "mean_f", "exclusion_reason")
)
hunt_audit <- merge(
  hunt_audit, inventory_wide,
  by.x = "hunt_source_id", by.y = "source_id", all.x = TRUE, sort = FALSE
)
hunt_audit <- merge(
  hunt_audit,
  hunt_same_snp[, .(
    discovery_source_id, discovery_snp, discovery_effect_allele,
    discovery_other_allele, discovery_eaf, discovery_beta, discovery_se,
    discovery_p, discovery_F, hunt_variant_id, allele_relation,
    hunt_eaf_aligned, hunt_beta_aligned, hunt_se, hunt_p,
    hunt_signed_z_aligned, hunt_F_same_snp, direction_concordant,
    phenotype_pair, effect_scale_comparability
  )],
  by = "discovery_source_id", all.x = TRUE, sort = FALSE
)
existing_hunt_mr <- mr_raw[
  dataset == "microbiome_2026_hunt" &
    outcome_id == "finngen_r12_erectile_dysfunction" &
    tier == "exploratory" & method == "mr_ivw_mre" &
    source_id %in% hunt_audit$hunt_source_id,
  .(
    hunt_source_id = source_id, hunt_selected_exploratory_nsnp = nsnp,
    hunt_selected_exploratory_mr_beta = beta,
    hunt_selected_exploratory_mr_se = se,
    hunt_selected_exploratory_mr_p = p,
    hunt_selected_exploratory_mr_or = or,
    hunt_selected_exploratory_mr_or_ci_lower = or_ci_lower,
    hunt_selected_exploratory_mr_or_ci_upper = or_ci_upper
  )
]
hunt_audit <- merge(
  hunt_audit, existing_hunt_mr, by = "hunt_source_id", all.x = TRUE,
  sort = FALSE
)
outcome_for_hunt <- finngen_harmonised[
  source_id %in% hunt_audit$discovery_source_id &
    harmonisation_status == "harmonised",
  .(
    discovery_source_id = source_id, discovery_snp = reference_id,
    outcome_beta_aligned = beta_outcome_harmonised,
    outcome_se = se_outcome_harmonised
  )
]
hunt_audit <- merge(
  hunt_audit, outcome_for_hunt,
  by = c("discovery_source_id", "discovery_snp"), all.x = TRUE, sort = FALSE
)
hunt_audit[, same_snp_wald_beta_descriptive := outcome_beta_aligned / hunt_beta_aligned]
hunt_audit[, same_snp_wald_se_descriptive := sqrt(
  outcome_se^2 / hunt_beta_aligned^2 +
    outcome_beta_aligned^2 * hunt_se^2 / hunt_beta_aligned^4
)]
hunt_audit[, same_snp_wald_p_descriptive := 2 * pnorm(
  abs(same_snp_wald_beta_descriptive / same_snp_wald_se_descriptive),
  lower.tail = FALSE
)]
hunt_audit[, same_snp_wald_interpretability := fifelse(
  hunt_F_same_snp > 10,
  "sensitivity estimate may be inspected subject to scale caveats",
  "not interpretable as MR because the same SNP is a weak HUNT instrument"
)]
hunt_audit[, existing_hunt_design :=
  "HUNT-selected instruments at exploratory P<1e-5 paired with FinnGen outcome"]
hunt_audit[, same_snp_design :=
  "Swedish lead SNP looked up at the same GRCh37 position and alleles in exact-label HUNT GWAS"]
hunt_audit[, final_evidence_name :=
  "exploratory exact-label HUNT sensitivity analysis with cross-cohort same-SNP exposure validation"]
hunt_audit[, independent_replication := FALSE]
setorder(hunt_audit, discovery_mr_p)
hunt_audit_path <- write_output(hunt_audit, "hunt_nominal_trait_audit.csv")

# Full method closure and explicit non-estimability ----------------------------
forward_methods <- mr_raw[
  dataset == "microbiome_2026" & tier == "primary" &
    outcome_id == "finngen_r12_erectile_dysfunction"
]
forward_sensitivity <- fread(file.path(
  project_root, "05_results", "tables", "mr_sensitivity.csv"
))
forward_pair_ids <- pair_registry[
  dataset == "microbiome_2026" & tier == "primary" &
    outcome_id == "finngen_r12_erectile_dysfunction", pair_id
]
forward_sensitivity <- forward_sensitivity[pair_id %in% forward_pair_ids]
method_status <- forward_methods[, .(
  rows = .N,
  estimated = sum(analysis_status == "estimated"),
  failed = sum(analysis_status == "failed"),
  not_estimable = sum(analysis_status == "not_estimable"),
  minimum_p = if (any(is.finite(p))) min(p, na.rm = TRUE) else NA_real_
), by = method]
method_status_path <- write_output(method_status, "forward_method_status_summary.csv")
forward_methods_path <- write_output(
  forward_methods, "forward_all_method_results.csv"
)
forward_sensitivity_path <- write_output(
  forward_sensitivity, "forward_diagnostic_trigger_status.csv"
)

mechanistic_validation <- fread(file.path(
  project_root, "08_qc", "mechanistic_full_validation_receipt.csv"
))
cytokine_leads <- fread(file.path(project_root, "config", "cytokine_cis_leads.csv"))
ccl11 <- cytokine_leads[mediator_id == "cytokine_CCL11"]
mechanistic_decision <- fread(file.path(
  project_root, "08_qc", "mechanistic_extension_decision.csv"
))

closure <- data.table(
  analysis = c(
    "2025 European ED outcome sensitivity",
    "2025 African-ancestry ED outcome sensitivity",
    "2025 cross-ancestry ED outcome sensitivity",
    "Weighted median", "MR-Egger", "MR-RAPS", "Steiger directionality",
    "MR-PRESSO", "HUNT evaluation", "Prespecified bounded mechanistic screening",
    "CCL11 source-heterogeneity sensitivity", "Colocalization triggering rule",
    "Source-study-wide significance sensitivity",
    "Estimable-only BH sensitivity", "Unique-signal-cluster BH sensitivity",
    "Power and minimum detectable effect"
  ),
  final_status = c(
    rep("completed_and_reported", 3L),
    rep("completed_when_instrument_count_permitted", 3L),
    "not_triggered_and_not_interpreted_as_support",
    "not_triggered_and_not_interpreted_as_support",
    "completed_at_two_evidence_levels",
    "completed_and_reported",
    "completed_and_excluded_in_sensitivity",
    "not_triggered_component_gates_failed",
    rep("completed_and_reported", 4L)
  ),
  result_or_reason = c(
    vapply(c("ed_2025_eur", "ed_2025_afr", "ed_2025_cross_ancestry"),
           function(id) {
             row <- outcome_summary[outcome_id == id]
             sprintf(
               "%d/230 estimable; minimum P %.6g; minimum q %.6g; %d FDR signals",
               row$estimable, row$minimum_p, row$minimum_q,
               row$fdr_significant
             )
           }, character(1)),
    vapply(c("mr_weighted_median", "mr_egger_regression", "mr_raps"),
           function(method_name) {
             row <- method_status[method == method_name]
             sprintf("%d estimated, %d explicit failures, %d not estimable",
                     row$estimated, row$failed, row$not_estimable)
           }, character(1)),
    paste(
      "No forward association passed FDR, so the candidate-triggered analysis did not activate;",
      "population prevalence required for a defensible binary-outcome comparison was not prespecified"
    ),
    "No forward association passed FDR; all seven nominal forward estimates used one SNP and MR-PRESSO was not estimable",
    sprintf(
      paste0(
        "97 exact-label same-SNP lookups: %d direction-concordant; ",
        "the two nominal exact-label HUNT GWASs had 0 GWS instruments and used 23/20 HUNT-selected exploratory SNPs in the older analysis"
      ),
      sum(hunt_same_snp$direction_concordant)
    ),
    sprintf(
      "%d result families, %d rows, %d FDR signals; retained only as bounded screening",
      mechanistic_validation$result_families_verified,
      mechanistic_validation$result_rows_verified,
      mechanistic_validation$total_fdr_signals
    ),
    sprintf(
      "CCL11 cis lead %s had source heterogeneity I2 %.1f%%, P %.6g; excluded under the predefined P<0.05 rule",
      ccl11$lead_snp, ccl11$het_i2, ccl11$het_p
    ),
    "No X-to-M and M-to-ED component pair jointly passed FDR; colocalization was not triggered",
    sprintf(
      "%d traits eligible, %d estimable, minimum P %.6g, minimum q %.6g, 0 FDR signals",
      strict_summary$eligible_traits, strict_summary$estimable_traits,
      strict_summary$minimum_p, strict_summary$minimum_q
    ),
    sprintf(
      "Denominator %d; minimum q %.6g; 0 FDR signals",
      multiplicity_summary[analysis == "estimable_only_BH", denominator],
      multiplicity_summary[analysis == "estimable_only_BH", minimum_q]
    ),
    sprintf(
      "Denominator %d; minimum q %.6g; 0 FDR signals",
      multiplicity_summary[analysis == "unique_signal_cluster_BH", denominator],
      multiplicity_summary[analysis == "unique_signal_cluster_BH", minimum_q]
    ),
    paste(
      "Completed for all 218 estimable forward traits using mRnd binary-outcome approximation;",
      "presence traits used liability-scale R2 with prevalence scenarios"
    )
  ),
  evidence_location = c(
    rep("ed_2025_known_overlap_sensitivity_results.csv", 3L),
    rep("forward_all_method_results.csv", 3L),
    "forward_diagnostic_trigger_status.csv",
    "forward_diagnostic_trigger_status.csv",
    "hunt_same_snp_validation.csv; hunt_nominal_trait_audit.csv",
    "mechanistic_screening_full_enriched.csv",
    "config/cytokine_cis_leads.csv",
    "mechanistic_extension_decision.csv",
    "source_study_wide_mr_primary_results.csv",
    "multiplicity_sensitivity_trait_results.csv",
    "multiplicity_unique_signal_clusters.csv",
    "power_mde_trait_results.csv"
  )
)
closure_path <- write_output(closure, "prespecified_analysis_closure_audit.csv")

# Instrument architecture and QQ inputs ---------------------------------------
architecture <- forward_family[, .(
  trait_count = .N
), by = .(nsnp = fifelse(is.finite(nsnp), as.integer(nsnp), 0L))]
setorder(architecture, nsnp)
architecture_path <- write_output(architecture, "forward_instrument_architecture.csv")

qq_input <- rbindlist(list(
  data.table(
    direction = "forward",
    p = sort(forward_family[is.finite(p), p]),
    expected_p = ppoints(sum(is.finite(forward_family$p)))
  ),
  data.table(
    direction = "reverse",
    p = sort(fread(file.path(
      project_root, "05_results", "tables", "reverse_mr_multiplicity.csv"
    ))[is.finite(p), p]),
    expected_p = ppoints(1572L)
  )
))
qq_input[, `:=`(
  observed_minus_log10_p = -log10(p),
  expected_minus_log10_p = -log10(expected_p)
)]
qq_path <- write_output(qq_input, "qq_plot_input.csv")

# Consolidated receipt ---------------------------------------------------------
output_paths <- c(
  threshold_ledger_path, strict_instruments_path, strict_inventory_path,
  strict_method_path, strict_primary_path, strict_sensitivity_path,
  strict_summary_path, power_inputs_path, power_trait_path, power_summary_path,
  multiplicity_path, cluster_path, exact_audit_path,
  multiplicity_summary_path, outcome_results_path, outcome_summary_path,
  hunt_audit_path, method_status_path, forward_methods_path,
  forward_sensitivity_path, closure_path, architecture_path, qq_path
)
input_paths <- c(
  "03_data/processed/instruments/instruments.parquet",
  "03_data/processed/harmonised/finngen_r12_erectile_dysfunction.parquet",
  "05_results/tables/mr_multiplicity_forward.csv",
  "05_results/tables/reverse_mr_multiplicity.csv",
  "05_results/tables/mr_raw.csv",
  "05_results/tables/mr_pair_registry.csv",
  "08_qc/exposure_metadata_catalog.csv",
  "08_qc/exposure_replication_map.csv",
  "08_qc/mechanistic_full_validation_receipt.csv",
  "config/cytokine_cis_leads.csv",
  "02_literature/source_files/Dekkers_2026_Nature_Genetics_source_GWAS.pdf",
  "scripts/29_run_v0_3_methodological_analyses.R"
)
receipt <- rbindlist(list(
  data.table(
    role = "input",
    artifact = input_paths,
    sha256 = vapply(file.path(project_root, input_paths), function(path) {
      digest(file = path, algo = "sha256", serialize = FALSE)
    }, character(1))
  ),
  data.table(
    role = "output", artifact = basename(output_paths),
    sha256 = vapply(output_paths, function(path) {
      digest(file = path, algo = "sha256", serialize = FALSE)
    }, character(1))
  )
))
receipt[, completed_at_utc := format(
  Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
)]
receipt_path <- write_output(receipt, "v0_3_methodological_analysis_receipt.csv")

cat(sprintf(
  paste0(
    "v0.3 methodological analyses complete: strict sensitivity %d eligible/%d ",
    "estimable (min q %.6g); power/MDE %d traits; unique clusters %d; ",
    "known-overlap 2025 outcome FDR counts EUR=%d, AFR=%d, cross-ancestry=%d.\n"
  ),
  strict_summary$eligible_traits, strict_summary$estimable_traits,
  strict_summary$minimum_q, uniqueN(power_long$source_id),
  uniqueN(multiplicity$signal_cluster),
  outcome_summary[outcome_id == "ed_2025_eur", fdr_significant],
  outcome_summary[outcome_id == "ed_2025_afr", fdr_significant],
  outcome_summary[outcome_id == "ed_2025_cross_ancestry", fdr_significant]
))
