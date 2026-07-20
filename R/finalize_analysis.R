select_hunt_validation_estimates <- function(mr_raw, replication_map) {
  raw <- data.table::as.data.table(mr_raw)
  mapping <- data.table::as.data.table(replication_map)
  validation <- raw[
    outcome_id == "finngen_r12_erectile_dysfunction" &
      dataset == "microbiome_2026_hunt" &
      method %in% c("mr_wald_ratio", "mr_ivw_mre")
  ]
  validation[, tier_rank := ifelse(tier == "primary", 1L, 2L)]
  data.table::setorder(validation, source_id, tier_rank)
  validation <- validation[, .SD[1L], by = source_id]
  mapped <- mapping[match_status == "matched", .(
    discovery_source_id, canonical_trait_id, replication_source_id,
    replication_trait
  )]
  merge(
    mapped,
    validation[, .(
      replication_source_id = source_id,
      validation_tier = tier, validation_method = method,
      validation_nsnp = nsnp, validation_beta = beta, validation_se = se,
      validation_ci_lower = ci_lower, validation_ci_upper = ci_upper,
      validation_p = p, validation_status = analysis_status
    )],
    by = "replication_source_id", all.x = TRUE, sort = FALSE
  )
}

build_forward_replication_audit <- function(
  forward, mr_raw, sensitivity, replication_map
) {
  forward <- data.table::as.data.table(forward)
  raw <- data.table::as.data.table(mr_raw)
  sensitivity <- data.table::as.data.table(sensitivity)
  validation <- select_hunt_validation_estimates(raw, replication_map)
  result <- merge(
    forward, validation,
    by.x = "source_id", by.y = "discovery_source_id",
    all.x = TRUE, sort = FALSE
  )
  robust <- raw[
    pair_id %in% forward$pair_id &
    method %in% c("mr_weighted_median", "mr_raps") &
      analysis_status == "estimated",
    .(
      robust_estimable_count = .N,
      robust_same_sign = any(sign(beta) == sign(
        forward$beta[match(pair_id, forward$pair_id)]
      ), na.rm = TRUE),
      robust_methods_same_sign = paste(
        method[sign(beta) == sign(
          forward$beta[match(pair_id, forward$pair_id)]
        )], collapse = ";"
      )
    ),
    by = pair_id
  ]
  result <- merge(result, robust, by = "pair_id", all.x = TRUE, sort = FALSE)
  result[is.na(robust_estimable_count), `:=`(
    robust_estimable_count = 0L, robust_same_sign = FALSE,
    robust_methods_same_sign = ""
  )]
  result <- merge(
    result,
    sensitivity[, .(
      pair_id, egger_intercept_p, steiger_status, steiger_reason,
      presso_status
    )], by = "pair_id", all.x = TRUE, sort = FALSE
  )
  result[, `:=`(
    discovery_fdr_gate = !is.na(q) & q < 0.05,
    conditional_discovery_gate = !is.na(p) & p < 0.05,
    trait_mapping_gate = !is.na(replication_source_id),
    validation_overlap_class = ifelse(
      !is.na(replication_source_id), "none_known", NA_character_
    ),
    validation_effect_gate = !is.na(validation_p) & validation_p < 0.05 &
      sign(validation_beta) == sign(beta) &
      ((beta > 0 & validation_ci_lower > 0) |
         (beta < 0 & validation_ci_upper < 0)),
    robust_direction_gate = robust_same_sign,
    steiger_gate = !is.na(steiger_status) &
      steiger_status == "computed_no_reversal",
    pleiotropy_gate = nsnp >= 4L & !is.na(egger_intercept_p) &
      egger_intercept_p >= 0.05 & presso_status == "computed_no_severe_pleiotropy"
  )]
  result[, `:=`(
    replicated = discovery_fdr_gate & trait_mapping_gate &
      validation_effect_gate & robust_direction_gate & steiger_gate &
      pleiotropy_gate,
    conditional_go_candidate = conditional_discovery_gate &
      trait_mapping_gate & validation_effect_gate & robust_direction_gate &
      steiger_gate & pleiotropy_gate
  )]
  result[, gate_failure_reasons := vapply(seq_len(.N), function(index) {
    gates <- c(
      discovery_fdr = result$discovery_fdr_gate[[index]],
      trait_mapping = result$trait_mapping_gate[[index]],
      validation_effect = result$validation_effect_gate[[index]],
      robust_direction = result$robust_direction_gate[[index]],
      steiger = result$steiger_gate[[index]],
      pleiotropy = result$pleiotropy_gate[[index]]
    )
    paste(names(gates)[!gates | is.na(gates)], collapse = ";")
  }, character(1))]
  data.table::setorder(result, q, p, source_id, na.last = TRUE)
  as.data.frame(result)
}

combine_directional_multiplicity <- function(forward, reverse, replication) {
  forward <- data.table::as.data.table(forward)
  reverse <- data.table::as.data.table(reverse)
  replication <- data.table::as.data.table(replication)
  forward_count <- nrow(forward)
  reverse_count <- nrow(reverse)
  if (!forward_count || !reverse_count) {
    stop("Both frozen direction-specific families are required", call. = FALSE)
  }
  global_threshold <- 0.05 / (forward_count + reverse_count)
  forward <- merge(
    forward,
    replication[, .(pair_id, replicated, conditional_go_candidate)],
    by = "pair_id", all.x = TRUE, sort = FALSE
  )
  stale_final_columns <- intersect(
    c(
      "n_forward", "n_reverse", "global_bonferroni_threshold",
      "global_bonferroni_status"
    ),
    names(forward)
  )
  if (length(stale_final_columns)) {
    forward[, (stale_final_columns) := NULL]
  }
  forward[, `:=`(
    n_forward = as.integer(forward_count),
    n_reverse = as.integer(reverse_count),
    global_bonferroni_threshold = as.numeric(global_threshold),
    global_bonferroni_status = "computed",
    bonferroni_pass = !is.na(p) & p < global_threshold,
    analysis_role_final = "forward_causal",
    evidence_label = ifelse(
      analysis_status != "estimated" | is.na(p), "insufficient",
      ifelse(
        replicated,
        ifelse(p < global_threshold, "strict", "primary"), "exploratory"
      )
    )
  )]
  reverse[, `:=`(
    n_forward = as.integer(forward_count),
    n_reverse = as.integer(reverse_count),
    global_bonferroni_threshold = as.numeric(global_threshold),
    global_bonferroni_status = "computed",
    bonferroni_pass = !is.na(p) & p < global_threshold,
    analysis_role_final = "reverse_sensitivity",
    evidence_label = ifelse(
      analysis_status == "estimated" & !is.na(p),
      "exploratory", "insufficient"
    ),
    replicated = NA,
    conditional_go_candidate = NA
  )]
  forward$direction <- "forward"
  reverse$direction <- "reverse"
  combined <- data.table::rbindlist(
    list(forward, reverse), use.names = TRUE, fill = TRUE
  )
  data.table::setorder(combined, direction, q, p, source_id, na.last = TRUE)
  as.data.frame(combined)
}

finalize_analysis <- function(
  forward_path = "05_results/tables/mr_multiplicity_forward.csv",
  reverse_path = "05_results/tables/reverse_mr_multiplicity.csv",
  mr_raw_path = "05_results/tables/mr_raw.csv",
  sensitivity_path = "05_results/tables/mr_sensitivity.csv",
  replication_map_path = "08_qc/exposure_replication_map.csv",
  replication_output = "05_results/tables/forward_replication_audit.csv",
  combined_output = "05_results/tables/mr_multiplicity.csv",
  decision_output = "05_results/tables/analysis_decision.csv"
) {
  forward <- data.table::fread(forward_path, data.table = FALSE)
  reverse <- data.table::fread(reverse_path, data.table = FALSE)
  raw <- data.table::fread(mr_raw_path, data.table = FALSE)
  sensitivity <- data.table::fread(sensitivity_path, data.table = FALSE)
  mapping <- data.table::fread(replication_map_path, data.table = FALSE)
  replication <- build_forward_replication_audit(
    forward, raw, sensitivity, mapping
  )
  combined <- combine_directional_multiplicity(
    forward, reverse, replication
  )
  go <- any(replication$replicated)
  conditional <- any(replication$conditional_go_candidate)
  decision <- data.frame(
    decision = if (go) "GO" else if (conditional) "CONDITIONAL GO" else "NO-GO",
    n_forward = nrow(forward), n_reverse = nrow(reverse),
    forward_fdr_signals = sum(forward$fdr_significant),
    reverse_fdr_signals = sum(reverse$fdr_significant),
    replicated_forward_signals = sum(replication$replicated),
    conditional_go_candidates = sum(replication$conditional_go_candidate),
    global_bonferroni_threshold = unique(combined$global_bonferroni_threshold),
    interpretation = if (go) {
      "At least one forward signal passed every prespecified gate"
    } else if (conditional) {
      "No FDR signal; at least one nominal genome-wide-instrument signal passed all other gates"
    } else {
      "No forward association satisfied the prespecified GO or conditional-GO gates"
    },
    stringsAsFactors = FALSE
  )
  atomic_write_csv(replication, replication_output)
  atomic_write_csv(combined, combined_output)
  atomic_write_csv(decision, decision_output)
  invisible(list(
    replication = replication, combined = combined, decision = decision
  ))
}

write_final_analysis_receipt <- function(
  receipt_path = "08_qc/final_analysis_receipt.csv",
  input_paths = c(
    forward_multiplicity = "05_results/tables/mr_multiplicity_forward.csv",
    reverse_multiplicity = "05_results/tables/reverse_mr_multiplicity.csv",
    forward_mr_raw = "05_results/tables/mr_raw.csv",
    forward_sensitivity = "05_results/tables/mr_sensitivity.csv",
    replication_map = "08_qc/exposure_replication_map.csv"
  ),
  output_paths = c(
    replication_audit = "05_results/tables/forward_replication_audit.csv",
    combined_multiplicity = "05_results/tables/mr_multiplicity.csv",
    analysis_decision = "05_results/tables/analysis_decision.csv"
  ),
  code_paths = c(
    finalization = "R/finalize_analysis.R",
    finalization_script = "scripts/13_finalize_analysis.R"
  )
) {
  required <- c(input_paths, output_paths, code_paths)
  if (is.null(names(input_paths)) || is.null(names(output_paths)) ||
      is.null(names(code_paths)) || !all(file.exists(required))) {
    stop("Final analysis receipt inputs must be named existing files",
         call. = FALSE)
  }
  hash_files <- function(paths) {
    paste(names(paths), vapply(paths, function(path) {
      digest::digest(file = path, algo = "sha256", serialize = FALSE)
    }, character(1)), sep = "=", collapse = ";")
  }
  decision <- data.table::fread(
    output_paths[["analysis_decision"]], data.table = FALSE,
    showProgress = FALSE
  )
  if (nrow(decision) != 1L) {
    stop("Final analysis decision must contain exactly one row", call. = FALSE)
  }
  receipt <- data.frame(
    decision = decision$decision[[1L]],
    n_forward = decision$n_forward[[1L]],
    n_reverse = decision$n_reverse[[1L]],
    global_bonferroni_threshold =
      decision$global_bonferroni_threshold[[1L]],
    input_sha256 = hash_files(input_paths),
    output_sha256 = hash_files(output_paths),
    code_sha256 = hash_files(code_paths),
    completed_at_utc = format(
      Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    ),
    stringsAsFactors = FALSE
  )
  atomic_write_csv(receipt, receipt_path)
  invisible(receipt)
}
