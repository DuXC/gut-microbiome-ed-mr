outcome_part_code <- function(path) {
  match <- regexec("_([a-z]{2})[.]gz$", basename(path), perl = TRUE)
  parts <- regmatches(basename(path), match)[[1L]]
  if (length(parts) != 2L) {
    stop("Outcome part filename lacks a two-letter suffix: ", path,
         call. = FALSE)
  }
  parts[[2L]]
}

validate_outcome_part_sequence <- function(paths) {
  if (!is.character(paths) || !length(paths) || anyNA(paths)) {
    stop("Outcome part paths must be a non-empty character vector", call. = FALSE)
  }
  codes <- unname(vapply(paths, outcome_part_code, character(1)))
  expected <- sprintf("a%s", letters[seq_along(paths)])
  if (!identical(codes, expected)) {
    stop(
      "Outcome parts must be contiguous and ordered from aa: got ",
      paste(codes, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

copy_binary_connection <- function(input_path, output_connection, block_size) {
  input <- file(input_path, open = "rb")
  on.exit(close(input), add = TRUE)
  repeat {
    block <- readBin(input, what = "raw", n = block_size)
    if (!length(block)) {
      break
    }
    writeBin(block, output_connection)
  }
  invisible(TRUE)
}

gzip_is_valid <- function(path) {
  status <- suppressWarnings(system2(
    "/usr/bin/gzip", args = c("-t", shQuote(path)),
    stdout = FALSE, stderr = FALSE
  ))
  identical(as.integer(status), 0L)
}

assemble_binary_parts <- function(
  paths, output_path, block_size = 8L * 1024L * 1024L
) {
  paths <- normalizePath(paths, mustWork = TRUE)
  validate_outcome_part_sequence(paths)
  if (!is.numeric(block_size) || length(block_size) != 1L || is.na(block_size) ||
      !is.finite(block_size) || block_size <= 0 || block_size != floor(block_size)) {
    stop("block_size must be a positive integer", call. = FALSE)
  }
  first_bytes <- readBin(paths[[1L]], what = "raw", n = 2L)
  if (!identical(first_bytes, as.raw(c(0x1f, 0x8b)))) {
    stop("First outcome part does not begin with a gzip header", call. = FALSE)
  }
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(output_path, ".tmp-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  output <- file(temporary, open = "wb")
  tryCatch(
    {
      for (path in paths) {
        copy_binary_connection(path, output, as.integer(block_size))
      }
    },
    finally = close(output)
  )
  expected_bytes <- sum(file.info(paths)$size)
  actual_bytes <- file.info(temporary)$size
  if (!identical(as.numeric(actual_bytes), as.numeric(expected_bytes))) {
    stop("Assembled outcome byte count does not equal the sum of its parts",
         call. = FALSE)
  }
  if (!gzip_is_valid(temporary)) {
    stop("Assembled outcome failed gzip integrity testing", call. = FALSE)
  }
  if (!file.rename(temporary, output_path)) {
    stop("Could not atomically replace assembled outcome: ", output_path,
         call. = FALSE)
  }
  invisible(output_path)
}

parse_ed_part_name <- function(file_name) {
  match <- regexec(
    "^ed_(eur|afr|cross_ancestry)_meta_([a-z]{2})[.]gz$",
    file_name, perl = TRUE
  )
  parts <- regmatches(file_name, match)[[1L]]
  if (length(parts) != 3L) {
    stop("Unexpected ED outcome part filename: ", file_name, call. = FALSE)
  }
  list(ancestry = parts[[2L]], part = parts[[3L]])
}

build_ed_outcome_assemblies <- function(
  manifest_path = "MANIFEST.csv",
  output_root = "03_data/processed/outcomes/ed_2025",
  receipt_path = "08_qc/outcome_assembly_receipt.csv",
  project_root = getwd()
) {
  manifest_path <- normalizePath(manifest_path, mustWork = TRUE)
  manifest <- data.table::fread(
    manifest_path, data.table = FALSE, colClasses = "character",
    showProgress = FALSE
  )
  required <- c("dataset", "source_id", "file_name", "path", "bytes", "sha256")
  missing <- setdiff(required, names(manifest))
  if (length(missing)) {
    stop("Manifest is missing columns: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  rows <- manifest[manifest$dataset == "ed_2025", , drop = FALSE]
  if (nrow(rows) != 8L) {
    stop("Expected exactly eight ED 2025 outcome parts", call. = FALSE)
  }
  parsed <- lapply(rows$file_name, parse_ed_part_name)
  rows$ancestry <- vapply(parsed, `[[`, character(1), "ancestry")
  rows$part <- vapply(parsed, `[[`, character(1), "part")
  rows$absolute_path <- file.path(project_root, rows$path)
  if (!all(file.exists(rows$absolute_path))) {
    stop("One or more ED outcome parts are missing", call. = FALSE)
  }
  actual_bytes <- file.info(rows$absolute_path)$size
  if (!all(actual_bytes == as.numeric(rows$bytes))) {
    stop("One or more ED outcome part sizes differ from the manifest",
         call. = FALSE)
  }
  actual_sha256 <- unname(vapply(rows$absolute_path, function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1)))
  if (!identical(actual_sha256, rows$sha256)) {
    stop("One or more ED outcome part hashes differ from the manifest",
         call. = FALSE)
  }

  receipts <- lapply(c("eur", "afr", "cross_ancestry"), function(ancestry) {
    group <- rows[rows$ancestry == ancestry, , drop = FALSE]
    group <- group[order(group$part), , drop = FALSE]
    validate_outcome_part_sequence(group$absolute_path)
    output_path <- file.path(output_root, sprintf("ed_%s_meta.gz", ancestry))
    assemble_binary_parts(group$absolute_path, output_path)
    data.frame(
      ancestry = toupper(ancestry),
      source_ids = paste(group$source_id, collapse = ";"),
      part_names = paste(group$file_name, collapse = ";"),
      part_bytes = paste(group$bytes, collapse = ";"),
      part_sha256 = paste(group$sha256, collapse = ";"),
      assembled_path = output_path,
      assembled_bytes = file.info(output_path)$size,
      assembled_sha256 = digest::digest(
        file = output_path, algo = "sha256", serialize = FALSE
      ),
      gzip_valid = gzip_is_valid(output_path),
      manifest_sha256 = digest::digest(
        file = manifest_path, algo = "sha256", serialize = FALSE
      ),
      completed_at_utc = format(
        Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
      ),
      stringsAsFactors = FALSE
    )
  })
  receipt <- do.call(rbind, receipts)
  atomic_write_csv(receipt, receipt_path)
  invisible(receipt)
}

outcome_column <- function(x, normalized_name) {
  normalized <- normalize_gwas_header(names(x))
  index <- which(normalized == normalized_name)
  if (length(index) != 1L) {
    stop("Outcome table must have exactly one ", normalized_name, " column",
         call. = FALSE)
  }
  x[[index]]
}

expand_matched_rsids <- function(x, id_column, wanted_ids) {
  values <- as.character(x[[id_column]])
  rows <- lapply(seq_len(nrow(x)), function(i) {
    ids <- unlist(strsplit(values[[i]], "[,;]", perl = TRUE), use.names = FALSE)
    ids <- intersect(ids, wanted_ids)
    if (!length(ids)) {
      return(NULL)
    }
    result <- x[rep(i, length(ids)), , drop = FALSE]
    result$matched_rsid <- ids
    result
  })
  rows <- rows[vapply(rows, Negate(is.null), logical(1))]
  if (!length(rows)) {
    result <- x[FALSE, , drop = FALSE]
    result$matched_rsid <- character()
    return(result)
  }
  result <- data.table::rbindlist(rows, use.names = TRUE, fill = TRUE)
  as.data.frame(result)
}

normalize_ed_meta_outcome <- function(
  x, outcome_id, ancestry, cases, controls, build = "GRCh38"
) {
  rsid <- as.character(outcome_column(x, "rsid"))
  chr <- toupper(as.character(outcome_column(x, "chr")))
  pos <- as_gwas_number(outcome_column(x, "bp"))
  ea <- toupper(as.character(outcome_column(x, "allele1")))
  oa <- toupper(as.character(outcome_column(x, "allele2")))
  weight <- as_gwas_number(outcome_column(x, "weight"))
  z <- as_gwas_number(outcome_column(x, "zscore"))
  p <- as_gwas_number(outcome_column(x, "p_value"))
  valid <- !is.na(weight) & is.finite(weight) & weight > 0 &
    !is.na(z) & is.finite(z) & !is.na(p) & is.finite(p) & p >= 0 & p <= 1
  if (!all(valid)) {
    stop("ED meta-analysis outcome has invalid weight, Z, or P values",
         call. = FALSE)
  }
  p[p == 0] <- .Machine$double.xmin
  result <- data.frame(
    outcome_id = outcome_id, ancestry = ancestry, build = build,
    rsid = rsid, chr = chr, pos = pos, ea = ea, oa = oa,
    beta = z / sqrt(weight), se = 1 / sqrt(weight), z = z, p = p,
    eaf = NA_real_, sample_weight = weight,
    cases = as.numeric(cases), controls = as.numeric(controls),
    total_n = as.numeric(cases + controls),
    effect_scale = "standardized_z_per_sqrt_metal_weight",
    sample_size_type = "variant_specific_METAL_effective_sample_weight",
    analysis_role = "high_power_outcome_meta_sensitivity",
    stringsAsFactors = FALSE
  )
  if (anyDuplicated(result$rsid)) {
    stop("ED meta-analysis extract contains duplicate rsIDs", call. = FALSE)
  }
  result
}

normalize_finngen_outcome <- function(
  x, wanted_ids, cases = 2886, controls = 215272, build = "GRCh38"
) {
  normalized <- normalize_gwas_header(names(x))
  id_index <- which(normalized == "rsids")
  if (length(id_index) != 1L) {
    stop("FinnGen outcome must have exactly one rsids column", call. = FALSE)
  }
  expanded <- expand_matched_rsids(x, names(x)[id_index], wanted_ids)
  beta <- as_gwas_number(outcome_column(expanded, "beta"))
  se <- as_gwas_number(outcome_column(expanded, "sebeta"))
  p <- as_gwas_number(outcome_column(expanded, "pval"))
  mlogp <- as_gwas_number(outcome_column(expanded, "mlogp"))
  p[p == 0 & is.finite(mlogp)] <- 10^(-mlogp[p == 0 & is.finite(mlogp)])
  p[p == 0] <- .Machine$double.xmin
  result <- data.frame(
    outcome_id = "finngen_r12_erectile_dysfunction",
    ancestry = "Finnish", build = build,
    rsid = expanded$matched_rsid,
    chr = toupper(as.character(outcome_column(expanded, "chrom"))),
    pos = as_gwas_number(outcome_column(expanded, "pos")),
    ea = toupper(as.character(outcome_column(expanded, "alt"))),
    oa = toupper(as.character(outcome_column(expanded, "ref"))),
    beta = beta, se = se, z = beta / se, p = p,
    eaf = as_gwas_number(outcome_column(expanded, "af_alt")),
    sample_weight = NA_real_, cases = as.numeric(cases),
    controls = as.numeric(controls), total_n = as.numeric(cases + controls),
    effect_scale = "log_odds",
    sample_size_type = "endpoint_total_cases_plus_controls",
    analysis_role = "primary_outcome",
    stringsAsFactors = FALSE
  )
  valid <- is.finite(result$beta) & is.finite(result$se) & result$se > 0 &
    is.finite(result$p) & result$p > 0 & result$p <= 1 &
    is.finite(result$eaf) & result$eaf > 0 & result$eaf < 1
  if (!all(valid)) {
    stop("FinnGen outcome has invalid beta, SE, P, or allele frequency",
         call. = FALSE)
  }
  record_key <- paste(
    result$rsid, result$chr, result$pos, result$oa, result$ea, sep = ":"
  )
  if (anyDuplicated(record_key)) {
    stop("FinnGen outcome extract contains duplicate allele-specific records",
         call. = FALSE)
  }
  result
}

extract_outcome_rows <- function(
  input_path, id_path, output_path,
  awk_script = "scripts/extract_outcome_ids.awk"
) {
  input_path <- normalizePath(input_path, mustWork = TRUE)
  id_path <- normalizePath(id_path, mustWork = TRUE)
  awk_script <- normalizePath(awk_script, mustWork = TRUE)
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(output_path, ".tmp-", Sys.getpid())
  log_path <- paste0(output_path, ".log-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  on.exit(unlink(log_path), add = TRUE)
  command <- paste(
    "LC_ALL=C /usr/bin/gzip -dc", shQuote(input_path), "|",
    "LC_ALL=C /usr/bin/awk -f", shQuote(awk_script), shQuote(id_path), "-"
  )
  status <- system2(
    "/bin/zsh", c("-c", shQuote(command)),
    stdout = temporary, stderr = log_path
  )
  if (!identical(as.integer(status), 0L)) {
    details <- if (file.exists(log_path)) {
      paste(readLines(log_path, warn = FALSE), collapse = "\n")
    } else {
      "no extraction log was created"
    }
    stop(
      "Outcome candidate extraction failed: ",
      details, call. = FALSE
    )
  }
  if (!file.exists(temporary) || file.info(temporary)$size == 0) {
    stop("Outcome candidate extraction created no table", call. = FALSE)
  }
  if (!file.rename(temporary, output_path)) {
    stop("Could not atomically replace outcome extract: ", output_path,
         call. = FALSE)
  }
  invisible(output_path)
}

build_outcome_candidate_layer <- function(
  instrument_path = "03_data/processed/instruments/instruments.parquet",
  assembled_root = "03_data/processed/outcomes/ed_2025",
  finngen_path = paste0(
    "03_data/raw/finngen_r12/finngen_R12_ERECTILE_DYSFUNCTION/",
    "finngen_R12_ERECTILE_DYSFUNCTION.gz"
  ),
  output_root = "03_data/processed/outcomes/candidates",
  qc_path = "08_qc/outcome_candidate_inventory.csv",
  workers = 4L
) {
  instruments <- as.data.frame(arrow::read_parquet(instrument_path))
  wanted_ids <- sort(unique(instruments$reference_id))
  wanted_ids <- wanted_ids[!is.na(wanted_ids) & nzchar(wanted_ids)]
  if (!length(wanted_ids)) {
    stop("Instrument table contains no reference IDs", call. = FALSE)
  }
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
  id_path <- file.path(output_root, "instrument_reference_ids.txt")
  writeLines(wanted_ids, id_path, useBytes = TRUE)
  specifications <- list(
    list(
      outcome_id = "ed_2025_eur", ancestry = "EUR", cases = 136867,
      controls = 913194 - 136867,
      input = file.path(assembled_root, "ed_eur_meta.gz"), type = "meta"
    ),
    list(
      outcome_id = "ed_2025_afr", ancestry = "AFR", cases = 51599,
      controls = 125315 - 51599,
      input = file.path(assembled_root, "ed_afr_meta.gz"), type = "meta"
    ),
    list(
      outcome_id = "ed_2025_cross_ancestry", ancestry = "cross_ancestry",
      cases = 136867 + 51599, controls = 1038509 - 136867 - 51599,
      input = file.path(assembled_root, "ed_cross_ancestry_meta.gz"), type = "meta"
    ),
    list(
      outcome_id = "finngen_r12_erectile_dysfunction", ancestry = "Finnish",
      cases = 2886, controls = 215272, input = finngen_path, type = "finngen"
    )
  )
  worker <- function(specification) {
    raw_extract <- file.path(output_root, paste0(
      specification$outcome_id, "_matched.tsv"
    ))
    extract_outcome_rows(specification$input, id_path, raw_extract)
    raw <- data.table::fread(
      raw_extract, data.table = FALSE, check.names = FALSE,
      showProgress = FALSE
    )
    normalized <- if (specification$type == "meta") {
      normalize_ed_meta_outcome(
        raw, outcome_id = specification$outcome_id,
        ancestry = specification$ancestry, cases = specification$cases,
        controls = specification$controls
      )
    } else {
      normalize_finngen_outcome(
        raw, wanted_ids = wanted_ids, cases = specification$cases,
        controls = specification$controls
      )
    }
    output_path <- file.path(output_root, paste0(
      specification$outcome_id, ".parquet"
    ))
    write_candidate_parquet_atomic(normalized, output_path)
    data.frame(
      outcome_id = specification$outcome_id,
      ancestry = specification$ancestry,
      analysis_role = unique(normalized$analysis_role),
      effect_scale = unique(normalized$effect_scale),
      requested_reference_ids = length(wanted_ids),
      raw_matched_rows = nrow(raw), normalized_rows = nrow(normalized),
      unique_matched_ids = data.table::uniqueN(normalized$rsid),
      multiallelic_reference_ids = sum(table(normalized$rsid) > 1L),
      maximum_rows_per_reference_id = max(table(normalized$rsid)),
      coverage = data.table::uniqueN(normalized$rsid) / length(wanted_ids),
      output_path = output_path,
      output_sha256 = digest::digest(
        file = output_path, algo = "sha256", serialize = FALSE
      ),
      stringsAsFactors = FALSE
    )
  }
  results <- if (.Platform$OS.type == "unix" && workers > 1L) {
    parallel::mclapply(
      specifications, worker, mc.cores = min(workers, length(specifications)),
      mc.preschedule = FALSE
    )
  } else {
    lapply(specifications, worker)
  }
  failed <- vapply(results, inherits, logical(1), what = "try-error")
  if (any(failed)) {
    stop(
      "Outcome candidate layer failed: ",
      paste(as.character(results[failed]), collapse = " | "), call. = FALSE
    )
  }
  inventory <- do.call(rbind, results)
  inventory$completed_at_utc <- format(
    Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
  )
  atomic_write_csv(inventory, qc_path)
  invisible(inventory)
}
