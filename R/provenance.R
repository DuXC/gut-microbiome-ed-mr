SOURCE_INVENTORY_REQUIRED_COLUMNS <- c(
  "dataset", "source_id", "file_name", "source_url", "expected_bytes",
  "ancestry", "genome_build", "license", "overlap_note",
  "cohort_membership", "known_overlap_datasets", "replication_role",
  "resolved_at_utc", "checksum_algorithm", "expected_checksum"
)

SOURCE_URL_PREFIXES <- c(
  microbiome_2026 =
    "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/",
  microbiome_2026_hunt =
    "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/",
  ed_2025 = "https://ndownloader.figshare.com/files/",
  finngen_r12 = paste0(
    "https://storage.googleapis.com/finngen-public-data-r12/",
    "summary_stats/release/"
  ),
  ld_reference_1kg = "https://zenodo.org/api/records/6614170/files/"
)

REPLICATION_ROLES <- c(
  "exposure_discovery", "independent_exposure_replication",
  "high_power_outcome_meta_sensitivity",
  "outcome_source_known_overlap_with_ed_2025", "external_ld_reference"
)

encode_provenance_vector <- function(value) {
  if (!is.character(value) || anyNA(value) || any(!nzchar(value)) ||
      any(grepl(";", value, fixed = TRUE)) || anyDuplicated(value)) {
    stop("Provenance vector must contain unique non-empty semicolon-free strings", call. = FALSE)
  }
  paste(value, collapse = ";")
}

decode_provenance_vector <- function(value) {
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    stop("Encoded provenance vector must be one non-missing string", call. = FALSE)
  }
  if (!nzchar(value)) return(character())
  parts <- strsplit(value, ";", fixed = TRUE)[[1L]]
  if (any(!nzchar(parts)) || anyDuplicated(parts) ||
      any(!grepl("^[A-Za-z0-9_]+$", parts))) {
    stop("Encoded provenance vector is invalid", call. = FALSE)
  }
  parts
}

inventory_key <- function(inventory) {
  paste(inventory$dataset, inventory$source_id, inventory$file_name, sep = "\r")
}

safe_inventory_basename <- function(value) {
  is.character(value) & !is.na(value) & nzchar(value) &
    basename(value) == value & !grepl("[/\\\\]", value) &
    !grepl("[[:cntrl:]]", value) & value != ".." &
    !startsWith(value, "._") & grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", value)
}

is_valid_https_url <- function(value) {
  label <- "[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
  pattern <- paste0(
    "^https://", label, "(?:\\.", label, ")*",
    "(?::[0-9]{1,5})?(?:[/?#].*)?$"
  )
  is.character(value) & !is.na(value) & !grepl("[[:space:]]", value) &
    grepl(pattern, value, perl = TRUE)
}

is_valid_utc_timestamp <- function(value) {
  pattern <- "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"
  syntax_ok <- is.character(value) & !is.na(value) & grepl(pattern, value)
  parsed <- as.POSIXct(value, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  syntax_ok & !is.na(parsed) & format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC") == value
}

validate_source_inventory_impl <- function(inventory) {
  if (!is.data.frame(inventory)) {
    stop("Source inventory must be a data frame", call. = FALSE)
  }
  missing <- setdiff(SOURCE_INVENTORY_REQUIRED_COLUMNS, names(inventory))
  if (length(missing)) {
    stop("Source inventory is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!nrow(inventory)) {
    stop("Source inventory must contain at least one row", call. = FALSE)
  }

  nonempty_columns <- c(
    "dataset", "source_id", "file_name", "source_url", "ancestry",
    "genome_build", "license", "overlap_note", "cohort_membership",
    "replication_role", "resolved_at_utc"
  )
  invalid_text <- vapply(nonempty_columns, function(column) {
    value <- inventory[[column]]
    !is.character(value) || length(value) != nrow(inventory) ||
      anyNA(value) || any(!nzchar(trimws(value)))
  }, logical(1))
  if (any(invalid_text)) {
    stop(
      "Source inventory requires nonempty scalar values in: ",
      paste(nonempty_columns[invalid_text], collapse = ", "),
      call. = FALSE
    )
  }
  if (anyDuplicated(inventory_key(inventory))) {
    stop("Source inventory contains duplicate immutable keys", call. = FALSE)
  }
  if (anyDuplicated(inventory$source_url)) {
    stop("Source inventory contains duplicate source_url values", call. = FALSE)
  }

  bytes <- inventory$expected_bytes
  if (!is.numeric(bytes) || length(bytes) != nrow(inventory) ||
      any(!is.na(bytes) & (!is.finite(bytes) | bytes < 0 | bytes != floor(bytes)))) {
    stop("expected_bytes values must be nonnegative integers or NA", call. = FALSE)
  }
  if (any(!is_valid_https_url(inventory$source_url))) {
    stop("Every source_url must be a valid HTTPS URL", call. = FALSE)
  }
  if (any(!safe_inventory_basename(inventory$file_name))) {
    stop("Every file_name must be a safe basename", call. = FALSE)
  }
  unknown_datasets <- setdiff(unique(inventory$dataset), names(SOURCE_URL_PREFIXES))
  if (length(unknown_datasets)) {
    stop(
      "Source inventory contains datasets without an approved source prefix: ",
      paste(unknown_datasets, collapse = ", "),
      call. = FALSE
    )
  }
  approved_url <- vapply(seq_len(nrow(inventory)), function(index) {
    startsWith(
      inventory$source_url[[index]],
      SOURCE_URL_PREFIXES[[inventory$dataset[[index]]]]
    )
  }, logical(1))
  if (any(!approved_url)) {
    stop("Every source_url must match its dataset approved source prefix", call. = FALSE)
  }
  if (any(!is_valid_utc_timestamp(inventory$resolved_at_utc))) {
    stop("Every resolved_at_utc value must be an exact UTC timestamp", call. = FALSE)
  }

  if (!is.character(inventory$known_overlap_datasets) ||
      length(inventory$known_overlap_datasets) != nrow(inventory) ||
      anyNA(inventory$known_overlap_datasets)) {
    stop("known_overlap_datasets must be encoded strings", call. = FALSE)
  }
  invisible(lapply(inventory$cohort_membership, function(value) {
    decoded <- decode_provenance_vector(value)
    if (!length(decoded)) stop("cohort_membership cannot be empty", call. = FALSE)
  }))
  invisible(lapply(inventory$known_overlap_datasets, decode_provenance_vector))
  if (any(!inventory$replication_role %in% REPLICATION_ROLES)) {
    stop("replication_role contains an unapproved value", call. = FALSE)
  }

  algorithm <- inventory$checksum_algorithm
  checksum <- inventory$expected_checksum
  if (!is.character(algorithm) || !is.character(checksum) ||
      length(algorithm) != nrow(inventory) || length(checksum) != nrow(inventory) ||
      anyNA(algorithm) || anyNA(checksum)) {
    stop("Checksum fields must be character values, using blanks when unavailable", call. = FALSE)
  }
  paired <- nzchar(algorithm) == nzchar(checksum)
  known <- (algorithm == "" & checksum == "") |
    (algorithm == "md5" & grepl("^[a-f0-9]{32}$", checksum)) |
    (algorithm == "sha256" & grepl("^[a-f0-9]{64}$", checksum))
  if (any(!paired | !known)) {
    stop("Checksum fields must be blank pairs or valid lowercase md5/sha256 pairs", call. = FALSE)
  }

  invisible(inventory)
}

validate_source_inventory <- function(inventory, path = NULL) {
  if (is.null(path)) {
    return(validate_source_inventory_impl(inventory))
  }
  tryCatch(
    validate_source_inventory_impl(inventory),
    error = function(error) {
      stop(
        "Source inventory at ", path, " is invalid: ",
        conditionMessage(error),
        call. = FALSE
      )
    }
  )
}

source_metadata_rows <- function(inventory) {
  required <- c(
    "dataset", "cohort_membership", "known_overlap_datasets",
    "replication_role"
  )
  missing <- setdiff(required, names(inventory))
  if (length(missing)) {
    stop("Overlap metadata is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  metadata <- unique(inventory[, required, drop = FALSE])
  if (anyDuplicated(metadata$dataset)) {
    stop("Structured overlap metadata is inconsistent within a dataset", call. = FALSE)
  }
  metadata
}

validate_overlap_symmetry_impl <- function(inventory) {
  metadata <- source_metadata_rows(inventory)
  for (index in seq_len(nrow(metadata))) {
    dataset <- metadata$dataset[[index]]
    overlaps <- decode_provenance_vector(metadata$known_overlap_datasets[[index]])
    unknown <- setdiff(overlaps, metadata$dataset)
    if (length(unknown)) {
      stop("Known overlap references unknown dataset: ", unknown[[1L]], call. = FALSE)
    }
    for (other in overlaps) {
      reverse <- decode_provenance_vector(
        metadata$known_overlap_datasets[metadata$dataset == other][[1L]]
      )
      if (!dataset %in% reverse) {
        stop(
          "Known overlap is not symmetric: ", dataset, " -> ", other,
          call. = FALSE
        )
      }
    }
  }
  invisible(metadata)
}

validate_overlap_symmetry <- function(inventory, path = NULL) {
  if (is.null(path)) {
    return(validate_overlap_symmetry_impl(inventory))
  }
  tryCatch(
    validate_overlap_symmetry_impl(inventory),
    error = function(error) {
      stop(
        "Source inventory overlap metadata at ", path, " is invalid: ",
        conditionMessage(error),
        call. = FALSE
      )
    }
  )
}

classify_dataset_pair <- function(dataset_a, dataset_b, inventory) {
  metadata <- validate_overlap_symmetry(inventory)
  if (!all(c(dataset_a, dataset_b) %in% metadata$dataset)) {
    stop("Pair classification requires known datasets", call. = FALSE)
  }
  row_a <- metadata[metadata$dataset == dataset_a, , drop = FALSE]
  row_b <- metadata[metadata$dataset == dataset_b, , drop = FALSE]
  known <- dataset_b %in% decode_provenance_vector(row_a$known_overlap_datasets) ||
    dataset_a %in% decode_provenance_vector(row_b$known_overlap_datasets)
  if (known) {
    return(list(overlap_class = "known", action = "sensitivity_only"))
  }
  roles <- c(row_a$replication_role, row_b$replication_role)
  if (setequal(
    roles,
    c("exposure_discovery", "independent_exposure_replication")
  )) {
    return(list(
      overlap_class = "none_known",
      action = "independent_exposure_replication"
    ))
  }
  list(overlap_class = "none_known", action = "primary")
}

sort_source_inventory <- function(inventory, dataset_order = sort(unique(inventory$dataset))) {
  unknown <- setdiff(unique(inventory$dataset), dataset_order)
  if (length(unknown)) {
    stop("Dataset order omits: ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  row_order <- order(
    match(inventory$dataset, dataset_order),
    inventory$source_id,
    inventory$file_name,
    seq_len(nrow(inventory)),
    method = "radix"
  )
  result <- inventory[row_order, , drop = FALSE]
  rownames(result) <- NULL
  result
}

read_source_inventory_csv <- function(path) {
  inventory <- utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    na.strings = "__CODEX_NO_NA__",
    check.names = FALSE
  )
  if (is.character(inventory$expected_bytes)) {
    inventory$expected_bytes[inventory$expected_bytes == ""] <- NA_character_
    inventory$expected_bytes <- as.numeric(inventory$expected_bytes)
  }
  for (column in c(
    "known_overlap_datasets", "checksum_algorithm", "expected_checksum"
  )) {
    if (column %in% names(inventory)) {
      inventory[[column]][is.na(inventory[[column]])] <- ""
      inventory[[column]] <- as.character(inventory[[column]])
    }
  }
  inventory
}

reconcile_source_inventory <- function(current, previous) {
  validate_source_inventory(current)
  if (!is.data.frame(previous) ||
      !all(c("dataset", "source_id", "file_name", "resolved_at_utc") %in%
        names(previous))) {
    stop("Previous source inventory cannot be reconciled", call. = FALSE)
  }
  current_keys <- inventory_key(current)
  previous_keys <- inventory_key(previous)
  removed_keys <- setdiff(previous_keys, current_keys)
  new_keys <- setdiff(current_keys, previous_keys)
  changed_keys <- character()
  unchanged_keys <- character()
  stable_columns <- setdiff(names(current), "resolved_at_utc")
  comparable <- all(stable_columns %in% names(previous))
  for (index in seq_len(nrow(current))) {
    prior_index <- match(current_keys[[index]], previous_keys)
    if (is.na(prior_index)) next
    unchanged <- comparable && all(vapply(stable_columns, function(column) {
      current_value <- current[[column]][[index]]
      previous_value <- previous[[column]][[prior_index]]
      (is.na(current_value) && is.na(previous_value)) ||
        identical(as.character(current_value), as.character(previous_value))
    }, logical(1)))
    if (unchanged) {
      current$resolved_at_utc[[index]] <- previous$resolved_at_utc[[prior_index]]
      unchanged_keys <- c(unchanged_keys, current_keys[[index]])
    } else {
      changed_keys <- c(changed_keys, current_keys[[index]])
    }
  }
  list(
    inventory = current,
    removed_keys = removed_keys,
    new_keys = new_keys,
    changed_keys = changed_keys,
    unchanged_keys = unchanged_keys
  )
}

write_source_inventory_atomic <- function(
  inventory,
  path,
  dataset_order,
  replace_file = file.rename
) {
  inventory <- sort_source_inventory(inventory, dataset_order)
  validate_source_inventory(inventory)
  if (file.exists(path)) {
    previous <- read_source_inventory_csv(path)
    validate_source_inventory(previous, path = path)
    validate_overlap_symmetry(previous, path = path)
    reconciliation <- reconcile_source_inventory(inventory, previous)
    inventory <- reconciliation$inventory
    tryCatch(
      validate_source_inventory(inventory),
      error = function(error) {
        stop(
          "Reconciled source inventory for ", path, " is invalid: ",
          conditionMessage(error),
          call. = FALSE
        )
      }
    )
    if (length(reconciliation$removed_keys)) {
      stop(
        "Inventory drift detected removed rows before replacement: ",
        paste(reconciliation$removed_keys, collapse = ", "),
        call. = FALSE
      )
    }
    if (!length(reconciliation$new_keys) &&
        !length(reconciliation$changed_keys)) {
      return(invisible(inventory))
    }
  }
  directory <- dirname(path)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile(pattern = ".source_inventory-", tmpdir = directory, fileext = ".csv")
  on.exit(unlink(temporary), add = TRUE)
  utils::write.csv(inventory, temporary, row.names = FALSE, na = "")
  if (!replace_file(temporary, path)) {
    stop("Atomic source inventory rename failed: ", path, call. = FALSE)
  }
  invisible(inventory)
}
