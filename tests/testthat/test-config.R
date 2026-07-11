project_root <- normalizePath(testthat::test_path("..", ".."))
project_config_path <- file.path(project_root, "config", "project.yml")
source_config_path <- file.path(project_root, "config", "data_sources.yml")
plan_path <- file.path(
  project_root, "docs", "superpowers", "plans",
  "2026-07-10-gut-ed-mr-rebuild-implementation.md"
)
source(file.path(project_root, "R", "config.R"))

write_temp_yaml <- function(x) {
  path <- tempfile(fileext = ".yml")
  yaml::write_yaml(x, path)
  path
}

set_config_value <- function(x, key, value) {
  set_parts <- function(node, parts) {
    if (length(parts) == 1L) {
      node[[parts[[1L]]]] <- value
      return(node)
    }
    child <- node[[parts[[1L]]]]
    if (is.null(child)) child <- list()
    node[[parts[[1L]]]] <- set_parts(child, parts[-1L])
    node
  }
  set_parts(x, strsplit(key, ".", fixed = TRUE)[[1L]])
}

mutate_approved_value <- function(value) {
  if (is.logical(value)) return(!value)
  if (is.numeric(value)) {
    return(if (value >= 1) value + 1 else value * 1.1)
  }
  if (is.character(value) && length(value) == 1L) {
    return(paste0(value, "_changed"))
  }
  if (is.character(value) && length(value) == 0L) return("unexpected")
  value[rev(seq_along(value))]
}

test_that("project thresholds are explicit", {
  cfg <- read_project_config(project_config_path)
  expect_equal(cfg$instruments$primary_p, 5e-8)
  expect_equal(cfg$instruments$exploratory_p, 1e-5)
  expect_equal(cfg$multiple_testing$fdr, 0.05)
  expect_true(cfg$multiple_testing$freeze_eligibility_before_mr_p)
  expect_equal(cfg$multiple_testing$families, c("forward_primary", "reverse"))
  expect_true(cfg$multiple_testing$record_denominators)
  expect_false(cfg$multiple_testing$strata_reduce_denominators)
  expect_equal(
    cfg$multiple_testing$global_bonferroni$denominator,
    "N_forward_plus_N_reverse"
  )
  expect_equal(cfg$replication$required_overlap_class, "none_known")
  expect_equal(cfg$replication$validation$two_sided_p_lt, 0.05)
  expect_equal(
    cfg$replication$robust_estimators,
    c("weighted_median", "mr_raps")
  )
  expect_equal(cfg$replication$steiger_reversal_p_lt, 0.05)
  expect_equal(cfg$replication$pleiotropy$egger_intercept_p_lt, 0.05)
  expect_equal(cfg$replication$pleiotropy$presso_global_p_lt, 0.05)
  expect_equal(cfg$replication$non_estimable_tests, "report_not_pass")
  expect_equal(cfg$ld$eur$r2, 0.001)
  expect_equal(cfg$ld$eur$kb, 10000)
})

test_that("every project governance value is closed to the approved contract", {
  approved <- list(
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
    multiple_testing.eligibility_criteria = c("source", "qc", "instrument"),
    multiple_testing.families = c("forward_primary", "reverse"),
    multiple_testing.record_denominators = TRUE,
    multiple_testing.strata_reduce_denominators = FALSE,
    multiple_testing.global_bonferroni.alpha = 0.05,
    multiple_testing.global_bonferroni.denominator =
      "N_forward_plus_N_reverse",
    replication.discovery_family = "forward_primary",
    replication.discovery_q_lt = 0.05,
    replication.required_overlap_class = "none_known",
    replication.sensitivity_only_overlap_classes = c("known", "possible"),
    replication.validation.same_beta_sign = TRUE,
    replication.validation.two_sided_p_lt = 0.05,
    replication.validation.ci_excludes_null_same_direction = TRUE,
    replication.robust_estimators = c("weighted_median", "mr_raps"),
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
    coloc.pp4_support = 0.80,
    mvmr_covariates = c(
      "BMI", "type_2_diabetes", "coronary_artery_disease"
    )
  )

  for (key in names(approved)) {
    cfg <- yaml::read_yaml(project_config_path)
    cfg <- set_config_value(
      cfg, key, mutate_approved_value(approved[[key]])
    )
    path <- write_temp_yaml(cfg)
    expect_error(
      read_project_config(path),
      paste0(path, ": ", key),
      fixed = TRUE,
      info = key
    )
  }
})

test_that("project governance rejects wrong types and padded decisions", {
  cases <- list(
    genome_build = 38,
    instruments.primary_p = "5e-8",
    multiple_testing.freeze_eligibility_before_mr_p = "true",
    multiple_testing.method = " BH",
    multiple_testing.families = c(1, 2),
    replication.robust_estimators = c("weighted_median", "mr_raps ")
  )

  for (key in names(cases)) {
    cfg <- yaml::read_yaml(project_config_path)
    cfg <- set_config_value(cfg, key, cases[[key]])
    path <- write_temp_yaml(cfg)
    expect_error(
      read_project_config(path),
      paste0(path, ": ", key),
      fixed = TRUE,
      info = key
    )
  }
})

test_that("data sources include access and overlap metadata", {
  src <- read_source_config(source_config_path)
  expect_true(
    all(
      c(
        "microbiome_2026", "microbiome_2026_hunt", "ed_2025", "finngen_r12",
        "ld_reference_1kg"
      ) %in% names(src)
    )
  )
  expect_true(all(vapply(src, function(x) nzchar(x$license), logical(1))))
})

test_that("structured cohort overlap and replication roles are exact and symmetric", {
  src <- read_source_config(source_config_path)
  expect_equal(
    src$microbiome_2026$cohort_membership,
    "Swedish_discovery_cohorts"
  )
  expect_equal(src$microbiome_2026_hunt$accessions$first, "GCST90666541")
  expect_equal(src$microbiome_2026_hunt$accessions$last, "GCST90667549")
  expect_equal(src$microbiome_2026_hunt$cohort_membership, "HUNT")
  expect_equal(
    src$microbiome_2026_hunt$replication_role,
    "independent_exposure_replication"
  )
  expect_equal(src$ed_2025$known_overlap_datasets, "finngen_r12")
  expect_equal(src$finngen_r12$known_overlap_datasets, "ed_2025")
  expect_length(src$microbiome_2026$known_overlap_datasets, 0L)
  expect_length(src$microbiome_2026_hunt$known_overlap_datasets, 0L)

  broken <- yaml::read_yaml(source_config_path)
  broken$finngen_r12$known_overlap_datasets <- character()
  path <- write_temp_yaml(broken)
  expect_error(read_source_config(path), "not symmetric")
})

test_that("source builds and ED ancestry patterns are deterministic", {
  src <- read_source_config(source_config_path)
  expect_equal(src$microbiome_2026$genome_build, "GRCh37")
  expect_equal(src$microbiome_2026_hunt$genome_build, "GRCh37")
  expect_equal(src$ed_2025$genome_build, "GRCh38")
  expect_equal(src$finngen_r12$genome_build, "GRCh38")
  expect_equal(
    src$ed_2025$ancestry_file_patterns,
    list(
      EUR = "^ed_eur_meta_(aa|ab|ac)\\.gz$",
      AFR = "^ed_afr_meta_(aa|ab)\\.gz$",
      cross_ancestry = "^ed_cross_ancestry_meta_(aa|ab|ac)\\.gz$"
    )
  )
})

test_that("ED ancestry patterns uniquely classify all eight approved files", {
  patterns <- read_source_config(source_config_path)$ed_2025$ancestry_file_patterns
  files <- c(
    "ed_eur_meta_ac.gz", "ed_eur_meta_ab.gz", "ed_eur_meta_aa.gz",
    "ed_afr_meta_aa.gz", "ed_cross_ancestry_meta_ac.gz",
    "ed_afr_meta_ab.gz", "ed_cross_ancestry_meta_aa.gz",
    "ed_cross_ancestry_meta_ab.gz"
  )
  matches <- vapply(
    files,
    function(file) sum(vapply(patterns, grepl, logical(1), x = file)),
    integer(1)
  )
  expect_equal(unname(matches), rep(1L, 8L))
})

test_that("plan and configuration snippets remain identical", {
  plan <- readLines(plan_path, warn = FALSE)
  extract_snippet <- function(marker_text) {
    marker <- which(plan == marker_text)
    expect_length(marker, 1L)
    closing <- which(seq_along(plan) > marker & plan == "```")[[1L]]
    plan[(marker + 1L):(closing - 1L)]
  }
  expect_identical(
    extract_snippet("# config/project.yml"),
    readLines(project_config_path, warn = FALSE)
  )
  expect_identical(
    extract_snippet("# config/data_sources.yml"),
    readLines(source_config_path, warn = FALSE)
  )
  expect_true(any(grepl(
    "must never be parsed to infer a file's ancestry", plan,
    fixed = TRUE
  )))
})

test_that("immutable source identities are closed to approved values", {
  approved <- list(
    microbiome_2026.accessions.first = "GCST90670368",
    microbiome_2026.accessions.last = "GCST90671939",
    microbiome_2026.article =
      "https://doi.org/10.1038/s41588-026-02512-2",
    microbiome_2026.catalog_root = paste0(
      "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics"
    ),
    microbiome_2026.genome_build = "GRCh37",
    microbiome_2026.ancestry = "EUR",
    microbiome_2026_hunt.accessions.first = "GCST90666541",
    microbiome_2026_hunt.accessions.last = "GCST90667549",
    microbiome_2026_hunt.article =
      "https://doi.org/10.1038/s41588-026-02512-2",
    microbiome_2026_hunt.catalog_root = paste0(
      "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics"
    ),
    microbiome_2026_hunt.genome_build = "GRCh37",
    microbiome_2026_hunt.ancestry = "EUR",
    ed_2025.article_id = 30505799,
    ed_2025.api = "https://api.figshare.com/v2/articles/30505799",
    ed_2025.article = "https://doi.org/10.1038/s41467-025-66723-7",
    ed_2025.genome_build = "GRCh38",
    ed_2025.ancestry = "EUR, AFR, cross-ancestry",
    finngen_r12.manifest = paste0(
      "https://storage.googleapis.com/finngen-public-data-r12/",
      "summary_stats/finngen_R12_manifest.tsv"
    ),
    finngen_r12.phenotype_regex =
      "(^|_)ERECTILE_DYSFUNCTION$|(^|_)N52($|_)",
    finngen_r12.genome_build = "GRCh38",
    finngen_r12.ancestry = "Finnish",
    ld_reference_1kg.record = "https://doi.org/10.5281/zenodo.6614170",
    ld_reference_1kg.ancestry_files = c("EUR", "AFR"),
    ld_reference_1kg.genome_build = "GRCh37",
    microbiome_2026.cohort_membership = "Swedish_discovery_cohorts",
    microbiome_2026.replication_role = "exposure_discovery",
    microbiome_2026_hunt.cohort_membership = "HUNT",
    microbiome_2026_hunt.replication_role =
      "independent_exposure_replication",
    ed_2025.replication_role = "high_power_outcome_meta_sensitivity",
    finngen_r12.replication_role =
      "outcome_source_known_overlap_with_ed_2025",
    ld_reference_1kg.replication_role = "external_ld_reference"
  )

  for (key in names(approved)) {
    src <- yaml::read_yaml(source_config_path)
    src <- set_config_value(
      src, key, mutate_approved_value(approved[[key]])
    )
    path <- write_temp_yaml(src)
    expect_error(
      read_source_config(path),
      paste0(path, ": ", key),
      fixed = TRUE,
      info = key
    )
  }
})

test_that("source cross-identities and accession bounds are validated", {
  cases <- list(
    list(key = "microbiome_2026.accessions.first", mutate = function(x) {
      x$microbiome_2026$accessions$first <- "GCST123"
      x
    }),
    list(key = "microbiome_2026.accessions.first", mutate = function(x) {
      x$microbiome_2026$accessions$first <- "GCST90671940"
      x
    }),
    list(key = "ed_2025.article_id", mutate = function(x) {
      x$ed_2025$article_id <- 30505798
      x
    }),
    list(key = "ed_2025.article_id", mutate = function(x) {
      x$ed_2025$article_id <- 30505799.5
      x
    }),
    list(key = "ed_2025.api", mutate = function(x) {
      x$ed_2025$api <- "https://api.figshare.com/v2/articles/30505798"
      x
    })
  )

  for (case in cases) {
    src <- yaml::read_yaml(source_config_path)
    path <- write_temp_yaml(case$mutate(src))
    expect_error(
      read_source_config(path),
      paste0(path, ": ", case$key),
      fixed = TRUE,
      info = case$key
    )
  }
})

test_that("ancestry mappings reject unknown, duplicate, empty, and wrong entries", {
  approved_patterns <- list(
    EUR = "^ed_eur_meta_(aa|ab|ac)\\.gz$",
    AFR = "^ed_afr_meta_(aa|ab)\\.gz$",
    cross_ancestry = "^ed_cross_ancestry_meta_(aa|ab|ac)\\.gz$"
  )
  cases <- list(
    list(key = "ed_2025.ancestry_file_patterns", value = c(
      approved_patterns, UNKNOWN = "^unknown\\.gz$"
    )),
    list(key = "ed_2025.ancestry_file_patterns", value = list(
      EUR = approved_patterns$EUR,
      AFR = approved_patterns$EUR,
      cross_ancestry = approved_patterns$cross_ancestry
    )),
    list(key = "ed_2025.ancestry_file_patterns", value = list(
      EUR = approved_patterns$EUR,
      AFR = "",
      cross_ancestry = approved_patterns$cross_ancestry
    )),
    list(key = "ed_2025.ancestry_file_patterns", value = list(
      EUR = approved_patterns$EUR,
      AFR = "^wrong_afr\\.gz$",
      cross_ancestry = approved_patterns$cross_ancestry
    )),
    list(key = "ld_reference_1kg.ancestry_files", value = c("EUR", "EUR")),
    list(key = "ld_reference_1kg.ancestry_files", value = c("EUR", "EAS"))
  )

  for (case in cases) {
    src <- yaml::read_yaml(source_config_path)
    src <- set_config_value(src, case$key, case$value)
    path <- write_temp_yaml(src)
    expect_error(
      read_source_config(path),
      paste0(path, ": ", case$key),
      fixed = TRUE
    )
  }
})

test_that("exact source URLs reject hostile or ambiguous URL forms", {
  invalid_urls <- c(
    "https://localhost/v2/articles/30505799",
    "https://127.0.0.1/v2/articles/30505799",
    "https://api.figshare.com:99999/v2/articles/30505799",
    "https://api.figshare.com/v2/articles/%ZZ"
  )

  for (url in invalid_urls) {
    src <- yaml::read_yaml(source_config_path)
    src$ed_2025$api <- url
    path <- write_temp_yaml(src)
    expect_error(
      read_source_config(path),
      paste0(path, ": ed_2025.api"),
      fixed = TRUE,
      info = url
    )
  }
})

test_that("checked YAML rejects missing, empty, and malformed documents", {
  missing_path <- tempfile(fileext = ".yml")
  expect_error(
    read_yaml_checked(missing_path, "required"),
    paste0("Missing config: ", missing_path),
    fixed = TRUE
  )

  empty_path <- tempfile(fileext = ".yml")
  file.create(empty_path)
  expect_error(
    read_yaml_checked(empty_path, "required"),
    paste0("Invalid YAML in ", empty_path, ": document is empty"),
    fixed = TRUE
  )

  malformed_path <- tempfile(fileext = ".yml")
  writeLines("required: [", malformed_path)
  expect_error(
    read_yaml_checked(malformed_path, "required"),
    paste0("Invalid YAML in ", malformed_path),
    fixed = TRUE
  )
})

test_that("project config rejects missing nested decision keys", {
  cfg <- yaml::read_yaml(project_config_path)
  cfg$instruments$min_f <- NULL
  path <- write_temp_yaml(cfg)

  expect_error(
    read_project_config(path),
    paste0("Missing key in ", path, ": instruments.min_f"),
    fixed = TRUE
  )
})

test_that("project config rejects invalid thresholds and probabilities", {
  cases <- list(
    list(key = "instruments.primary_p", mutate = function(x) {
      x$instruments$primary_p <- 0
      x
    }),
    list(key = "multiple_testing.fdr", mutate = function(x) {
      x$multiple_testing$fdr <- 1.5
      x
    }),
    list(key = "replication.validation.two_sided_p_lt", mutate = function(x) {
      x$replication$validation$two_sided_p_lt <- NA_real_
      x
    }),
    list(key = "coloc.pp4_support", mutate = function(x) {
      x$coloc$pp4_support <- -0.1
      x
    })
  )

  for (case in cases) {
    cfg <- yaml::read_yaml(project_config_path)
    path <- write_temp_yaml(case$mutate(cfg))
    expect_error(
      read_project_config(path),
      paste0(path, ": ", case$key),
      fixed = TRUE,
      info = case$key
    )
  }
})

test_that("project config preserves primary and exploratory threshold order", {
  cfg <- yaml::read_yaml(project_config_path)
  cfg$instruments$primary_p <- cfg$instruments$exploratory_p
  path <- write_temp_yaml(cfg)
  expect_error(
    read_project_config(path),
    paste0(path, ": instruments.primary_p"),
    fixed = TRUE
  )

  cfg$instruments$primary_p <- 1e-4
  path <- write_temp_yaml(cfg)
  expect_error(
    read_project_config(path),
    paste0(path, ": instruments.primary_p"),
    fixed = TRUE
  )
})

test_that("project config rejects invalid LD settings", {
  cfg <- yaml::read_yaml(project_config_path)
  cfg$ld$eur$r2 <- 1.1
  path <- write_temp_yaml(cfg)
  expect_error(
    read_project_config(path),
    paste0(path, ": ld.eur.r2"),
    fixed = TRUE
  )

  cfg <- yaml::read_yaml(project_config_path)
  cfg$ld$afr$kb <- 0
  path <- write_temp_yaml(cfg)
  expect_error(
    read_project_config(path),
    paste0(path, ": ld.afr.kb"),
    fixed = TRUE
  )

  cfg <- yaml::read_yaml(project_config_path)
  cfg$ld$eur$population <- "AFR"
  cfg$ld$afr$population <- "EUR"
  path <- write_temp_yaml(cfg)
  expect_error(
    read_project_config(path),
    paste0(path, ": ld.eur.population"),
    fixed = TRUE
  )

  cfg <- yaml::read_yaml(project_config_path)
  cfg$ld$afr$population <- ""
  path <- write_temp_yaml(cfg)
  expect_error(
    read_project_config(path),
    paste0(path, ": ld.afr.population"),
    fixed = TRUE
  )
})

test_that("project config requires exact normalized testing families", {
  cfg <- yaml::read_yaml(project_config_path)
  cfg$multiple_testing$families <- c("forward_primary", "forward_primary")
  path <- write_temp_yaml(cfg)

  expect_error(
    read_project_config(path),
    paste0(path, ": multiple_testing.families"),
    fixed = TRUE
  )

  cfg$multiple_testing$families <- c("forward_primary", " forward_primary ")
  path <- write_temp_yaml(cfg)
  expect_error(
    read_project_config(path),
    paste0(path, ": multiple_testing.families"),
    fixed = TRUE
  )

  cfg$multiple_testing$families <- c("reverse", "forward_primary")
  path <- write_temp_yaml(cfg)
  expect_error(
    read_project_config(path),
    paste0(path, ": multiple_testing.families"),
    fixed = TRUE
  )
})

test_that("project config requires exact typed analysis decisions", {
  cases <- list(
    list(key = "multiple_testing.method", mutate = function(x) {
      x$multiple_testing$method <- "bonferroni"
      x
    }),
    list(key = "multiple_testing.eligibility_criteria", mutate = function(x) {
      x$multiple_testing$eligibility_criteria <- character()
      x
    }),
    list(key = "multiple_testing.eligibility_criteria", mutate = function(x) {
      x$multiple_testing$eligibility_criteria <- c("source", "qc", "wrong")
      x
    }),
    list(
      key = "replication.sensitivity_only_overlap_classes",
      mutate = function(x) {
        x$replication$sensitivity_only_overlap_classes <- c(1, 2)
        x
      }
    ),
    list(key = "replication.robust_estimators", mutate = function(x) {
      x$replication$robust_estimators <- c("weighted_median", " mr_raps")
      x
    }),
    list(key = "replication.robust_estimators", mutate = function(x) {
      x$replication$robust_estimators <- c(
        "weighted_median", "weighted_median"
      )
      x
    }),
    list(key = "mvmr_covariates", mutate = function(x) {
      x$mvmr_covariates <- c("BMI", "type_2_diabetes")
      x
    })
  )

  for (case in cases) {
    cfg <- yaml::read_yaml(project_config_path)
    path <- write_temp_yaml(case$mutate(cfg))
    expect_error(
      read_project_config(path),
      paste0(path, ": ", case$key),
      fixed = TRUE,
      info = case$key
    )
  }
})

test_that("positive integers fail cleanly for every invalid numeric shape", {
  invalid_values <- list(Inf, NA_real_, 10.5, 0, -1, 3e9)

  for (value in invalid_values) {
    cfg <- yaml::read_yaml(project_config_path)
    cfg$ld$eur$kb <- value
    path <- write_temp_yaml(cfg)
    expect_error(
      read_project_config(path),
      paste0(path, ": ld.eur.kb"),
      fixed = TRUE,
      info = as.character(value)
    )
  }
})

test_that("plain YAML integers above R range fail without parser warnings", {
  config_lines <- readLines(project_config_path, warn = FALSE)
  config_lines <- sub(
    "min_snps_mr_presso: 4",
    "min_snps_mr_presso: 2147483648",
    config_lines,
    fixed = TRUE
  )
  path <- tempfile(fileext = ".yml")
  writeLines(config_lines, path)

  expect_no_warning(
    expect_error(
      read_project_config(path),
      paste0(path, ": instruments.min_snps_mr_presso"),
      fixed = TRUE
    )
  )
})

test_that("source config rejects missing nested metadata", {
  src <- yaml::read_yaml(source_config_path)
  src$finngen_r12$overlap_note <- NULL
  path <- write_temp_yaml(src)

  expect_error(
    read_source_config(path),
    paste0("Missing key in ", path, ": finngen_r12.overlap_note"),
    fixed = TRUE
  )
})

test_that("source config rejects empty licenses and overlap notes", {
  src <- yaml::read_yaml(source_config_path)
  src$microbiome_2026$license <- ""
  path <- write_temp_yaml(src)
  expect_error(
    read_source_config(path),
    paste0(path, ": microbiome_2026.license"),
    fixed = TRUE
  )

  src <- yaml::read_yaml(source_config_path)
  src$ed_2025$overlap_note <- "   "
  path <- write_temp_yaml(src)
  expect_error(
    read_source_config(path),
    paste0(path, ": ed_2025.overlap_note"),
    fixed = TRUE
  )

  src <- yaml::read_yaml(source_config_path)
  src$ld_reference_1kg$license <- c("first", "second")
  path <- write_temp_yaml(src)
  expect_error(
    read_source_config(path),
    paste0(path, ": ld_reference_1kg.license"),
    fixed = TRUE
  )
})

test_that("source config rejects empty and non-HTTPS access fields", {
  src <- yaml::read_yaml(source_config_path)
  src$finngen_r12$manifest <- ""
  path <- write_temp_yaml(src)
  expect_error(
    read_source_config(path),
    paste0(path, ": finngen_r12.manifest"),
    fixed = TRUE
  )

  src <- yaml::read_yaml(source_config_path)
  src$ld_reference_1kg$record <- "http://example.org/record"
  path <- write_temp_yaml(src)
  expect_error(
    read_source_config(path),
    paste0(path, ": ld_reference_1kg.record"),
    fixed = TRUE
  )

  for (invalid_url in c("https://", "https://   /path")) {
    src <- yaml::read_yaml(source_config_path)
    src$ed_2025$api <- invalid_url
    path <- write_temp_yaml(src)
    expect_error(
      read_source_config(path),
      paste0(path, ": ed_2025.api"),
      fixed = TRUE,
      info = invalid_url
    )
  }
})
