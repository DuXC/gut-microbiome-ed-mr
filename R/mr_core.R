mr_methods_for_n <- function(n) {
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 0 ||
      n != floor(n)) {
    stop("n must be one non-negative integer", call. = FALSE)
  }
  if (n == 0L) return("not_estimable")
  if (n == 1L) return("mr_wald_ratio")
  c(
    "mr_ivw_mre", "mr_weighted_median", "mr_egger_regression", "mr_raps"
  )
}

can_run_presso <- function(n, minimum = 4L) {
  is.numeric(n) && length(n) == 1L && !is.na(n) && is.finite(n) &&
    n >= minimum
}

stable_mr_seed <- function(key) {
  hexadecimal <- substr(digest::digest(
    as.character(key), algo = "xxhash32", serialize = FALSE
  ), 1L, 7L)
  as.integer(strtoi(hexadecimal, base = 16L))
}

mr_ivw_mre_constrained <- function(b_exp, b_out, se_out) {
  if (length(b_exp) < 2L) {
    return(list(b = NA_real_, se = NA_real_, pval = NA_real_, nsnp = NA_integer_))
  }
  fit <- summary(stats::lm(b_out ~ -1 + b_exp, weights = 1 / se_out^2))
  beta <- unname(fit$coef["b_exp", "Estimate"])
  raw_se <- unname(fit$coef["b_exp", "Std. Error"])
  residual_scale <- unname(fit$sigma)
  se <- raw_se / min(1, residual_scale)
  q_df <- length(b_exp) - 1L
  q <- residual_scale^2 * q_df
  list(
    b = beta, se = se,
    pval = 2 * stats::pnorm(abs(beta / se), lower.tail = FALSE),
    nsnp = length(b_exp), Q = q, Q_df = q_df,
    Q_pval = stats::pchisq(q, q_df, lower.tail = FALSE),
    residual_scale = residual_scale,
    underdispersion_floor_applied = residual_scale < 1
  )
}

run_twosamplemr_method <- function(method, data, parameters) {
  minimum <- c(
    mr_wald_ratio = 1L, mr_ivw_mre = 2L, mr_weighted_median = 3L,
    mr_egger_regression = 3L, mr_raps = 2L
  )
  if (!method %in% names(minimum)) {
    stop("Unsupported MR method: ", method, call. = FALSE)
  }
  n <- nrow(data)
  if (n < minimum[[method]]) {
    return(list(
      value = NULL, status = "not_estimable",
      error = sprintf("%s requires at least %d SNPs", method, minimum[[method]]),
      warnings = character()
    ))
  }
  warnings <- character()
  value <- tryCatch(
    withCallingHandlers(
      if (method == "mr_ivw_mre") {
        mr_ivw_mre_constrained(
          data$beta_exposure, data$beta_outcome_harmonised,
          data$se_outcome_harmonised
        )
      } else {
        do.call(
          getExportedValue("TwoSampleMR", method),
          list(
            b_exp = data$beta_exposure,
            b_out = data$beta_outcome_harmonised,
            se_exp = data$se_exposure,
            se_out = data$se_outcome_harmonised,
            parameters = parameters
          )
        )
      },
      warning = function(condition) {
        warnings <<- c(warnings, conditionMessage(condition))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(condition) condition
  )
  if (inherits(value, "error")) {
    return(list(
      value = NULL, status = "failed", error = conditionMessage(value),
      warnings = unique(warnings)
    ))
  }
  raps_unreliable <- method == "mr_raps" && any(grepl(
    "Did not converge|another finite root", warnings, ignore.case = TRUE
  ))
  if (raps_unreliable) {
    return(list(
      value = value, status = "failed",
      error = "MR-RAPS reported non-convergence or multiple finite roots",
      warnings = unique(warnings)
    ))
  }
  valid <- is.numeric(value$b) && length(value$b) == 1L &&
    is.finite(value$b) && is.numeric(value$se) && length(value$se) == 1L &&
    is.finite(value$se) && value$se > 0 && is.numeric(value$pval) &&
    length(value$pval) == 1L && is.finite(value$pval) && value$pval >= 0 &&
    value$pval <= 1
  if (!valid) {
    return(list(
      value = value, status = "not_estimable",
      error = paste(method, "returned no finite estimate"),
      warnings = unique(warnings)
    ))
  }
  list(
    value = value, status = "estimated", error = "",
    warnings = unique(warnings)
  )
}

empty_mr_method_row <- function(meta, method, nsnp, status, error_message) {
  data.frame(
    pair_id = meta$pair_id, dataset = meta$dataset,
    source_id = meta$source_id, trait = meta$trait, tier = meta$tier,
    outcome_id = meta$outcome_id, outcome_ancestry = meta$outcome_ancestry,
    analysis_role = meta$analysis_role, effect_scale = meta$effect_scale,
    method = method,
    method_role = if (method %in% c("mr_wald_ratio", "mr_ivw_mre")) {
      "primary_estimator"
    } else {
      "robust_estimator"
    },
    nsnp = as.integer(nsnp), beta = NA_real_, se = NA_real_,
    ci_lower = NA_real_, ci_upper = NA_real_, p = NA_real_,
    exponentiable = identical(meta$effect_scale, "log_odds"),
    or = NA_real_, or_ci_lower = NA_real_, or_ci_upper = NA_real_,
    mean_F = meta$mean_F, min_F = meta$min_F,
    analysis_status = status, error_message = error_message,
    warning_message = "", stringsAsFactors = FALSE
  )
}

method_result_row <- function(meta, method, nsnp, result) {
  row <- empty_mr_method_row(
    meta, method, nsnp, result$status, result$error
  )
  row$warning_message <- paste(result$warnings, collapse = " | ")
  if (!identical(result$status, "estimated")) return(row)
  value <- result$value
  row$beta <- value$b
  row$se <- value$se
  row$ci_lower <- value$b - stats::qnorm(0.975) * value$se
  row$ci_upper <- value$b + stats::qnorm(0.975) * value$se
  row$p <- value$pval
  if (row$exponentiable) {
    row$or <- exp(row$beta)
    row$or_ci_lower <- exp(row$ci_lower)
    row$or_ci_upper <- exp(row$ci_upper)
  }
  row
}

run_mr_pair <- function(data, meta, nboot = 1000L) {
  if (!is.data.frame(data)) data <- as.data.frame(data)
  required <- c(
    "beta_exposure", "se_exposure", "beta_outcome_harmonised",
    "se_outcome_harmonised", "F", "reference_id"
  )
  if (nrow(data) && length(setdiff(required, names(data)))) {
    stop("Harmonised pair lacks required MR columns", call. = FALSE)
  }
  nsnp <- nrow(data)
  if (nsnp) {
    valid <- is.finite(data$beta_exposure) & data$beta_exposure != 0 &
      is.finite(data$se_exposure) & data$se_exposure > 0 &
      is.finite(data$beta_outcome_harmonised) &
      is.finite(data$se_outcome_harmonised) &
      data$se_outcome_harmonised > 0
    if (!all(valid) || anyDuplicated(data$reference_id)) {
      stop("Harmonised MR pair has invalid or duplicate SNP rows", call. = FALSE)
    }
  }
  meta$mean_F <- if (nsnp) mean(data$F) else NA_real_
  meta$min_F <- if (nsnp) min(data$F) else NA_real_
  methods <- mr_methods_for_n(nsnp)
  if (identical(methods, "not_estimable")) {
    rows <- empty_mr_method_row(
      meta, methods, 0L, "not_estimable",
      "No harmonised instruments remained"
    )
    sensitivity <- data.frame(
      pair_id = meta$pair_id, nsnp = 0L,
      ivw_Q = NA_real_, ivw_Q_df = NA_real_, ivw_Q_p = NA_real_,
      egger_intercept = NA_real_, egger_intercept_se = NA_real_,
      egger_intercept_p = NA_real_,
      steiger_status = "not_estimable",
      steiger_reason = "No harmonised instruments remained",
      presso_status = "not_estimable", loo_status = "not_estimable",
      singlesnp_status = "not_estimable", stringsAsFactors = FALSE
    )
    return(list(estimates = rows, sensitivity = sensitivity))
  }
  parameters <- TwoSampleMR::default_parameters()
  parameters$nboot <- as.integer(nboot)
  set.seed(stable_mr_seed(meta$pair_id))
  results <- lapply(methods, function(method) {
    run_twosamplemr_method(method, data, parameters)
  })
  names(results) <- methods
  rows <- do.call(rbind, Map(
    function(method, result) method_result_row(meta, method, nsnp, result),
    methods, results
  ))
  ivw <- results[["mr_ivw_mre"]]
  egger <- results[["mr_egger_regression"]]
  ivw_value <- if (!is.null(ivw) && !is.null(ivw$value)) ivw$value else list()
  egger_value <- if (!is.null(egger) && !is.null(egger$value)) {
    egger$value
  } else {
    list()
  }
  sensitivity <- data.frame(
    pair_id = meta$pair_id, nsnp = as.integer(nsnp),
    ivw_Q = ivw_value$Q %||% NA_real_,
    ivw_Q_df = ivw_value$Q_df %||% NA_real_,
    ivw_Q_p = ivw_value$Q_pval %||% NA_real_,
    egger_intercept = egger_value$b_i %||% NA_real_,
    egger_intercept_se = egger_value$se_i %||% NA_real_,
    egger_intercept_p = egger_value$pval_i %||% NA_real_,
    steiger_status = "not_computed",
    steiger_reason = paste(
      "Binary-outcome population prevalence has not been prespecified;",
      "unavailable Steiger is not treated as support"
    ),
    presso_status = if (can_run_presso(nsnp)) {
      "deferred_until_post_FDR"
    } else {
      "not_estimable_fewer_than_4_snps"
    },
    loo_status = if (nsnp >= 3L) {
      "deferred_until_post_FDR"
    } else {
      "not_estimable_fewer_than_3_snps"
    },
    singlesnp_status = if (nsnp >= 2L) {
      "deferred_until_post_FDR"
    } else {
      "primary_wald_estimate"
    },
    stringsAsFactors = FALSE
  )
  list(estimates = rows, sensitivity = sensitivity)
}

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

build_mr_pair_registry <- function(
  audit_path = "03_data/processed/harmonised/harmonisation_audit.parquet",
  harmonised_root = "03_data/processed/harmonised"
) {
  audit <- data.table::as.data.table(arrow::read_parquet(audit_path))
  metadata <- data.table::rbindlist(lapply(
    setdiff(
      list.files(harmonised_root, pattern = "[.]parquet$", full.names = TRUE),
      audit_path
    ),
    function(path) {
      x <- data.table::as.data.table(arrow::read_parquet(path))
      ancestry_column <- intersect(
        c("ancestry_outcome", "ancestry.y", "ancestry"), names(x)
      )
      if (length(ancestry_column) != 1L) {
        stop("Harmonised file lacks one unambiguous outcome ancestry column",
             call. = FALSE)
      }
      unique(x[, .(
        outcome_id,
        outcome_ancestry = get(ancestry_column),
        analysis_role, effect_scale
      )])
    }
  ), use.names = TRUE)
  registry <- audit[, .(
    requested_instrument_rows = .N,
    harmonised_snps = sum(harmonisation_status == "harmonised"),
    excluded_snps = sum(harmonisation_status != "harmonised"),
    pair_harmonisation_status = if (
      any(harmonisation_status == "harmonised")
    ) "estimable" else "not_estimable"
  ), by = .(outcome_id, dataset, source_id, trait, tier)]
  registry <- merge(registry, metadata, by = "outcome_id", all.x = TRUE)
  registry[, pair_id := paste(
    outcome_id, dataset, source_id, tier, sep = "|"
  )]
  registry[, `:=`(
    exposure_role = ifelse(
      dataset == "microbiome_2026",
      "discovery_exposure", "independent_exposure_replication"
    ),
    exposure_outcome_overlap_class = "none_known",
    cross_analysis_dependence = ifelse(
      outcome_id == "finngen_r12_erectile_dysfunction",
      "primary_outcome",
      "known_outcome_sample_overlap_with_primary_finngen"
    )
  )]
  data.table::setorder(registry, outcome_id, dataset, source_id, tier)
  as.data.frame(registry)
}

read_harmonised_pairs <- function(
  harmonised_root = "03_data/processed/harmonised"
) {
  paths <- list.files(harmonised_root, pattern = "[.]parquet$", full.names = TRUE)
  paths <- paths[basename(paths) != "harmonisation_audit.parquet"]
  data <- data.table::rbindlist(lapply(paths, function(path) {
    data.table::as.data.table(arrow::read_parquet(path))
  }), use.names = TRUE, fill = TRUE)
  data[, pair_id := paste(
    outcome_id, dataset, source_id, tier, sep = "|"
  )]
  split(data, data$pair_id)
}

write_mr_run_receipt <- function(
  output_root = "05_results/tables", workers = 8L, nboot = 1000L,
  receipt_path = "08_qc/mr_run_receipt.csv"
) {
  harmonisation <- data.table::fread(
    "08_qc/harmonisation_inventory.csv", data.table = FALSE,
    showProgress = FALSE
  )
  harmonised_hashes <- unique(harmonisation[, c(
    "outcome_id", "output_sha256"
  )])
  harmonised_hashes <- harmonised_hashes[order(harmonised_hashes$outcome_id), ]
  paths <- file.path(output_root, c(
    "mr_pair_registry.csv", "mr_raw.csv", "mr_sensitivity.csv"
  ))
  if (!all(file.exists(paths))) {
    stop("MR outputs must exist before writing the run receipt", call. = FALSE)
  }
  receipt <- data.frame(
    R_version = R.version.string,
    TwoSampleMR_version = as.character(utils::packageVersion("TwoSampleMR")),
    mr_raps_version = as.character(utils::packageVersion("mr.raps")),
    parallel_backend = if (workers > 1L) "PSOCK" else "sequential",
    workers = as.integer(workers), weighted_median_bootstraps = as.integer(nboot),
    random_seed_basis = "xxhash32_pair_id_first_7_hex_digits",
    ivw_method = "multiplicative_random_effects",
    ivw_underdispersion_floor = TRUE,
    steiger_status = "not_computed_without_prespecified_ED_prevalence",
    harmonised_output_sha256 = paste(
      harmonised_hashes$outcome_id, harmonised_hashes$output_sha256,
      sep = "=", collapse = ";"
    ),
    harmonisation_audit_sha256 = unique(harmonisation$audit_sha256),
    mr_core_sha256 = digest::digest(
      file = "R/mr_core.R", algo = "sha256", serialize = FALSE
    ),
    pair_registry_sha256 = digest::digest(
      file = paths[[1L]], algo = "sha256", serialize = FALSE
    ),
    mr_raw_sha256 = digest::digest(
      file = paths[[2L]], algo = "sha256", serialize = FALSE
    ),
    mr_sensitivity_sha256 = digest::digest(
      file = paths[[3L]], algo = "sha256", serialize = FALSE
    ),
    completed_at_utc = format(
      Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    ),
    stringsAsFactors = FALSE
  )
  atomic_write_csv(receipt, receipt_path)
  invisible(receipt)
}

run_all_mr <- function(
  output_root = "05_results/tables", workers = 8L, nboot = 1000L
) {
  if (!is.numeric(workers) || length(workers) != 1L || is.na(workers) ||
      workers < 1 || workers != floor(workers)) {
    stop("workers must be a positive integer", call. = FALSE)
  }
  registry <- build_mr_pair_registry()
  pairs <- read_harmonised_pairs()
  worker <- function(index) {
    meta <- as.list(registry[index, , drop = FALSE])
    data <- pairs[[meta$pair_id]]
    if (is.null(data)) data <- data.frame()
    run_mr_pair(data, meta, nboot = nboot)
  }
  results <- if (workers > 1L) {
    cluster <- parallel::makePSOCKcluster(
      min(as.integer(workers), nrow(registry))
    )
    on.exit(parallel::stopCluster(cluster), add = TRUE)
    parallel::clusterCall(
      cluster,
      function(project_root) {
        setwd(project_root)
        source("R/mr_core.R")
        invisible(TRUE)
      },
      getwd()
    )
    parallel::clusterExport(
      cluster, c("registry", "pairs", "nboot"), envir = environment()
    )
    parallel::parLapply(cluster, seq_len(nrow(registry)), function(index) {
      meta <- as.list(registry[index, , drop = FALSE])
      data <- pairs[[meta$pair_id]]
      if (is.null(data)) data <- data.frame()
      run_mr_pair(data, meta, nboot = nboot)
    })
  } else {
    lapply(seq_len(nrow(registry)), worker)
  }
  failed <- vapply(results, inherits, logical(1), what = "try-error")
  if (any(failed)) {
    stop(
      "MR pair execution failed outside the structured method boundary: ",
      paste(as.character(results[failed]), collapse = " | "), call. = FALSE
    )
  }
  estimates <- data.table::rbindlist(
    lapply(results, `[[`, "estimates"), use.names = TRUE, fill = TRUE
  )
  sensitivity <- data.table::rbindlist(
    lapply(results, `[[`, "sensitivity"), use.names = TRUE, fill = TRUE
  )
  data.table::setorder(estimates, outcome_id, dataset, source_id, tier, method)
  data.table::setorder(sensitivity, pair_id)
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
  atomic_write_csv(registry, file.path(output_root, "mr_pair_registry.csv"))
  atomic_write_csv(as.data.frame(estimates), file.path(output_root, "mr_raw.csv"))
  atomic_write_csv(
    as.data.frame(sensitivity), file.path(output_root, "mr_sensitivity.csv")
  )
  write_mr_run_receipt(
    output_root = output_root, workers = workers, nboot = nboot
  )
  invisible(list(
    registry = registry, estimates = as.data.frame(estimates),
    sensitivity = as.data.frame(sensitivity)
  ))
}
