config_error <- function(path, key, detail) {
  stop(
    sprintf("Invalid config %s: %s %s", path, key, detail),
    call. = FALSE
  )
}

config_value <- function(x, path, key) {
  value <- x
  for (part in strsplit(key, ".", fixed = TRUE)[[1L]]) {
    if (!is.list(value) || is.null(names(value)) ||
        !part %in% names(value) || is.null(value[[part]])) {
      stop(sprintf("Missing key in %s: %s", path, key), call. = FALSE)
    }
    value <- value[[part]]
  }
  value
}

require_config_keys <- function(x, path, keys) {
  invisible(lapply(keys, function(key) config_value(x, path, key)))
}

validate_probability <- function(x, path, key) {
  value <- config_value(x, path, key)
  if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
      !is.finite(value) || value <= 0 || value > 1) {
    config_error(path, key, "must be a finite number in (0, 1]")
  }
}

validate_positive_number <- function(x, path, key, integer = FALSE) {
  value <- config_value(x, path, key)
  invalid <- !is.numeric(value) || length(value) != 1L || is.na(value) ||
    !is.finite(value) || value <= 0
  if (integer && !invalid) {
    invalid <- value != floor(value) || value > .Machine$integer.max
  }
  if (invalid) {
    requirement <- if (integer) "a positive integer" else "a positive number"
    config_error(path, key, paste("must be", requirement))
  }
}

validate_flag <- function(x, path, key) {
  value <- config_value(x, path, key)
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    config_error(path, key, "must be true or false")
  }
}

validate_text <- function(x, path, key) {
  value <- config_value(x, path, key)
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(trimws(value))) {
    config_error(path, key, "must be a non-empty string")
  }
}

validate_exact_text <- function(x, path, key, expected) {
  validate_text(x, path, key)
  value <- config_value(x, path, key)
  if (!identical(value, expected)) {
    config_error(path, key, sprintf("must equal '%s'", expected))
  }
}

validate_exact_scalar <- function(x, path, key, expected) {
  value <- config_value(x, path, key)
  if (length(value) != 1L || !identical(value, expected)) {
    config_error(
      path, key,
      sprintf("must equal the approved value %s", deparse(expected))
    )
  }
}

validate_exact_vector <- function(x, path, key, expected) {
  value <- config_value(x, path, key)
  if (!is.character(value) || !identical(value, expected)) {
    config_error(
      path, key,
      sprintf("must equal [%s]", paste(expected, collapse = ", "))
    )
  }
}

validate_https <- function(x, path, key) {
  validate_text(x, path, key)
  value <- config_value(x, path, key)
  label <- "[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
  pattern <- paste0(
    "^https://", label, "(?:\\.", label, ")*",
    "(?::[0-9]{1,5})?(?:[/?#].*)?$"
  )
  if (grepl("[[:space:]]", value) || !grepl(pattern, value, perl = TRUE)) {
    config_error(path, key, "must be an HTTPS URL with a valid host")
  }
}

read_yaml_checked <- function(path, keys) {
  if (!file.exists(path)) {
    stop("Missing config: ", path, call. = FALSE)
  }

  x <- tryCatch(
    yaml::read_yaml(
      path,
      handlers = list(int = function(value) as.numeric(value))
    ),
    error = function(error) {
      stop(
        sprintf("Invalid YAML in %s: %s", path, conditionMessage(error)),
        call. = FALSE
      )
    }
  )
  if (is.null(x)) {
    stop(sprintf("Invalid YAML in %s: document is empty", path), call. = FALSE)
  }
  if (!is.list(x) || is.null(names(x))) {
    stop(sprintf("Invalid YAML in %s: root must be a mapping", path), call. = FALSE)
  }

  missing <- setdiff(keys, names(x))
  if (length(missing)) {
    stop(
      "Missing keys in ", path, ": ", paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  x
}

validate_project_config <- function(x, path) {
  nested_keys <- c(
    "instruments.primary_p", "instruments.exploratory_p",
    "instruments.min_f", "instruments.min_snps_mr_presso",
    "ld.eur.population", "ld.eur.r2", "ld.eur.kb",
    "ld.afr.population", "ld.afr.r2", "ld.afr.kb",
    "multiple_testing.method", "multiple_testing.fdr",
    "multiple_testing.freeze_eligibility_before_mr_p",
    "multiple_testing.eligibility_criteria", "multiple_testing.families",
    "multiple_testing.record_denominators",
    "multiple_testing.strata_reduce_denominators",
    "multiple_testing.global_bonferroni.alpha",
    "multiple_testing.global_bonferroni.denominator",
    "replication.discovery_family", "replication.discovery_q_lt",
    "replication.required_overlap_class",
    "replication.sensitivity_only_overlap_classes",
    "replication.validation.same_beta_sign",
    "replication.validation.two_sided_p_lt",
    "replication.validation.ci_excludes_null_same_direction",
    "replication.robust_estimators",
    "replication.require_one_robust_same_sign",
    "replication.robust_significance_required",
    "replication.steiger_reversal_p_lt", "replication.steiger_unavailable",
    "replication.pleiotropy.egger_intercept_p_lt",
    "replication.pleiotropy.presso_global_p_lt",
    "replication.pleiotropy.unresolved_outliers_fail",
    "replication.pleiotropy.corrected_sign_change_fail",
    "replication.pleiotropy.corrected_unavailable_fail",
    "replication.non_estimable_tests", "coloc.prior_p1", "coloc.prior_p2",
    "coloc.prior_p12", "coloc.pp4_support"
  )
  require_config_keys(x, path, nested_keys)

  probability_keys <- c(
    "instruments.primary_p", "instruments.exploratory_p",
    "multiple_testing.fdr", "multiple_testing.global_bonferroni.alpha",
    "replication.discovery_q_lt", "replication.validation.two_sided_p_lt",
    "replication.steiger_reversal_p_lt",
    "replication.pleiotropy.egger_intercept_p_lt",
    "replication.pleiotropy.presso_global_p_lt", "coloc.prior_p1",
    "coloc.prior_p2", "coloc.prior_p12", "coloc.pp4_support"
  )
  invisible(lapply(
    probability_keys,
    function(key) validate_probability(x, path, key)
  ))
  if (x$instruments$primary_p >= x$instruments$exploratory_p) {
    config_error(
      path, "instruments.primary_p",
      "must be less than instruments.exploratory_p"
    )
  }

  validate_positive_number(x, path, "instruments.min_f")
  validate_positive_number(
    x, path, "instruments.min_snps_mr_presso", integer = TRUE
  )
  for (ancestry in c("eur", "afr")) {
    r2_key <- paste("ld", ancestry, "r2", sep = ".")
    validate_probability(x, path, r2_key)
    validate_positive_number(
      x, path, paste("ld", ancestry, "kb", sep = "."), integer = TRUE
    )
  }
  validate_exact_text(x, path, "ld.eur.population", "EUR")
  validate_exact_text(x, path, "ld.afr.population", "AFR")

  flag_keys <- c(
    "multiple_testing.freeze_eligibility_before_mr_p",
    "multiple_testing.record_denominators",
    "multiple_testing.strata_reduce_denominators",
    "replication.validation.same_beta_sign",
    "replication.validation.ci_excludes_null_same_direction",
    "replication.require_one_robust_same_sign",
    "replication.robust_significance_required",
    "replication.pleiotropy.unresolved_outliers_fail",
    "replication.pleiotropy.corrected_sign_change_fail",
    "replication.pleiotropy.corrected_unavailable_fail"
  )
  invisible(lapply(flag_keys, function(key) validate_flag(x, path, key)))

  approved_scalars <- list(
    genome_build = "GRCh38",
    instruments.primary_p = 5e-8,
    instruments.exploratory_p = 1e-5,
    instruments.min_f = 10,
    instruments.min_snps_mr_presso = 4,
    ld.eur.population = "EUR",
    ld.eur.r2 = 0.001,
    ld.eur.kb = 10000,
    ld.afr.population = "AFR",
    ld.afr.r2 = 0.001,
    ld.afr.kb = 10000,
    multiple_testing.method = "BH",
    multiple_testing.fdr = 0.05,
    multiple_testing.freeze_eligibility_before_mr_p = TRUE,
    multiple_testing.record_denominators = TRUE,
    multiple_testing.strata_reduce_denominators = FALSE,
    multiple_testing.global_bonferroni.alpha = 0.05,
    multiple_testing.global_bonferroni.denominator =
      "N_forward_plus_N_reverse",
    replication.discovery_family = "forward_primary",
    replication.discovery_q_lt = 0.05,
    replication.required_overlap_class = "none_known",
    replication.validation.same_beta_sign = TRUE,
    replication.validation.two_sided_p_lt = 0.05,
    replication.validation.ci_excludes_null_same_direction = TRUE,
    replication.require_one_robust_same_sign = TRUE,
    replication.robust_significance_required = FALSE,
    replication.steiger_reversal_p_lt = 0.05,
    replication.steiger_unavailable = "report_not_support",
    replication.pleiotropy.egger_intercept_p_lt = 0.05,
    replication.pleiotropy.presso_global_p_lt = 0.05,
    replication.pleiotropy.unresolved_outliers_fail = TRUE,
    replication.pleiotropy.corrected_sign_change_fail = TRUE,
    replication.pleiotropy.corrected_unavailable_fail = TRUE,
    replication.non_estimable_tests = "report_not_pass",
    coloc.prior_p1 = 1e-4,
    coloc.prior_p2 = 1e-4,
    coloc.prior_p12 = 1e-5,
    coloc.pp4_support = 0.80
  )
  invisible(lapply(
    names(approved_scalars),
    function(key) validate_exact_scalar(
      x, path, key, approved_scalars[[key]]
    )
  ))

  validate_exact_vector(
    x, path, "multiple_testing.eligibility_criteria",
    c("source", "qc", "instrument")
  )
  validate_exact_vector(
    x, path, "multiple_testing.families",
    c("forward_primary", "reverse")
  )
  validate_exact_vector(
    x, path, "replication.sensitivity_only_overlap_classes",
    c("known", "possible")
  )
  validate_exact_vector(
    x, path, "replication.robust_estimators",
    c("weighted_median", "mr_raps")
  )
  validate_exact_vector(
    x, path, "mvmr_covariates",
    c("BMI", "type_2_diabetes", "coronary_artery_disease")
  )
  x
}

read_project_config <- function(path) {
  x <- read_yaml_checked(
    path,
    c(
      "genome_build", "instruments", "ld", "multiple_testing",
      "replication", "coloc", "mvmr_covariates"
    )
  )
  validate_project_config(x, path)
}

validate_source_config <- function(x, path) {
  for (source in intersect(
    names(x),
    c(
      "microbiome_2026", "microbiome_2026_hunt", "ed_2025",
      "finngen_r12", "ld_reference_1kg"
    )
  )) {
    if (is.list(x[[source]]$known_overlap_datasets) &&
        !length(x[[source]]$known_overlap_datasets)) {
      x[[source]]$known_overlap_datasets <- character()
    }
  }
  required <- list(
    microbiome_2026 = c(
      "accessions.first", "accessions.last", "article", "catalog_root",
      "ancestry", "genome_build", "license", "cohort_membership",
      "known_overlap_datasets", "replication_role", "overlap_note"
    ),
    microbiome_2026_hunt = c(
      "accessions.first", "accessions.last", "article", "catalog_root",
      "ancestry", "genome_build", "license", "cohort_membership",
      "known_overlap_datasets", "replication_role", "overlap_note"
    ),
    ed_2025 = c(
      "article_id", "api", "article", "ancestry", "genome_build",
      "ancestry_file_patterns", "license", "cohort_membership",
      "known_overlap_datasets", "replication_role", "overlap_note"
    ),
    finngen_r12 = c(
      "manifest", "phenotype_regex", "ancestry", "genome_build", "license",
      "cohort_membership", "known_overlap_datasets", "replication_role",
      "overlap_note"
    ),
    ld_reference_1kg = c(
      "record", "ancestry_files", "genome_build", "license",
      "cohort_membership", "known_overlap_datasets", "replication_role",
      "overlap_note"
    )
  )
  for (source in names(required)) {
    require_config_keys(
      x, path, paste(source, required[[source]], sep = ".")
    )
  }

  url_keys <- c(
    "microbiome_2026.article", "microbiome_2026.catalog_root",
    "microbiome_2026_hunt.article", "microbiome_2026_hunt.catalog_root",
    "ed_2025.api", "ed_2025.article", "finngen_r12.manifest",
    "ld_reference_1kg.record"
  )
  invisible(lapply(url_keys, function(key) validate_https(x, path, key)))

  metadata_keys <- unlist(lapply(
    names(required),
    function(source) paste(
      source, c("license", "replication_role", "overlap_note"), sep = "."
    )
  ))
  invisible(lapply(metadata_keys, function(key) validate_text(x, path, key)))

  text_keys <- c(
    "microbiome_2026.accessions.first", "microbiome_2026.accessions.last",
    "microbiome_2026.ancestry", "microbiome_2026.genome_build",
    "microbiome_2026_hunt.accessions.first",
    "microbiome_2026_hunt.accessions.last",
    "microbiome_2026_hunt.ancestry", "microbiome_2026_hunt.genome_build",
    "ed_2025.ancestry", "ed_2025.genome_build",
    "finngen_r12.phenotype_regex", "finngen_r12.ancestry",
    "finngen_r12.genome_build",
    "ld_reference_1kg.genome_build"
  )
  invisible(lapply(text_keys, function(key) validate_text(x, path, key)))

  validate_positive_number(x, path, "ed_2025.article_id", integer = TRUE)

  for (source in c("microbiome_2026", "microbiome_2026_hunt")) {
    accessions <- c(
      first = config_value(x, path, paste0(source, ".accessions.first")),
      last = config_value(x, path, paste0(source, ".accessions.last"))
    )
    for (bound in names(accessions)) {
      if (!grepl("^GCST[0-9]{8}$", accessions[[bound]])) {
        config_error(
          path, paste(source, "accessions", bound, sep = "."),
          "must match ^GCST[0-9]{8}$"
        )
      }
    }
    accession_numbers <- as.numeric(sub("^GCST", "", accessions))
    if (accession_numbers[[1L]] > accession_numbers[[2L]]) {
      config_error(
        path, paste0(source, ".accessions.first"),
        paste0("must not exceed ", source, ".accessions.last")
      )
    }
  }

  validate_source_vector <- function(source, field, allow_empty = FALSE) {
    value <- config_value(x, path, paste(source, field, sep = "."))
    valid <- is.character(value) && !anyNA(value) &&
      (allow_empty || length(value) > 0L) &&
      all(nzchar(value)) && all(value == trimws(value)) && !anyDuplicated(value)
    if (!valid) {
      config_error(
        path, paste(source, field, sep = "."),
        "must be an ordered vector of unique normalized strings"
      )
    }
  }
  for (source in names(required)) {
    validate_source_vector(source, "cohort_membership")
    validate_source_vector(source, "known_overlap_datasets", allow_empty = TRUE)
  }

  patterns <- config_value(x, path, "ed_2025.ancestry_file_patterns")
  valid_patterns <- is.list(patterns) && !is.null(names(patterns)) &&
    length(patterns) == 3L && !anyDuplicated(names(patterns)) &&
    all(vapply(
      patterns,
      function(value) {
        is.character(value) && length(value) == 1L &&
          !is.na(value) && nzchar(value) && identical(value, trimws(value))
      },
      logical(1)
    )) && !anyDuplicated(unlist(patterns, use.names = FALSE))
  if (!valid_patterns) {
    config_error(
      path, "ed_2025.ancestry_file_patterns",
      "must contain unique named non-empty patterns"
    )
  }

  ancestry_files <- config_value(x, path, "ld_reference_1kg.ancestry_files")
  if (!is.character(ancestry_files) || !length(ancestry_files) ||
      anyNA(ancestry_files) || any(!nzchar(trimws(ancestry_files))) ||
      any(ancestry_files != trimws(ancestry_files)) ||
      anyDuplicated(ancestry_files)) {
    config_error(
      path, "ld_reference_1kg.ancestry_files",
      "must contain unique normalized ancestry names"
    )
  }

  for (source in names(required)) {
    overlaps <- config_value(x, path, paste0(source, ".known_overlap_datasets"))
    unknown <- setdiff(overlaps, names(required))
    if (length(unknown)) {
      config_error(
        path, paste0(source, ".known_overlap_datasets"),
        paste("contains unknown datasets", paste(unknown, collapse = ", "))
      )
    }
    for (other in overlaps) {
      reverse <- config_value(x, path, paste0(other, ".known_overlap_datasets"))
      if (!source %in% reverse) {
        config_error(
          path, paste0(source, ".known_overlap_datasets"),
          paste("is not symmetric with", other)
        )
      }
    }
  }

  approved_scalars <- list(
    microbiome_2026.accessions.first = "GCST90670368",
    microbiome_2026.accessions.last = "GCST90671939",
    microbiome_2026.article =
      "https://doi.org/10.1038/s41588-026-02512-2",
    microbiome_2026.catalog_root =
      "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics",
    microbiome_2026.genome_build = "GRCh37",
    microbiome_2026.ancestry = "EUR",
    microbiome_2026.overlap_note = "Swedish discovery cohorts",
    microbiome_2026.replication_role = "exposure_discovery",
    microbiome_2026_hunt.accessions.first = "GCST90666541",
    microbiome_2026_hunt.accessions.last = "GCST90667549",
    microbiome_2026_hunt.article =
      "https://doi.org/10.1038/s41588-026-02512-2",
    microbiome_2026_hunt.catalog_root =
      "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics",
    microbiome_2026_hunt.genome_build = "GRCh37",
    microbiome_2026_hunt.ancestry = "EUR",
    microbiome_2026_hunt.overlap_note =
      "Norwegian HUNT independent exposure replication cohort",
    microbiome_2026_hunt.replication_role =
      "independent_exposure_replication",
    ed_2025.article_id = 30505799,
    ed_2025.api = "https://api.figshare.com/v2/articles/30505799",
    ed_2025.article = "https://doi.org/10.1038/s41467-025-66723-7",
    ed_2025.genome_build = "GRCh38",
    ed_2025.ancestry = "EUR, AFR, cross-ancestry",
    ed_2025.replication_role = "high_power_outcome_meta_sensitivity",
    finngen_r12.manifest = paste0(
      "https://storage.googleapis.com/finngen-public-data-r12/",
      "summary_stats/finngen_R12_manifest.tsv"
    ),
    finngen_r12.phenotype_regex =
      "(^|_)ERECTILE_DYSFUNCTION$|(^|_)N52($|_)",
    finngen_r12.genome_build = "GRCh38",
    finngen_r12.ancestry = "Finnish",
    finngen_r12.overlap_note =
      "FinnGen overlaps the ed_2025 outcome meta-analysis",
    finngen_r12.replication_role =
      "outcome_source_known_overlap_with_ed_2025",
    ld_reference_1kg.record = "https://doi.org/10.5281/zenodo.6614170",
    ld_reference_1kg.genome_build = "GRCh37",
    ld_reference_1kg.replication_role = "external_ld_reference"
  )
  invisible(lapply(
    names(approved_scalars),
    function(key) validate_exact_scalar(
      x, path, key, approved_scalars[[key]]
    )
  ))
  validate_exact_vector(
    x, path, "ld_reference_1kg.ancestry_files", c("EUR", "AFR")
  )
  approved_vectors <- list(
    microbiome_2026.cohort_membership = "Swedish_discovery_cohorts",
    microbiome_2026.known_overlap_datasets = character(),
    microbiome_2026_hunt.cohort_membership = "HUNT",
    microbiome_2026_hunt.known_overlap_datasets = character(),
    ed_2025.cohort_membership = c(
      "UK_Biobank", "MVP", "FinnGen", "All_of_Us", "Estonian_Biobank",
      "Partners_HealthCare_Biobank"
    ),
    ed_2025.known_overlap_datasets = "finngen_r12",
    finngen_r12.cohort_membership = "FinnGen",
    finngen_r12.known_overlap_datasets = "ed_2025",
    ld_reference_1kg.cohort_membership = "1000_Genomes",
    ld_reference_1kg.known_overlap_datasets = character()
  )
  invisible(lapply(names(approved_vectors), function(key) {
    validate_exact_vector(x, path, key, approved_vectors[[key]])
  }))
  approved_patterns <- list(
    EUR = "^ed_eur_meta_(aa|ab|ac)\\.gz$",
    AFR = "^ed_afr_meta_(aa|ab)\\.gz$",
    cross_ancestry = "^ed_cross_ancestry_meta_(aa|ab|ac)\\.gz$"
  )
  if (!identical(patterns, approved_patterns)) {
    config_error(
      path, "ed_2025.ancestry_file_patterns",
      "must equal the approved named filename patterns"
    )
  }

  api_id <- sub("^.*/", "", config_value(x, path, "ed_2025.api"))
  if (!grepl("^[0-9]+$", api_id) ||
      as.numeric(api_id) != config_value(x, path, "ed_2025.article_id")) {
    config_error(
      path, "ed_2025.api",
      "terminal article ID must equal ed_2025.article_id"
    )
  }
  x
}

read_source_config <- function(path) {
  x <- read_yaml_checked(
    path,
    c(
      "microbiome_2026", "microbiome_2026_hunt", "ed_2025",
      "finngen_r12", "ld_reference_1kg"
    )
  )
  validate_source_config(x, path)
}
