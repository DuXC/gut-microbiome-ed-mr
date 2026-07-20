adjust_with_frozen_denominator <- function(p, denominator, method = "BH") {
  if (!is.numeric(denominator) || length(denominator) != 1L ||
      is.na(denominator) || denominator < length(p) ||
      denominator != floor(denominator)) {
    stop("denominator must be an integer at least length(p)", call. = FALSE)
  }
  result <- rep(NA_real_, length(p))
  estimable <- is.finite(p) & p >= 0 & p <= 1
  if (any(estimable)) {
    result[estimable] <- stats::p.adjust(
      p[estimable], method = method, n = denominator
    )
  }
  result
}

freeze_forward_primary_family <- function(
  registry, estimates, outcome_id = "finngen_r12_erectile_dysfunction",
  discovery_dataset = "microbiome_2026", alpha = 0.05
) {
  registry <- data.table::as.data.table(registry)
  estimates <- data.table::as.data.table(estimates)
  target_outcome_id <- outcome_id
  family <- registry[
    outcome_id == target_outcome_id & dataset == discovery_dataset &
      tier == "primary"
  ]
  if (!nrow(family) || anyDuplicated(family$pair_id)) {
    stop("Forward-primary registry must contain unique eligible pairs",
         call. = FALSE)
  }
  primary <- estimates[
    method %in% c("mr_wald_ratio", "mr_ivw_mre"),
    .(
      pair_id, method, nsnp, beta, se, ci_lower, ci_upper, p,
      exponentiable, or, or_ci_lower, or_ci_upper, mean_F, min_F,
      analysis_status, error_message, warning_message
    )
  ]
  if (anyDuplicated(primary$pair_id)) {
    stop("MR results contain more than one primary estimator per pair",
         call. = FALSE)
  }
  family <- merge(family, primary, by = "pair_id", all.x = TRUE, sort = FALSE)
  family[is.na(method), `:=`(
    method = "not_estimable", nsnp = 0L,
    analysis_status = "not_estimable",
    error_message = "No harmonised instruments remained",
    warning_message = ""
  )]
  family[, `:=`(
    family = "forward_primary",
    eligible = TRUE,
    eligibility_frozen = TRUE,
    n_forward = .N,
    q = adjust_with_frozen_denominator(p, .N, method = "BH")
  )]
  family[, `:=`(
    fdr_alpha = alpha,
    fdr_significant = !is.na(q) & q < alpha,
    n_reverse = NA_integer_,
    global_bonferroni_threshold = NA_real_,
    global_bonferroni_status = "pending_reverse_family"
  )]
  data.table::setorder(family, q, p, source_id, na.last = TRUE)
  as.data.frame(family)
}

apply_forward_multiplicity <- function(
  registry_path = "05_results/tables/mr_pair_registry.csv",
  mr_path = "05_results/tables/mr_raw.csv",
  output_path = "05_results/tables/mr_multiplicity_forward.csv"
) {
  registry <- data.table::fread(registry_path, data.table = FALSE)
  estimates <- data.table::fread(mr_path, data.table = FALSE)
  result <- freeze_forward_primary_family(registry, estimates)
  atomic_write_csv(result, output_path)
  invisible(result)
}
