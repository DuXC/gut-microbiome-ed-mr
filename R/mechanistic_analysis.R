MECHANISTIC_TOTAL_OUTCOME_ID <- "finngen_r12_erectile_dysfunction"

CYTOKINE_M_TO_Y_COLUMNS <- c(
  "mediator_id", "mediator_name", "source_id", "lead_snp",
  "instrument_class", "heterogeneity_sensitivity_status",
  "source_gwas_verification", "outcome_id", "outcome_overlap_class",
  "harmonisation_status", "nsnp", "beta", "se", "ci_lower", "ci_upper",
  "p", "p_for_fdr", "q", "fdr_alpha", "fdr_significant", "odds_ratio",
  "or_ci_lower", "or_ci_upper", "instrument_F", "analysis_status",
  "evidence_label", "family", "family_denominator"
)

CYTOKINE_X_TO_M_COLUMNS <- c(
  "exposure_id", "module_id", "exposure_trait", "mediator_id",
  "mediator_name", "mediator_source_id", "instrument_snp",
  "source_gwas_verification", "x_m_overlap_class", "exposure_beta",
  "exposure_se", "mediator_beta", "mediator_se", "beta", "se",
  "ci_lower", "ci_upper", "p", "p_for_fdr", "q", "fdr_alpha",
  "provisional_fdr_signal", "fdr_significant", "odds_ratio",
  "instrument_F", "analysis_status", "multiplicity_status",
  "evidence_label", "family", "family_denominator"
)

ENDOTHELIAL_X_TO_M_COLUMNS <- c(
  "exposure_id", "module_id", "exposure_trait", "mediator_id",
  "mediator_name", "mediator_source_id", "instrument_snp",
  "source_gwas_verification", "x_m_overlap_class", "exposure_beta",
  "exposure_se", "mediator_beta", "mediator_se", "beta", "se",
  "ci_lower", "ci_upper", "p", "p_for_fdr", "q", "fdr_alpha",
  "fdr_significant", "instrument_F", "analysis_status",
  "multiplicity_status", "evidence_label", "family", "family_denominator"
)

MECHANISTIC_INDIRECT_COLUMNS <- c(
  "exposure_id", "module_id", "exposure_trait", "mediator_id",
  "mediator_name", "a_beta", "a_se", "b_beta", "b_se", "indirect_beta",
  "indirect_se", "ci_lower", "ci_upper", "p", "p_for_fdr", "q",
  "fdr_alpha", "product_fdr_significant", "x_to_m_fdr_significant",
  "m_to_y_fdr_significant", "component_fdr_gate", "overlap_class",
  "variance_status", "colocalization_status", "analysis_status",
  "evidence_label", "family", "family_denominator"
)

cytokine_cis_instrument_table <- function(cis_leads, mediators) {
  cytokines <- mediators[mediators$family == "cytokine", , drop = FALSE]
  index <- match(cis_leads$mediator_id, cytokines$mediator_id)
  if (anyNA(index)) {
    stop("Cytokine cis instruments do not match mediator registry", call. = FALSE)
  }
  result <- data.frame(
    reference_id = cis_leads$lead_snp,
    chr = as.character(cis_leads$chr_grch37),
    pos = cis_leads$position_grch37,
    ea = toupper(cis_leads$effect_allele),
    oa = toupper(cis_leads$other_allele),
    beta = cis_leads$beta,
    se = cis_leads$se,
    eaf = cis_leads$eaf,
    p = cis_leads$p,
    n = NA_real_,
    build = "GRCh37",
    source_id = cis_leads$source_id,
    trait = cytokines$mediator_name[index],
    dataset = "cytokines_2025_meta",
    F = (cis_leads$beta / cis_leads$se)^2,
    tier = "paper_classified_cis_screen",
    stringsAsFactors = FALSE
  )
  if (any(!is.finite(result$F) | result$F <= 10)) {
    stop("Cytokine cis instrument F-statistic gate failed", call. = FALSE)
  }
  result
}

cytokine_m_to_y_family <- function(
  harmonised, audit, mediators, cis_leads,
  verified_source_ids = character(), fdr_alpha = 0.05
) {
  cytokines <- mediators[mediators$family == "cytokine", , drop = FALSE]
  if (nrow(cytokines) != 40L || nrow(cis_leads) != 19L ||
      !is.data.frame(harmonised) || !is.data.frame(audit)) {
    stop("Cytokine M-to-Y family inputs are invalid", call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(cytokines)), function(index) {
    mediator <- cytokines[index, , drop = FALSE]
    cis <- cis_leads[
      cis_leads$mediator_id == mediator$mediator_id[[1L]], , drop = FALSE
    ]
    if (!nrow(cis)) {
      return(data.frame(
        mediator_id = mediator$mediator_id, mediator_name = mediator$mediator_name,
        source_id = mediator$source_id, lead_snp = NA_character_,
        instrument_class = "no_paper_classified_cis_lead",
        heterogeneity_sensitivity_status = "not_applicable",
        source_gwas_verification = ifelse(
          mediator$source_id %in% verified_source_ids, "verified", "pending"
        ),
        outcome_id = MECHANISTIC_TOTAL_OUTCOME_ID,
        outcome_overlap_class = mediator$outcome_overlap_class,
        harmonisation_status = "not_attempted_no_cis_instrument",
        nsnp = 0L, beta = NA_real_, se = NA_real_, ci_lower = NA_real_,
        ci_upper = NA_real_, p = NA_real_, instrument_F = NA_real_,
        analysis_status = "not_estimable_no_cis_instrument",
        stringsAsFactors = FALSE
      ))
    }
    audit_hit <- audit$source_id == cis$source_id &
      audit$reference_id == cis$lead_snp
    if (sum(audit_hit) != 1L) {
      stop("Cytokine M-to-Y harmonisation audit is incomplete", call. = FALSE)
    }
    harmonised_hit <- harmonised$source_id == cis$source_id &
      harmonised$reference_id == cis$lead_snp
    if (sum(harmonised_hit) > 1L) {
      stop("Cytokine M-to-Y has duplicate harmonised rows", call. = FALSE)
    }
    estimated <- sum(harmonised_hit) == 1L
    beta <- se <- p <- NA_real_
    if (estimated) {
      row <- harmonised[harmonised_hit, , drop = FALSE]
      beta <- row$beta_outcome_harmonised / row$beta_exposure
      se <- row$se_outcome_harmonised / abs(row$beta_exposure)
      p <- 2 * stats::pnorm(abs(beta / se), lower.tail = FALSE)
    }
    data.frame(
      mediator_id = mediator$mediator_id, mediator_name = mediator$mediator_name,
      source_id = mediator$source_id, lead_snp = cis$lead_snp,
      instrument_class = cis$instrument_class,
      heterogeneity_sensitivity_status = cis$heterogeneity_sensitivity_status,
      source_gwas_verification = ifelse(
        mediator$source_id %in% verified_source_ids, "verified", "pending"
      ),
      outcome_id = MECHANISTIC_TOTAL_OUTCOME_ID,
      outcome_overlap_class = mediator$outcome_overlap_class,
      harmonisation_status = audit$harmonisation_status[audit_hit],
      nsnp = as.integer(estimated), beta = beta, se = se,
      ci_lower = ifelse(estimated, beta - 1.96 * se, NA_real_),
      ci_upper = ifelse(estimated, beta + 1.96 * se, NA_real_),
      p = p, instrument_F = (cis$beta / cis$se)^2,
      analysis_status = ifelse(
        estimated, "estimated_screening_known_partial_overlap",
        "not_estimable_after_harmonisation"
      ),
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  estimated <- result$nsnp == 1L & is.finite(result$p)
  result$p_for_fdr <- ifelse(estimated, result$p, 1)
  result$q <- stats::p.adjust(result$p_for_fdr, method = "BH", n = 40L)
  result$fdr_alpha <- fdr_alpha
  result$fdr_significant <- estimated & result$q < fdr_alpha
  result$odds_ratio <- ifelse(estimated, exp(result$beta), NA_real_)
  result$or_ci_lower <- ifelse(estimated, exp(result$ci_lower), NA_real_)
  result$or_ci_upper <- ifelse(estimated, exp(result$ci_upper), NA_real_)
  result$evidence_label <- ifelse(
    result$fdr_significant,
    "fdr_supported_screening_known_partial_overlap",
    ifelse(estimated, "screening_not_fdr_supported", "non_estimable")
  )
  result$family <- "cytokine_m_to_y"
  result$family_denominator <- 40L
  result <- result[, CYTOKINE_M_TO_Y_COLUMNS, drop = FALSE]
  rownames(result) <- NULL
  result
}

cytokine_x_to_m_family <- function(
  extracts, mediators, exposure_freeze, completed_source_ids,
  fdr_alpha = 0.05
) {
  cytokines <- mediators[mediators$family == "cytokine", , drop = FALSE]
  required_freeze <- c(
    "exposure_id", "module_id", "trait", "reference_id", "exposure_beta",
    "exposure_se", "F"
  )
  if (nrow(cytokines) != 40L || nrow(exposure_freeze) != 5L ||
      length(setdiff(required_freeze, names(exposure_freeze))) ||
      !is.data.frame(extracts)) {
    stop("Cytokine X-to-M family inputs are invalid", call. = FALSE)
  }
  family_complete <- setequal(completed_source_ids, cytokines$source_id)
  rows <- vector("list", 200L)
  row_index <- 0L
  for (mediator_index in seq_len(nrow(cytokines))) {
    mediator <- cytokines[mediator_index, , drop = FALSE]
    source_complete <- mediator$source_id[[1L]] %in% completed_source_ids
    for (exposure_index in seq_len(nrow(exposure_freeze))) {
      row_index <- row_index + 1L
      exposure <- exposure_freeze[exposure_index, , drop = FALSE]
      hit <- extracts$source_id == mediator$source_id[[1L]] &
        extracts$request_role == "x_instrument_to_mediator" &
        extracts$request_id == exposure$exposure_id[[1L]]
      if (sum(hit) > 1L) {
        stop("Cytokine X-to-M extract has duplicate target rows", call. = FALSE)
      }
      matched <- sum(hit) == 1L &&
        extracts$extraction_status[hit] == "matched"
      mediator_beta <- mediator_se <- p <- NA_real_
      beta <- se <- NA_real_
      if (matched) {
        mediator_beta <- extracts$beta[hit]
        mediator_se <- extracts$se[hit]
        beta <- mediator_beta / exposure$exposure_beta[[1L]]
        se <- mediator_se / abs(exposure$exposure_beta[[1L]])
        p <- 2 * stats::pnorm(abs(beta / se), lower.tail = FALSE)
      }
      status <- if (matched) {
        "estimated_single_instrument"
      } else if (!source_complete) {
        "pending_source_download"
      } else {
        "not_estimable_instrument_missing_in_mediator_gwas"
      }
      rows[[row_index]] <- data.frame(
        exposure_id = exposure$exposure_id,
        module_id = exposure$module_id,
        exposure_trait = exposure$trait,
        mediator_id = mediator$mediator_id,
        mediator_name = mediator$mediator_name,
        mediator_source_id = mediator$source_id,
        instrument_snp = exposure$reference_id,
        source_gwas_verification = ifelse(
          source_complete, "verified", "pending"
        ),
        x_m_overlap_class = "possible_unresolved",
        exposure_beta = exposure$exposure_beta,
        exposure_se = exposure$exposure_se,
        mediator_beta = mediator_beta, mediator_se = mediator_se,
        beta = beta, se = se,
        ci_lower = ifelse(matched, beta - 1.96 * se, NA_real_),
        ci_upper = ifelse(matched, beta + 1.96 * se, NA_real_),
        p = p, instrument_F = exposure$F,
        analysis_status = status,
        stringsAsFactors = FALSE
      )
    }
  }
  result <- do.call(rbind, rows)
  estimated <- result$analysis_status == "estimated_single_instrument"
  result$p_for_fdr <- ifelse(estimated, result$p, 1)
  result$q <- stats::p.adjust(result$p_for_fdr, method = "BH", n = 200L)
  result$fdr_alpha <- fdr_alpha
  result$provisional_fdr_signal <- estimated & result$q < fdr_alpha
  result$fdr_significant <- family_complete & result$provisional_fdr_signal
  result$odds_ratio <- NA_real_
  result$multiplicity_status <- ifelse(
    family_complete, "complete_200_test_family", "provisional_incomplete_family"
  )
  result$evidence_label <- ifelse(
    result$fdr_significant,
    "fdr_supported_single_instrument_possible_overlap",
    ifelse(estimated, "exploratory_single_instrument", "non_estimable_or_pending")
  )
  result$family <- "cytokine_x_to_m"
  result$family_denominator <- 200L
  result <- result[, CYTOKINE_X_TO_M_COLUMNS, drop = FALSE]
  rownames(result) <- NULL
  result
}

extract_mechanistic_total_effects <- function(
  mr_raw,
  exposures,
  outcome_id = MECHANISTIC_TOTAL_OUTCOME_ID,
  fdr_alpha = 0.05
) {
  required <- c(
    "dataset", "source_id", "tier", "outcome_id", "effect_scale",
    "method", "method_role", "nsnp", "beta", "se", "ci_lower",
    "ci_upper", "p", "mean_F", "min_F", "analysis_status",
    "error_message", "warning_message"
  )
  if (!is.data.frame(mr_raw) || !all(required %in% names(mr_raw))) {
    stop("Mechanistic total-effect source schema mismatch", call. = FALSE)
  }
  validate_mechanistic_exposures(exposures)
  if (!is.character(outcome_id) || length(outcome_id) != 1L ||
      is.na(outcome_id) || !nzchar(outcome_id) ||
      !is.numeric(fdr_alpha) || length(fdr_alpha) != 1L ||
      is.na(fdr_alpha) || fdr_alpha <= 0 || fdr_alpha >= 1) {
    stop("Mechanistic total-effect arguments are invalid", call. = FALSE)
  }

  selected <- mr_raw[
    mr_raw$dataset == "microbiome_2026_hunt" &
      mr_raw$source_id %in% exposures$source_id &
      mr_raw$tier == "primary" &
      mr_raw$outcome_id == outcome_id &
      mr_raw$method_role == "primary_estimator",
    , drop = FALSE
  ]
  counts <- table(factor(selected$source_id, levels = exposures$source_id))
  if (nrow(selected) != 5L || any(counts != 1L)) {
    stop("Expected exactly one frozen total-effect row per exposure", call. = FALSE)
  }
  selected <- selected[match(exposures$source_id, selected$source_id), , drop = FALSE]
  estimated <- selected$analysis_status == "estimated"
  valid_estimate <- is.finite(selected$beta) & is.finite(selected$se) &
    selected$se > 0 & is.finite(selected$p) & selected$p >= 0 &
    selected$p <= 1 & selected$method == "mr_wald_ratio" &
    selected$nsnp == 1L & selected$effect_scale == "log_odds"
  if (any(estimated & !valid_estimate) ||
      any(!estimated &
        (!is.na(selected$p) | !is.na(selected$beta) | !is.na(selected$se)))) {
    stop("Frozen total-effect rows contain invalid estimate states", call. = FALSE)
  }

  p_for_fdr <- ifelse(estimated, selected$p, 1)
  q <- stats::p.adjust(p_for_fdr, method = "BH", n = 5L)
  significant <- estimated & q < fdr_alpha
  label <- ifelse(
    significant,
    "fdr_supported_single_instrument_total_effect",
    ifelse(estimated, "exploratory_not_fdr_supported", "insufficient_non_estimable")
  )
  result <- data.frame(
    exposure_id = exposures$exposure_id,
    source_id = exposures$source_id,
    module_id = exposures$module_id,
    trait = exposures$trait,
    outcome_id = outcome_id,
    effect_scale = selected$effect_scale,
    method = selected$method,
    nsnp = as.integer(selected$nsnp),
    beta = selected$beta,
    se = selected$se,
    ci_lower = selected$ci_lower,
    ci_upper = selected$ci_upper,
    p = selected$p,
    p_for_fdr = p_for_fdr,
    q = q,
    fdr_alpha = fdr_alpha,
    fdr_significant = significant,
    odds_ratio = ifelse(estimated, exp(selected$beta), NA_real_),
    or_ci_lower = ifelse(estimated, exp(selected$ci_lower), NA_real_),
    or_ci_upper = ifelse(estimated, exp(selected$ci_upper), NA_real_),
    mean_F = selected$mean_F,
    min_F = selected$min_F,
    analysis_status = selected$analysis_status,
    evidence_label = label,
    error_message = selected$error_message,
    warning_message = selected$warning_message,
    family = "mechanistic_x_to_y",
    family_denominator = 5L,
    stringsAsFactors = FALSE
  )
  rownames(result) <- NULL
  result
}

endothelial_x_to_m_family <- function(
  extracts, mediators, exposure_freeze, fdr_alpha = 0.05
) {
  endothelial <- mediators[mediators$family == "endothelial", , drop = FALSE]
  required_freeze <- c(
    "exposure_id", "module_id", "trait", "reference_id", "effect_allele",
    "other_allele", "exposure_beta", "exposure_se", "F"
  )
  if (nrow(endothelial) != 9L || nrow(exposure_freeze) != 5L ||
      length(setdiff(required_freeze, names(exposure_freeze))) ||
      !is.data.frame(extracts)) {
    stop("Endothelial X-to-M family inputs are invalid", call. = FALSE)
  }
  rows <- vector("list", 45L)
  row_index <- 0L
  for (mediator_index in seq_len(nrow(endothelial))) {
    mediator <- endothelial[mediator_index, , drop = FALSE]
    for (exposure_index in seq_len(nrow(exposure_freeze))) {
      row_index <- row_index + 1L
      exposure <- exposure_freeze[exposure_index, , drop = FALSE]
      hit <- extracts$mediator_id == mediator$mediator_id[[1L]] &
        extracts$request_role == "x_instrument_to_mediator" &
        extracts$request_id == exposure$exposure_id[[1L]]
      selected <- extracts[hit, , drop = FALSE]
      status <- "not_estimable_target_missing_or_allele_mismatch"
      mediator_beta <- mediator_se <- beta <- se <- p <- NA_real_
      if (nrow(selected) == 1L && selected$extraction_status[[1L]] == "matched") {
        observed_ea <- toupper(selected$ea[[1L]])
        observed_oa <- toupper(selected$oa[[1L]])
        exposure_ea <- toupper(exposure$effect_allele[[1L]])
        exposure_oa <- toupper(exposure$other_allele[[1L]])
        complement_ea <- mechanistic_complement_allele(observed_ea)
        complement_oa <- mechanistic_complement_allele(observed_oa)
        signs <- c(
          if (observed_ea == exposure_ea && observed_oa == exposure_oa) 1 else numeric(),
          if (observed_ea == exposure_oa && observed_oa == exposure_ea) -1 else numeric(),
          if (complement_ea == exposure_ea && complement_oa == exposure_oa) 1 else numeric(),
          if (complement_ea == exposure_oa && complement_oa == exposure_ea) -1 else numeric()
        )
        signs <- unique(signs)
        if (length(signs) == 1L) {
          mediator_beta <- signs[[1L]] * selected$beta[[1L]]
          mediator_se <- selected$se[[1L]]
          beta <- mediator_beta / exposure$exposure_beta[[1L]]
          se <- mediator_se / abs(exposure$exposure_beta[[1L]])
          p <- 2 * stats::pnorm(abs(beta / se), lower.tail = FALSE)
          status <- "estimated_single_instrument"
        } else if (length(signs) > 1L) {
          status <- "not_estimable_palindromic_orientation_ambiguous"
        }
      } else if (nrow(selected) > 1L) {
        stop("Endothelial X-to-M extract has duplicate targets", call. = FALSE)
      }
      rows[[row_index]] <- data.frame(
        exposure_id = exposure$exposure_id,
        module_id = exposure$module_id,
        exposure_trait = exposure$trait,
        mediator_id = mediator$mediator_id,
        mediator_name = mediator$mediator_name,
        mediator_source_id = mediator$source_id,
        instrument_snp = exposure$reference_id,
        source_gwas_verification = "verified",
        x_m_overlap_class = "possible_unresolved",
        exposure_beta = exposure$exposure_beta,
        exposure_se = exposure$exposure_se,
        mediator_beta = mediator_beta,
        mediator_se = mediator_se,
        beta = beta, se = se,
        ci_lower = ifelse(is.finite(beta), beta - 1.96 * se, NA_real_),
        ci_upper = ifelse(is.finite(beta), beta + 1.96 * se, NA_real_),
        p = p, instrument_F = exposure$F,
        analysis_status = status,
        stringsAsFactors = FALSE
      )
    }
  }
  result <- do.call(rbind, rows)
  estimated <- result$analysis_status == "estimated_single_instrument"
  result$p_for_fdr <- ifelse(estimated, result$p, 1)
  result$q <- stats::p.adjust(result$p_for_fdr, method = "BH", n = 45L)
  result$fdr_alpha <- fdr_alpha
  result$fdr_significant <- estimated & result$q < fdr_alpha
  result$multiplicity_status <- "complete_45_test_family"
  result$evidence_label <- ifelse(
    result$fdr_significant,
    "fdr_supported_single_instrument_possible_overlap",
    ifelse(estimated, "exploratory_single_instrument", "non_estimable")
  )
  result$family <- "endothelial_x_to_m"
  result$family_denominator <- 45L
  result <- result[, ENDOTHELIAL_X_TO_M_COLUMNS, drop = FALSE]
  rownames(result) <- NULL
  result
}

finalize_endothelial_m_to_y_family <- function(
  primary_rows, mediators, fdr_alpha = 0.05
) {
  endothelial <- mediators[mediators$family == "endothelial", , drop = FALSE]
  required <- c(
    "mediator_id", "mediator_name", "source_id", "method", "nsnp",
    "beta", "se", "ci_lower", "ci_upper", "p", "mean_F", "min_F",
    "analysis_status", "error_message", "warning_message"
  )
  if (nrow(endothelial) != 9L || !is.data.frame(primary_rows) ||
      length(setdiff(required, names(primary_rows))) ||
      anyDuplicated(primary_rows$mediator_id) ||
      !setequal(primary_rows$mediator_id, endothelial$mediator_id)) {
    stop("Endothelial M-to-Y family inputs are invalid", call. = FALSE)
  }
  result <- primary_rows[
    match(endothelial$mediator_id, primary_rows$mediator_id), , drop = FALSE
  ]
  estimated <- result$analysis_status == "estimated" &
    is.finite(result$p) & is.finite(result$beta) &
    is.finite(result$se) & result$se > 0
  result$p_for_fdr <- ifelse(estimated, result$p, 1)
  result$q <- stats::p.adjust(result$p_for_fdr, method = "BH", n = 9L)
  result$fdr_alpha <- fdr_alpha
  result$fdr_significant <- estimated & result$q < fdr_alpha
  result$outcome_id <- MECHANISTIC_TOTAL_OUTCOME_ID
  result$outcome_overlap_class <- "possible_unresolved"
  result$odds_ratio <- ifelse(estimated, exp(result$beta), NA_real_)
  result$or_ci_lower <- ifelse(estimated, exp(result$ci_lower), NA_real_)
  result$or_ci_upper <- ifelse(estimated, exp(result$ci_upper), NA_real_)
  result$evidence_label <- ifelse(
    result$fdr_significant,
    "fdr_supported_screening_possible_overlap",
    ifelse(estimated, "screening_not_fdr_supported", "non_estimable")
  )
  result$family <- "endothelial_m_to_y"
  result$family_denominator <- 9L
  rownames(result) <- NULL
  result
}

mechanistic_indirect_family <- function(
  x_to_m, m_to_y, family, denominator, overlap_class,
  fdr_alpha = 0.05
) {
  required_x <- c(
    "exposure_id", "module_id", "exposure_trait", "mediator_id",
    "mediator_name", "beta", "se", "fdr_significant"
  )
  required_m <- c("mediator_id", "beta", "se", "fdr_significant")
  if (!is.data.frame(x_to_m) || !is.data.frame(m_to_y) ||
      length(setdiff(required_x, names(x_to_m))) ||
      length(setdiff(required_m, names(m_to_y))) ||
      nrow(x_to_m) != denominator || anyDuplicated(m_to_y$mediator_id) ||
      !family %in% c("cytokine_indirect", "endothelial_indirect") ||
      !overlap_class %in% c("known_partial", "possible_unresolved")) {
    stop("Mechanistic indirect-effect inputs are invalid", call. = FALSE)
  }
  m <- m_to_y[, required_m, drop = FALSE]
  names(m)[names(m) != "mediator_id"] <- paste0(
    "m_to_y_", names(m)[names(m) != "mediator_id"]
  )
  joined <- merge(x_to_m, m, by = "mediator_id", all.x = TRUE, sort = FALSE)
  joined <- joined[match(
    paste(x_to_m$exposure_id, x_to_m$mediator_id, sep = "\r"),
    paste(joined$exposure_id, joined$mediator_id, sep = "\r")
  ), , drop = FALSE]
  estimable <- is.finite(joined$beta) & is.finite(joined$se) & joined$se > 0 &
    is.finite(joined$m_to_y_beta) & is.finite(joined$m_to_y_se) &
    joined$m_to_y_se > 0
  indirect_beta <- ifelse(
    estimable, joined$beta * joined$m_to_y_beta, NA_real_
  )
  indirect_se <- ifelse(
    estimable,
    sqrt(
      joined$m_to_y_beta^2 * joined$se^2 +
        joined$beta^2 * joined$m_to_y_se^2
    ),
    NA_real_
  )
  p <- ifelse(
    estimable & indirect_se > 0,
    2 * stats::pnorm(abs(indirect_beta / indirect_se), lower.tail = FALSE),
    NA_real_
  )
  p_for_fdr <- ifelse(is.finite(p), p, 1)
  q <- stats::p.adjust(p_for_fdr, method = "BH", n = denominator)
  x_gate <- as.logical(joined$fdr_significant)
  m_gate <- as.logical(joined$m_to_y_fdr_significant)
  component_gate <- estimable & x_gate & m_gate
  product_gate <- estimable & q < fdr_alpha
  result <- data.frame(
    exposure_id = joined$exposure_id,
    module_id = joined$module_id,
    exposure_trait = joined$exposure_trait,
    mediator_id = joined$mediator_id,
    mediator_name = joined$mediator_name,
    a_beta = joined$beta, a_se = joined$se,
    b_beta = joined$m_to_y_beta, b_se = joined$m_to_y_se,
    indirect_beta = indirect_beta, indirect_se = indirect_se,
    ci_lower = ifelse(estimable, indirect_beta - 1.96 * indirect_se, NA_real_),
    ci_upper = ifelse(estimable, indirect_beta + 1.96 * indirect_se, NA_real_),
    p = p, p_for_fdr = p_for_fdr, q = q, fdr_alpha = fdr_alpha,
    product_fdr_significant = product_gate,
    x_to_m_fdr_significant = x_gate,
    m_to_y_fdr_significant = m_gate,
    component_fdr_gate = component_gate,
    overlap_class = overlap_class,
    variance_status = "sensitivity_delta_covariance_unavailable_due_overlap",
    colocalization_status = ifelse(
      component_gate,
      "pending_required_before_mechanistic_support",
      "not_triggered_component_fdr_gate_failed"
    ),
    analysis_status = ifelse(
      estimable, "estimated_sensitivity_overlap_covariance_unknown",
      "not_estimable_component_missing"
    ),
    evidence_label = ifelse(
      component_gate & product_gate,
      "exploratory_pending_independence_and_colocalization",
      ifelse(estimable, "exploratory_not_all_mediation_gates_met", "insufficient")
    ),
    family = family,
    family_denominator = denominator,
    stringsAsFactors = FALSE
  )
  result <- result[, MECHANISTIC_INDIRECT_COLUMNS, drop = FALSE]
  rownames(result) <- NULL
  result
}
