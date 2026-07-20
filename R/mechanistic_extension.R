MECHANISTIC_MEDIATOR_COLUMNS <- c(
  "mediator_id", "mediator_name", "family", "source_dataset", "source_id",
  "source_file", "analysis_tier", "download_wave", "instrument_policy",
  "outcome_overlap_class", "status"
)

MECHANISTIC_EXPOSURE_COLUMNS <- c(
  "exposure_id", "source_dataset", "source_id", "module_id", "trait",
  "pathway_family", "clumped_primary_instruments", "instrument_tier",
  "analysis_role", "replication_status"
)

MECHANISTIC_OVERLAP_COLUMNS <- c(
  "dataset_a", "dataset_b", "overlap_class", "analysis_action",
  "evidence_note"
)

MECHANISTIC_FAMILY_DENOMINATORS <- c(
  x_to_y = 5L,
  cytokine_m_to_y = 40L,
  endothelial_m_to_y = 9L,
  cytokine_x_to_m = 200L,
  endothelial_x_to_m = 45L,
  cytokine_indirect = 200L,
  endothelial_indirect = 45L
)

mechanistic_error <- function(detail) {
  stop("Invalid mechanistic extension: ", detail, call. = FALSE)
}

read_mechanistic_csv <- function(path, expected_columns) {
  if (!file.exists(path)) mechanistic_error(paste("missing file", path))
  value <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE,
    colClasses = "character"
  )
  if (!identical(names(value), expected_columns)) {
    mechanistic_error(paste("unexpected columns in", path))
  }
  if (!nrow(value) || anyNA(value) || any(!nzchar(trimws(as.matrix(value))))) {
    mechanistic_error(paste("blank or missing values in", path))
  }
  value
}

validate_mechanistic_config <- function(config) {
  if (!is.list(config) || is.null(names(config))) {
    mechanistic_error("configuration root must be a mapping")
  }
  required <- c(
    "version", "frozen_on", "parent_release", "selection_rule",
    "outcome_p_values_used_for_selection", "exposure_family",
    "mediator_families", "multiple_testing", "mediator_instruments",
    "colocalization", "indirect_effect", "sources", "download"
  )
  if (!all(required %in% names(config))) {
    mechanistic_error("configuration is missing required sections")
  }
  if (!identical(config$version, "v0.2") ||
      !identical(as.character(config$frozen_on), "2026-07-21") ||
      !identical(config$parent_release, "v0.1.0")) {
    mechanistic_error("version, freeze date, or parent release drifted")
  }
  if (!identical(config$outcome_p_values_used_for_selection, FALSE)) {
    mechanistic_error("outcome P values must not select hypotheses")
  }
  if (!identical(as.integer(config$exposure_family$count), 5L)) {
    mechanistic_error("exposure family count must equal 5")
  }
  observed <- unlist(config$multiple_testing$denominators, use.names = TRUE)
  observed <- as.integer(observed[names(MECHANISTIC_FAMILY_DENOMINATORS)])
  names(observed) <- names(MECHANISTIC_FAMILY_DENOMINATORS)
  if (!identical(observed, MECHANISTIC_FAMILY_DENOMINATORS)) {
    mechanistic_error("frozen family denominators drifted")
  }
  if (!identical(config$multiple_testing$method, "BH") ||
      !identical(as.numeric(config$multiple_testing$fdr), 0.05)) {
    mechanistic_error("BH FDR must remain 5%")
  }
  if (!identical(as.numeric(config$colocalization$pp4_support), 0.80)) {
    mechanistic_error("colocalization PP4 threshold must remain 0.80")
  }
  config
}

read_mechanistic_config <- function(path) {
  if (!file.exists(path)) mechanistic_error(paste("missing config", path))
  config <- yaml::read_yaml(
    path, handlers = list(int = function(value) as.numeric(value))
  )
  validate_mechanistic_config(config)
}

validate_mechanistic_mediators <- function(registry, config) {
  if (!is.data.frame(registry) ||
      !identical(names(registry), MECHANISTIC_MEDIATOR_COLUMNS)) {
    mechanistic_error("mediator registry schema mismatch")
  }
  if (nrow(registry) != 49L || anyDuplicated(registry$mediator_id) ||
      anyDuplicated(paste(registry$source_dataset, registry$source_id))) {
    mechanistic_error("mediator registry must contain 49 unique sources")
  }
  counts <- table(registry$family)
  if (!identical(
      as.integer(counts[c("cytokine", "endothelial")]), c(40L, 9L)
    )) {
    mechanistic_error("mediator family counts must be 40 and 9")
  }
  wave <- suppressWarnings(as.integer(registry$download_wave))
  if (anyNA(wave) || any(wave != 1L)) {
    mechanistic_error("all current registry rows must be download wave 1")
  }
  cytokines <- registry[registry$family == "cytokine", , drop = FALSE]
  expected_accessions <- sprintf("GCST%08d", 90428399:90428438)
  if (!identical(cytokines$source_id, expected_accessions)) {
    mechanistic_error("cytokine accession range or order drifted")
  }
  expected_files <- paste0(expected_accessions, ".h.tsv.gz")
  if (!identical(cytokines$source_file, expected_files)) {
    mechanistic_error("cytokine harmonized filenames drifted")
  }
  if (!all(registry$source_dataset %in%
      c("cytokines_2025_meta", "scallop_cvd1"))) {
    mechanistic_error("unapproved mediator source dataset")
  }
  invisible(registry)
}

read_mechanistic_mediators <- function(path, config) {
  registry <- read_mechanistic_csv(path, MECHANISTIC_MEDIATOR_COLUMNS)
  validate_mechanistic_mediators(registry, config)
  registry$download_wave <- as.integer(registry$download_wave)
  registry
}

validate_mechanistic_exposures <- function(exposures) {
  if (!is.data.frame(exposures) ||
      !identical(names(exposures), MECHANISTIC_EXPOSURE_COLUMNS)) {
    mechanistic_error("exposure registry schema mismatch")
  }
  expected_sources <- c(
    "GCST90667140", "GCST90667145", "GCST90667169", "GCST90667437",
    "GCST90667452"
  )
  expected_modules <- c("M00080", "M00091", "M00136", "M00530", "M00569")
  instruments <- suppressWarnings(as.integer(exposures$clumped_primary_instruments))
  if (nrow(exposures) != 5L || anyDuplicated(exposures$exposure_id) ||
      !identical(exposures$source_id, expected_sources) ||
      !identical(exposures$module_id, expected_modules) ||
      anyNA(instruments) || any(instruments != 1L) ||
      any(exposures$source_dataset != "microbiome_2026_hunt") ||
      any(exposures$instrument_tier != "primary")) {
    mechanistic_error("five-exposure freeze drifted")
  }
  invisible(exposures)
}

read_mechanistic_exposures <- function(path) {
  exposures <- read_mechanistic_csv(path, MECHANISTIC_EXPOSURE_COLUMNS)
  validate_mechanistic_exposures(exposures)
  exposures$clumped_primary_instruments <- as.integer(
    exposures$clumped_primary_instruments
  )
  exposures
}

validate_mechanistic_overlap <- function(overlap) {
  if (!is.data.frame(overlap) ||
      !identical(names(overlap), MECHANISTIC_OVERLAP_COLUMNS)) {
    mechanistic_error("sample-overlap schema mismatch")
  }
  allowed <- c("none_known", "possible_unresolved", "known_partial")
  if (any(!overlap$overlap_class %in% allowed) ||
      anyDuplicated(paste(overlap$dataset_a, overlap$dataset_b))) {
    mechanistic_error("invalid or duplicated overlap classification")
  }
  required_pair <- overlap$dataset_a == "cytokines_2025_meta" &
    overlap$dataset_b == "finngen_r12"
  if (sum(required_pair) != 1L ||
      overlap$overlap_class[required_pair] != "known_partial") {
    mechanistic_error("cytokine meta--FinnGen overlap must remain known partial")
  }
  invisible(overlap)
}

read_mechanistic_overlap <- function(path) {
  overlap <- read_mechanistic_csv(path, MECHANISTIC_OVERLAP_COLUMNS)
  validate_mechanistic_overlap(overlap)
  overlap
}

gwas_catalog_block <- function(accession) {
  if (length(accession) != 1L ||
      !grepl("^GCST[0-9]{8}$", accession)) {
    mechanistic_error("GWAS accession must match GCST plus eight digits")
  }
  number <- as.numeric(sub("^GCST", "", accession))
  first <- floor((number - 1) / 1000) * 1000 + 1
  last <- first + 999
  sprintf("GCST%08d-GCST%08d", first, last)
}

gwas_harmonised_urls <- function(accession, catalog_root) {
  base <- paste(
    sub("/$", "", catalog_root), gwas_catalog_block(accession), accession,
    "harmonised", sep = "/"
  )
  file <- paste0(accession, ".h.tsv.gz")
  list(
    data = paste(base, file, sep = "/"),
    metadata = paste0(paste(base, file, sep = "/"), "-meta.yaml")
  )
}

mechanistic_request <- function(url, method = "GET", max_tries = 5L) {
  if (!is.character(url) || length(url) != 1L ||
      !grepl("^https://", url)) {
    mechanistic_error("remote URL must use HTTPS")
  }
  error <- NULL
  for (attempt in seq_len(max_tries)) {
    response <- tryCatch({
      request <- httr2::request(url) |>
        httr2::req_user_agent("gut-ed-mechanistic-extension/0.2") |>
        httr2::req_timeout(90)
      if (method == "HEAD") request <- httr2::req_method(request, "HEAD")
      httr2::req_perform(request)
    }, error = identity)
    if (!inherits(response, "error") && httr2::resp_status(response) == 200L) {
      return(response)
    }
    error <- if (inherits(response, "error")) {
      conditionMessage(response)
    } else {
      paste("HTTP", httr2::resp_status(response))
    }
    if (attempt < max_tries) Sys.sleep(min(2^(attempt - 1L), 8))
  }
  stop("Remote request failed for ", url, ": ", error, call. = FALSE)
}

remote_content_length <- function(response, url) {
  value <- httr2::resp_header(response, "content-length")
  bytes <- suppressWarnings(as.numeric(value))
  if (length(bytes) != 1L || is.na(bytes) || !is.finite(bytes) || bytes <= 0) {
    stop("Remote content length is invalid for ", url, call. = FALSE)
  }
  bytes
}

resolve_cytokine_source <- function(row, config) {
  urls <- gwas_harmonised_urls(
    row$source_id[[1L]], config$sources$cytokines_2025_meta$catalog_root
  )
  metadata_response <- mechanistic_request(urls$metadata)
  metadata_text <- httr2::resp_body_string(metadata_response)
  metadata <- yaml::yaml.load(metadata_text)
  if (!identical(metadata$gwas_id, row$source_id[[1L]]) ||
      !identical(metadata$data_file_name, row$source_file[[1L]]) ||
      !identical(metadata$is_harmonised, TRUE) ||
      !identical(metadata$genome_assembly, "GRCh38") ||
      !grepl("^[a-f0-9]{32}$", metadata$data_file_md5sum)) {
    stop("GWAS Catalog metadata mismatch for ", row$source_id[[1L]], call. = FALSE)
  }
  data_response <- mechanistic_request(urls$data, method = "HEAD")
  sample_size <- metadata$samples[[1L]]$sample_size
  trait <- unlist(metadata$trait_description, use.names = FALSE)[[1L]]
  list(
    inventory = data.frame(
      dataset = "cytokines_2025_meta",
      source_id = row$source_id[[1L]],
      file_name = row$source_file[[1L]],
      source_url = urls$data,
      expected_bytes = remote_content_length(data_response, urls$data),
      ancestry = "EUR",
      genome_build = "GRCh38",
      license = "GWAS Catalog CC0",
      overlap_note = paste0(
        "Known partial overlap with FinnGen through legacy FINRISK; ",
        "screening/sensitivity only"
      ),
      cohort_membership = "YFS_FINRISK;SCALLOP;deCODE",
      known_overlap_datasets = "",
      replication_role =
        "mechanistic_mediator_screen_known_partial_overlap",
      resolved_at_utc = "",
      checksum_algorithm = "md5",
      expected_checksum = metadata$data_file_md5sum,
      stringsAsFactors = FALSE
    ),
    metadata = data.frame(
      source_dataset = "cytokines_2025_meta",
      source_id = row$source_id[[1L]],
      registry_name = row$mediator_name[[1L]],
      remote_trait = trait,
      sample_size = as.numeric(sample_size),
      genome_build = metadata$genome_assembly,
      remote_data_url = urls$data,
      remote_metadata_url = urls$metadata,
      http_status = httr2::resp_status(data_response),
      stringsAsFactors = FALSE
    )
  )
}

resolve_scallop_sources <- function(rows, config) {
  response <- mechanistic_request(config$sources$scallop_cvd1$api)
  record <- httr2::resp_body_json(response, simplifyVector = FALSE)
  files <- record$files
  by_name <- stats::setNames(files, vapply(files, `[[`, character(1), "key"))
  resolved <- lapply(seq_len(nrow(rows)), function(index) {
    row <- rows[index, , drop = FALSE]
    file <- by_name[[row$source_file[[1L]]]]
    if (is.null(file) || !grepl("^md5:[a-f0-9]{32}$", file$checksum)) {
      stop("Zenodo file metadata missing for ", row$source_file[[1L]], call. = FALSE)
    }
    url <- file$links$self
    head <- mechanistic_request(url, method = "HEAD")
    bytes <- suppressWarnings(as.numeric(file$size))
    if (length(bytes) != 1L || is.na(bytes) || !is.finite(bytes) ||
        bytes <= 0 || bytes != floor(bytes)) {
      stop("Zenodo API file size is invalid for ", row$source_file[[1L]],
        call. = FALSE)
    }
    header_bytes <- suppressWarnings(as.numeric(
      httr2::resp_header(head, "content-length")
    ))
    if (length(header_bytes) == 1L && !is.na(header_bytes) &&
        is.finite(header_bytes) && !identical(bytes, header_bytes)) {
      stop("Zenodo content length mismatch for ", row$source_file[[1L]], call. = FALSE)
    }
    list(
      inventory = data.frame(
        dataset = "scallop_cvd1",
        source_id = row$source_id[[1L]],
        file_name = row$source_file[[1L]],
        source_url = url,
        expected_bytes = bytes,
        ancestry = "EUR",
        genome_build = "GRCh37",
        license = "CC BY 2.0",
        overlap_note = paste0(
          "SCALLOP cohort overlap with HUNT and FinnGen remains ",
          "possible/unresolved"
        ),
        cohort_membership = "SCALLOP_CVD_I_13_cohorts",
        known_overlap_datasets = "",
        replication_role = "mechanistic_endothelial_mediator_screen",
        resolved_at_utc = "",
        checksum_algorithm = "md5",
        expected_checksum = sub("^md5:", "", file$checksum),
        stringsAsFactors = FALSE
      ),
      metadata = data.frame(
        source_dataset = "scallop_cvd1",
        source_id = row$source_id[[1L]],
        registry_name = row$mediator_name[[1L]],
        remote_trait = row$source_id[[1L]],
        sample_size = 30931,
        genome_build = "GRCh37",
        remote_data_url = url,
        remote_metadata_url = config$sources$scallop_cvd1$api,
        http_status = httr2::resp_status(head),
        stringsAsFactors = FALSE
      )
    )
  })
  list(
    inventory = do.call(rbind, lapply(resolved, `[[`, "inventory")),
    metadata = do.call(rbind, lapply(resolved, `[[`, "metadata"))
  )
}

resolve_mechanistic_sources <- function(registry, config, clock = Sys.time) {
  validate_mechanistic_mediators(registry, config)
  cytokines <- registry[registry$source_dataset == "cytokines_2025_meta", ,
    drop = FALSE]
  cytokine_resolved <- lapply(seq_len(nrow(cytokines)), function(index) {
    result <- resolve_cytokine_source(cytokines[index, , drop = FALSE], config)
    Sys.sleep(0.10)
    result
  })
  scallop <- resolve_scallop_sources(
    registry[registry$source_dataset == "scallop_cvd1", , drop = FALSE],
    config
  )
  inventory <- rbind(
    do.call(rbind, lapply(cytokine_resolved, `[[`, "inventory")),
    scallop$inventory
  )
  metadata <- rbind(
    do.call(rbind, lapply(cytokine_resolved, `[[`, "metadata")),
    scallop$metadata
  )
  resolved_at <- format(clock(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  inventory$resolved_at_utc <- resolved_at
  rownames(inventory) <- NULL
  rownames(metadata) <- NULL
  list(inventory = inventory, metadata = metadata)
}

write_csv_atomic <- function(value, path) {
  directory <- dirname(path)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile(".mechanistic-", tmpdir = directory, fileext = ".csv")
  on.exit(unlink(temporary), add = TRUE)
  utils::write.csv(value, temporary, row.names = FALSE, na = "")
  if (!file.rename(temporary, path)) {
    stop("Atomic CSV replacement failed: ", path, call. = FALSE)
  }
  invisible(value)
}
