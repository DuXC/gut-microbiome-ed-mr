harmonise_reverse_pair <- function(exposure, outcome, outcome_metadata) {
  exposure <- data.table::as.data.table(exposure)
  outcome <- data.table::as.data.table(outcome)
  exposure <- data.table::copy(exposure)
  outcome <- data.table::copy(outcome)
  exposure[, instrument_record_id := .I]
  data.table::setnames(
    exposure,
    c("chr", "pos", "ea", "oa", "beta", "se", "eaf", "p", "n", "build"),
    paste0(c("chr", "pos", "ea", "oa", "beta", "se", "eaf", "p", "n", "build"),
           "_exposure")
  )
  if (nrow(outcome)) {
    outcome[, outcome_record_id := .I]
    data.table::setnames(
      outcome,
      c("snp", "chr", "pos", "ea", "oa", "beta", "se", "eaf", "p", "n", "build"),
      c("reference_id", paste0(
        c("chr", "pos", "ea", "oa", "beta", "se", "eaf", "p", "n", "build"),
        "_outcome"
      ))
    )
  } else {
    outcome <- data.table::data.table(
      reference_id = character(), outcome_record_id = integer(),
      chr_outcome = character(), pos_outcome = numeric(),
      ea_outcome = character(), oa_outcome = character(),
      beta_outcome = numeric(), se_outcome = numeric(), eaf_outcome = numeric(),
      p_outcome = numeric(), n_outcome = numeric(), build_outcome = character()
    )
  }
  joined <- merge(
    exposure, outcome, by = "reference_id", all.x = TRUE, sort = FALSE,
    allow.cartesian = TRUE
  )
  joined <- data.table::as.data.table(classify_harmonisation_candidates(
    joined, palindromic_maf_max = 0.42, eaf_tolerance = 0.10
  ))
  joined[, harmonisable_rows := sum(candidate_keep), by = instrument_record_id]
  joined[harmonisable_rows > 1L, `:=`(
    candidate_keep = FALSE,
    harmonisation_status = "multiallelic_multiple_matches"
  )]
  selected <- joined[candidate_keep == TRUE]
  selected[, `:=`(
    beta_outcome_harmonised = outcome_sign * beta_outcome,
    se_outcome_harmonised = se_outcome,
    outcome_source_id = outcome_metadata$source_id[[1L]],
    outcome_trait = outcome_metadata$trait[[1L]],
    outcome_canonical_trait_id = outcome_metadata$canonical_trait_id[[1L]],
    analysis_role = "reverse_sensitivity",
    matching_basis = "rsID_and_alleles_across_declared_builds"
  )]
  status <- joined[, {
    keep_count <- sum(candidate_keep)
    pair_status <- if (keep_count == 1L) {
      "harmonised"
    } else if (any(harmonisation_status == "multiallelic_multiple_matches")) {
      "multiallelic_multiple_matches"
    } else {
      choose_harmonisation_failure(harmonisation_status)
    }
    list(harmonisation_status = pair_status)
  }, by = instrument_record_id]
  audit <- data.frame(
    source_id = outcome_metadata$source_id[[1L]],
    trait = outcome_metadata$trait[[1L]],
    canonical_trait_id = outcome_metadata$canonical_trait_id[[1L]],
    requested_instruments = nrow(exposure),
    harmonised_snps = sum(status$harmonisation_status == "harmonised"),
    outcome_rsid_missing = sum(
      status$harmonisation_status == "outcome_rsid_missing"
    ),
    allele_mismatch = sum(status$harmonisation_status == "allele_mismatch"),
    palindromic_excluded = sum(grepl(
      "^palindromic_", status$harmonisation_status
    )),
    multiallelic_multiple_matches = sum(
      status$harmonisation_status == "multiallelic_multiple_matches"
    ),
    pair_status = if (nrow(selected)) "estimable" else "not_estimable",
    stringsAsFactors = FALSE
  )
  list(harmonised = as.data.frame(selected), audit = audit)
}

build_reverse_harmonised_layer <- function(
  exposure_path = "03_data/processed/reverse/reverse_ed_instruments.parquet",
  outcome_root = "03_data/processed/reverse/microbiome_outcomes",
  metadata_path = "08_qc/exposure_metadata_catalog.csv",
  output_path = "03_data/processed/reverse/reverse_harmonised.parquet",
  audit_path = "03_data/processed/reverse/reverse_harmonisation_audit.parquet",
  inventory_path = "08_qc/reverse_harmonisation_inventory.csv"
) {
  exposure <- as.data.frame(arrow::read_parquet(exposure_path))
  metadata <- data.table::fread(
    metadata_path, data.table = FALSE, showProgress = FALSE
  )
  metadata <- metadata[metadata$dataset == "microbiome_2026", ]
  paths <- file.path(outcome_root, paste0(metadata$source_id, ".parquet"))
  if (!all(file.exists(paths))) {
    stop("Reverse microbiome outcome extraction is incomplete", call. = FALSE)
  }
  results <- lapply(seq_len(nrow(metadata)), function(index) {
    outcome <- as.data.frame(arrow::read_parquet(paths[[index]]))
    harmonise_reverse_pair(
      exposure, outcome, metadata[index, , drop = FALSE]
    )
  })
  harmonised <- data.table::rbindlist(
    lapply(results, `[[`, "harmonised"), use.names = TRUE, fill = TRUE
  )
  audit <- data.table::rbindlist(
    lapply(results, `[[`, "audit"), use.names = TRUE, fill = TRUE
  )
  data.table::setorder(harmonised, outcome_source_id, reference_id)
  data.table::setorder(audit, source_id)
  write_candidate_parquet_atomic(as.data.frame(harmonised), output_path)
  write_candidate_parquet_atomic(as.data.frame(audit), audit_path)
  inventory <- data.frame(
    reverse_family_traits = nrow(audit),
    estimable_traits = sum(audit$pair_status == "estimable"),
    requested_instrument_rows = sum(audit$requested_instruments),
    harmonised_rows = sum(audit$harmonised_snps),
    missing_rows = sum(audit$outcome_rsid_missing),
    allele_mismatch_rows = sum(audit$allele_mismatch),
    palindromic_excluded_rows = sum(audit$palindromic_excluded),
    harmonised_sha256 = digest::digest(
      file = output_path, algo = "sha256", serialize = FALSE
    ),
    audit_sha256 = digest::digest(
      file = audit_path, algo = "sha256", serialize = FALSE
    ),
    completed_at_utc = format(
      Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    ), stringsAsFactors = FALSE
  )
  atomic_write_csv(inventory, inventory_path)
  invisible(list(
    harmonised = as.data.frame(harmonised), audit = as.data.frame(audit),
    inventory = inventory
  ))
}

run_all_reverse_mr <- function(
  harmonised_path = "03_data/processed/reverse/reverse_harmonised.parquet",
  audit_path = "03_data/processed/reverse/reverse_harmonisation_audit.parquet",
  output_root = "05_results/tables", workers = 8L, nboot = 1000L
) {
  data <- data.table::as.data.table(arrow::read_parquet(harmonised_path))
  audit <- data.table::as.data.table(arrow::read_parquet(audit_path))
  registry <- audit[, .(
    pair_id = paste0("reverse|", source_id),
    dataset = "ed_2025_eur_reverse_exposure", source_id, trait,
    canonical_trait_id, tier = "primary",
    outcome_id = source_id, outcome_ancestry = "EUR",
    analysis_role = "reverse_sensitivity",
    effect_scale = "microbiome_trait_units_per_standardized_ED_exposure",
    harmonised_snps, pair_harmonisation_status = pair_status,
    family = "reverse", eligible = TRUE, eligibility_frozen = TRUE
  )]
  data[, pair_id := paste0("reverse|", outcome_source_id)]
  pairs <- split(data, data$pair_id)
  worker <- function(index) {
    meta <- as.list(registry[index, , drop = FALSE])
    pair <- pairs[[meta$pair_id]]
    if (is.null(pair)) pair <- data.frame()
    run_mr_pair(pair, meta, nboot = nboot)
  }
  if (workers > 1L) {
    cluster <- parallel::makePSOCKcluster(
      min(as.integer(workers), nrow(registry))
    )
    on.exit(parallel::stopCluster(cluster), add = TRUE)
    parallel::clusterCall(cluster, function(project_root) {
      setwd(project_root)
      source("R/mr_core.R")
      invisible(TRUE)
    }, getwd())
    parallel::clusterExport(
      cluster, c("registry", "pairs", "nboot"), envir = environment()
    )
    results <- parallel::parLapply(
      cluster, seq_len(nrow(registry)), function(index) {
        meta <- as.list(registry[index, , drop = FALSE])
        pair <- pairs[[meta$pair_id]]
        if (is.null(pair)) pair <- data.frame()
        run_mr_pair(pair, meta, nboot = nboot)
      }
    )
  } else {
    results <- lapply(seq_len(nrow(registry)), worker)
  }
  estimates <- data.table::rbindlist(
    lapply(results, `[[`, "estimates"), use.names = TRUE, fill = TRUE
  )
  sensitivity <- data.table::rbindlist(
    lapply(results, `[[`, "sensitivity"), use.names = TRUE, fill = TRUE
  )
  primary <- estimates[method %in% c("mr_wald_ratio", "mr_ivw_mre")]
  multiplicity <- merge(
    registry, primary[, .(
      pair_id, method, nsnp, beta, se, ci_lower, ci_upper, p,
      analysis_status, error_message, warning_message
    )], by = "pair_id", all.x = TRUE, sort = FALSE
  )
  multiplicity[is.na(method), `:=`(
    method = "not_estimable", nsnp = 0L,
    analysis_status = "not_estimable",
    error_message = "No harmonised instruments remained",
    warning_message = ""
  )]
  multiplicity[, `:=`(
    n_reverse = .N,
    q = adjust_with_frozen_denominator(p, .N, method = "BH"),
    fdr_significant = FALSE
  )]
  multiplicity[, fdr_significant := !is.na(q) & q < 0.05]
  data.table::setorder(estimates, source_id, method)
  data.table::setorder(sensitivity, pair_id)
  data.table::setorder(multiplicity, q, p, source_id, na.last = TRUE)
  atomic_write_csv(
    as.data.frame(registry), file.path(output_root, "reverse_mr_pair_registry.csv")
  )
  atomic_write_csv(
    as.data.frame(estimates), file.path(output_root, "reverse_mr_raw.csv")
  )
  atomic_write_csv(
    as.data.frame(sensitivity),
    file.path(output_root, "reverse_mr_sensitivity.csv")
  )
  atomic_write_csv(
    as.data.frame(multiplicity),
    file.path(output_root, "reverse_mr_multiplicity.csv")
  )
  invisible(list(
    registry = as.data.frame(registry), estimates = as.data.frame(estimates),
    sensitivity = as.data.frame(sensitivity),
    multiplicity = as.data.frame(multiplicity)
  ))
}

write_reverse_run_receipt <- function(
  receipt_path = "08_qc/reverse_run_receipt.csv", workers = 8L,
  nboot = 1000L
) {
  required <- c(
    "03_data/processed/reverse/reverse_ed_instruments.parquet",
    "03_data/processed/reverse/reverse_harmonised.parquet",
    "03_data/processed/reverse/reverse_harmonisation_audit.parquet",
    "08_qc/reverse_microbiome_outcome_inventory.csv",
    "05_results/tables/reverse_mr_pair_registry.csv",
    "05_results/tables/reverse_mr_raw.csv",
    "05_results/tables/reverse_mr_sensitivity.csv",
    "05_results/tables/reverse_mr_multiplicity.csv"
  )
  if (!all(file.exists(required))) {
    stop("Reverse outputs must exist before writing the run receipt",
         call. = FALSE)
  }
  code_paths <- c(
    "R/reverse_instruments.R", "R/reverse_outcomes.R",
    "R/reverse_analysis.R", "R/outcomes.R", "R/mr_core.R",
    "R/multiplicity.R",
    "scripts/extract_outcome_ids.awk"
  )
  receipt <- data.frame(
    workers = as.integer(workers), parallel_backend = "PSOCK",
    weighted_median_bootstraps = as.integer(nboot),
    reverse_instrument_sha256 = digest::digest(
      file = required[[1L]], algo = "sha256", serialize = FALSE
    ),
    reverse_harmonised_sha256 = digest::digest(
      file = required[[2L]], algo = "sha256", serialize = FALSE
    ),
    reverse_harmonisation_audit_sha256 = digest::digest(
      file = required[[3L]], algo = "sha256", serialize = FALSE
    ),
    reverse_outcome_inventory_sha256 = digest::digest(
      file = required[[4L]], algo = "sha256", serialize = FALSE
    ),
    reverse_mr_registry_sha256 = digest::digest(
      file = required[[5L]], algo = "sha256", serialize = FALSE
    ),
    reverse_mr_raw_sha256 = digest::digest(
      file = required[[6L]], algo = "sha256", serialize = FALSE
    ),
    reverse_mr_sensitivity_sha256 = digest::digest(
      file = required[[7L]], algo = "sha256", serialize = FALSE
    ),
    reverse_multiplicity_sha256 = digest::digest(
      file = required[[8L]], algo = "sha256", serialize = FALSE
    ),
    code_sha256 = paste(
      basename(code_paths), vapply(code_paths, function(path) {
        digest::digest(file = path, algo = "sha256", serialize = FALSE)
      }, character(1)), sep = "=", collapse = ";"
    ),
    completed_at_utc = format(
      Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    ), stringsAsFactors = FALSE
  )
  atomic_write_csv(receipt, receipt_path)
  invisible(receipt)
}
