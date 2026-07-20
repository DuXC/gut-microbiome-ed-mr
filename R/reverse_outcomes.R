reverse_outcome_dependency_hashes <- function(
  id_path, manifest_path = "MANIFEST.csv",
  schema_path = "R/gwas_schema.R",
  extractor_path = "scripts/extract_outcome_ids.awk"
) {
  paths <- c(id_path, manifest_path, schema_path, extractor_path)
  if (!all(file.exists(paths))) {
    stop("Reverse-outcome dependency file is missing", call. = FALSE)
  }
  setNames(vapply(paths, function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1)), c(
    "instrument_ids_sha256", "manifest_sha256", "schema_sha256",
    "extractor_sha256"
  ))
}

reverse_outcome_receipt_valid <- function(receipt_path, output_path, hashes) {
  if (!file.exists(receipt_path) || !file.exists(output_path)) return(FALSE)
  receipt <- tryCatch(
    data.table::fread(receipt_path, data.table = FALSE, showProgress = FALSE),
    error = function(condition) NULL
  )
  if (is.null(receipt) || nrow(receipt) != 1L) return(FALSE)
  hash_columns <- names(hashes)
  if (!all(hash_columns %in% names(receipt)) ||
      !all(as.character(receipt[1, hash_columns]) == unname(hashes))) {
    return(FALSE)
  }
  identical(
    digest::digest(file = output_path, algo = "sha256", serialize = FALSE),
    receipt$output_sha256[[1L]]
  )
}

extract_one_reverse_microbiome_outcome <- function(
  metadata, id_path, output_root, hashes,
  awk_script = "scripts/extract_outcome_ids.awk"
) {
  source_id <- metadata$source_id[[1L]]
  output_path <- file.path(output_root, paste0(source_id, ".parquet"))
  receipt_path <- file.path(output_root, paste0(source_id, ".receipt.csv"))
  if (reverse_outcome_receipt_valid(
    receipt_path, output_path, hashes
  )) {
    return(data.table::fread(
      receipt_path, data.table = FALSE, showProgress = FALSE
    ))
  }
  temporary_extract <- file.path(
    output_root, paste0(source_id, ".matched.tmp-", Sys.getpid(), ".tsv")
  )
  on.exit(unlink(temporary_extract), add = TRUE)
  extract_outcome_rows(
    metadata$data_path[[1L]], id_path, temporary_extract,
    awk_script = awk_script
  )
  raw <- data.table::fread(
    temporary_extract, data.table = FALSE, check.names = FALSE,
    showProgress = FALSE
  )
  normalized <- normalize_gwas_frame(
    raw, role = "outcome", build = metadata$genome_build[[1L]],
    ancestry = "EUR", sample_size = metadata$sample_size[[1L]],
    source_id = source_id, trait = metadata$trait[[1L]]
  )
  normalized$dataset <- metadata$dataset[[1L]]
  normalized$canonical_trait_id <- metadata$canonical_trait_id[[1L]]
  write_candidate_parquet_atomic(normalized, output_path)
  receipt <- data.frame(
    dataset = metadata$dataset[[1L]], source_id = source_id,
    trait = metadata$trait[[1L]],
    canonical_trait_id = metadata$canonical_trait_id[[1L]],
    input_path = metadata$data_path[[1L]],
    input_bytes = file.info(metadata$data_path[[1L]])$size,
    matched_rows = nrow(normalized), unique_rsids = data.table::uniqueN(
      normalized$snp[!is.na(normalized$snp)]
    ),
    output_path = output_path,
    output_sha256 = digest::digest(
      file = output_path, algo = "sha256", serialize = FALSE
    ),
    instrument_ids_sha256 = hashes[["instrument_ids_sha256"]],
    manifest_sha256 = hashes[["manifest_sha256"]],
    schema_sha256 = hashes[["schema_sha256"]],
    extractor_sha256 = hashes[["extractor_sha256"]],
    completed_at_utc = format(
      Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    ), stringsAsFactors = FALSE
  )
  atomic_write_csv(receipt, receipt_path)
  receipt
}

extract_reverse_microbiome_outcomes <- function(
  metadata_path = "08_qc/exposure_metadata_catalog.csv",
  instrument_path = "03_data/processed/reverse/reverse_ed_instruments.parquet",
  output_root = "03_data/processed/reverse/microbiome_outcomes",
  inventory_path = "08_qc/reverse_microbiome_outcome_inventory.csv",
  workers = 8L
) {
  metadata <- data.table::fread(
    metadata_path, data.table = FALSE, showProgress = FALSE
  )
  metadata <- metadata[metadata$dataset == "microbiome_2026", ]
  if (nrow(metadata) != 1572L || anyDuplicated(metadata$source_id)) {
    stop("Expected 1,572 unique Swedish microbiome outcomes", call. = FALSE)
  }
  instruments <- as.data.frame(arrow::read_parquet(instrument_path))
  ids <- sort(unique(instruments$reference_id))
  if (!length(ids) || anyNA(ids)) {
    stop("Reverse ED instruments lack valid reference IDs", call. = FALSE)
  }
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
  id_path <- file.path(output_root, "reverse_ed_instrument_ids.txt")
  writeLines(ids, id_path, useBytes = TRUE)
  hashes <- reverse_outcome_dependency_hashes(id_path)
  worker <- function(index) {
    extract_one_reverse_microbiome_outcome(
      metadata[index, , drop = FALSE], id_path, output_root, hashes
    )
  }
  if (workers > 1L) {
    cluster <- parallel::makePSOCKcluster(
      min(as.integer(workers), nrow(metadata))
    )
    on.exit(parallel::stopCluster(cluster), add = TRUE)
    parallel::clusterCall(cluster, function(project_root) {
      setwd(project_root)
      source("R/gwas_schema.R")
      source("R/exposure_candidates.R")
      source("R/outcomes.R")
      source("R/reverse_outcomes.R")
      invisible(TRUE)
    }, getwd())
    parallel::clusterExport(
      cluster,
      c("metadata", "id_path", "output_root", "hashes"),
      envir = environment()
    )
    receipts <- parallel::parLapplyLB(
      cluster, seq_len(nrow(metadata)), function(index) {
        extract_one_reverse_microbiome_outcome(
          metadata[index, , drop = FALSE], id_path, output_root, hashes
        )
      }, chunk.size = 1L
    )
  } else {
    receipts <- lapply(seq_len(nrow(metadata)), worker)
  }
  inventory <- data.table::rbindlist(receipts, use.names = TRUE, fill = TRUE)
  data.table::setorder(inventory, source_id)
  atomic_write_csv(as.data.frame(inventory), inventory_path)
  invisible(as.data.frame(inventory))
}
