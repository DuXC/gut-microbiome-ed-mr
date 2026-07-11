#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) {
  sub("^--file=", "", script_argument[[1L]])
} else {
  ""
}
script_path <- if (nzchar(script_file) && script_file != "-") {
  script_file
} else {
  file.path("scripts", "01_source_inventory.R")
}
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "catalog.R"))
source(file.path(project_root, "R", "provenance.R"))

USER_AGENT <- paste0(
  "Gut-ED-MR-source-inventory/1.0 ",
  "(metadata-only public research provenance)"
)
MAX_REQUESTS_PER_SECOND <- 6
REQUEST_TIMEOUT_SECONDS <- 20
MAX_TRIES <- 3L
DATASET_ORDER <- c(
  "microbiome_2026", "microbiome_2026_hunt", "ed_2025", "finngen_r12",
  "ld_reference_1kg"
)

messagef <- function(...) message(sprintf(...))

metadata_request <- function(url, method = "GET") {
  httr2::request(url) |>
    httr2::req_method(method) |>
    httr2::req_user_agent(USER_AGENT) |>
    httr2::req_headers(Accept = "application/json, text/plain, text/html, */*") |>
    httr2::req_timeout(REQUEST_TIMEOUT_SECONDS)
}

live_rate_state <- new.env(parent = emptyenv())
live_rate_state$last_started <- -Inf

perform_metadata_live <- function(
  urls,
  method,
  labels,
  transform,
  allow_not_found = FALSE
) {
  perform_metadata(
    urls, method, labels, transform,
    allow_not_found = allow_not_found,
    performer = httr2::req_perform,
    sleeper = Sys.sleep,
    clock = function() unname(proc.time()[["elapsed"]]),
    jitter = function() stats::runif(1L, 0, 0.25),
    status_of = httr2::resp_status,
    header_of = function(response, name, default = NULL) {
      httr2::resp_header(response, name, default = default)
    },
    max_starts_per_second = MAX_REQUESTS_PER_SECOND,
    max_tries = MAX_TRIES,
    request_builder = metadata_request,
    rate_state = live_rate_state,
    reporter = messagef
  )
}

perform_one <- function(url, method = "GET", label = url) {
  perform_metadata_live(
    url,
    method,
    label,
    transform = identity,
    allow_not_found = FALSE
  )[[1L]]
}

response_content_length <- function(response) {
  value <- httr2::resp_header(response, "content-length", default = NA_character_)
  if (is.na(value) || !nzchar(value)) return(NA_real_)
  if (!grepl("^[0-9]+$", value)) {
    stop("Invalid Content-Length response header: ", value, call. = FALSE)
  }
  as.numeric(value)
}

head_metadata <- function(response) {
  status <- httr2::resp_status(response)
  list(
    status = status,
    expected_bytes = if (status >= 200L && status < 300L) {
      response_content_length(response)
    } else {
      NA_real_
    }
  )
}

parse_bucket_accessions <- function(response) {
  document <- xml2::read_html(httr2::resp_body_string(response))
  hrefs <- rvest::html_attr(rvest::html_elements(document, "a"), "href")
  sub("/$", "", hrefs[grepl("^GCST[0-9]{8}/$", hrefs)])
}

constant_metadata <- function(rows, dataset, source_config, resolved_at_utc) {
  rows$dataset <- dataset
  rows$genome_build <- source_config$genome_build
  rows$license <- source_config$license
  rows$overlap_note <- source_config$overlap_note
  rows$cohort_membership <- encode_provenance_vector(
    source_config$cohort_membership
  )
  rows$known_overlap_datasets <- encode_provenance_vector(
    source_config$known_overlap_datasets
  )
  rows$replication_role <- source_config$replication_role
  rows$resolved_at_utc <- resolved_at_utc
  rows[, SOURCE_INVENTORY_REQUIRED_COLUMNS, drop = FALSE]
}

resolve_microbiome <- function(dataset, config, resolved_at_utc) {
  accessions <- expand_gwas_accessions(
    config$accessions$first,
    config$accessions$last
  )
  bucket_urls <- paste0(
    sub("/+$", "", config$catalog_root), "/",
    unique(vapply(accessions, gwas_bucket, character(1))), "/"
  )
  messagef(
    "Validating %d %s accessions in %d bucket listings",
    length(accessions), dataset, length(bucket_urls)
  )
  listed <- unlist(lapply(bucket_urls, function(url) {
    parse_bucket_accessions(perform_one(url, label = paste("GWAS bucket", url)))
  }), use.names = FALSE)
  counts <- table(factor(listed, levels = accessions))
  missing <- accessions[counts == 0L]
  duplicated <- accessions[counts > 1L]
  if (length(missing) || length(duplicated)) {
    stop(
      sprintf(
        "GWAS bucket completeness failed: missing=%s duplicate=%s",
        if (length(missing)) paste(missing, collapse = ",") else "none",
        if (length(duplicated)) paste(duplicated, collapse = ",") else "none"
      ),
      call. = FALSE
    )
  }

  accession_directories <- vapply(
    accessions,
    gwas_accession_dir,
    character(1),
    catalog_root = config$catalog_root
  )
  data_candidates <- unlist(lapply(accessions, function(accession) {
    c(paste0(accession, ".tsv.gz"), paste0(accession, ".tsv"))
  }), use.names = FALSE)
  data_candidate_urls <- paste0(rep(accession_directories, each = 2L), data_candidates)
  messagef(
    "HEAD-validating %d compressed/uncompressed GWAS data candidates",
    length(data_candidate_urls)
  )
  candidate_metadata <- perform_metadata_live(
    data_candidate_urls,
    "HEAD",
    data_candidates,
    transform = head_metadata,
    allow_not_found = TRUE
  )
  candidate_status <- matrix(
    vapply(candidate_metadata, `[[`, integer(1), "status"),
    ncol = 2L,
    byrow = TRUE
  )
  selected_data_names <- vapply(seq_along(accessions), function(index) {
    present <- data_candidates[(2L * index - 1L):(2L * index)][
      candidate_status[index, ] >= 200L & candidate_status[index, ] < 300L
    ]
    if (length(present) != 1L) {
      stop(
        sprintf(
          paste0(
            "Expected exactly one original summary-statistics file for %s; ",
            "%s=HTTP%d, %s=HTTP%d"
          ),
          accessions[[index]],
          data_candidates[[2L * index - 1L]], candidate_status[index, 1L],
          data_candidates[[2L * index]], candidate_status[index, 2L]
        ),
        call. = FALSE
      )
    }
    present
  }, character(1))
  selected_candidate_index <- match(selected_data_names, data_candidates)
  selected_data_bytes <- vapply(
    candidate_metadata[selected_candidate_index],
    `[[`,
    numeric(1),
    "expected_bytes"
  )

  metadata_names <- paste0(selected_data_names, "-meta.yaml")
  metadata_urls <- paste0(accession_directories, metadata_names)
  messagef("HEAD-validating %d exact matching GWAS metadata files", length(metadata_urls))
  metadata_head <- perform_metadata_live(
    metadata_urls,
    "HEAD",
    metadata_names,
    transform = head_metadata,
    allow_not_found = TRUE
  )
  metadata_status <- vapply(metadata_head, `[[`, integer(1), "status")
  missing_metadata <- which(metadata_status == 404L)
  if (length(missing_metadata)) {
    index <- missing_metadata[[1L]]
    stop(
      sprintf(
        "Exact matching metadata is absent for %s: %s returned HTTP 404",
        accessions[[index]], metadata_urls[[index]]
      ),
      call. = FALSE
    )
  }
  metadata_bytes <- vapply(metadata_head, `[[`, numeric(1), "expected_bytes")

  selected_pairs <- Map(function(data_name, metadata_name, accession) {
    select_gwas_original_files(c(data_name, metadata_name), accession)
  }, selected_data_names, metadata_names, accessions)
  file_names <- unlist(selected_pairs, use.names = FALSE)
  source_ids <- rep(accessions, each = 2L)
  directories <- rep(accession_directories, each = 2L)
  source_urls <- paste0(directories, file_names)
  expected_bytes <- unlist(Map(
    c,
    selected_data_bytes,
    metadata_bytes
  ), use.names = FALSE)
  if (length(expected_bytes) != length(source_urls)) {
    stop("GWAS HEAD metadata did not align with selected files", call. = FALSE)
  }
  missing_lengths <- sum(is.na(expected_bytes))
  if (missing_lengths) {
    messagef("  upstream omitted Content-Length for %d files; recording NA", missing_lengths)
  }

  messagef(
    "  selected originals: compressed=%d, uncompressed=%d",
    sum(grepl("\\.tsv\\.gz$", selected_data_names)),
    sum(grepl("\\.tsv$", selected_data_names))
  )

  md5_urls <- paste0(vapply(
    accessions,
    gwas_accession_dir,
    character(1),
    catalog_root = config$catalog_root
  ), "md5sum.txt")
  messagef("Resolving %d published GWAS checksum manifests", length(md5_urls))
  md5_text <- perform_metadata_live(
    md5_urls,
    "GET",
    accessions,
    transform = httr2::resp_body_string
  )
  checksums <- unlist(Map(function(text, accession, expected_files) {
    parse_md5_manifest(
      text,
      expected_files
    )
  }, md5_text, accessions, selected_pairs), use.names = FALSE)

  rows <- data.frame(
    dataset = dataset,
    source_id = source_ids,
    file_name = file_names,
    source_url = source_urls,
    expected_bytes = expected_bytes,
    ancestry = config$ancestry,
    genome_build = config$genome_build,
    license = config$license,
    overlap_note = config$overlap_note,
    cohort_membership = encode_provenance_vector(config$cohort_membership),
    known_overlap_datasets = encode_provenance_vector(
      config$known_overlap_datasets
    ),
    replication_role = config$replication_role,
    resolved_at_utc = resolved_at_utc,
    checksum_algorithm = "md5",
    expected_checksum = checksums,
    stringsAsFactors = FALSE
  )
  rows[, SOURCE_INVENTORY_REQUIRED_COLUMNS, drop = FALSE]
}

resolve_figshare <- function(config, resolved_at_utc) {
  messagef("Resolving Figshare article metadata: %s", config$api)
  response <- perform_one(config$api, label = "Figshare article 30505799")
  article <- httr2::resp_body_json(response, simplifyVector = FALSE)
  configured_id <- as.character(config$article_id)
  api_id <- sub(".*/", "", sub("/+$", "", config$api))
  if (!identical(as.character(article$id), configured_id) ||
      !identical(api_id, configured_id)) {
    stop("Figshare API/article identity does not match configured article_id", call. = FALSE)
  }
  if (length(article$files) != 8L) {
    stop("Figshare article must contain exactly 8 current file records", call. = FALSE)
  }
  if (is.null(article$license$name) || !identical(article$license$name, "CC BY 4.0")) {
    stop("Figshare article license metadata is not CC BY 4.0", call. = FALSE)
  }
  rows <- parse_figshare_files(article)
  rows$ancestry <- classify_ed_ancestry(
    rows$file_name,
    config$ancestry_file_patterns
  )
  checksums <- vapply(article$files, function(file) {
    supplied <- tolower(as.character(file$supplied_md5))
    computed <- tolower(as.character(file$computed_md5))
    if (!grepl("^[a-f0-9]{32}$", supplied) || !identical(supplied, computed)) {
      stop("Figshare supplied/computed MD5 metadata is absent or inconsistent", call. = FALSE)
    }
    supplied
  }, character(1))
  rows$checksum_algorithm <- "md5"
  rows$expected_checksum <- checksums
  constant_metadata(rows, "ed_2025", config, resolved_at_utc)
}

resolve_finngen <- function(config, resolved_at_utc) {
  messagef("Resolving FinnGen R12 manifest metadata: %s", config$manifest)
  response <- perform_one(config$manifest, label = "FinnGen R12 manifest")
  manifest <- data.table::fread(
    text = httr2::resp_body_string(response),
    sep = "\t",
    header = TRUE,
    data.table = FALSE,
    check.names = FALSE,
    showProgress = FALSE
  )
  matched <- extract_finngen_manifest_rows(manifest, config$phenotype_regex)
  if (nrow(matched) != 1L) {
    stop(
      "FinnGen phenotype regex must resolve exactly one unique manifest row; found ",
      nrow(matched),
      call. = FALSE
    )
  }
  file_name <- basename(matched$path_https)
  head <- perform_metadata_live(
    matched$path_https,
    "HEAD",
    file_name,
    transform = function(response) {
      parse_finngen_head_metadata(as.list(httr2::resp_headers(response)))
    }
  )[[1L]]
  if (!identical(head$expected_bytes, 809561836) ||
      !identical(head$expected_checksum, "cdb92e57e4c62d4336be808ce8b423e2")) {
    stop("FinnGen HEAD metadata differs from the approved R12 ED object", call. = FALSE)
  }
  rows <- data.frame(
    source_id = sub("\\.gz$", "", file_name),
    file_name = file_name,
    source_url = matched$path_https,
    expected_bytes = head$expected_bytes,
    ancestry = config$ancestry,
    checksum_algorithm = head$checksum_algorithm,
    expected_checksum = head$expected_checksum,
    stringsAsFactors = FALSE
  )
  constant_metadata(rows, "finngen_r12", config, resolved_at_utc)
}

resolve_zenodo <- function(config, resolved_at_utc) {
  record_id <- zenodo_record_id(config$record)
  api <- paste0("https://zenodo.org/api/records/", record_id)
  messagef("Resolving Zenodo record metadata: %s", api)
  response <- perform_one(api, label = paste("Zenodo record", record_id))
  record <- httr2::resp_body_json(response, simplifyVector = FALSE)
  if (!identical(as.character(record$id), record_id) ||
      !identical(as.character(record$doi), paste0("10.5281/zenodo.", record_id))) {
    stop("Zenodo API/DOI identity does not match configured record", call. = FALSE)
  }
  rows <- parse_zenodo_plink_files(
    record,
    config$ancestry_files,
    expected_record_id = record_id
  )
  constant_metadata(rows, "ld_reference_1kg", config, resolved_at_utc)
}

validate_resolved_contract <- function(inventory, config) {
  validate_source_inventory(inventory)
  validate_overlap_symmetry(inventory)
  expected_counts <- c(
    microbiome_2026 = as.integer(2L * length(expand_gwas_accessions(
      config$microbiome_2026$accessions$first,
      config$microbiome_2026$accessions$last
    ))),
    microbiome_2026_hunt = as.integer(2L * length(expand_gwas_accessions(
      config$microbiome_2026_hunt$accessions$first,
      config$microbiome_2026_hunt$accessions$last
    ))),
    ed_2025 = 8L,
    finngen_r12 = 1L,
    ld_reference_1kg = 6L
  )
  counts <- table(factor(inventory$dataset, levels = names(expected_counts)))
  if (!identical(unname(as.integer(counts)), unname(expected_counts))) {
    stop(
      "Resolved dataset row counts differ from contract: ",
      paste(names(counts), counts, sep = "=", collapse = ", "),
      call. = FALSE
    )
  }
  expected_ancestry <- list(
    microbiome_2026 = "EUR",
    microbiome_2026_hunt = "EUR",
    ed_2025 = c("EUR", "AFR", "cross_ancestry"),
    finngen_r12 = "Finnish",
    ld_reference_1kg = c("EUR", "AFR")
  )
  for (dataset in names(expected_counts)) {
    rows <- inventory[inventory$dataset == dataset, , drop = FALSE]
    if (!identical(unique(rows$genome_build), config[[dataset]]$genome_build)) {
      stop("Resolved genome build differs from config for ", dataset, call. = FALSE)
    }
    if (!setequal(unique(rows$ancestry), expected_ancestry[[dataset]])) {
      stop("Resolved ancestries differ from contract for ", dataset, call. = FALSE)
    }
    expected_structured <- c(
      cohort_membership = encode_provenance_vector(
        config[[dataset]]$cohort_membership
      ),
      known_overlap_datasets = encode_provenance_vector(
        config[[dataset]]$known_overlap_datasets
      ),
      replication_role = config[[dataset]]$replication_role
    )
    if (!all(rows$license == config[[dataset]]$license) ||
        !all(rows$overlap_note == config[[dataset]]$overlap_note) ||
        any(vapply(names(expected_structured), function(field) {
          !all(rows[[field]] == expected_structured[[field]])
        }, logical(1)))) {
      stop("Resolved source metadata changed for ", dataset, call. = FALSE)
    }
  }
  invisible(inventory)
}

main <- function() {
  config <- read_source_config(file.path(project_root, "config", "data_sources.yml"))
  resolved_at_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  inventory <- do.call(rbind, list(
    resolve_microbiome(
      "microbiome_2026", config$microbiome_2026, resolved_at_utc
    ),
    resolve_microbiome(
      "microbiome_2026_hunt", config$microbiome_2026_hunt,
      resolved_at_utc
    ),
    resolve_figshare(config$ed_2025, resolved_at_utc),
    resolve_finngen(config$finngen_r12, resolved_at_utc),
    resolve_zenodo(config$ld_reference_1kg, resolved_at_utc)
  ))
  rownames(inventory) <- NULL
  validate_resolved_contract(inventory, config)

  output_path <- file.path(project_root, "00_admin", "source_inventory.csv")
  written <- write_source_inventory_atomic(inventory, output_path, DATASET_ORDER)

  counts <- table(factor(written$dataset, levels = DATASET_ORDER))
  message("Source inventory written atomically: ", output_path)
  message("Dataset rows: ", paste(names(counts), counts, sep = "=", collapse = ", "))
  messagef(
    "Published size metadata: %.0f bytes across %d known rows; %d unknown rows",
    sum(written$expected_bytes, na.rm = TRUE),
    sum(!is.na(written$expected_bytes)),
    sum(is.na(written$expected_bytes))
  )
}

if (sys.nframe() == 0L) main()
