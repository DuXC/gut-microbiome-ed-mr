MECHANISTIC_CYTOKINE_EXTRACT_COLUMNS <- c(
  "mediator_id", "mediator_name", "source_dataset", "source_id",
  "source_file", "family", "request_role", "request_id", "rsid", "chr",
  "pos", "ea", "oa", "beta", "se", "eaf", "p", "build",
  "extraction_status"
)

MECHANISTIC_ENDOTHELIAL_EXTRACT_COLUMNS <- c(
  "mediator_id", "mediator_name", "source_dataset", "source_id",
  "source_file", "family", "request_role", "request_id", "marker_name",
  "reference_id", "chr", "pos", "ea", "oa", "beta", "se", "eaf", "p",
  "n", "F", "build", "extraction_status"
)

mechanistic_numeric <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

mechanistic_complement_allele <- function(x) {
  map <- c(A = "T", T = "A", C = "G", G = "C")
  unname(map[toupper(as.character(x))])
}

cytokine_target_requests <- function(mediator, exposure_freeze, cis_leads) {
  if (!is.data.frame(mediator) || nrow(mediator) != 1L ||
      mediator$family[[1L]] != "cytokine") {
    mechanistic_error("cytokine target request requires one cytokine row")
  }
  required_exposure <- c("exposure_id", "reference_id")
  if (!is.data.frame(exposure_freeze) || nrow(exposure_freeze) != 5L ||
      length(setdiff(required_exposure, names(exposure_freeze))) ||
      anyDuplicated(exposure_freeze$exposure_id) ||
      anyNA(exposure_freeze[required_exposure])) {
    mechanistic_error("cytokine target request exposure freeze drifted")
  }
  requests <- data.frame(
    request_role = "x_instrument_to_mediator",
    request_id = exposure_freeze$exposure_id,
    rsid = exposure_freeze$reference_id,
    stringsAsFactors = FALSE
  )
  cis <- cis_leads[
    cis_leads$mediator_id == mediator$mediator_id[[1L]], , drop = FALSE
  ]
  if (nrow(cis) > 1L) {
    mechanistic_error("cytokine has more than one frozen cis lead")
  }
  if (nrow(cis) == 1L) {
    requests <- rbind(
      requests,
      data.frame(
        request_role = "mediator_cis_instrument",
        request_id = mediator$mediator_id[[1L]],
        rsid = cis$lead_snp[[1L]],
        stringsAsFactors = FALSE
      )
    )
  }
  if (anyDuplicated(paste(requests$request_role, requests$request_id)) ||
      anyNA(requests) || any(!nzchar(as.matrix(requests)))) {
    mechanistic_error("cytokine target requests are invalid")
  }
  requests
}

normalize_cytokine_gwas_rows <- function(raw) {
  required <- c(
    "chromosome", "base_pair_location", "effect_allele", "other_allele",
    "beta", "standard_error", "effect_allele_frequency", "p_value", "rsid"
  )
  if (!is.data.frame(raw) || length(setdiff(required, names(raw)))) {
    mechanistic_error("cytokine harmonized GWAS schema mismatch")
  }
  result <- data.frame(
    rsid = as.character(raw$rsid),
    chr = toupper(as.character(raw$chromosome)),
    pos = mechanistic_numeric(raw$base_pair_location),
    ea = toupper(as.character(raw$effect_allele)),
    oa = toupper(as.character(raw$other_allele)),
    beta = mechanistic_numeric(raw$beta),
    se = mechanistic_numeric(raw$standard_error),
    eaf = mechanistic_numeric(raw$effect_allele_frequency),
    p = mechanistic_numeric(raw$p_value),
    build = "GRCh38",
    stringsAsFactors = FALSE
  )
  if (!nrow(result)) return(result)
  valid <- !is.na(result$rsid) & grepl("^rs[0-9]+$", result$rsid) &
    !is.na(result$chr) & result$chr %in% c(as.character(1:22), "X") &
    is.finite(result$pos) & result$pos > 0 &
    result$pos == floor(result$pos) &
    result$ea %in% c("A", "C", "G", "T") &
    result$oa %in% c("A", "C", "G", "T") & result$ea != result$oa &
    is.finite(result$beta) & is.finite(result$se) & result$se > 0 &
    is.finite(result$eaf) & result$eaf > 0 & result$eaf < 1 &
    is.finite(result$p) & result$p >= 0 & result$p <= 1
  if (!all(valid) || anyDuplicated(result$rsid)) {
    mechanistic_error("cytokine target rows contain invalid or duplicate data")
  }
  result
}

align_cytokine_target_requests <- function(
  requests, normalized, mediator, cis_leads
) {
  index <- match(requests$rsid, normalized$rsid)
  values <- normalized[index, , drop = FALSE]
  values$rsid <- requests$rsid
  status <- ifelse(is.na(index), "not_found_in_source", "matched")
  result <- data.frame(
    mediator_id = mediator$mediator_id[[1L]],
    mediator_name = mediator$mediator_name[[1L]],
    source_dataset = mediator$source_dataset[[1L]],
    source_id = mediator$source_id[[1L]],
    source_file = mediator$source_file[[1L]],
    family = mediator$family[[1L]],
    request_role = requests$request_role,
    request_id = requests$request_id,
    rsid = requests$rsid,
    chr = values$chr,
    pos = values$pos,
    ea = values$ea,
    oa = values$oa,
    beta = values$beta,
    se = values$se,
    eaf = values$eaf,
    p = values$p,
    build = ifelse(is.na(index), "GRCh38", values$build),
    extraction_status = status,
    stringsAsFactors = FALSE
  )
  result <- result[, MECHANISTIC_CYTOKINE_EXTRACT_COLUMNS, drop = FALSE]

  cis <- cis_leads[
    cis_leads$mediator_id == mediator$mediator_id[[1L]], , drop = FALSE
  ]
  if (nrow(cis) == 1L) {
    hit <- result$request_role == "mediator_cis_instrument"
    if (sum(hit) != 1L || result$extraction_status[hit] != "matched") {
      mechanistic_error("frozen cytokine cis lead is absent from source GWAS")
    }
    close_number <- function(observed, expected, tolerance = 1e-5) {
      abs(observed - expected) <= max(1e-12, tolerance * abs(expected))
    }
    if (result$ea[hit] != toupper(cis$effect_allele[[1L]]) ||
        result$oa[hit] != toupper(cis$other_allele[[1L]]) ||
        !close_number(result$beta[hit], cis$beta[[1L]]) ||
        !close_number(result$se[hit], cis$se[[1L]]) ||
        !close_number(result$p[hit], cis$p[[1L]])) {
      mechanistic_error("frozen cytokine cis lead differs from source GWAS")
    }
  }
  result
}

extract_mechanistic_target_rows <- function(
  input_path, target_ids, output_path,
  awk_script = "scripts/extract_outcome_ids.awk"
) {
  if (!exists("extract_outcome_rows", mode = "function")) {
    mechanistic_error("extract_outcome_rows must be loaded before extraction")
  }
  if (!is.character(target_ids) || !length(target_ids) || anyNA(target_ids) ||
      any(!grepl("^rs[0-9]+$", target_ids))) {
    mechanistic_error("target rsID set is invalid")
  }
  id_path <- tempfile("mechanistic-target-ids-", fileext = ".txt")
  on.exit(unlink(id_path), add = TRUE)
  writeLines(sort(unique(target_ids)), id_path, useBytes = TRUE)
  extract_outcome_rows(
    input_path, id_path, output_path, awk_script = awk_script
  )
}

write_mechanistic_parquet_atomic <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  arrow::write_parquet(value, temporary, compression = "zstd")
  if (!file.rename(temporary, path)) {
    mechanistic_error(paste("could not atomically replace", path))
  }
  invisible(path)
}

extract_available_cytokine_targets <- function(
  project_root = getwd(),
  inventory_path = file.path(project_root, "00_admin", "mechanistic_source_inventory.csv"),
  manifest_path = file.path(project_root, "08_qc", "mechanistic_raw_manifest.csv"),
  output_root = file.path(project_root, "03_data", "processed", "mechanistic", "cytokine_targets"),
  receipt_path = file.path(project_root, "08_qc", "mechanistic_cytokine_extract_inventory.csv")
) {
  inventory <- read_source_inventory_csv(inventory_path)
  validate_source_inventory(inventory, inventory_path)
  manifest <- read_manifest_csv(manifest_path)
  validate_receipt(manifest, inventory, project_root, verify_files = FALSE)
  config <- read_mechanistic_config(
    file.path(project_root, "config", "mechanistic_extension.yml")
  )
  mediators <- read_mechanistic_mediators(
    file.path(project_root, "config", "mechanistic_mediators.csv"), config
  )
  cytokines <- mediators[mediators$family == "cytokine", , drop = FALSE]
  cis_leads <- read_cytokine_cis_leads(
    file.path(project_root, "config", "cytokine_cis_leads.csv"), mediators
  )
  exposure_freeze <- utils::read.csv(
    file.path(project_root, "08_qc", "mechanistic_exposure_freeze.csv"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  manifest_keys <- inventory_key(manifest)
  receipts <- list()
  for (index in seq_len(nrow(cytokines))) {
    mediator <- cytokines[index, , drop = FALSE]
    source <- inventory[
      inventory$dataset == mediator$source_dataset[[1L]] &
        inventory$source_id == mediator$source_id[[1L]] &
        inventory$file_name == mediator$source_file[[1L]], , drop = FALSE
    ]
    key <- inventory_key(source)
    manifest_index <- match(key, manifest_keys)
    if (nrow(source) != 1L || is.na(manifest_index)) next
    raw_path <- raw_absolute_path(
      project_root, manifest$path[[manifest_index]]
    )
    expected_bytes <- as.numeric(manifest$bytes[[manifest_index]])
    if (!file.exists(raw_path) ||
        !identical(as.numeric(file.info(raw_path)$size), expected_bytes)) {
      mechanistic_error("receipted cytokine source file is missing or truncated")
    }
    requests <- cytokine_target_requests(mediator, exposure_freeze, cis_leads)
    temporary_extract <- tempfile("cytokine-target-", fileext = ".tsv")
    on.exit(unlink(temporary_extract), add = TRUE)
    extract_mechanistic_target_rows(
      raw_path, requests$rsid, temporary_extract,
      awk_script = file.path(project_root, "scripts", "extract_outcome_ids.awk")
    )
    raw <- data.table::fread(
      temporary_extract, data.table = FALSE, check.names = FALSE,
      showProgress = FALSE
    )
    normalized <- normalize_cytokine_gwas_rows(raw)
    result <- align_cytokine_target_requests(
      requests, normalized, mediator, cis_leads
    )
    output_path <- file.path(output_root, paste0(mediator$source_id, ".parquet"))
    write_mechanistic_parquet_atomic(result, output_path)
    receipts[[length(receipts) + 1L]] <- data.frame(
      mediator_id = mediator$mediator_id,
      source_id = mediator$source_id,
      raw_path = manifest$path[[manifest_index]],
      raw_sha256 = manifest$sha256[[manifest_index]],
      requested_rows = nrow(result),
      matched_rows = sum(result$extraction_status == "matched"),
      missing_rows = sum(result$extraction_status != "matched"),
      cis_lead_verified = ifelse(
        any(result$request_role == "mediator_cis_instrument"), "yes", "not_applicable"
      ),
      output_path = sub(paste0("^", project_root, "/"), "", output_path),
      output_sha256 = digest::digest(
        output_path, algo = "sha256", file = TRUE, serialize = FALSE
      ),
      completed_at_utc = format(
        Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
      ),
      stringsAsFactors = FALSE
    )
    unlink(temporary_extract)
  }
  if (!length(receipts)) {
    mechanistic_error("no receipted cytokine sources are available")
  }
  receipt <- do.call(rbind, receipts)
  write_csv_atomic(receipt, receipt_path)
  receipt
}

normalize_scallop_gwas_rows <- function(raw) {
  required <- c(
    "MarkerName", "Allele1", "Allele2", "Freq1", "Effect", "StdErr",
    "P-value", "TotalSampleSize"
  )
  if (!is.data.frame(raw) || length(setdiff(required, names(raw)))) {
    mechanistic_error("SCALLOP GWAS schema mismatch")
  }
  marker <- regexec(
    "^([0-9]+|X):([0-9]+):([ACGT]+)_([ACGT]+)$",
    toupper(as.character(raw$MarkerName)), perl = TRUE
  )
  parts <- regmatches(toupper(as.character(raw$MarkerName)), marker)
  parsed <- lengths(parts) == 5L
  chr <- pos <- marker_a1 <- marker_a2 <- rep(NA_character_, nrow(raw))
  if (any(parsed)) {
    chr[parsed] <- vapply(parts[parsed], `[[`, character(1), 2L)
    pos[parsed] <- vapply(parts[parsed], `[[`, character(1), 3L)
    marker_a1[parsed] <- vapply(parts[parsed], `[[`, character(1), 4L)
    marker_a2[parsed] <- vapply(parts[parsed], `[[`, character(1), 5L)
  }
  result <- data.frame(
    marker_name = as.character(raw$MarkerName),
    chr = chr, pos = mechanistic_numeric(pos),
    marker_a1 = marker_a1, marker_a2 = marker_a2,
    ea = toupper(as.character(raw$Allele1)),
    oa = toupper(as.character(raw$Allele2)),
    beta = mechanistic_numeric(raw$Effect),
    se = mechanistic_numeric(raw$StdErr),
    eaf = mechanistic_numeric(raw$Freq1),
    p = mechanistic_numeric(raw[["P-value"]]),
    n = mechanistic_numeric(raw$TotalSampleSize),
    build = "GRCh37",
    stringsAsFactors = FALSE
  )
  if (!nrow(result)) {
    result$F <- numeric()
    return(result)
  }
  marker_alleles_match <- (
    result$ea == result$marker_a1 & result$oa == result$marker_a2
  ) | (
    result$ea == result$marker_a2 & result$oa == result$marker_a1
  )
  valid <- parsed & result$chr %in% c(as.character(1:22), "X") &
    is.finite(result$pos) & result$pos > 0 &
    result$pos == floor(result$pos) &
    result$ea %in% c("A", "C", "G", "T") &
    result$oa %in% c("A", "C", "G", "T") & result$ea != result$oa &
    marker_alleles_match & is.finite(result$beta) &
    is.finite(result$se) & result$se > 0 &
    is.finite(result$eaf) & result$eaf > 0 & result$eaf < 1 &
    is.finite(result$p) & result$p >= 0 & result$p <= 1 &
    is.finite(result$n) & result$n > 0
  if (!all(valid) || anyDuplicated(result$marker_name)) {
    mechanistic_error("SCALLOP selected rows contain invalid or duplicate data")
  }
  result$F <- (result$beta / result$se)^2
  result
}

endothelial_selected_rows <- function(
  normalized, mediator, region, exposure_freeze
) {
  if (!is.data.frame(mediator) || nrow(mediator) != 1L ||
      mediator$family[[1L]] != "endothelial" ||
      !is.data.frame(region) || nrow(region) != 1L ||
      region$mediator_id[[1L]] != mediator$mediator_id[[1L]] ||
      nrow(exposure_freeze) != 5L) {
    mechanistic_error("endothelial extraction inputs are invalid")
  }
  target_rows <- lapply(seq_len(nrow(exposure_freeze)), function(index) {
    exposure <- exposure_freeze[index, , drop = FALSE]
    candidate <- normalized$chr == as.character(exposure$chromosome[[1L]]) &
      normalized$pos == exposure$position_grch37[[1L]]
    compatible <- candidate & (
      (normalized$ea == toupper(exposure$effect_allele[[1L]]) &
        normalized$oa == toupper(exposure$other_allele[[1L]])) |
      (normalized$ea == toupper(exposure$other_allele[[1L]]) &
        normalized$oa == toupper(exposure$effect_allele[[1L]])) |
      (mechanistic_complement_allele(normalized$ea) ==
        toupper(exposure$effect_allele[[1L]]) &
        mechanistic_complement_allele(normalized$oa) ==
        toupper(exposure$other_allele[[1L]])) |
      (mechanistic_complement_allele(normalized$ea) ==
        toupper(exposure$other_allele[[1L]]) &
        mechanistic_complement_allele(normalized$oa) ==
        toupper(exposure$effect_allele[[1L]]))
    )
    if (sum(compatible) > 1L) {
      mechanistic_error("SCALLOP target has multiple allele-compatible rows")
    }
    hit <- which(compatible)
    value <- if (length(hit)) normalized[hit, , drop = FALSE] else NULL
    data.frame(
      request_role = "x_instrument_to_mediator",
      request_id = exposure$exposure_id,
      marker_name = if (length(hit)) value$marker_name else NA_character_,
      reference_id = exposure$reference_id,
      chr = if (length(hit)) value$chr else as.character(exposure$chromosome),
      pos = if (length(hit)) value$pos else exposure$position_grch37,
      ea = if (length(hit)) value$ea else NA_character_,
      oa = if (length(hit)) value$oa else NA_character_,
      beta = if (length(hit)) value$beta else NA_real_,
      se = if (length(hit)) value$se else NA_real_,
      eaf = if (length(hit)) value$eaf else NA_real_,
      p = if (length(hit)) value$p else NA_real_,
      n = if (length(hit)) value$n else NA_real_,
      F = if (length(hit)) value$F else NA_real_,
      build = "GRCh37",
      extraction_status = ifelse(
        length(hit), "matched", "not_found_in_source"
      ),
      stringsAsFactors = FALSE
    )
  })
  target_rows <- do.call(rbind, target_rows)
  cis <- normalized[
    normalized$chr == as.character(region$chromosome_grch37[[1L]]) &
      normalized$pos >= region$cis_start_grch37[[1L]] &
      normalized$pos <= region$cis_end_grch37[[1L]] &
      normalized$p < region$instrument_p[[1L]] &
      normalized$F > 10, , drop = FALSE
  ]
  cis_rows <- if (nrow(cis)) data.frame(
    request_role = "mediator_cis_candidate",
    request_id = mediator$mediator_id[[1L]],
    marker_name = cis$marker_name,
    reference_id = NA_character_, chr = cis$chr, pos = cis$pos,
    ea = cis$ea, oa = cis$oa, beta = cis$beta, se = cis$se,
    eaf = cis$eaf, p = cis$p, n = cis$n, F = cis$F,
    build = cis$build,
    extraction_status = "candidate_unmapped_to_ld_reference",
    stringsAsFactors = FALSE
  ) else target_rows[FALSE, , drop = FALSE]
  selected <- rbind(target_rows, cis_rows)
  result <- data.frame(
    mediator_id = mediator$mediator_id[[1L]],
    mediator_name = mediator$mediator_name[[1L]],
    source_dataset = mediator$source_dataset[[1L]],
    source_id = mediator$source_id[[1L]],
    source_file = mediator$source_file[[1L]],
    family = mediator$family[[1L]],
    selected,
    stringsAsFactors = FALSE
  )
  result[, MECHANISTIC_ENDOTHELIAL_EXTRACT_COLUMNS, drop = FALSE]
}

extract_scallop_mechanistic_rows <- function(
  input_path, exposure_freeze, region, output_path,
  awk_script = "scripts/extract_scallop_mechanistic.awk"
) {
  input_path <- normalizePath(input_path, mustWork = TRUE)
  awk_script <- normalizePath(awk_script, mustWork = TRUE)
  plan <- rbind(
    data.frame(
      type = "TARGET", chromosome = exposure_freeze$chromosome,
      start = exposure_freeze$position_grch37, end = "",
      stringsAsFactors = FALSE
    ),
    data.frame(
      type = "REGION", chromosome = region$chromosome_grch37,
      start = region$cis_start_grch37, end = region$cis_end_grch37,
      stringsAsFactors = FALSE
    )
  )
  plan_path <- tempfile("scallop-plan-", fileext = ".tsv")
  temporary <- paste0(output_path, ".tmp-", Sys.getpid())
  log_path <- paste0(output_path, ".log-", Sys.getpid())
  on.exit(unlink(c(plan_path, temporary, log_path)), add = TRUE)
  data.table::fwrite(
    plan, plan_path, sep = "\t", col.names = FALSE, quote = FALSE, na = ""
  )
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  reader <- if (grepl("[.]gz$", input_path, ignore.case = TRUE)) {
    paste("/usr/bin/gzip -dc", shQuote(input_path))
  } else paste("/bin/cat", shQuote(input_path))
  threshold <- format(
    region$instrument_p[[1L]], scientific = TRUE, digits = 17L
  )
  command <- paste(
    "set -o pipefail; LC_ALL=C", reader,
    "| LC_ALL=C /usr/bin/awk -v", paste0("threshold=", threshold),
    "-f", shQuote(awk_script), shQuote(plan_path), "-"
  )
  status <- system2(
    "/bin/zsh", c("-c", shQuote(command)), stdout = temporary,
    stderr = log_path
  )
  if (!identical(as.integer(status), 0L) || !file.exists(temporary) ||
      file.info(temporary)$size == 0) {
    details <- if (file.exists(log_path)) {
      paste(readLines(log_path, warn = FALSE), collapse = "\n")
    } else "no extraction log"
    mechanistic_error(paste("SCALLOP extraction failed", details))
  }
  if (!file.rename(temporary, output_path)) {
    mechanistic_error("could not atomically replace SCALLOP extract")
  }
  invisible(output_path)
}
