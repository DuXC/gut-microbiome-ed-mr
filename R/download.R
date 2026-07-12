download_source_key <- function(source_row) {
  paste(
    source_row$dataset[[1L]], source_row$source_id[[1L]],
    source_row$file_name[[1L]], sep = "/"
  )
}

CURL_RECOVERABLE_TRANSPORT_STATUSES <- 18L
CURL_MAX_EXTRA_ATTEMPTS <- 3L
CURL_RECOVERY_DELAY_SECONDS <- 1

curl_download_args <- function(source_row, part_path) {
  if (!is_valid_https_url(source_row$source_url[[1L]])) {
    stop("Download source must use strict HTTPS", call. = FALSE)
  }
  validate_safe_basename(source_row$file_name[[1L]], "file_name")
  c(
    "--fail", "--location", "--silent", "--show-error",
    "--continue-at", "-",
    "--retry", "5", "--retry-delay", "5",
    "--connect-timeout", "30",
    "--speed-limit", "32768", "--speed-time", "120",
    "--proto", "=https", "--proto-redir", "=https",
    "--output", part_path, source_row$source_url[[1L]]
  )
}

run_curl_download <- function(source_row, part_path, runner = safe_system2) {
  args <- curl_download_args(source_row, part_path)
  status <- runner("curl", args)
  if (length(status) != 1L || is.na(status)) {
    stop("curl runner returned no scalar status", call. = FALSE)
  }
  as.integer(status)
}

run_curl_with_recovery <- function(
  source_row,
  part_path,
  runner,
  failure_validator,
  recoverable_statuses = CURL_RECOVERABLE_TRANSPORT_STATUSES,
  max_extra_attempts = CURL_MAX_EXTRA_ATTEMPTS,
  retry_delay_seconds = CURL_RECOVERY_DELAY_SECONDS,
  sleep = Sys.sleep,
  logger = message
) {
  dependencies <- list(runner, failure_validator, sleep, logger)
  if (!all(vapply(dependencies, is.function, logical(1)))) {
    stop("curl recovery dependencies must be functions", call. = FALSE)
  }
  if (!is.numeric(recoverable_statuses) || anyNA(recoverable_statuses) ||
      any(!is.finite(recoverable_statuses)) ||
      any(recoverable_statuses != floor(recoverable_statuses))) {
    stop("Recoverable curl statuses must be integer status codes", call. = FALSE)
  }
  if (!is.numeric(max_extra_attempts) || length(max_extra_attempts) != 1L ||
      is.na(max_extra_attempts) || !is.finite(max_extra_attempts) ||
      max_extra_attempts < 0 || max_extra_attempts != floor(max_extra_attempts)) {
    stop("curl max extra attempts must be one nonnegative integer", call. = FALSE)
  }
  if (!is.numeric(retry_delay_seconds) || length(retry_delay_seconds) != 1L ||
      is.na(retry_delay_seconds) || !is.finite(retry_delay_seconds) ||
      retry_delay_seconds < 0) {
    stop("curl recovery delay must be one nonnegative number", call. = FALSE)
  }
  recoverable_statuses <- unique(as.integer(recoverable_statuses))
  total_allowed <- as.integer(max_extra_attempts) + 1L
  for (attempt in seq_len(total_allowed)) {
    status <- run_curl_download(source_row, part_path, runner)
    if (status == 0L) {
      return(list(status = 0L, attempts = attempt, completed_after_error = FALSE))
    }
    state <- tryCatch(
      failure_validator(status, attempt),
      error = identity
    )
    if (inherits(state, "error")) {
      stop(
        "curl status ", status, " after attempt ", attempt,
        " left an invalid .part: ", conditionMessage(state),
        call. = FALSE
      )
    }
    if (identical(state, "complete") && status %in% recoverable_statuses) {
      logger(sprintf(
        "curl recoverable status %d after attempt %d; .part is complete and valid",
        status, attempt
      ))
      return(list(status = 0L, attempts = attempt, completed_after_error = TRUE))
    }
    retry <- status %in% recoverable_statuses && attempt < total_allowed
    if (!retry) {
      return(list(
        status = status, attempts = attempt, completed_after_error = FALSE
      ))
    }
    logger(sprintf(
      paste0(
        "curl recoverable status %d after attempt %d; ",
        "retrying attempt %d of %d after %s seconds"
      ),
      status, attempt, attempt + 1L, total_allowed,
      format(retry_delay_seconds, scientific = FALSE)
    ))
    sleep(retry_delay_seconds)
  }
  stop("curl recovery loop ended unexpectedly", call. = FALSE)
}

reject_symbolic_link <- function(path, label) {
  target <- Sys.readlink(path)
  if (length(target) == 1L && !is.na(target) && nzchar(target)) {
    stop(label, " must not be a symbolic link: ", path, call. = FALSE)
  }
  invisible(path)
}

manifest_target_receipt <- function(manifest, source_row) {
  hit <- which(manifest_key(manifest) == inventory_key(source_row))
  if (!length(hit)) return(empty_manifest())
  manifest[hit, , drop = FALSE]
}

default_regular_file_provider <- function(path) {
  type <- suppressWarnings(safe_system2(
    "/usr/bin/stat", c("-f", "%HT", path),
    stdout = TRUE, stderr = FALSE
  ))
  status <- attr(type, "status")
  (is.null(status) || identical(status, 0L)) &&
    length(type) == 1L && identical(type[[1L]], "Regular File")
}

require_regular_partial <- function(
  part_path,
  regular_file_provider = default_regular_file_provider
) {
  reject_symbolic_link(part_path, "Partial download")
  if (!is.function(regular_file_provider)) {
    stop("Partial regular-file provider must be a function", call. = FALSE)
  }
  exists <- file.exists(part_path) || dir.exists(part_path)
  if (exists && !isTRUE(regular_file_provider(part_path))) {
    stop("Partial download must be a regular file: ", part_path, call. = FALSE)
  }
  invisible(exists)
}

inspect_partial_file <- function(
  part_path,
  source_row,
  receipt = empty_manifest(),
  regular_file_provider = default_regular_file_provider,
  sha256_provider = sha256_file,
  checksum_provider = checksum_file
) {
  exists <- require_regular_partial(part_path, regular_file_provider)
  expected <- as.numeric(source_row$expected_bytes[[1L]])
  if (!exists) {
    return(list(state = "missing", size = 0, remaining = expected, sha256 = NULL))
  }
  size <- as.numeric(file.info(part_path)$size)
  if (is.na(size)) stop("Partial download size is unavailable", call. = FALSE)
  if (size > expected) {
    stop(
      "Partial download is larger than expected: expected=",
      format(expected, scientific = FALSE), " actual=",
      format(size, scientific = FALSE),
      call. = FALSE
    )
  }
  if (size < expected) {
    return(list(
      state = "partial", size = size, remaining = expected - size,
      sha256 = NULL
    ))
  }
  verify_upstream_file(part_path, source_row, checksum_provider)
  sha256 <- sha256_provider(part_path)
  if (nrow(receipt) && !identical(sha256, receipt$sha256[[1L]])) {
    stop(
      "Complete partial receipt SHA-256 conflicts with frozen receipt: expected=",
      receipt$sha256[[1L]], " actual=", sha256,
      call. = FALSE
    )
  }
  list(state = "complete", size = size, remaining = 0, sha256 = sha256)
}

ensure_part_writable <- function(
  part_path,
  chmod_file = Sys.chmod,
  regular_file_provider = default_regular_file_provider
) {
  exists <- require_regular_partial(part_path, regular_file_provider)
  if (exists && !chmod_file(part_path, mode = "0644")) {
    stop("Could not make partial download writable: ", part_path, call. = FALSE)
  }
  invisible(part_path)
}

finish_verified_part <- function(
  part_path,
  final_path,
  rename_file = file.rename,
  regular_file_provider = default_regular_file_provider
) {
  require_regular_partial(part_path, regular_file_provider)
  reject_symbolic_link(final_path, "Raw final file")
  if (file.exists(final_path)) {
    stop("Refusing to overwrite existing final file: ", final_path, call. = FALSE)
  }
  if (!rename_file(part_path, final_path)) {
    stop("Atomic final-file rename failed: ", final_path, call. = FALSE)
  }
  reject_symbolic_link(final_path, "Raw final file")
  invisible(final_path)
}

validate_promoted_file <- function(
  final_path,
  source_row,
  expected_sha256,
  receipt = empty_manifest(),
  sha256_provider = sha256_file,
  checksum_provider = checksum_file,
  frozen_validator = validate_frozen_file,
  verify_frozen = TRUE
) {
  reject_symbolic_link(final_path, "Raw final file")
  verify_upstream_file(final_path, source_row, checksum_provider)
  actual_sha256 <- sha256_provider(final_path)
  if (!identical(actual_sha256, expected_sha256)) {
    stop(
      "Raw file changed during promotion: expected SHA-256=", expected_sha256,
      " actual=", actual_sha256,
      call. = FALSE
    )
  }
  if (nrow(receipt) && !identical(actual_sha256, receipt$sha256[[1L]])) {
    stop("Promoted file SHA-256 conflicts with frozen receipt", call. = FALSE)
  }
  if (verify_frozen) frozen_validator(final_path)
  invisible(actual_sha256)
}

rollback_failed_promotion <- function(
  final_path,
  part_path,
  chmod_file = Sys.chmod,
  flag_runner = safe_system2,
  rollback_rename = file.rename,
  regular_file_provider = default_regular_file_provider
) {
  if (!file.exists(final_path)) return(invisible(FALSE))
  try(chmod_file(final_path, "0644"), silent = TRUE)
  try(flag_runner(
    "/usr/bin/chflags", c("nouchg", final_path),
    stdout = FALSE, stderr = FALSE
  ), silent = TRUE)
  if (file.exists(part_path) || dir.exists(part_path) ||
      !rollback_rename(final_path, part_path)) {
    stop("Failed promotion could not be restored to its .part path", call. = FALSE)
  }
  ensure_part_writable(part_path, chmod_file, regular_file_provider)
  invisible(TRUE)
}

promote_verified_part <- function(
  part_path,
  final_path,
  source_row,
  expected_sha256,
  receipt = empty_manifest(),
  rename_file = file.rename,
  rollback_rename = file.rename,
  chmod_file = Sys.chmod,
  mode_provider = default_raw_mode_provider,
  freeze_runner = safe_system2,
  regular_file_provider = default_regular_file_provider,
  sha256_provider = sha256_file,
  checksum_provider = checksum_file
) {
  finish_verified_part(
    part_path, final_path, rename_file, regular_file_provider
  )
  promoted <- tryCatch({
    validate_promoted_file(
      final_path, source_row, expected_sha256, receipt,
      sha256_provider = sha256_provider,
      checksum_provider = checksum_provider,
      verify_frozen = FALSE
    )
    freeze_raw_file(final_path, chmod_file, mode_provider, freeze_runner)
    validate_promoted_file(
      final_path, source_row, expected_sha256, receipt,
      sha256_provider = sha256_provider,
      checksum_provider = checksum_provider,
      frozen_validator = function(path) {
        validate_frozen_file(path, mode_provider, freeze_runner)
      },
      verify_frozen = TRUE
    )
    TRUE
  }, error = identity)
  if (inherits(promoted, "error")) {
    rollback_error <- tryCatch({
      rollback_failed_promotion(
        final_path, part_path, chmod_file, freeze_runner, rollback_rename,
        regular_file_provider
      )
      NULL
    }, error = identity)
    if (inherits(rollback_error, "error")) {
      stop(
        conditionMessage(promoted), "; ", conditionMessage(rollback_error),
        call. = FALSE
      )
    }
    stop(conditionMessage(promoted), call. = FALSE)
  }
  invisible(final_path)
}

download_inventory_row <- function(
  source_row,
  inventory,
  manifest_path,
  project_root,
  runner = safe_system2,
  clock = function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  rename_file = file.rename,
  chmod_file = Sys.chmod,
  mode_provider = default_raw_mode_provider,
  freeze_runner = safe_system2,
  manifest_writer = write_manifest_atomic,
  regular_file_provider = default_regular_file_provider,
  sha256_provider = sha256_file,
  checksum_provider = checksum_file,
  rollback_rename = file.rename,
  curl_recoverable_statuses = CURL_RECOVERABLE_TRANSPORT_STATUSES,
  curl_max_extra_attempts = CURL_MAX_EXTRA_ATTEMPTS,
  curl_retry_delay_seconds = CURL_RECOVERY_DELAY_SECONDS,
  curl_sleep = Sys.sleep,
  curl_retry_logger = message
) {
  validate_download_source(source_row, inventory)
  relative_path <- safe_raw_relative_path(source_row)
  final_path <- raw_absolute_path(project_root, relative_path)
  part_path <- paste0(final_path, ".part")
  reject_symbolic_link(final_path, "Raw final file")
  reject_symbolic_link(part_path, "Partial download")
  manifest <- read_manifest_csv(manifest_path)
  validate_receipt(manifest, inventory, project_root, verify_files = FALSE)
  receipt <- manifest_target_receipt(manifest, source_row)

  if (nrow(receipt) && file.exists(final_path)) {
    validate_receipt(
      receipt, inventory, project_root,
      verify_files = TRUE, verify_frozen = FALSE
    )
    freeze_raw_file(final_path, chmod_file, mode_provider, freeze_runner)
    return(invisible(list(
      status = "skipped", bytes = 0,
      key = download_source_key(source_row), path = relative_path
    )))
  }

  if (!nrow(receipt) && file.exists(final_path)) {
    verify_upstream_file(final_path, source_row)
    freeze_raw_file(final_path, chmod_file, mode_provider, freeze_runner)
    new_receipt <- file_receipt(source_row, relative_path, final_path, clock())
    candidate <- append_receipt_idempotent(manifest, new_receipt)
    manifest_writer(candidate, manifest_path, inventory, project_root)
    return(invisible(list(
      status = "adopted", bytes = 0,
      key = download_source_key(source_row), path = relative_path
    )))
  }

  dir.create(dirname(final_path), recursive = TRUE, showWarnings = FALSE)
  partial <- inspect_partial_file(
    part_path, source_row, receipt,
    regular_file_provider = regular_file_provider,
    sha256_provider = sha256_provider,
    checksum_provider = checksum_provider
  )
  if (identical(partial$state, "complete")) {
    promote_verified_part(
      part_path, final_path, source_row, partial$sha256, receipt,
      rename_file = rename_file,
      rollback_rename = rollback_rename,
      chmod_file = chmod_file,
      mode_provider = mode_provider,
      freeze_runner = freeze_runner,
      regular_file_provider = regular_file_provider,
      sha256_provider = sha256_provider,
      checksum_provider = checksum_provider
    )
    if (!nrow(receipt)) {
      new_receipt <- file_receipt(
        source_row, relative_path, final_path, clock(),
        verified_sha256 = partial$sha256
      )
      candidate <- append_receipt_idempotent(manifest, new_receipt)
      manifest_writer(candidate, manifest_path, inventory, project_root)
    }
    return(invisible(list(
      status = "completed", bytes = 0,
      key = download_source_key(source_row), path = relative_path
    )))
  }
  ensure_part_writable(part_path, chmod_file, regular_file_provider)
  curl <- run_curl_with_recovery(
    source_row, part_path, runner,
    failure_validator = function(status, attempt) {
      failed <- inspect_partial_file(
        part_path, source_row, receipt,
        regular_file_provider = regular_file_provider,
        sha256_provider = sha256_provider,
        checksum_provider = checksum_provider
      )
      if (identical(failed$state, "complete")) return("complete")
      ensure_part_writable(part_path, chmod_file, regular_file_provider)
      failed$state
    },
    recoverable_statuses = curl_recoverable_statuses,
    max_extra_attempts = curl_max_extra_attempts,
    retry_delay_seconds = curl_retry_delay_seconds,
    sleep = curl_sleep,
    logger = curl_retry_logger
  )
  if (curl$status != 0L) {
    stop(
      "curl failed with status ", curl$status, " after ", curl$attempts,
      if (curl$attempts == 1L) " attempt" else " attempts",
      call. = FALSE
    )
  }
  ensure_part_writable(part_path, chmod_file, regular_file_provider)
  completed <- inspect_partial_file(
    part_path, source_row, receipt,
    regular_file_provider = regular_file_provider,
    sha256_provider = sha256_provider,
    checksum_provider = checksum_provider
  )
  if (!identical(completed$state, "complete")) {
    stop(
      "Partial download did not reach expected bytes: expected=",
      source_row$expected_bytes[[1L]], " actual=", completed$size,
      call. = FALSE
    )
  }

  promote_verified_part(
    part_path, final_path, source_row, completed$sha256, receipt,
    rename_file = rename_file,
    rollback_rename = rollback_rename,
    chmod_file = chmod_file,
    mode_provider = mode_provider,
    freeze_runner = freeze_runner,
    regular_file_provider = regular_file_provider,
    sha256_provider = sha256_provider,
    checksum_provider = checksum_provider
  )
  if (!nrow(receipt)) {
    new_receipt <- file_receipt(
      source_row, relative_path, final_path, clock(),
      verified_sha256 = completed$sha256
    )
    candidate <- append_receipt_idempotent(manifest, new_receipt)
    manifest_writer(candidate, manifest_path, inventory, project_root)
  }
  invisible(list(
    status = "completed", bytes = as.numeric(partial$remaining),
    key = download_source_key(source_row), path = relative_path
  ))
}

default_free_space_provider <- function(path) {
  output <- safe_system2("df", c("-Pk", path), stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  if (!is.null(status) && status != 0L) {
    stop("Could not determine free disk space", call. = FALSE)
  }
  lines <- output[nzchar(trimws(output))]
  if (length(lines) < 2L) stop("Could not parse free disk space", call. = FALSE)
  fields <- strsplit(trimws(tail(lines, 1L)), "[[:space:]]+")[[1L]]
  if (length(fields) < 4L || !grepl("^[0-9]+$", fields[[4L]])) {
    stop("Could not parse free disk space", call. = FALSE)
  }
  as.numeric(fields[[4L]]) * 1024
}

row_download_bytes <- function(
  source_row,
  manifest,
  project_root,
  inventory,
  regular_file_provider = default_regular_file_provider,
  sha256_provider = sha256_file,
  checksum_provider = checksum_file
) {
  receipt <- manifest_target_receipt(manifest, source_row)
  final_path <- raw_absolute_path(project_root, safe_raw_relative_path(source_row))
  if (file.exists(final_path)) {
    if (nrow(receipt)) {
      validate_receipt(
        receipt, inventory, project_root,
        verify_files = TRUE, verify_frozen = FALSE
      )
    } else {
      verify_upstream_file(final_path, source_row)
    }
    return(0)
  }
  part_path <- paste0(final_path, ".part")
  partial <- inspect_partial_file(
    part_path, source_row, receipt,
    regular_file_provider = regular_file_provider,
    sha256_provider = sha256_provider,
    checksum_provider = checksum_provider
  )
  as.numeric(partial$remaining)
}

preflight_download_space <- function(
  selected,
  manifest,
  project_root,
  free_space_provider = default_free_space_provider,
  reserve_bytes = 10 * 1024^3,
  inventory = selected,
  regular_file_provider = default_regular_file_provider,
  sha256_provider = sha256_file,
  checksum_provider = checksum_file
) {
  if (!is.numeric(reserve_bytes) || length(reserve_bytes) != 1L ||
      is.na(reserve_bytes) || !is.finite(reserve_bytes) || reserve_bytes < 0) {
    stop("Safety reserve must be one nonnegative byte count", call. = FALSE)
  }
  validate_receipt(manifest, inventory, project_root, verify_files = FALSE)
  remaining <- vapply(seq_len(nrow(selected)), function(index) {
    source <- selected[index, , drop = FALSE]
    tryCatch(
      row_download_bytes(
        source, manifest, project_root, inventory,
        regular_file_provider = regular_file_provider,
        sha256_provider = sha256_provider,
        checksum_provider = checksum_provider
      ),
      error = function(error) {
        stop(
          "Disk preflight failed for ", download_source_key(source), ": ",
          conditionMessage(error),
          call. = FALSE
        )
      }
    )
  }, numeric(1))
  download_bytes <- sum(remaining)
  if (!is.finite(download_bytes)) {
    stop("Disk preflight requires expected bytes for every selected source", call. = FALSE)
  }
  required <- download_bytes + reserve_bytes
  free <- as.numeric(free_space_provider(project_root))
  if (length(free) != 1L || is.na(free) || !is.finite(free) || free < 0) {
    stop("Free-space provider returned an invalid byte count", call. = FALSE)
  }
  if (free < required) {
    stop(
      "Insufficient disk space: required=", format(required, scientific = FALSE),
      " free=", format(free, scientific = FALSE),
      " download=", format(download_bytes, scientific = FALSE),
      " reserve=", format(reserve_bytes, scientific = FALSE),
      call. = FALSE
    )
  }
  list(
    download_bytes = download_bytes, required_bytes = required,
    free_bytes = free, reserve_bytes = reserve_bytes
  )
}

parse_cli_filters <- function(args) {
  values <- list(dataset = NULL, file = NULL, limit = NULL)
  index <- 1L
  while (index <= length(args)) {
    argument <- args[[index]]
    equal <- regexec("^--(dataset|file|limit)=(.*)$", argument, perl = TRUE)
    pieces <- regmatches(argument, equal)[[1L]]
    if (length(pieces)) {
      name <- pieces[[2L]]
      value <- pieces[[3L]]
    } else if (argument %in% c("--dataset", "--file", "--limit")) {
      name <- sub("^--", "", argument)
      index <- index + 1L
      if (index > length(args) || startsWith(args[[index]], "--")) {
        stop("Missing value for --", name, call. = FALSE)
      }
      value <- args[[index]]
    } else {
      stop("unknown argument: ", argument, call. = FALSE)
    }
    if (!is.null(values[[name]])) stop("duplicate --", name, call. = FALSE)
    if (!nzchar(value)) stop("Empty value for --", name, call. = FALSE)
    values[[name]] <- value
    index <- index + 1L
  }
  if (!is.null(values$limit)) {
    if (!grepl("^[1-9][0-9]*$", values$limit)) {
      stop("--limit must be a positive integer", call. = FALSE)
    }
    values$limit <- as.integer(values$limit)
  }
  values
}

select_download_rows <- function(inventory, args) {
  validate_source_inventory(inventory)
  filters <- parse_cli_filters(args)
  selected <- inventory
  if (!is.null(filters$dataset)) {
    selected <- selected[selected$dataset == filters$dataset, , drop = FALSE]
  }
  if (!is.null(filters$file)) {
    selected <- selected[selected$file_name == filters$file, , drop = FALSE]
  }
  if (!nrow(selected)) stop("CLI filters matched no inventory rows", call. = FALSE)
  if (!is.null(filters$limit)) {
    selected <- head(selected, filters$limit)
  }
  rownames(selected) <- NULL
  selected
}

download_selected_rows <- function(
  selected,
  inventory,
  manifest_path,
  project_root,
  runner = safe_system2,
  clock = function() format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  rename_file = file.rename,
  chmod_file = Sys.chmod,
  free_space_provider = default_free_space_provider,
  reserve_bytes = 10 * 1024^3
) {
  manifest <- read_manifest_csv(manifest_path)
  preflight <- preflight_download_space(
    selected, manifest, project_root, free_space_provider, reserve_bytes,
    inventory = inventory
  )
  completed <- 0L
  skipped <- 0L
  bytes <- 0
  for (index in seq_len(nrow(selected))) {
    source <- selected[index, , drop = FALSE]
    key <- download_source_key(source)
    result <- tryCatch(
      download_inventory_row(
        source, inventory, manifest_path, project_root,
        runner = runner, clock = clock, rename_file = rename_file,
        chmod_file = chmod_file
      ),
      error = function(error) {
        stop("Download failed for ", key, ": ", conditionMessage(error), call. = FALSE)
      }
    )
    if (identical(result$status, "skipped")) {
      skipped <- skipped + 1L
    } else {
      completed <- completed + 1L
    }
    bytes <- bytes + result$bytes
  }
  list(
    selected = nrow(selected), completed = completed, skipped = skipped,
    bytes = bytes, preflight = preflight
  )
}

default_lock_age <- function(lock_path) {
  owner <- file.path(lock_path, "owner")
  path <- if (file.exists(owner)) owner else lock_path
  as.numeric(difftime(Sys.time(), file.info(path)$mtime, units = "secs"))
}

default_lock_owner_alive <- function(owner) {
  if (!is.character(owner) || length(owner) != 1L ||
      !grepl("^[0-9]+-", owner)) {
    return(FALSE)
  }
  pid <- sub("-.*$", "", owner)
  status <- suppressWarnings(safe_system2(
    "kill", c("-0", pid), stdout = FALSE, stderr = FALSE
  ))
  identical(as.integer(status), 0L)
}

validate_lock_token <- function(token) {
  valid <- is.character(token) && length(token) == 1L && !is.na(token) &&
    grepl("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", token) &&
    !grepl("[[:cntrl:]/\\\\]", token) && !startsWith(token, "._")
  if (!valid) stop("Download lock token is unsafe", call. = FALSE)
  token
}

validate_lock_path <- function(lock_path) {
  valid <- is.character(lock_path) && length(lock_path) == 1L &&
    !is.na(lock_path) && nzchar(lock_path) &&
    !grepl("[[:cntrl:]]", lock_path) &&
    identical(lock_path, file.path(dirname(lock_path), basename(lock_path))) &&
    grepl("^\\.?[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", basename(lock_path)) &&
    !startsWith(basename(lock_path), "._") && dir.exists(dirname(lock_path))
  if (!valid) stop("Download lock path is unsafe", call. = FALSE)
  invisible(normalizePath(dirname(lock_path), mustWork = TRUE))
  lock_path
}

default_create_lock_dir <- function(path) {
  dir.create(path, recursive = FALSE, showWarnings = FALSE)
}

default_remove_lock_dir <- function(path) {
  unlink(path, recursive = TRUE, force = FALSE)
  !dir.exists(path) && !file.exists(path)
}

default_lock_quarantine_path <- function(lock_path) {
  tempfile(
    pattern = paste0(basename(lock_path), ".stale-", Sys.getpid(), "-"),
    tmpdir = dirname(lock_path)
  )
}

validate_lock_quarantine <- function(quarantine_path, lock_path) {
  parent <- normalizePath(dirname(lock_path), mustWork = TRUE)
  valid <- is.character(quarantine_path) && length(quarantine_path) == 1L &&
    !is.na(quarantine_path) && nzchar(quarantine_path) &&
    !grepl("[[:cntrl:]/\\\\]", basename(quarantine_path)) &&
    identical(normalizePath(dirname(quarantine_path), mustWork = TRUE), parent) &&
    startsWith(
      basename(quarantine_path),
      paste0(basename(lock_path), ".stale-")
    ) && !identical(quarantine_path, lock_path) &&
    !file.exists(quarantine_path) && !dir.exists(quarantine_path)
  if (!valid) stop("Download lock quarantine path is unsafe", call. = FALSE)
  quarantine_path
}

read_lock_owner <- function(lock_path) {
  owner_path <- file.path(lock_path, "owner")
  if (!file.exists(owner_path)) return(character())
  readLines(owner_path, warn = FALSE)
}

write_lock_owner_atomic <- function(lock_path, token) {
  temporary <- tempfile(pattern = ".owner-", tmpdir = lock_path)
  on.exit(unlink(temporary), add = TRUE)
  connection <- file(temporary, open = "wx")
  connection_open <- TRUE
  on.exit({
    if (connection_open) close(connection)
  }, add = TRUE)
  writeLines(token, connection, useBytes = TRUE)
  close(connection)
  connection_open <- FALSE
  owner_path <- file.path(lock_path, "owner")
  if (file.exists(owner_path) || !file.rename(temporary, owner_path)) {
    stop("Atomic download-lock owner write failed", call. = FALSE)
  }
  if (!identical(read_lock_owner(lock_path), token)) {
    stop("Download-lock owner token verification failed", call. = FALSE)
  }
  invisible(token)
}

cleanup_created_lock <- function(lock_path, token, claim_path, remove_lock_dir) {
  if (!file.exists(claim_path) || !dir.exists(lock_path)) return(invisible(FALSE))
  owner <- read_lock_owner(lock_path)
  if (!length(owner) || identical(owner, token)) {
    remove_lock_dir(lock_path)
  } else {
    unlink(claim_path)
  }
  invisible(TRUE)
}

claim_created_lock <- function(
  lock_path,
  token,
  owner_writer,
  remove_lock_dir
) {
  claim_path <- file.path(lock_path, paste0(".claim-", token))
  if (!file.create(claim_path)) {
    owner <- read_lock_owner(lock_path)
    entries <- list.files(lock_path, all.files = TRUE, no.. = TRUE)
    if (!length(owner) && !length(entries)) remove_lock_dir(lock_path)
    stop("Could not establish download-lock ownership claim", call. = FALSE)
  }
  complete <- FALSE
  on.exit({
    if (!complete) cleanup_created_lock(lock_path, token, claim_path, remove_lock_dir)
  }, add = TRUE)
  owner_writer(lock_path, token)
  if (!identical(read_lock_owner(lock_path), token)) {
    stop("Download-lock owner token verification failed", call. = FALSE)
  }
  unlink(claim_path)
  complete <- TRUE
  token
}

lock_is_stale <- function(
  lock_path,
  stale_after,
  age_provider,
  owner_alive_provider
) {
  age <- age_provider(lock_path)
  owner <- read_lock_owner(lock_path)
  owner_alive <- owner_alive_provider(owner)
  if (!is.numeric(age) || length(age) != 1L || is.na(age) ||
      !is.logical(owner_alive) || length(owner_alive) != 1L || is.na(owner_alive)) {
    stop("Download lock state cannot be validated", call. = FALSE)
  }
  age > stale_after && !owner_alive
}

validate_shlock_pid <- function(pid) {
  if (!is.numeric(pid) || length(pid) != 1L || is.na(pid) ||
      !is.finite(pid) || pid != floor(pid) || pid <= 0) {
    stop("Download-lock guard PID is invalid", call. = FALSE)
  }
  as.integer(pid)
}

reclaim_guard_path <- function(lock_path) {
  # shlock uses hard links, which exFAT does not support. A deterministic guard
  # in the user's local TMPDIR serializes processes for this normalized path.
  temporary_root <- Sys.getenv("TMPDIR", unset = "/tmp")
  if (!nzchar(temporary_root)) temporary_root <- "/tmp"
  temporary_root <- normalizePath(temporary_root, mustWork = TRUE)
  normalized_lock <- file.path(
    normalizePath(dirname(lock_path), mustWork = TRUE), basename(lock_path)
  )
  key <- digest::digest(normalized_lock, algo = "sha256", serialize = FALSE)
  guard <- file.path(
    temporary_root, paste0(".gut-ed-download-", key, ".reclaim")
  )
  valid <- identical(normalizePath(dirname(guard), mustWork = TRUE), temporary_root) &&
    grepl(
      "^\\.gut-ed-download-[a-f0-9]{64}\\.reclaim$",
      basename(guard)
    ) && !grepl("[[:cntrl:]/\\\\]", basename(guard))
  if (!valid) stop("Download-lock transition guard path is unsafe", call. = FALSE)
  guard
}

acquire_reclaim_guard <- function(
  lock_path,
  shlock_runner = safe_system2,
  pid = Sys.getpid()
) {
  if (!is.function(shlock_runner)) {
    stop("Download-lock shlock runner must be a function", call. = FALSE)
  }
  pid <- validate_shlock_pid(pid)
  guard <- reclaim_guard_path(lock_path)
  result <- shlock_runner(
    "/usr/bin/shlock", c("-f", guard, "-p", as.character(pid))
  )
  if (command_result_status(result) != 0L) {
    stop("Download-lock transition guard is already held", call. = FALSE)
  }
  recorded <- if (file.exists(guard)) readLines(guard, warn = FALSE) else character()
  if (!identical(recorded, as.character(pid))) {
    stop("Download-lock transition guard PID verification failed", call. = FALSE)
  }
  list(path = guard, pid = pid)
}

release_reclaim_guard <- function(guard, remove_file = unlink) {
  if (!is.list(guard) || !identical(names(guard), c("path", "pid")) ||
      !is.function(remove_file)) {
    stop("Download-lock transition guard release is invalid", call. = FALSE)
  }
  pid <- validate_shlock_pid(guard$pid)
  recorded <- if (file.exists(guard$path)) {
    readLines(guard$path, warn = FALSE)
  } else {
    character()
  }
  if (!identical(recorded, as.character(pid))) {
    stop("Refusing to release transition guard owned by another process", call. = FALSE)
  }
  result <- remove_file(guard$path)
  removed <- (is.numeric(result) && length(result) == 1L && !is.na(result) && result == 0) ||
    (is.logical(result) && length(result) == 1L && isTRUE(result))
  if (!removed) {
    stop("Download-lock transition guard removal failed", call. = FALSE)
  }
  if (file.exists(guard$path)) {
    successor <- readLines(guard$path, warn = FALSE)
    valid_successor <- length(successor) == 1L && grepl("^[0-9]+$", successor) &&
      !identical(successor, as.character(pid))
    if (!valid_successor) {
      stop("Download-lock transition guard removal failed", call. = FALSE)
    }
  }
  invisible(TRUE)
}

remove_owned_lock_under_guard <- function(lock_path, token, remove_lock_dir) {
  owner <- read_lock_owner(lock_path)
  if (!identical(owner, token)) {
    stop("Refusing to remove download lock owned by another process", call. = FALSE)
  }
  if (!isTRUE(remove_lock_dir(lock_path))) {
    stop("Download lock removal failed", call. = FALSE)
  }
  invisible(TRUE)
}

acquire_download_lock <- function(
  lock_path,
  token = paste(Sys.getpid(), format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), sep = "-"),
  stale_after = 24 * 60 * 60,
  age_provider = default_lock_age,
  owner_alive_provider = default_lock_owner_alive,
  create_lock_dir = default_create_lock_dir,
  rename_lock_dir = file.rename,
  remove_lock_dir = default_remove_lock_dir,
  owner_writer = write_lock_owner_atomic,
  quarantine_factory = default_lock_quarantine_path,
  shlock_runner = safe_system2,
  guard_remove_file = unlink
) {
  lock_path <- validate_lock_path(lock_path)
  token <- validate_lock_token(token)
  if (!is.numeric(stale_after) || length(stale_after) != 1L ||
      is.na(stale_after) || !is.finite(stale_after) || stale_after < 0) {
    stop("Download lock stale_after must be nonnegative", call. = FALSE)
  }
  dependencies <- list(
    age_provider, owner_alive_provider, create_lock_dir, rename_lock_dir,
    remove_lock_dir, owner_writer, quarantine_factory, shlock_runner,
    guard_remove_file
  )
  if (!all(vapply(dependencies, is.function, logical(1)))) {
    stop("Download lock dependencies must be functions", call. = FALSE)
  }

  if (isTRUE(create_lock_dir(lock_path))) {
    return(claim_created_lock(lock_path, token, owner_writer, remove_lock_dir))
  }

  guard <- acquire_reclaim_guard(lock_path, shlock_runner)
  on.exit(release_reclaim_guard(guard, guard_remove_file), add = TRUE)
  if (isTRUE(create_lock_dir(lock_path))) {
    return(claim_created_lock(lock_path, token, owner_writer, remove_lock_dir))
  }
  if (!dir.exists(lock_path) ||
      !lock_is_stale(lock_path, stale_after, age_provider, owner_alive_provider)) {
    stop("Download lock is already held: ", lock_path, call. = FALSE)
  }

  quarantine <- validate_lock_quarantine(quarantine_factory(lock_path), lock_path)
  if (!isTRUE(rename_lock_dir(lock_path, quarantine))) {
    if (isTRUE(create_lock_dir(lock_path))) {
      return(claim_created_lock(lock_path, token, owner_writer, remove_lock_dir))
    }
    stop("Download lock is already held: ", lock_path, call. = FALSE)
  }

  if (!isTRUE(create_lock_dir(lock_path))) {
    remove_lock_dir(quarantine)
    stop("Download lock is already held after stale reclaim: ", lock_path, call. = FALSE)
  }
  result <- tryCatch(
    claim_created_lock(lock_path, token, owner_writer, remove_lock_dir),
    error = identity
  )
  quarantine_removed <- isTRUE(remove_lock_dir(quarantine))
  if (inherits(result, "error")) stop(conditionMessage(result), call. = FALSE)
  if (!quarantine_removed) {
    remove_owned_lock_under_guard(lock_path, token, remove_lock_dir)
    if (!dir.exists(lock_path) && dir.exists(quarantine)) {
      rename_lock_dir(quarantine, lock_path)
    }
    stop("Could not remove stale download-lock quarantine", call. = FALSE)
  }
  result
}

release_download_lock <- function(
  lock_path,
  token,
  shlock_runner = safe_system2,
  guard_remove_file = unlink,
  remove_lock_dir = default_remove_lock_dir
) {
  lock_path <- validate_lock_path(lock_path)
  token <- validate_lock_token(token)
  if (!all(vapply(
    list(shlock_runner, guard_remove_file, remove_lock_dir),
    is.function,
    logical(1)
  ))) {
    stop("Download lock release dependencies must be functions", call. = FALSE)
  }
  if (!dir.exists(lock_path)) return(invisible(FALSE))
  guard <- acquire_reclaim_guard(lock_path, shlock_runner)
  on.exit(release_reclaim_guard(guard, guard_remove_file), add = TRUE)
  remove_owned_lock_under_guard(lock_path, token, remove_lock_dir)
  invisible(TRUE)
}

with_download_lock <- function(
  lock_path,
  code,
  token = paste(Sys.getpid(), format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"), sep = "-"),
  stale_after = 24 * 60 * 60,
  age_provider = default_lock_age,
  owner_alive_provider = default_lock_owner_alive
) {
  if (!is.function(code)) stop("Lock scope code must be a function", call. = FALSE)
  token <- acquire_download_lock(
    lock_path, token = token, stale_after = stale_after,
    age_provider = age_provider, owner_alive_provider = owner_alive_provider
  )
  on.exit(release_download_lock(lock_path, token), add = TRUE)
  code()
}
