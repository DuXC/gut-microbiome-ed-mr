GWAS_CATALOG_ROOT <- paste0(
  "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics"
)

validate_gwas_accession <- function(accession) {
  if (!is.character(accession) || length(accession) != 1L ||
      is.na(accession) || !grepl("^GCST[0-9]{8}$", accession)) {
    stop("GWAS accession must be GCST followed by 8 digits", call. = FALSE)
  }
  accession
}

gwas_accession_number <- function(accession) {
  accession <- validate_gwas_accession(accession)
  as.numeric(sub("^GCST", "", accession))
}

format_gwas_accession <- function(number) {
  if (!is.numeric(number) || length(number) != 1L || is.na(number) ||
      !is.finite(number) || number != floor(number) ||
      number < 0 || number > 99999999) {
    stop("GWAS accession number must be an integer from 0 to 99999999", call. = FALSE)
  }
  sprintf("GCST%08.0f", number)
}

expand_gwas_accessions <- function(first, last) {
  first_number <- gwas_accession_number(first)
  last_number <- gwas_accession_number(last)
  if (first_number > last_number) {
    stop("First GWAS accession must not exceed last accession", call. = FALSE)
  }
  vapply(
    seq.int(first_number, last_number),
    format_gwas_accession,
    character(1)
  )
}

gwas_bucket <- function(accession) {
  number <- gwas_accession_number(accession)
  first <- floor((number - 1) / 1000) * 1000 + 1
  paste(format_gwas_accession(first), format_gwas_accession(first + 999), sep = "-")
}

gwas_accession_dir <- function(accession, catalog_root = GWAS_CATALOG_ROOT) {
  accession <- validate_gwas_accession(accession)
  if (!is.character(catalog_root) || length(catalog_root) != 1L ||
      is.na(catalog_root) || !grepl("^https://", catalog_root)) {
    stop("GWAS catalog root must be one HTTPS URL", call. = FALSE)
  }
  paste0(sub("/+$", "", catalog_root), "/", gwas_bucket(accession), "/", accession, "/")
}

select_gwas_original_files <- function(file_names, accession) {
  accession <- validate_gwas_accession(accession)
  if (!is.character(file_names) || anyNA(file_names)) {
    stop("GWAS directory file names must be character values", call. = FALSE)
  }
  data_candidates <- c(
    paste0(accession, ".tsv.gz"),
    paste0(accession, ".tsv")
  )
  metadata_candidates <- paste0(data_candidates, "-meta.yaml")
  allowed <- c(data_candidates, metadata_candidates)
  unexpected_data <- grepl(
    "\\.tsv(?:\\.gz)?(?:-meta\\.yaml)?$",
    file_names,
    perl = TRUE
  ) & !file_names %in% allowed
  if (any(unexpected_data)) {
    stop(
      "Found unexpected GWAS data-like file: ",
      paste(file_names[unexpected_data], collapse = ", "),
      call. = FALSE
    )
  }
  data_hits <- file_names[file_names %in% data_candidates]
  if (length(data_hits) != 1L) {
    stop(
      "Expected exactly one original summary-statistics file for ",
      accession,
      call. = FALSE
    )
  }
  matching_metadata <- paste0(data_hits, "-meta.yaml")
  metadata_hits <- file_names[file_names %in% metadata_candidates]
  if (length(metadata_hits) != 1L ||
      !identical(metadata_hits, matching_metadata)) {
    stop(
      "Expected exactly one exact matching metadata YAML for ",
      accession,
      call. = FALSE
    )
  }
  c(data_hits, matching_metadata)
}

parse_figshare_files <- function(article) {
  files <- article$files
  if (!is.list(files) || !length(files)) {
    stop("Figshare article metadata must contain file records", call. = FALSE)
  }
  required <- c("id", "name", "download_url", "size")
  rows <- lapply(files, function(file) {
    missing <- required[vapply(required, function(key) is.null(file[[key]]), logical(1))]
    if (length(missing)) {
      stop(
        "Figshare file record is missing: ", paste(missing, collapse = ", "),
        call. = FALSE
      )
    }
    data.frame(
      source_id = as.character(file$id),
      file_name = as.character(file$name),
      source_url = as.character(file$download_url),
      expected_bytes = as.numeric(file$size),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

classify_ed_ancestry <- function(
  file_names,
  ancestry_file_patterns,
  allowed_keys = c("EUR", "AFR", "cross_ancestry")
) {
  if (!is.character(file_names) || anyNA(file_names) || !length(file_names)) {
    stop("ED file names must be non-missing character values", call. = FALSE)
  }
  if (!is.list(ancestry_file_patterns) || is.null(names(ancestry_file_patterns)) ||
      !identical(sort(names(ancestry_file_patterns)), sort(allowed_keys))) {
    stop("Found missing or unknown ancestry pattern keys", call. = FALSE)
  }
  if (any(!vapply(
    ancestry_file_patterns,
    function(pattern) is.character(pattern) && length(pattern) == 1L &&
      !is.na(pattern) && nzchar(pattern),
    logical(1)
  ))) {
    stop("Every ancestry file pattern must be one non-empty string", call. = FALSE)
  }

  unname(vapply(file_names, function(file_name) {
    hits <- names(ancestry_file_patterns)[vapply(
      ancestry_file_patterns,
      grepl,
      logical(1),
      x = file_name,
      perl = TRUE
    )]
    if (!length(hits)) {
      stop("ED file ancestry pattern produced zero matches: ", file_name, call. = FALSE)
    }
    if (length(hits) > 1L) {
      stop("ED file ancestry pattern produced multiple matches: ", file_name, call. = FALSE)
    }
    hits
  }, character(1)))
}

extract_finngen_manifest_rows <- function(manifest, phenotype_regex) {
  if (!is.data.frame(manifest)) {
    stop("FinnGen manifest must be a data frame", call. = FALSE)
  }
  required <- c("phenocode", "path_https")
  missing <- setdiff(required, names(manifest))
  if (length(missing)) {
    stop("FinnGen manifest is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (!is.character(phenotype_regex) || length(phenotype_regex) != 1L ||
      is.na(phenotype_regex) || !nzchar(phenotype_regex)) {
    stop("FinnGen phenotype regex must be one non-empty string", call. = FALSE)
  }
  matched <- manifest[grepl(phenotype_regex, manifest$phenocode, perl = TRUE), , drop = FALSE]
  if (!nrow(matched)) {
    stop("Found no FinnGen manifest rows matching configured phenotype regex", call. = FALSE)
  }
  identity <- paste(matched$phenocode, matched$path_https, sep = "\r")
  if (anyDuplicated(identity)) {
    stop("Found duplicate FinnGen source identities", call. = FALSE)
  }
  rownames(matched) <- NULL
  matched
}

split_published_checksum <- function(checksum) {
  if (!is.character(checksum) || length(checksum) != 1L || is.na(checksum) ||
      !grepl("^[A-Za-z0-9_-]+:[A-Fa-f0-9]+$", checksum)) {
    stop("Published checksum must use algorithm:hex format", call. = FALSE)
  }
  pieces <- strsplit(checksum, ":", fixed = TRUE)[[1L]]
  c(algorithm = tolower(pieces[[1L]]), checksum = tolower(pieces[[2L]]))
}

parse_zenodo_plink_files <- function(
  record,
  ancestries,
  expected_record_id = 6614170
) {
  if (is.null(record$id) || !identical(as.character(record$id), as.character(expected_record_id))) {
    stop("Zenodo record identity does not match configured record", call. = FALSE)
  }
  if (!is.character(ancestries) || !length(ancestries) || anyNA(ancestries) ||
      anyDuplicated(ancestries)) {
    stop("Zenodo ancestries must be unique character values", call. = FALSE)
  }
  extensions <- c("bed", "bim", "fam")
  rows <- list()
  index <- 1L
  for (ancestry in ancestries) {
    for (extension in extensions) {
      expected_name <- paste0("1000G_", ancestry, ".", extension)
      hits <- Filter(function(file) identical(file$key, expected_name), record$files)
      if (length(hits) != 1L) {
        stop("Expected exactly one Zenodo file named ", expected_name, call. = FALSE)
      }
      file <- hits[[1L]]
      checksum <- split_published_checksum(file$checksum)
      rows[[index]] <- data.frame(
        source_id = as.character(file$id),
        file_name = expected_name,
        source_url = as.character(file$links$self),
        expected_bytes = as.numeric(file$size),
        ancestry = ancestry,
        checksum_algorithm = unname(checksum[["algorithm"]]),
        expected_checksum = unname(checksum[["checksum"]]),
        stringsAsFactors = FALSE
      )
      index <- index + 1L
    }
  }
  do.call(rbind, rows)
}

zenodo_record_id <- function(record_url) {
  if (!is.character(record_url) || length(record_url) != 1L ||
      is.na(record_url)) {
    stop("Zenodo DOI URL must be one string", call. = FALSE)
  }
  match <- regexec(
    "^https://doi\\.org/10\\.5281/zenodo\\.([0-9]+)$",
    record_url,
    perl = TRUE
  )
  parts <- regmatches(record_url, match)[[1L]]
  if (length(parts) != 2L) {
    stop("Zenodo DOI URL must identify a numeric Zenodo record", call. = FALSE)
  }
  parts[[2L]]
}

parse_md5_manifest <- function(text, expected_files) {
  if (!is.character(text) || length(text) != 1L || is.na(text)) {
    stop("MD5 manifest must be one text value", call. = FALSE)
  }
  lines <- strsplit(text, "\\r?\\n", perl = TRUE)[[1L]]
  lines <- lines[nzchar(lines)]
  matches <- regexec("^([A-Fa-f0-9]{32})[[:space:]]+[*]?(.+)$", lines, perl = TRUE)
  parts <- regmatches(lines, matches)
  if (any(lengths(parts) != 3L)) {
    stop("MD5 manifest contains an invalid line", call. = FALSE)
  }
  checksums <- setNames(
    vapply(parts, function(part) tolower(part[[2L]]), character(1)),
    vapply(parts, `[[`, character(1), 3L)
  )
  if (anyDuplicated(names(checksums))) {
    stop("MD5 manifest contains duplicate file names", call. = FALSE)
  }
  missing <- setdiff(expected_files, names(checksums))
  if (length(missing)) {
    stop("MD5 manifest is missing expected files: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  unname(checksums[expected_files])
}

is_transient_http_status <- function(status) {
  status %in% c(408L, 425L, 429L) | (status >= 500L & status <= 599L)
}

metadata_rate_delay <- function(last_started, now, max_per_second) {
  values <- c(last_started, now, max_per_second)
  if (!is.numeric(values) || anyNA(values) || any(!is.finite(values)) ||
      max_per_second <= 0) {
    stop("Metadata rate inputs must be finite and rate must be positive", call. = FALSE)
  }
  max(0, 1 / max_per_second - (now - last_started))
}

retry_after_seconds <- function(value, cap = 60) {
  if (is.null(value) || !length(value) || is.na(value[[1L]]) ||
      !grepl("^[0-9]+(?:\\.[0-9]+)?$", value[[1L]])) {
    return(NA_real_)
  }
  min(as.numeric(value[[1L]]), cap)
}

perform_metadata <- function(
  urls,
  method,
  labels,
  transform,
  allow_not_found = FALSE,
  performer,
  sleeper = Sys.sleep,
  clock = function() unname(proc.time()[["elapsed"]]),
  jitter = function() stats::runif(1L, 0, 0.25),
  status_of,
  header_of,
  max_starts_per_second = 6,
  max_tries = 3L,
  request_builder,
  rate_state = NULL,
  reporter = function(...) invisible(NULL)
) {
  if (!length(urls)) return(list())
  if (length(urls) != length(labels)) {
    stop("Metadata URLs and labels must align", call. = FALSE)
  }
  if (is.null(rate_state)) {
    rate_state <- new.env(parent = emptyenv())
    rate_state$last_started <- -Inf
  }
  responses <- vector("list", length(urls))
  for (index in seq_along(urls)) {
    succeeded <- FALSE
    failure_detail <- NA_character_
    for (attempt in seq_len(max_tries)) {
      now <- clock()
      if (is.finite(max_starts_per_second) &&
          is.finite(rate_state$last_started)) {
        sleeper(metadata_rate_delay(
          rate_state$last_started, now, max_starts_per_second
        ))
      }
      rate_state$last_started <- clock()
      result <- tryCatch(
        performer(request_builder(urls[[index]], method)),
        error = identity
      )
      response <- if (inherits(result, "error")) result$resp else result
      if (is.null(response)) {
        failure_detail <- if (inherits(result, "error")) {
          conditionMessage(result)
        } else {
          "request performer returned NULL"
        }
      } else {
        status <- status_of(response)
        if ((status >= 200L && status < 300L) ||
            (status == 404L && allow_not_found)) {
          responses[[index]] <- transform(response)
          succeeded <- TRUE
          break
        }
        if (!is_transient_http_status(status)) {
          stop(
            sprintf(
              "Metadata request returned HTTP %d for %s (%d/%d)",
              status, labels[[index]], index, length(urls)
            ),
            call. = FALSE
          )
        }
        failure_detail <- sprintf("HTTP %d", status)
      }
      if (attempt < max_tries) {
        retry_after <- if (is.null(response)) NA_real_ else {
          retry_after_seconds(header_of(response, "retry-after", NULL))
        }
        delay <- if (is.na(retry_after)) {
          min(60, 2^(attempt - 1L) + max(0, jitter()))
        } else {
          retry_after
        }
        reporter(
          "  retrying transient %s failure for %s (attempt %d/%d; %.2fs)",
          method, labels[[index]], attempt + 1L, max_tries, delay
        )
        sleeper(delay)
      }
    }
    if (!succeeded) {
      stop(
        sprintf(
          "Metadata request failed after %d attempts for %s (%d/%d): %s",
          max_tries, labels[[index]], index, length(urls), failure_detail
        ),
        call. = FALSE
      )
    }
    if (index %% 600L == 0L || index == length(urls)) {
      reporter("  resolved %d/%d %s metadata requests", index, length(urls), method)
    }
  }
  responses
}

header_list_value <- function(headers, name) {
  if (is.null(names(headers))) return(NULL)
  hit <- which(tolower(names(headers)) == tolower(name))
  if (!length(hit)) NULL else headers[[hit[[1L]]]]
}

parse_finngen_head_metadata <- function(headers) {
  length_value <- header_list_value(headers, "content-length")
  etag_value <- header_list_value(headers, "etag")
  hash_value <- header_list_value(headers, "x-goog-hash")
  if (is.null(length_value) || !grepl("^[0-9]+$", length_value)) {
    stop("FinnGen Content-Length header is missing or invalid", call. = FALSE)
  }
  if (is.null(etag_value) || is.null(hash_value)) {
    stop("FinnGen checksum headers are missing", call. = FALSE)
  }
  etag_md5 <- tolower(gsub('^"|"$', "", etag_value))
  if (length(etag_md5) != 1L || !grepl("^[a-f0-9]{32}$", etag_md5)) {
    stop("FinnGen ETag does not contain an MD5", call. = FALSE)
  }
  tokens <- trimws(unlist(strsplit(hash_value, ",", fixed = TRUE)))
  md5_token <- sub("^md5=", "", tokens[grepl("^md5=", tokens)])
  if (!any(grepl("^crc32c=", tokens)) || length(md5_token) > 1L) {
    stop("FinnGen x-goog-hash is missing CRC32C or has duplicate MD5", call. = FALSE)
  }
  if (length(md5_token) == 1L) {
    decoded <- jsonlite::base64_dec(md5_token)
    header_md5 <- paste(sprintf("%02x", as.integer(decoded)), collapse = "")
    if (!identical(header_md5, etag_md5)) {
      stop("FinnGen MD5 headers are inconsistent", call. = FALSE)
    }
  }
  list(
    expected_bytes = as.numeric(length_value),
    checksum_algorithm = "md5",
    expected_checksum = etag_md5
  )
}
