complement_allele <- function(x) {
  map <- c(A = "T", T = "A", C = "G", G = "C")
  unname(map[toupper(as.character(x))])
}

normalize_match_chromosome <- function(x) {
  value <- toupper(sub("^CHR", "", as.character(x), ignore.case = TRUE))
  value[value == "23"] <- "X"
  value[value == "24"] <- "Y"
  value[value == "25"] <- "XY"
  value[value == "26"] <- "MT"
  value[value == "M"] <- "MT"
  value
}

is_palindromic_pair <- function(effect_allele, other_allele) {
  pair <- paste0(
    toupper(as.character(effect_allele)),
    toupper(as.character(other_allele))
  )
  pair %in% c("AT", "TA", "CG", "GC")
}

validate_harmonisation_thresholds <- function(palindromic_maf_max, eaf_tolerance) {
  valid_probability <- function(x) {
    is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x) &&
      x > 0 && x < 0.5
  }
  if (!valid_probability(palindromic_maf_max)) {
    stop("palindromic_maf_max must be a finite number in (0, 0.5)",
         call. = FALSE)
  }
  if (!valid_probability(eaf_tolerance)) {
    stop("eaf_tolerance must be a finite number in (0, 0.5)",
         call. = FALSE)
  }
  invisible(TRUE)
}

classify_harmonisation_candidates <- function(
  x, palindromic_maf_max = 0.42, eaf_tolerance = 0.10
) {
  validate_harmonisation_thresholds(palindromic_maf_max, eaf_tolerance)
  required <- c(
    "reference_id", "chr_exposure", "ea_exposure", "oa_exposure",
    "eaf_exposure", "outcome_record_id", "chr_outcome", "ea_outcome",
    "oa_outcome", "eaf_outcome"
  )
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop("Harmonisation candidates are missing columns: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  result <- as.data.frame(x, stringsAsFactors = FALSE)
  ex_ea <- toupper(as.character(result$ea_exposure))
  ex_oa <- toupper(as.character(result$oa_exposure))
  out_ea <- toupper(as.character(result$ea_outcome))
  out_oa <- toupper(as.character(result$oa_outcome))
  valid_alleles <- ex_ea %in% c("A", "C", "G", "T") &
    ex_oa %in% c("A", "C", "G", "T") &
    out_ea %in% c("A", "C", "G", "T") &
    out_oa %in% c("A", "C", "G", "T") & ex_ea != ex_oa & out_ea != out_oa
  chromosome_match <- normalize_match_chromosome(result$chr_exposure) ==
    normalize_match_chromosome(result$chr_outcome)
  exact_same <- valid_alleles & ex_ea == out_ea & ex_oa == out_oa
  exact_swapped <- valid_alleles & ex_ea == out_oa & ex_oa == out_ea
  strand_same <- valid_alleles &
    complement_allele(ex_ea) == out_ea &
    complement_allele(ex_oa) == out_oa
  strand_swapped <- valid_alleles &
    complement_allele(ex_ea) == out_oa &
    complement_allele(ex_oa) == out_ea
  compatible <- (exact_same | exact_swapped | strand_same | strand_swapped) &
    chromosome_match & !is.na(result$outcome_record_id)

  result$candidate_allele_match <- compatible
  result$palindromic <- is_palindromic_pair(ex_ea, ex_oa)
  result$harmonisation_status <- "allele_mismatch"
  result$harmonisation_status[is.na(result$outcome_record_id)] <-
    "outcome_rsid_missing"
  result$harmonisation_status[
    !is.na(result$outcome_record_id) & !valid_alleles
  ] <- "invalid_alleles"
  result$harmonisation_status[
    !is.na(result$outcome_record_id) & valid_alleles & !chromosome_match
  ] <- "chromosome_mismatch"
  result$allele_relation <- NA_character_
  result$outcome_sign <- NA_real_
  result$outcome_eaf_aligned <- NA_real_

  nonpal <- compatible & !result$palindromic
  relation <- rep(NA_character_, nrow(result))
  sign <- rep(NA_real_, nrow(result))
  relation[nonpal & exact_same] <- "same"
  sign[nonpal & exact_same] <- 1
  relation[nonpal & exact_swapped] <- "swapped"
  sign[nonpal & exact_swapped] <- -1
  unresolved <- nonpal & is.na(sign)
  relation[unresolved & strand_same] <- "strand_same"
  sign[unresolved & strand_same] <- 1
  relation[unresolved & strand_swapped] <- "strand_swapped"
  sign[unresolved & strand_swapped] <- -1
  result$harmonisation_status[nonpal] <- "harmonised"

  pal <- compatible & result$palindromic
  nominal_sign <- rep(NA_real_, nrow(result))
  nominal_sign[pal & exact_same] <- 1
  nominal_sign[pal & exact_swapped] <- -1
  eaf_available <- is.finite(result$eaf_exposure) &
    is.finite(result$eaf_outcome) & result$eaf_exposure > 0 &
    result$eaf_exposure < 1 & result$eaf_outcome > 0 & result$eaf_outcome < 1
  result$harmonisation_status[pal & !eaf_available] <-
    "palindromic_eaf_unavailable"
  high_maf <- pal & eaf_available & (
    pmin(result$eaf_exposure, 1 - result$eaf_exposure) >
      palindromic_maf_max |
      pmin(result$eaf_outcome, 1 - result$eaf_outcome) >
        palindromic_maf_max
  )
  result$harmonisation_status[high_maf] <- "palindromic_high_maf"
  assessable <- pal & eaf_available & !high_maf & !is.na(nominal_sign)
  nominal_eaf <- ifelse(
    nominal_sign == 1, result$eaf_outcome, 1 - result$eaf_outcome
  )
  same_distance <- abs(result$eaf_exposure - nominal_eaf)
  opposite_distance <- abs(result$eaf_exposure - (1 - nominal_eaf))
  retain_nominal <- assessable & same_distance <= eaf_tolerance &
    opposite_distance > eaf_tolerance
  flip_nominal <- assessable & opposite_distance <= eaf_tolerance &
    same_distance > eaf_tolerance
  ambiguous <- assessable & same_distance <= eaf_tolerance &
    opposite_distance <= eaf_tolerance
  discordant <- assessable & same_distance > eaf_tolerance &
    opposite_distance > eaf_tolerance
  sign[retain_nominal] <- nominal_sign[retain_nominal]
  relation[retain_nominal] <- "palindromic_frequency_same"
  sign[flip_nominal] <- -nominal_sign[flip_nominal]
  relation[flip_nominal] <- "palindromic_frequency_flipped"
  result$harmonisation_status[retain_nominal | flip_nominal] <- "harmonised"
  result$harmonisation_status[ambiguous] <- "palindromic_frequency_ambiguous"
  result$harmonisation_status[discordant] <- "palindromic_frequency_discordant"

  result$allele_relation <- relation
  result$outcome_sign <- sign
  result$outcome_eaf_aligned <- ifelse(
    sign == 1, result$eaf_outcome,
    ifelse(sign == -1, 1 - result$eaf_outcome, NA_real_)
  )
  result$candidate_keep <- result$harmonisation_status == "harmonised"
  result
}

choose_harmonisation_failure <- function(status) {
  priority <- c(
    "palindromic_high_maf", "palindromic_eaf_unavailable",
    "palindromic_frequency_ambiguous", "palindromic_frequency_discordant",
    "chromosome_mismatch", "invalid_alleles", "allele_mismatch",
    "outcome_rsid_missing"
  )
  available <- priority[priority %in% status]
  if (length(available)) available[[1L]] else "not_harmonised"
}

harmonise_one_outcome <- function(
  instruments, outcome, palindromic_maf_max = 0.42, eaf_tolerance = 0.10
) {
  instruments <- data.table::as.data.table(instruments)
  outcome <- data.table::as.data.table(outcome)
  required_instrument <- c(
    "reference_id", "chr", "pos", "ea", "oa", "beta", "se", "eaf",
    "p", "n", "build", "source_id", "trait", "dataset", "F", "tier"
  )
  required_outcome <- c(
    "outcome_id", "ancestry", "build", "rsid", "chr", "pos", "ea", "oa",
    "beta", "se", "p", "eaf", "effect_scale", "analysis_role"
  )
  if (length(setdiff(required_instrument, names(instruments)))) {
    stop("Instrument table lacks required harmonisation columns", call. = FALSE)
  }
  if (length(setdiff(required_outcome, names(outcome)))) {
    stop("Outcome table lacks required harmonisation columns", call. = FALSE)
  }
  outcome_ids <- unique(outcome$outcome_id)
  if (length(outcome_ids) != 1L || is.na(outcome_ids) || !nzchar(outcome_ids)) {
    stop("Outcome table must contain exactly one non-empty outcome_id",
         call. = FALSE)
  }
  instruments <- data.table::copy(instruments)
  outcome <- data.table::copy(outcome)
  instruments[, instrument_record_id := .I]
  outcome[, outcome_record_id := .I]
  data.table::setnames(
    instruments,
    c("chr", "pos", "ea", "oa", "beta", "se", "eaf", "p", "n", "build"),
    paste0(c("chr", "pos", "ea", "oa", "beta", "se", "eaf", "p", "n", "build"),
           "_exposure")
  )
  data.table::setnames(
    outcome,
    c("rsid", "chr", "pos", "ea", "oa", "beta", "se", "eaf", "p", "build"),
    c("reference_id", paste0(
      c("chr", "pos", "ea", "oa", "beta", "se", "eaf", "p", "build"),
      "_outcome"
    ))
  )
  joined <- merge(
    instruments, outcome, by = "reference_id", all.x = TRUE, sort = FALSE,
    allow.cartesian = TRUE
  )
  joined <- data.table::as.data.table(classify_harmonisation_candidates(
    joined, palindromic_maf_max = palindromic_maf_max,
    eaf_tolerance = eaf_tolerance
  ))
  joined[, harmonisable_rows := sum(candidate_keep), by = instrument_record_id]
  joined[harmonisable_rows > 1L,
         `:=`(candidate_keep = FALSE,
              harmonisation_status = "multiallelic_multiple_matches")]

  selected <- joined[candidate_keep == TRUE]
  if (anyDuplicated(selected$instrument_record_id)) {
    stop("Harmonisation selected more than one outcome row per instrument",
         call. = FALSE)
  }
  selected[, `:=`(
    beta_outcome_harmonised = outcome_sign * beta_outcome,
    se_outcome_harmonised = se_outcome,
    matching_basis = "rsID_and_alleles_across_declared_builds"
  )]

  audit <- joined[, {
    keep_count <- sum(candidate_keep)
    status <- if (keep_count == 1L) {
      "harmonised"
    } else if (any(harmonisation_status == "multiallelic_multiple_matches")) {
      "multiallelic_multiple_matches"
    } else {
      choose_harmonisation_failure(harmonisation_status)
    }
    list(
      outcome_id = outcome_ids,
      matched_outcome_rows = sum(!is.na(outcome_record_id)),
      allele_compatible_rows = sum(candidate_allele_match, na.rm = TRUE),
      harmonisable_rows = keep_count,
      harmonisation_status = status
    )
  }, by = .(
    instrument_record_id, dataset, source_id, trait, tier, reference_id,
    build_exposure
  )]
  data.table::setorder(selected, dataset, source_id, tier, reference_id)
  data.table::setorder(audit, dataset, source_id, tier, reference_id)
  list(harmonised = as.data.frame(selected), audit = as.data.frame(audit))
}

build_harmonised_layer <- function(
  instrument_path = "03_data/processed/instruments/instruments.parquet",
  outcome_root = "03_data/processed/outcomes/candidates",
  output_root = "03_data/processed/harmonised",
  audit_path = "03_data/processed/harmonised/harmonisation_audit.parquet",
  inventory_path = "08_qc/harmonisation_inventory.csv",
  palindromic_maf_max = 0.42, eaf_tolerance = 0.10
) {
  validate_harmonisation_thresholds(palindromic_maf_max, eaf_tolerance)
  instruments <- as.data.frame(arrow::read_parquet(instrument_path))
  outcome_paths <- list.files(
    outcome_root, pattern = "[.]parquet$", full.names = TRUE
  )
  if (!length(outcome_paths)) {
    stop("No outcome candidate Parquet files were found", call. = FALSE)
  }
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
  results <- lapply(sort(outcome_paths), function(path) {
    outcome <- as.data.frame(arrow::read_parquet(path))
    result <- harmonise_one_outcome(
      instruments, outcome, palindromic_maf_max, eaf_tolerance
    )
    outcome_id <- unique(outcome$outcome_id)
    output_path <- file.path(output_root, paste0(outcome_id, ".parquet"))
    write_candidate_parquet_atomic(result$harmonised, output_path)
    result$audit$outcome_path <- path
    result$audit$output_path <- output_path
    result$audit$output_sha256 <- digest::digest(
      file = output_path, algo = "sha256", serialize = FALSE
    )
    result
  })
  audit <- do.call(rbind, lapply(results, `[[`, "audit"))
  audit$palindromic_maf_max <- palindromic_maf_max
  audit$eaf_tolerance <- eaf_tolerance
  audit$completed_at_utc <- format(
    Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  write_candidate_parquet_atomic(audit, audit_path)
  audit_sha256 <- digest::digest(
    file = audit_path, algo = "sha256", serialize = FALSE
  )
  inventory <- data.table::as.data.table(audit)[, .(
    requested_instrument_rows = .N,
    harmonised_rows = sum(harmonisation_status == "harmonised"),
    outcome_rsid_missing = sum(harmonisation_status == "outcome_rsid_missing"),
    allele_mismatch = sum(harmonisation_status == "allele_mismatch"),
    chromosome_mismatch = sum(harmonisation_status == "chromosome_mismatch"),
    palindromic_excluded = sum(grepl("^palindromic_", harmonisation_status)),
    multiallelic_multiple_matches = sum(
      harmonisation_status == "multiallelic_multiple_matches"
    ),
    coverage = mean(harmonisation_status == "harmonised"),
    output_path = unique(output_path),
    output_sha256 = unique(output_sha256)
  ), by = .(outcome_id, dataset, tier, build_exposure)]
  data.table::setorder(inventory, outcome_id, dataset, tier)
  inventory[, `:=`(
    palindromic_maf_max = palindromic_maf_max,
    eaf_tolerance = eaf_tolerance,
    audit_path = audit_path,
    audit_sha256 = audit_sha256,
    completed_at_utc = format(
      Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    )
  )]
  atomic_write_csv(as.data.frame(inventory), inventory_path)
  invisible(list(audit = audit, inventory = as.data.frame(inventory)))
}
