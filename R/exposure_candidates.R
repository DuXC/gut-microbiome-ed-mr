validate_positive_integer <- function(value, label) {
  if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
      !is.finite(value) || value <= 0 || value != floor(value)) {
    stop(label, " must be a positive integer", call. = FALSE)
  }
  as.integer(value)
}

atomic_write_csv <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  data.table::fwrite(x, temporary, quote = TRUE, na = "")
  if (!file.rename(temporary, path)) {
    stop("Could not atomically replace CSV: ", path, call. = FALSE)
  }
  invisible(path)
}

candidate_shard_plan <- function(catalog, shard_size = 16L) {
  shard_size <- validate_positive_integer(shard_size, "shard_size")
  if (!is.data.frame(catalog) ||
      length(setdiff(c("dataset", "source_id"), names(catalog)))) {
    stop("Exposure catalog is missing dataset or source_id", call. = FALSE)
  }
  if (anyDuplicated(paste(catalog$dataset, catalog$source_id, sep = "\r"))) {
    stop("Exposure catalog contains duplicate accessions", call. = FALSE)
  }
  catalog <- catalog[order(catalog$dataset, catalog$source_id), , drop = FALSE]
  parts <- lapply(split(catalog, catalog$dataset), function(dataset_rows) {
    dataset_rows$shard <- ceiling(seq_len(nrow(dataset_rows)) / shard_size)
    dataset_rows
  })
  plan <- do.call(rbind, parts)
  rownames(plan) <- NULL
  plan
}

extract_one_exposure <- function(row, p_threshold) {
  extract_gwas_candidates(
    row$data_path, p_threshold = p_threshold, role = "exposure",
    build = row$genome_build, ancestry = "EUR",
    sample_size = row$sample_size, source_id = row$source_id,
    trait = row$trait
  )
}

write_candidate_parquet_atomic <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  on.exit(unlink(temporary), add = TRUE)
  arrow::write_parquet(x, temporary, compression = "zstd")
  if (!file.rename(temporary, path)) {
    stop("Could not atomically replace candidate shard: ", path, call. = FALSE)
  }
  invisible(path)
}

read_candidate_progress <- function(path) {
  columns <- c(
    "dataset", "shard", "source_ids", "output_path", "candidate_rows",
    "p_threshold", "manifest_sha256", "schema_sha256", "output_sha256",
    "completed_at_utc"
  )
  if (!file.exists(path)) {
    return(as.data.frame(setNames(replicate(
      length(columns), character(), simplify = FALSE
    ), columns), stringsAsFactors = FALSE))
  }
  progress <- data.table::fread(
    path, data.table = FALSE, check.names = FALSE, colClasses = "character",
    showProgress = FALSE
  )
  if (!identical(names(progress), columns)) {
    stop("Candidate progress ledger has an invalid schema", call. = FALSE)
  }
  if (anyDuplicated(paste(progress$dataset, progress$shard, sep = "\r"))) {
    stop("Candidate progress ledger has duplicate shard receipts", call. = FALSE)
  }
  progress
}

candidate_shard_is_complete <- function(
  progress, dataset, shard, source_ids, output_path, p_threshold,
  manifest_sha256, schema_sha256
) {
  hit <- progress$dataset == dataset & progress$shard == as.character(shard)
  if (sum(hit) != 1L || !file.exists(output_path)) {
    return(FALSE)
  }
  receipt <- progress[hit, , drop = FALSE]
  expected_ids <- paste(source_ids, collapse = ";")
  identical(receipt$source_ids, expected_ids) &&
    identical(receipt$output_path, output_path) &&
    identical(as.numeric(receipt$p_threshold), as.numeric(p_threshold)) &&
    identical(receipt$manifest_sha256, manifest_sha256) &&
    identical(receipt$schema_sha256, schema_sha256) &&
    identical(
      receipt$output_sha256,
      digest::digest(file = output_path, algo = "sha256", serialize = FALSE)
    )
}

append_candidate_progress <- function(progress, receipt, path) {
  key <- paste(receipt$dataset, receipt$shard, sep = "\r")
  old_key <- paste(progress$dataset, progress$shard, sep = "\r")
  progress <- progress[old_key != key, , drop = FALSE]
  progress <- rbind(progress, receipt)
  progress <- progress[order(progress$dataset, as.integer(progress$shard)), , drop = FALSE]
  atomic_write_csv(progress, path)
  progress
}

build_candidate_inventory <- function(plan, output_root, p_threshold) {
  sources <- unique(plan[, c(
    "dataset", "source_id", "trait", "canonical_trait_id", "sample_size",
    "genome_build", "manifest_sha256", "schema_sha256", "shard"
  )])
  sources$candidate_rows <- 0L
  sources$primary_rows <- 0L
  sources$rsid_rows <- 0L
  sources$min_p <- NA_real_

  for (dataset in unique(plan$dataset)) {
    shard_paths <- list.files(
      file.path(output_root, dataset), pattern = "^shard_[0-9]+[.]parquet$",
      full.names = TRUE
    )
    for (path in shard_paths) {
      candidates <- as.data.frame(arrow::read_parquet(path))
      validate_gwas(candidates)
      if (any(candidates$p >= p_threshold)) {
        stop("Candidate shard contains a row outside the extraction threshold",
             call. = FALSE)
      }
      for (source_id in unique(candidates$source_id)) {
        hit <- sources$dataset == dataset & sources$source_id == source_id
        rows <- candidates[candidates$source_id == source_id, , drop = FALSE]
        sources$candidate_rows[hit] <- nrow(rows)
        sources$primary_rows[hit] <- sum(rows$p < 5e-8)
        sources$rsid_rows[hit] <- sum(!is.na(rows$snp))
        sources$min_p[hit] <- min(rows$p)
      }
    }
  }
  sources[order(sources$dataset, sources$source_id), , drop = FALSE]
}

run_exposure_candidate_extraction <- function(
  manifest_path = "MANIFEST.csv",
  output_root = "03_data/processed/exposure_candidates",
  qc_root = "08_qc",
  p_threshold = 1e-5,
  workers = 4L,
  shard_size = 16L,
  project_root = getwd()
) {
  workers <- validate_positive_integer(workers, "workers")
  shard_size <- validate_positive_integer(shard_size, "shard_size")
  if (.Platform$OS.type != "unix" && workers > 1L) {
    stop("Parallel exposure extraction currently requires a Unix-like system",
         call. = FALSE)
  }
  manifest_path <- normalizePath(manifest_path, mustWork = TRUE)
  manifest_sha256 <- digest::digest(
    file = manifest_path, algo = "sha256", serialize = FALSE
  )
  schema_path <- normalizePath(
    file.path(project_root, "R", "gwas_schema.R"), mustWork = TRUE
  )
  schema_sha256 <- digest::digest(
    file = schema_path, algo = "sha256", serialize = FALSE
  )
  dir.create(qc_root, recursive = TRUE, showWarnings = FALSE)
  catalog_path <- file.path(qc_root, "exposure_metadata_catalog.csv")
  cached_catalog <- if (file.exists(catalog_path)) {
    data.table::fread(
      catalog_path, data.table = FALSE, check.names = FALSE,
      showProgress = FALSE
    )
  } else {
    NULL
  }
  cache_valid <- is.data.frame(cached_catalog) &&
    all(c("manifest_sha256", "schema_sha256") %in% names(cached_catalog)) &&
    nrow(cached_catalog) > 0L &&
    all(cached_catalog$manifest_sha256 == manifest_sha256) &&
    all(cached_catalog$schema_sha256 == schema_sha256)
  if (cache_valid) {
    catalog <- cached_catalog
    cat("Reusing verified exposure metadata catalog\n")
  } else {
    catalog <- build_microbiome_metadata_catalog(
      manifest_path, project_root, workers = workers
    )
    catalog$manifest_sha256 <- manifest_sha256
    catalog$schema_sha256 <- schema_sha256
    atomic_write_csv(catalog, catalog_path)
  }
  replication_map <- match_microbiome_replication_traits(catalog)
  atomic_write_csv(
    replication_map, file.path(qc_root, "exposure_replication_map.csv")
  )

  plan <- candidate_shard_plan(catalog, shard_size)
  progress_path <- file.path(output_root, "progress.csv")
  progress <- read_candidate_progress(progress_path)
  group_key <- paste(plan$dataset, plan$shard, sep = "\r")
  groups <- split(
    seq_len(nrow(plan)), factor(group_key, levels = unique(group_key))
  )
  total <- length(groups)
  completed <- 0L

  for (indices in groups) {
    rows <- plan[indices, , drop = FALSE]
    dataset <- rows$dataset[[1L]]
    shard <- rows$shard[[1L]]
    output_path <- normalizePath(
      file.path(output_root, dataset), mustWork = FALSE
    )
    dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
    output_path <- file.path(output_path, sprintf("shard_%04d.parquet", shard))
    source_ids <- rows$source_id

    if (candidate_shard_is_complete(
      progress, dataset, shard, source_ids, output_path, p_threshold,
      manifest_sha256, schema_sha256
    )) {
      completed <- completed + 1L
      cat(sprintf(
        "[%d/%d] resume %s shard %04d (%d accessions)\n",
        completed, total, dataset, shard, nrow(rows)
      ))
      flush.console()
      next
    }

    started <- proc.time()[["elapsed"]]
    jobs <- lapply(seq_len(nrow(rows)), function(index) {
      as.list(rows[index, , drop = FALSE])
    })
    results <- if (workers > 1L) {
      parallel::mclapply(
        jobs, extract_one_exposure, p_threshold = p_threshold,
        mc.cores = min(workers, length(jobs)), mc.preschedule = FALSE
      )
    } else {
      lapply(jobs, extract_one_exposure, p_threshold = p_threshold)
    }
    failed <- vapply(results, inherits, logical(1), what = "try-error")
    if (any(failed)) {
      stop(
        "Candidate extraction failed for ",
        paste(source_ids[failed], collapse = ", "), ": ",
        paste(as.character(results[failed]), collapse = " | "),
        call. = FALSE
      )
    }
    candidates <- do.call(rbind, results)
    rownames(candidates) <- NULL
    validate_gwas(candidates)
    write_candidate_parquet_atomic(candidates, output_path)
    output_sha256 <- digest::digest(
      file = output_path, algo = "sha256", serialize = FALSE
    )
    receipt <- data.frame(
      dataset = dataset,
      shard = as.character(shard),
      source_ids = paste(source_ids, collapse = ";"),
      output_path = output_path,
      candidate_rows = as.character(nrow(candidates)),
      p_threshold = format(p_threshold, scientific = TRUE, digits = 17L),
      manifest_sha256 = manifest_sha256,
      schema_sha256 = schema_sha256,
      output_sha256 = output_sha256,
      completed_at_utc = format(
        Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
      ),
      stringsAsFactors = FALSE
    )
    progress <- append_candidate_progress(progress, receipt, progress_path)
    completed <- completed + 1L
    elapsed <- proc.time()[["elapsed"]] - started
    cat(sprintf(
      "[%d/%d] wrote %s shard %04d: %d accessions, %d candidates, %.1fs\n",
      completed, total, dataset, shard, nrow(rows), nrow(candidates), elapsed
    ))
    flush.console()
  }

  inventory <- build_candidate_inventory(plan, output_root, p_threshold)
  atomic_write_csv(
    inventory, file.path(qc_root, "exposure_candidate_inventory.csv")
  )
  invisible(list(
    catalog = catalog, replication_map = replication_map,
    inventory = inventory, progress = progress
  ))
}
