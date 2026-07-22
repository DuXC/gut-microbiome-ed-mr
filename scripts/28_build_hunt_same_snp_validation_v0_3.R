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

source(file.path(project_root, "R", "exposure_candidates.R"))

output_root <- file.path(project_root, "05_results", "v0_3_20260722")
cache_root <- file.path(output_root, "hunt_same_snp_cache")
dir.create(cache_root, recursive = TRUE, showWarnings = FALSE)

workers <- suppressWarnings(as.integer(Sys.getenv("HUNT_LOOKUP_WORKERS", "4")))
if (is.na(workers) || workers < 1L) {
  stop("HUNT_LOOKUP_WORKERS must be a positive integer", call. = FALSE)
}

instruments <- as.data.table(read_parquet(file.path(
  project_root, "03_data", "processed", "instruments", "instruments.parquet"
)))
eligible <- unique(fread(file.path(
  project_root, "05_results", "tables", "mr_multiplicity_forward.csv"
))[, .(discovery_source_id = source_id)])
mapping <- fread(file.path(
  project_root, "08_qc", "exposure_replication_map.csv"
))[match_status == "matched"]

lead <- instruments[
  dataset == "microbiome_2026" & tier == "primary" &
    source_id %in% eligible$discovery_source_id
]
setorder(lead, source_id, p, reference_id)
lead <- lead[, .SD[1L], by = source_id]
lead <- lead[, .(
  discovery_source_id = source_id,
  discovery_trait = trait,
  discovery_snp = reference_id,
  discovery_variant_key = variant_key,
  discovery_chr = as.character(chr),
  discovery_pos_grch37 = as.numeric(pos),
  discovery_effect_allele = toupper(ea),
  discovery_other_allele = toupper(oa),
  discovery_eaf = as.numeric(eaf),
  discovery_beta = as.numeric(beta),
  discovery_se = as.numeric(se),
  discovery_p = as.numeric(p),
  discovery_F = as.numeric(F),
  discovery_n = as.numeric(n)
)]

plan <- merge(
  lead,
  mapping[, .(
    canonical_trait_id, discovery_source_id, replication_source_id,
    replication_trait
  )],
  by = "discovery_source_id", all = FALSE, sort = FALSE
)
setorder(plan, discovery_source_id)
if (nrow(plan) != 97L || anyDuplicated(plan$discovery_source_id) ||
    anyDuplicated(plan$replication_source_id)) {
  stop(
    "Expected exactly 97 unique exact-label matches among the frozen forward family",
    call. = FALSE
  )
}

lookup_one <- function(index) {
  row <- plan[index]
  cache_path <- file.path(
    cache_root, paste0(row$discovery_source_id, "__", row$replication_source_id, ".csv")
  )
  if (file.exists(cache_path)) {
    cached <- fread(cache_path)
    if (nrow(cached) == 1L) return(cached)
  }

  raw_path <- file.path(
    project_root, "03_data", "raw", "microbiome_2026_hunt",
    row$replication_source_id,
    paste0(row$replication_source_id, ".tsv.gz")
  )
  if (!file.exists(raw_path)) {
    stop("Missing HUNT raw file: ", raw_path, call. = FALSE)
  }
  awk_program <- sprintf(
    "NR==1 || ($1==%s && $2==%.0f)",
    row$discovery_chr, row$discovery_pos_grch37
  )
  command <- paste(
    "gzip -dc", shQuote(raw_path), "| awk -F '\\t'",
    shQuote(awk_program)
  )
  hit <- suppressWarnings(fread(cmd = command, showProgress = FALSE))

  if (!nrow(hit)) {
    result <- copy(row)[, `:=`(
      hunt_variant_id = NA_character_, hunt_effect_allele_raw = NA_character_,
      hunt_other_allele_raw = NA_character_, hunt_eaf_raw = NA_real_,
      hunt_beta_raw = NA_real_, hunt_se = NA_real_, hunt_p = NA_real_,
      allele_relation = "not_found_at_grch37_position",
      same_snp_lookup_status = "not_found", hunt_effect_allele_aligned = NA_character_,
      hunt_other_allele_aligned = NA_character_, hunt_eaf_aligned = NA_real_,
      hunt_beta_aligned = NA_real_, hunt_signed_z_aligned = NA_real_,
      hunt_F_same_snp = NA_real_, direction_concordant = NA
    )]
  } else if (nrow(hit) != 1L) {
    stop(
      "HUNT lookup returned multiple rows for ", row$replication_source_id,
      " at ", row$discovery_chr, ":", row$discovery_pos_grch37,
      call. = FALSE
    )
  } else {
    h_ea <- toupper(hit$effect_allele[[1L]])
    h_oa <- toupper(hit$other_allele[[1L]])
    direct <- h_ea == row$discovery_effect_allele &&
      h_oa == row$discovery_other_allele
    swapped <- h_ea == row$discovery_other_allele &&
      h_oa == row$discovery_effect_allele
    relation <- if (direct) "same" else if (swapped) "swapped" else "allele_mismatch"
    aligned_beta <- if (direct) {
      as.numeric(hit$beta[[1L]])
    } else if (swapped) {
      -as.numeric(hit$beta[[1L]])
    } else {
      NA_real_
    }
    aligned_eaf <- if (direct) {
      as.numeric(hit$effect_allele_frequency[[1L]])
    } else if (swapped) {
      1 - as.numeric(hit$effect_allele_frequency[[1L]])
    } else {
      NA_real_
    }
    hunt_se <- as.numeric(hit$standard_error[[1L]])
    result <- copy(row)[, `:=`(
      hunt_variant_id = as.character(hit$variant_id[[1L]]),
      hunt_effect_allele_raw = h_ea,
      hunt_other_allele_raw = h_oa,
      hunt_eaf_raw = as.numeric(hit$effect_allele_frequency[[1L]]),
      hunt_beta_raw = as.numeric(hit$beta[[1L]]),
      hunt_se = hunt_se,
      hunt_p = as.numeric(hit$p_value[[1L]]),
      allele_relation = relation,
      same_snp_lookup_status = if (relation == "allele_mismatch") {
        "found_but_alleles_incompatible"
      } else {
        "matched_and_aligned"
      },
      hunt_effect_allele_aligned = if (relation == "allele_mismatch") {
        NA_character_
      } else {
        discovery_effect_allele
      },
      hunt_other_allele_aligned = if (relation == "allele_mismatch") {
        NA_character_
      } else {
        discovery_other_allele
      },
      hunt_eaf_aligned = aligned_eaf,
      hunt_beta_aligned = aligned_beta,
      hunt_signed_z_aligned = aligned_beta / hunt_se,
      hunt_F_same_snp = (aligned_beta / hunt_se)^2,
      direction_concordant = sign(aligned_beta) == sign(discovery_beta)
    )]
  }
  result[, phenotype_pair := fifelse(
    grepl("presence", discovery_trait, ignore.case = TRUE),
    "Swedish presence vs HUNT normalized relative abundance",
    "Swedish RIN abundance/diversity vs HUNT normalized relative abundance"
  )]
  result[, effect_scale_comparability :=
    "Direction and signed Z may be compared; raw beta magnitudes are not directly comparable"]
  atomic_write_csv(as.data.frame(result), cache_path)
  result
}

indices <- seq_len(nrow(plan))
parts <- if (.Platform$OS.type == "unix" && workers > 1L) {
  parallel::mclapply(indices, lookup_one, mc.cores = workers, mc.preschedule = FALSE)
} else {
  lapply(indices, lookup_one)
}
if (any(vapply(parts, inherits, logical(1), what = "try-error"))) {
  stop(
    "One or more HUNT same-SNP lookups failed: ",
    paste(as.character(parts[vapply(parts, inherits, logical(1), what = "try-error")]),
          collapse = " | "),
    call. = FALSE
  )
}
result <- rbindlist(parts, use.names = TRUE, fill = TRUE)
setorder(result, discovery_source_id)

matched <- result[same_snp_lookup_status == "matched_and_aligned"]
binomial <- if (nrow(matched)) {
  stats::binom.test(sum(matched$direction_concordant), nrow(matched), p = 0.5)
} else {
  NULL
}
summary <- data.table(
  exact_label_forward_traits = nrow(result),
  same_position_found = sum(result$same_snp_lookup_status != "not_found"),
  allele_compatible = nrow(matched),
  direction_concordant = sum(matched$direction_concordant),
  direction_discordant = sum(!matched$direction_concordant),
  direction_concordance_proportion = if (nrow(matched)) {
    mean(matched$direction_concordant)
  } else {
    NA_real_
  },
  concordance_exact_95ci_lower = if (is.null(binomial)) NA_real_ else binomial$conf.int[[1L]],
  concordance_exact_95ci_upper = if (is.null(binomial)) NA_real_ else binomial$conf.int[[2L]],
  concordance_vs_half_p = if (is.null(binomial)) NA_real_ else binomial$p.value,
  same_snp_gws_in_hunt = sum(matched$hunt_p < 5e-8),
  same_snp_F_gt_10_in_hunt = sum(matched$hunt_F_same_snp > 10),
  evidence_name = "cross-cohort same-SNP exposure-association validation",
  inference_limit = paste(
    "HUNT supplies an independent exposure cohort but FinnGen remains the outcome;",
    "this is not independent MR replication"
  )
)

result_path <- file.path(output_root, "hunt_same_snp_validation.csv")
summary_path <- file.path(output_root, "hunt_same_snp_validation_summary.csv")
atomic_write_csv(as.data.frame(result), result_path)
atomic_write_csv(as.data.frame(summary), summary_path)

input_paths <- c(
  "03_data/processed/instruments/instruments.parquet",
  "05_results/tables/mr_multiplicity_forward.csv",
  "08_qc/exposure_replication_map.csv"
)
receipt <- data.table(
  artifact = c(input_paths, basename(result_path), basename(summary_path),
               "scripts/28_build_hunt_same_snp_validation_v0_3.R"),
  sha256 = c(
    vapply(file.path(project_root, input_paths), digest, character(1),
           algo = "sha256", serialize = FALSE, file = TRUE),
    digest(file = result_path, algo = "sha256", serialize = FALSE),
    digest(file = summary_path, algo = "sha256", serialize = FALSE),
    digest(file = file.path(project_root, "scripts", "28_build_hunt_same_snp_validation_v0_3.R"),
           algo = "sha256", serialize = FALSE)
  ),
  completed_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
)
atomic_write_csv(
  as.data.frame(receipt),
  file.path(output_root, "hunt_same_snp_validation_receipt.csv")
)

cat(sprintf(
  paste0(
    "HUNT same-SNP validation complete: %d exact labels, %d allele-compatible ",
    "lookups, %d concordant directions, %d HUNT GWS associations.\n"
  ),
  nrow(result), nrow(matched), sum(matched$direction_concordant),
  sum(matched$hunt_p < 5e-8)
))
