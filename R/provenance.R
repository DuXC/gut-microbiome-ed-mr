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
  ld_reference_1kg = "https://zenodo.org/api/records/6614170/files/",
  cytokines_2025_meta =
    "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/",
  scallop_cvd1 = "https://zenodo.org/api/records/2615265/files/"
)

REPLICATION_ROLES <- c(
  "exposure_discovery", "independent_exposure_replication",
  "high_power_outcome_meta_sensitivity",
  "outcome_source_known_overlap_with_ed_2025", "external_ld_reference",
  "mechanistic_mediator_screen_known_partial_overlap",
  "mechanistic_endothelial_mediator_screen"
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

MANIFEST_COLUMNS <- c(
  "dataset", "source_id", "file_name", "path", "source_url", "license",
  "bytes", "sha256", "frozen_at_utc"
)

MANIFEST_KEY_COLUMNS <- c("dataset", "source_id", "file_name")
MANIFEST_IMMUTABLE_COLUMNS <- c(
  "dataset", "source_id", "file_name", "path", "source_url", "license",
  "bytes", "sha256"
)

manifest_key <- function(receipt) {
  paste(receipt$dataset, receipt$source_id, receipt$file_name, sep = "\r")
}

empty_manifest <- function() {
  result <- as.data.frame(
    setNames(
      replicate(length(MANIFEST_COLUMNS), character(), simplify = FALSE),
      MANIFEST_COLUMNS
    ),
    stringsAsFactors = FALSE
  )
  result$bytes <- numeric()
  result
}

validate_safe_basename <- function(value, label) {
  if (length(value) != 1L || !safe_inventory_basename(value)) {
    stop(label, " must be a safe basename", call. = FALSE)
  }
  invisible(value)
}

safe_raw_relative_path <- function(source_row) {
  if (!is.data.frame(source_row) || nrow(source_row) != 1L ||
      !all(c("dataset", "source_id", "file_name") %in% names(source_row))) {
    stop("Source must be one row with dataset, source_id and file_name", call. = FALSE)
  }
  validate_safe_basename(source_row$dataset[[1L]], "dataset")
  validate_safe_basename(source_row$source_id[[1L]], "source_id")
  validate_safe_basename(source_row$file_name[[1L]], "file_name")
  file.path(
    "03_data", "raw", source_row$dataset[[1L]], source_row$source_id[[1L]],
    source_row$file_name[[1L]]
  )
}

validate_raw_relative_path <- function(path) {
  valid <- is.character(path) && length(path) == 1L && !is.na(path) &&
    nzchar(path) && !grepl("[[:cntrl:]]", path) &&
    !grepl("^[/\\\\]", path) && !grepl("^[A-Za-z]:", path) &&
    !grepl("\\\\", path) && identical(path, file.path(path))
  parts <- if (valid) strsplit(path, "/", fixed = TRUE)[[1L]] else character()
  valid <- valid && length(parts) == 5L && identical(parts[1:2], c("03_data", "raw")) &&
    all(vapply(parts[3:5], safe_inventory_basename, logical(1))) &&
    !any(parts %in% c(".", "..")) && !any(startsWith(parts, "._"))
  if (!valid) stop("Receipt path must be a safe raw path", call. = FALSE)
  invisible(path)
}

raw_absolute_path <- function(project_root, relative_path) {
  validate_raw_relative_path(relative_path)
  root <- normalizePath(project_root, mustWork = TRUE)
  path <- file.path(root, relative_path)
  prefix <- paste0(root, .Platform$file.sep)
  if (!startsWith(path, prefix)) {
    stop("Raw path escapes project root", call. = FALSE)
  }
  ancestor <- path
  while (!identical(ancestor, root) && !file.exists(ancestor) && !dir.exists(ancestor)) {
    ancestor <- dirname(ancestor)
  }
  resolved_ancestor <- normalizePath(ancestor, mustWork = TRUE)
  if (!identical(resolved_ancestor, root) &&
      !startsWith(resolved_ancestor, prefix)) {
    stop("Raw path escapes project root through a symbolic link", call. = FALSE)
  }
  path
}

validate_download_source <- function(source_row, inventory) {
  validate_source_inventory(inventory)
  if (!is.data.frame(source_row) || nrow(source_row) != 1L ||
      !identical(names(source_row), names(inventory))) {
    stop("Download source must be exactly one Task 4 inventory row", call. = FALSE)
  }
  safe_raw_relative_path(source_row)
  if (!is_valid_https_url(source_row$source_url[[1L]])) {
    stop("Download source must use strict HTTPS", call. = FALSE)
  }
  if (is.na(source_row$expected_bytes[[1L]])) {
    stop("Download source must declare expected bytes", call. = FALSE)
  }
  if (!source_row$checksum_algorithm[[1L]] %in% c("md5", "sha256") ||
      !nzchar(source_row$expected_checksum[[1L]])) {
    stop("Download source must declare a supported checksum", call. = FALSE)
  }
  key <- inventory_key(source_row)
  hit <- which(inventory_key(inventory) == key)
  if (length(hit) != 1L) {
    stop("Download source is not an exact Task 4 inventory row", call. = FALSE)
  }
  matches <- vapply(names(inventory), function(column) {
    left <- source_row[[column]][[1L]]
    right <- inventory[[column]][[hit]]
    (is.na(left) && is.na(right)) || identical(as.character(left), as.character(right))
  }, logical(1))
  if (!all(matches)) {
    stop("Download source is not an exact Task 4 inventory row", call. = FALSE)
  }
  invisible(source_row)
}

sha256_file <- function(path) {
  if (!file.exists(path) || dir.exists(path)) {
    stop("Cannot hash missing file: ", path, call. = FALSE)
  }
  digest::digest(path, algo = "sha256", file = TRUE, serialize = FALSE)
}

checksum_file <- function(path, algorithm) {
  if (identical(algorithm, "md5")) return(unname(tools::md5sum(path)))
  if (identical(algorithm, "sha256")) return(sha256_file(path))
  stop("Unsupported checksum algorithm: ", algorithm, call. = FALSE)
}

safe_system2 <- function(command, args = character(), ...) {
  if (!is.character(command) || length(command) != 1L || is.na(command) ||
      !nzchar(command) || grepl("[\r\n]", command)) {
    stop("Command must be one safe executable name or path", call. = FALSE)
  }
  if (!is.character(args) || anyNA(args) || any(grepl("[\r\n]", args))) {
    stop("Command arguments must be safe character scalars", call. = FALSE)
  }
  quoted <- unname(vapply(
    args, shQuote, character(1), type = "sh", USE.NAMES = FALSE
  ))
  system2(command, quoted, ...)
}

verify_upstream_file <- function(
  path,
  source_row,
  checksum_provider = checksum_file
) {
  expected_bytes <- as.numeric(source_row$expected_bytes[[1L]])
  actual_bytes <- unname(file.info(path)$size)
  if (is.na(actual_bytes) || !identical(as.numeric(actual_bytes), expected_bytes)) {
    stop(
      "File expected bytes mismatch: expected=", format(expected_bytes, scientific = FALSE),
      " actual=", format(actual_bytes, scientific = FALSE),
      call. = FALSE
    )
  }
  algorithm <- source_row$checksum_algorithm[[1L]]
  actual_checksum <- checksum_provider(path, algorithm)
  expected_checksum <- source_row$expected_checksum[[1L]]
  if (!identical(actual_checksum, expected_checksum)) {
    stop(
      "File ", algorithm, " mismatch: expected=", expected_checksum,
      " actual=", actual_checksum,
      call. = FALSE
    )
  }
  invisible(list(bytes = actual_bytes, checksum = actual_checksum))
}

file_receipt <- function(
  source_row,
  relative_path,
  file_path,
  frozen_at_utc,
  verified_sha256 = NULL
) {
  validate_raw_relative_path(relative_path)
  if (!identical(relative_path, safe_raw_relative_path(source_row))) {
    stop("Receipt raw path does not match source identity", call. = FALSE)
  }
  if (!is_valid_utc_timestamp(frozen_at_utc)) {
    stop("Receipt frozen_at_utc must be an exact UTC timestamp", call. = FALSE)
  }
  if (!file.exists(file_path) || dir.exists(file_path)) {
    stop("Receipt file is missing: ", file_path, call. = FALSE)
  }
  if (is.null(verified_sha256)) {
    verified_sha256 <- sha256_file(file_path)
  } else if (!is.character(verified_sha256) || length(verified_sha256) != 1L ||
      is.na(verified_sha256) || !grepl("^[a-f0-9]{64}$", verified_sha256)) {
    stop("Verified receipt SHA-256 is invalid", call. = FALSE)
  }
  data.frame(
    dataset = source_row$dataset[[1L]],
    source_id = source_row$source_id[[1L]],
    file_name = source_row$file_name[[1L]],
    path = relative_path,
    source_url = source_row$source_url[[1L]],
    license = source_row$license[[1L]],
    bytes = as.numeric(file.info(file_path)$size),
    sha256 = verified_sha256,
    frozen_at_utc = frozen_at_utc,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )[, MANIFEST_COLUMNS, drop = FALSE]
}

default_raw_mode_provider <- function(path) {
  as.integer(file.info(path)$mode)
}

command_result_status <- function(result) {
  status <- attr(result, "status")
  if (!is.null(status)) return(as.integer(status))
  if (is.numeric(result) && length(result) == 1L) return(as.integer(result))
  0L
}

mode_has_no_write_bits <- function(mode) {
  is.numeric(mode) && length(mode) == 1L && !is.na(mode) &&
    bitwAnd(as.integer(mode), strtoi("222", base = 8L)) == 0L
}

raw_file_flags <- function(path, command_runner = safe_system2) {
  output <- command_runner(
    "/usr/bin/stat", c("-f", "%Sf", path), stdout = TRUE, stderr = TRUE
  )
  if (command_result_status(output) != 0L) {
    stop("Could not verify raw file flags: ", path, call. = FALSE)
  }
  paste(as.character(output), collapse = " ")
}

validate_frozen_file <- function(
  path,
  mode_provider = default_raw_mode_provider,
  command_runner = safe_system2
) {
  if (!file.exists(path) || dir.exists(path)) {
    stop("Frozen raw file is missing: ", path, call. = FALSE)
  }
  if (mode_has_no_write_bits(mode_provider(path))) return(TRUE)
  flags <- raw_file_flags(path, command_runner)
  if (!grepl("(^|[ ,])uchg($|[ ,])", flags, perl = TRUE)) {
    stop("Raw file has neither no-write mode bits nor verified uchg: ", path, call. = FALSE)
  }
  TRUE
}

freeze_raw_file <- function(
  path,
  chmod_file = Sys.chmod,
  mode_provider = default_raw_mode_provider,
  command_runner = safe_system2
) {
  tryCatch(chmod_file(path, "0444"), error = function(error) FALSE)
  if (mode_has_no_write_bits(mode_provider(path))) return(TRUE)
  result <- command_runner(
    "/usr/bin/chflags", c("uchg", path), stdout = FALSE, stderr = FALSE
  )
  if (command_result_status(result) != 0L) {
    stop("chflags uchg failed for raw file: ", path, call. = FALSE)
  }
  tryCatch(
    validate_frozen_file(path, mode_provider, command_runner),
    error = function(error) {
      stop(
        "Raw file did not retain verified uchg after chmod fallback: ", path,
        "; ", conditionMessage(error),
        call. = FALSE
      )
    }
  )
}

validate_receipt_structure <- function(
  receipt,
  inventory,
  inventory_key_provider = inventory_key
) {
  if (!is.function(inventory_key_provider)) {
    stop("Inventory key provider must be a function", call. = FALSE)
  }
  if (!is.data.frame(receipt) || !identical(names(receipt), MANIFEST_COLUMNS)) {
    stop("Receipt must contain exactly the nine manifest columns", call. = FALSE)
  }
  character_columns <- setdiff(MANIFEST_COLUMNS, "bytes")
  bad_character <- vapply(character_columns, function(column) {
    !is.character(receipt[[column]]) || length(receipt[[column]]) != nrow(receipt) ||
      anyNA(receipt[[column]]) || any(!nzchar(receipt[[column]]))
  }, logical(1))
  if (any(bad_character)) {
    stop("Receipt character columns must be nonempty strings", call. = FALSE)
  }
  if (!is.numeric(receipt$bytes) || length(receipt$bytes) != nrow(receipt) ||
      anyNA(receipt$bytes) || any(!is.finite(receipt$bytes)) ||
      any(receipt$bytes < 0 | receipt$bytes != floor(receipt$bytes))) {
    stop("Receipt bytes must be nonnegative numeric integers", call. = FALSE)
  }
  if (anyDuplicated(manifest_key(receipt))) {
    stop("Manifest contains duplicate immutable receipt key", call. = FALSE)
  }
  validate_source_inventory(inventory)
  receipt_keys <- manifest_key(receipt)
  inventory_keys <- inventory_key_provider(inventory)
  source_indices <- match(receipt_keys, inventory_keys)
  if (anyNA(source_indices)) {
    stop("Receipt has no exact Task 4 inventory identity", call. = FALSE)
  }
  for (index in seq_len(nrow(receipt))) {
    row <- receipt[index, , drop = FALSE]
    source <- inventory[source_indices[[index]], , drop = FALSE]
    if (!identical(row$path[[1L]], safe_raw_relative_path(source))) {
      stop("Receipt raw path does not match Task 4 identity", call. = FALSE)
    }
    validate_raw_relative_path(row$path[[1L]])
    metadata_columns <- c("dataset", "source_id", "file_name", "source_url", "license")
    metadata_ok <- all(vapply(metadata_columns, function(column) {
      identical(row[[column]][[1L]], source[[column]][[1L]])
    }, logical(1)))
    if (!metadata_ok) {
      stop("Receipt source metadata does not match Task 4 inventory", call. = FALSE)
    }
    if (!identical(row$bytes[[1L]], as.numeric(source$expected_bytes[[1L]]))) {
      stop("Receipt bytes do not match Task 4 expected bytes", call. = FALSE)
    }
    if (!grepl("^[a-f0-9]{64}$", row$sha256[[1L]])) {
      stop("Receipt sha256 must be 64 lowercase hexadecimal characters", call. = FALSE)
    }
    if (!is_valid_utc_timestamp(row$frozen_at_utc[[1L]])) {
      stop("Receipt frozen_at_utc must be an exact UTC timestamp", call. = FALSE)
    }
  }
  invisible(receipt)
}

validate_receipt_files <- function(
  receipt,
  inventory,
  project_root,
  verify_frozen = TRUE,
  sha256_provider = sha256_file,
  checksum_provider = checksum_file,
  frozen_validator = validate_frozen_file
) {
  dependencies <- list(sha256_provider, checksum_provider, frozen_validator)
  if (!all(vapply(dependencies, is.function, logical(1)))) {
    stop("Receipt file validators must be functions", call. = FALSE)
  }
  inventory_keys <- inventory_key(inventory)
  for (index in seq_len(nrow(receipt))) {
    row <- receipt[index, , drop = FALSE]
    source_index <- match(manifest_key(row), inventory_keys)
    source <- inventory[source_index, , drop = FALSE]
    path <- raw_absolute_path(project_root, row$path[[1L]])
    if (!file.exists(path)) stop("Receipt file is missing: ", row$path[[1L]], call. = FALSE)
    actual_bytes <- as.numeric(file.info(path)$size)
    if (!identical(actual_bytes, row$bytes[[1L]])) {
      stop("Receipt bytes do not match file", call. = FALSE)
    }
    if (!identical(sha256_provider(path), row$sha256[[1L]])) {
      stop("Receipt SHA-256 does not match file", call. = FALSE)
    }
    verify_upstream_file(path, source, checksum_provider)
    if (verify_frozen) frozen_validator(path)
  }
  invisible(receipt)
}

validate_receipt <- function(
  receipt,
  inventory,
  project_root,
  verify_files = TRUE,
  verify_frozen = TRUE,
  sha256_provider = sha256_file,
  checksum_provider = checksum_file,
  frozen_validator = validate_frozen_file
) {
  validate_receipt_structure(receipt, inventory)
  if (verify_files) {
    validate_receipt_files(
      receipt, inventory, project_root,
      verify_frozen = verify_frozen,
      sha256_provider = sha256_provider,
      checksum_provider = checksum_provider,
      frozen_validator = frozen_validator
    )
  }
  invisible(receipt)
}

append_receipt_idempotent <- function(manifest, receipt) {
  if (!is.data.frame(manifest) || !identical(names(manifest), MANIFEST_COLUMNS) ||
      !is.data.frame(receipt) || !identical(names(receipt), MANIFEST_COLUMNS) ||
      nrow(receipt) != 1L) {
    stop("Manifest append requires exact manifest schema and one receipt", call. = FALSE)
  }
  if (anyDuplicated(manifest_key(manifest))) {
    stop("Manifest contains duplicate immutable receipt key", call. = FALSE)
  }
  hit <- which(manifest_key(manifest) == manifest_key(receipt))
  if (!length(hit)) {
    result <- rbind(manifest, receipt)
    rownames(result) <- NULL
    return(result)
  }
  same <- all(vapply(MANIFEST_IMMUTABLE_COLUMNS, function(column) {
    identical(manifest[[column]][[hit]], receipt[[column]][[1L]])
  }, logical(1)))
  if (!same) stop("Refusing conflicting receipt for immutable key", call. = FALSE)
  manifest
}

read_manifest_csv <- function(path) {
  if (!file.exists(path)) return(empty_manifest())
  manifest <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE,
    na.strings = "__CODEX_NO_NA__"
  )
  if ("bytes" %in% names(manifest)) manifest$bytes <- as.numeric(manifest$bytes)
  for (column in setdiff(MANIFEST_COLUMNS, "bytes")) {
    if (column %in% names(manifest)) manifest[[column]] <- as.character(manifest[[column]])
  }
  manifest
}

verify_manifest <- function(
  manifest,
  inventory,
  project_root,
  verify_files = TRUE,
  verify_frozen = TRUE,
  sha256_provider = sha256_file,
  checksum_provider = checksum_file,
  frozen_validator = validate_frozen_file
) {
  if (is.character(manifest) && length(manifest) == 1L) {
    manifest <- read_manifest_csv(manifest)
  }
  validate_receipt(
    manifest, inventory, project_root,
    verify_files = verify_files,
    verify_frozen = verify_frozen,
    sha256_provider = sha256_provider,
    checksum_provider = checksum_provider,
    frozen_validator = frozen_validator
  )
  TRUE
}

write_manifest_atomic <- function(
  manifest,
  path,
  inventory,
  project_root,
  replace_file = file.rename,
  sha256_provider = sha256_file,
  checksum_provider = checksum_file,
  frozen_validator = validate_frozen_file,
  verify_frozen = TRUE
) {
  candidate <- manifest
  rownames(candidate) <- NULL
  validate_receipt_structure(candidate, inventory)
  previous <- empty_manifest()
  if (file.exists(path)) {
    previous <- read_manifest_csv(path)
    validate_receipt_structure(previous, inventory)
    previous_keys <- manifest_key(previous)
    candidate_keys <- manifest_key(candidate)
    removed <- setdiff(previous_keys, candidate_keys)
    if (length(removed)) {
      stop(
        "Atomic MANIFEST replacement would remove immutable receipt: ",
        removed[[1L]],
        call. = FALSE
      )
    }
    candidate_indices <- match(previous_keys, candidate_keys)
    for (index in seq_len(nrow(previous))) {
      candidate_index <- candidate_indices[[index]]
      same <- all(vapply(MANIFEST_COLUMNS, function(column) {
        identical(previous[[column]][[index]], candidate[[column]][[candidate_index]])
      }, logical(1)))
      if (!same) {
        stop(
          "Atomic MANIFEST replacement conflicts with immutable receipt: ",
          previous_keys[[index]],
          call. = FALSE
        )
      }
    }
  }
  added_keys <- setdiff(manifest_key(candidate), manifest_key(previous))
  if (length(added_keys)) {
    added <- candidate[manifest_key(candidate) %in% added_keys, , drop = FALSE]
    validate_receipt_files(
      added, inventory, project_root,
      verify_frozen = verify_frozen,
      sha256_provider = sha256_provider,
      checksum_provider = checksum_provider,
      frozen_validator = frozen_validator
    )
  }
  directory <- dirname(path)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile(pattern = ".manifest-", tmpdir = directory, fileext = ".csv")
  on.exit(unlink(temporary), add = TRUE)
  utils::write.csv(candidate, temporary, row.names = FALSE, na = "")
  serialized <- read_manifest_csv(temporary)
  rownames(serialized) <- NULL
  validate_receipt_structure(serialized, inventory)
  if (!identical(serialized, candidate)) {
    stop("Serialized MANIFEST candidate changed before replacement", call. = FALSE)
  }
  if (!replace_file(temporary, path)) {
    stop("Atomic MANIFEST rename failed: ", path, call. = FALSE)
  }
  invisible(candidate)
}
