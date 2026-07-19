validate_instrument_threshold <- function(value, label) {
  if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
      !is.finite(value) || value <= 0 || value > 1) {
    stop(label, " must be one finite number in (0, 1]", call. = FALSE)
  }
  as.numeric(value)
}

validate_positive_instrument_number <- function(value, label) {
  if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
      !is.finite(value) || value <= 0) {
    stop(label, " must be one positive finite number", call. = FALSE)
  }
  as.numeric(value)
}

require_instrument_columns <- function(x, columns, label = "instrument table") {
  if (!is.data.frame(x)) {
    stop(label, " must be a data frame", call. = FALSE)
  }
  missing <- setdiff(columns, names(x))
  if (length(missing)) {
    stop(label, " is missing columns: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  invisible(TRUE)
}

select_by_p <- function(x, threshold) {
  threshold <- validate_instrument_threshold(threshold, "threshold")
  require_instrument_columns(x, "p")
  keep <- !is.na(x$p) & is.finite(x$p) & x$p < threshold
  x[keep, , drop = FALSE]
}

add_f_stat <- function(x) {
  require_instrument_columns(x, c("beta", "se"))
  result <- x
  valid <- !is.na(result$beta) & is.finite(result$beta) &
    !is.na(result$se) & is.finite(result$se) & result$se > 0
  result$F <- rep(NA_real_, nrow(result))
  result$F[valid] <- (result$beta[valid] / result$se[valid])^2
  result
}

filter_strong_iv <- function(x, min_f = 10) {
  min_f <- validate_positive_instrument_number(min_f, "min_f")
  result <- add_f_stat(x)
  result[!is.na(result$F) & is.finite(result$F) & result$F > min_f,
         , drop = FALSE]
}

validate_clump_ancestry <- function(requested, reference) {
  values <- list(requested = requested, reference = reference)
  for (label in names(values)) {
    value <- values[[label]]
    if (!is.character(value) || length(value) != 1L || is.na(value) ||
        !nzchar(trimws(value))) {
      stop(label, " ancestry must be one non-empty string", call. = FALSE)
    }
  }
  if (!identical(toupper(requested), toupper(reference))) {
    stop(
      sprintf(
        "Ancestry mismatch: requested %s but reference is %s",
        requested, reference
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

read_reference_variant_map <- function(path, build = "GRCh37") {
  if (!file.exists(path)) {
    stop("Missing reference variant map: ", path, call. = FALSE)
  }
  x <- data.table::fread(
    path, header = FALSE, sep = "\t", data.table = FALSE,
    col.names = c("chr", "pos", "reference_id", "reference_ref", "reference_alt"),
    colClasses = c("character", "numeric", "character", "character", "character"),
    showProgress = FALSE
  )
  x$chr <- toupper(sub("^chr", "", x$chr, ignore.case = TRUE))
  x$reference_ref <- toupper(x$reference_ref)
  x$reference_alt <- toupper(x$reference_alt)
  biallelic_snp <- grepl("^[ACGT]$", x$reference_ref) &
    grepl("^[ACGT]$", x$reference_alt) &
    x$reference_ref != x$reference_alt &
    !is.na(x$reference_id) & nzchar(x$reference_id) & x$reference_id != "."
  x <- x[biallelic_snp, , drop = FALSE]
  x$variant_key <- make_variant_key(
    x$chr, x$pos, x$reference_ref, x$reference_alt
  )
  x$reference_build <- build
  if (anyDuplicated(x$variant_key)) {
    stop("Reference variant map has duplicate allele keys", call. = FALSE)
  }
  x
}

map_candidates_to_reference <- function(
  candidates, reference_map, reference_build = "GRCh37"
) {
  require_instrument_columns(
    candidates, c("variant_key", "ea", "oa", "build"), "candidate table"
  )
  require_instrument_columns(
    reference_map,
    c(
      "variant_key", "reference_id", "reference_ref", "reference_alt",
      "reference_build"
    ),
    "reference variant map"
  )
  candidate_builds <- unique(candidates$build)
  candidate_builds <- candidate_builds[!is.na(candidate_builds)]
  if (!length(candidate_builds) ||
      !all(candidate_builds == reference_build) ||
      !all(reference_map$reference_build == reference_build)) {
    stop("Candidate and LD-reference genome builds do not match", call. = FALSE)
  }
  index <- match(candidates$variant_key, reference_map$variant_key)
  result <- candidates
  result$reference_id <- reference_map$reference_id[index]
  result$reference_ref <- reference_map$reference_ref[index]
  result$reference_alt <- reference_map$reference_alt[index]
  direct <- !is.na(index) & result$ea == result$reference_alt &
    result$oa == result$reference_ref
  swapped <- !is.na(index) & result$ea == result$reference_ref &
    result$oa == result$reference_alt
  result$reference_allele_relation <- NA_character_
  result$reference_allele_relation[direct] <- "effect_is_alt"
  result$reference_allele_relation[swapped] <- "effect_is_ref"
  result$reference_mapping_status <- ifelse(
    is.na(index), "not_in_reference",
    ifelse(direct | swapped, "allele_key_match", "allele_mismatch")
  )
  result$reference_id[result$reference_mapping_status != "allele_key_match"] <-
    NA_character_
  result
}

read_exposure_candidate_shards <- function(candidate_root) {
  paths <- list.files(
    candidate_root, pattern = "^shard_[0-9]+[.]parquet$",
    recursive = TRUE, full.names = TRUE
  )
  if (!length(paths)) {
    stop("No exposure candidate Parquet shards found under ", candidate_root,
         call. = FALSE)
  }
  parts <- lapply(paths, function(path) {
    x <- as.data.frame(arrow::read_parquet(path))
    validate_gwas(x)
    x$dataset <- basename(dirname(path))
    x
  })
  result <- data.table::rbindlist(parts, use.names = TRUE, fill = FALSE)
  as.data.frame(result)
}

prepare_clump_input <- function(x) {
  require_instrument_columns(x, c("reference_id", "p"))
  keep <- !is.na(x$reference_id) & nzchar(x$reference_id) &
    !is.na(x$p) & is.finite(x$p) & x$p > 0 & x$p <= 1
  result <- x[keep, , drop = FALSE]
  if (!nrow(result)) {
    return(data.frame(SNP = character(), P = numeric()))
  }
  result <- result[order(result$p, result$reference_id), , drop = FALSE]
  result <- result[!duplicated(result$reference_id), , drop = FALSE]
  data.frame(SNP = result$reference_id, P = result$p)
}

parse_plink_clumped <- function(path) {
  if (!file.exists(path) || file.info(path)$size == 0) {
    return(character())
  }
  x <- data.table::fread(
    path, data.table = FALSE, fill = TRUE, showProgress = FALSE
  )
  if (!"SNP" %in% names(x)) {
    stop("PLINK clump output is missing the SNP column", call. = FALSE)
  }
  unique(as.character(x$SNP[!is.na(x$SNP) & nzchar(x$SNP)]))
}

clump_local <- function(
  x, requested_ancestry, reference_ancestry, plink_binary, bfile_prefix,
  p_threshold, r2 = 0.001, kb = 10000
) {
  validate_clump_ancestry(requested_ancestry, reference_ancestry)
  p_threshold <- validate_instrument_threshold(p_threshold, "p_threshold")
  r2 <- validate_instrument_threshold(r2, "r2")
  if (!is.numeric(kb) || length(kb) != 1L || is.na(kb) ||
      !is.finite(kb) || kb <= 0 || kb != floor(kb)) {
    stop("kb must be a positive integer", call. = FALSE)
  }
  if (!file.exists(plink_binary)) {
    stop("Missing PLINK binary: ", plink_binary, call. = FALSE)
  }
  required_reference <- paste0(bfile_prefix, c(".bed", ".bim", ".fam"))
  if (!all(file.exists(required_reference))) {
    stop("Incomplete PLINK reference prefix: ", bfile_prefix, call. = FALSE)
  }
  clump_input <- prepare_clump_input(x)
  if (!nrow(clump_input)) {
    return(character())
  }

  work_dir <- tempfile("mr-clump-")
  dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(work_dir, recursive = TRUE, force = TRUE), add = TRUE)
  input_path <- file.path(work_dir, "candidates.tsv")
  output_prefix <- file.path(work_dir, "plink")
  log_path <- file.path(work_dir, "command.log")
  data.table::fwrite(clump_input, input_path, sep = "\t", quote = FALSE)
  args <- c(
    "--bfile", shQuote(bfile_prefix),
    "--clump", shQuote(input_path),
    "--clump-snp-field", "SNP", "--clump-field", "P",
    "--clump-p1", format(p_threshold, scientific = TRUE, digits = 17L),
    "--clump-p2", format(p_threshold, scientific = TRUE, digits = 17L),
    "--clump-r2", format(r2, scientific = FALSE, digits = 17L),
    "--clump-kb", as.character(as.integer(kb)),
    "--out", shQuote(output_prefix)
  )
  status <- system2(
    plink_binary, args = args, stdout = log_path, stderr = log_path
  )
  if (!identical(as.integer(status), 0L)) {
    details <- if (file.exists(log_path)) {
      paste(tail(readLines(log_path, warn = FALSE), 20L), collapse = "\n")
    } else {
      "PLINK did not create a log"
    }
    stop("PLINK clumping failed:\n", details, call. = FALSE)
  }
  parse_plink_clumped(paste0(output_prefix, ".clumped"))
}

instrument_tier_spec <- function(config) {
  data.frame(
    tier = c("primary", "exploratory"),
    p_threshold = c(
      config$instruments$primary_p, config$instruments$exploratory_p
    ),
    stringsAsFactors = FALSE
  )
}

instrument_task_plan <- function(n_groups, n_tiers) {
  if (!is.numeric(n_groups) || length(n_groups) != 1L || is.na(n_groups) ||
      n_groups <= 0 || n_groups != floor(n_groups) ||
      !is.numeric(n_tiers) || length(n_tiers) != 1L || is.na(n_tiers) ||
      n_tiers <= 0 || n_tiers != floor(n_tiers)) {
    stop("n_groups and n_tiers must be positive integers", call. = FALSE)
  }
  unlist(lapply(seq_len(n_tiers), function(tier_index) {
    lapply(seq_len(n_groups), function(group_index) {
      c(group_index = group_index, tier_index = tier_index)
    })
  }), recursive = FALSE)
}

build_one_instrument_set <- function(
  x, tier, p_threshold, min_f, plink_binary, bfile_prefix,
  reference_ancestry, r2, kb
) {
  selected <- select_by_p(x, p_threshold)
  strong <- filter_strong_iv(selected, min_f)
  mapped <- strong[!is.na(strong$reference_id), , drop = FALSE]
  retained_ids <- clump_local(
    mapped, requested_ancestry = unique(x$ancestry),
    reference_ancestry = reference_ancestry, plink_binary = plink_binary,
    bfile_prefix = bfile_prefix, p_threshold = p_threshold, r2 = r2, kb = kb
  )
  retained <- mapped[match(retained_ids, mapped$reference_id), , drop = FALSE]
  retained <- retained[!is.na(retained$reference_id), , drop = FALSE]
  if (nrow(retained)) {
    retained$tier <- tier
    retained$p_threshold <- p_threshold
  }
  exclusion_reason <- if (!nrow(selected)) {
    "no_variant_below_threshold"
  } else if (!nrow(strong)) {
    "no_strong_instrument"
  } else if (!nrow(mapped)) {
    "no_allele_matched_reference_variant"
  } else if (!nrow(retained)) {
    "no_variant_after_clumping"
  } else {
    ""
  }
  inventory <- data.frame(
    dataset = unique(x$dataset), source_id = unique(x$source_id),
    trait = unique(x$trait), ancestry = unique(x$ancestry),
    genome_build = unique(x$build), tier = tier,
    p_threshold = p_threshold, candidate_snps = nrow(selected),
    strong_snps = nrow(strong), mapped_snps = nrow(mapped),
    post_clump_snps = nrow(retained),
    min_f = if (nrow(retained)) min(retained$F) else NA_real_,
    mean_f = if (nrow(retained)) mean(retained$F) else NA_real_,
    exclusion_reason = exclusion_reason,
    stringsAsFactors = FALSE
  )
  list(inventory = inventory, instruments = retained)
}

build_instrument_inventory <- function(
  candidate_root = "03_data/processed/exposure_candidates",
  reference_map_path =
    paste0(
      "08_qc/download_cache/ld_reference_high_density/",
      "candidate_pvar_matches_chr_normalized.tsv"
    ),
  project_config_path = "config/project.yml",
  plink_binary = "08_qc/download_cache/tools/plink/plink",
  bfile_prefix =
    paste0(
      "03_data/processed/ld_reference_high_density/",
      "eur_candidate_chr_normalized_v2"
    ),
  inventory_path = "05_results/tables/instrument_inventory.csv",
  instrument_path = "03_data/processed/instruments/instruments.parquet",
  qc_path = "08_qc/clumping/clumping_run_receipt.csv",
  mapping_audit_path = "08_qc/ld_reference_mapping_audit.csv",
  unmapped_primary_path = "08_qc/ld_reference_unmapped_primary.csv",
  workers = 4L,
  reference_build = "GRCh37",
  reference_ancestry = "EUR"
) {
  if (!is.numeric(workers) || length(workers) != 1L || is.na(workers) ||
      workers <= 0 || workers != floor(workers)) {
    stop("workers must be a positive integer", call. = FALSE)
  }
  config <- read_project_config(project_config_path)
  candidates <- read_exposure_candidate_shards(candidate_root)
  reference_map <- read_reference_variant_map(
    reference_map_path, build = reference_build
  )
  candidates <- map_candidates_to_reference(
    candidates, reference_map, reference_build = reference_build
  )
  group_key <- paste(candidates$dataset, candidates$source_id, sep = "\r")
  groups <- split(seq_len(nrow(candidates)), factor(
    group_key, levels = unique(group_key)
  ))
  tiers <- instrument_tier_spec(config)
  tasks <- instrument_task_plan(length(groups), nrow(tiers))
  worker <- function(task) {
    x <- candidates[groups[[task[["group_index"]]]], , drop = FALSE]
    tier <- tiers[task[["tier_index"]], , drop = FALSE]
    build_one_instrument_set(
      x, tier = tier$tier, p_threshold = tier$p_threshold,
      min_f = config$instruments$min_f, plink_binary = plink_binary,
      bfile_prefix = bfile_prefix, reference_ancestry = reference_ancestry,
      r2 = config$ld$eur$r2, kb = config$ld$eur$kb
    )
  }
  results <- if (.Platform$OS.type == "unix" && workers > 1L) {
    parallel::mclapply(
      tasks, worker, mc.cores = as.integer(workers), mc.preschedule = TRUE
    )
  } else {
    lapply(tasks, worker)
  }
  failed <- vapply(results, inherits, logical(1), what = "try-error")
  if (any(failed)) {
    stop(
      "Instrument construction failed: ",
      paste(unique(as.character(results[failed])), collapse = " | "),
      call. = FALSE
    )
  }
  inventory <- data.table::rbindlist(lapply(results, `[[`, "inventory"))
  instrument_parts <- lapply(results, `[[`, "instruments")
  instrument_parts <- instrument_parts[vapply(instrument_parts, nrow, integer(1)) > 0L]
  instruments <- if (length(instrument_parts)) {
    data.table::rbindlist(instrument_parts, use.names = TRUE, fill = TRUE)
  } else {
    data.frame()
  }
  inventory <- as.data.frame(inventory)
  inventory <- inventory[order(
    inventory$dataset, inventory$source_id,
    match(inventory$tier, c("primary", "exploratory"))
  ), , drop = FALSE]
  dir.create(dirname(inventory_path), recursive = TRUE, showWarnings = FALSE)
  atomic_write_csv(inventory, inventory_path)
  dir.create(dirname(instrument_path), recursive = TRUE, showWarnings = FALSE)
  write_candidate_parquet_atomic(as.data.frame(instruments), instrument_path)

  audit_keys <- unique(inventory[, c("dataset", "tier")])
  mapping_audit <- do.call(rbind, lapply(seq_len(nrow(audit_keys)), function(i) {
    rows <- inventory$dataset == audit_keys$dataset[[i]] &
      inventory$tier == audit_keys$tier[[i]]
    data.frame(
      dataset = audit_keys$dataset[[i]], tier = audit_keys$tier[[i]],
      traits = sum(rows),
      traits_below_threshold = sum(inventory$candidate_snps[rows] > 0),
      traits_with_mapped_variant = sum(inventory$mapped_snps[rows] > 0),
      candidate_rows = sum(inventory$candidate_snps[rows]),
      strong_rows = sum(inventory$strong_snps[rows]),
      mapped_rows = sum(inventory$mapped_snps[rows]),
      mapping_coverage = if (sum(inventory$strong_snps[rows]) > 0) {
        sum(inventory$mapped_snps[rows]) / sum(inventory$strong_snps[rows])
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }))
  mapping_audit <- mapping_audit[order(
    mapping_audit$dataset,
    match(mapping_audit$tier, c("primary", "exploratory"))
  ), , drop = FALSE]
  atomic_write_csv(mapping_audit, mapping_audit_path)

  primary_candidates <- filter_strong_iv(
    select_by_p(candidates, config$instruments$primary_p),
    config$instruments$min_f
  )
  unmapped_primary <- primary_candidates[
    is.na(primary_candidates$reference_id), , drop = FALSE
  ]
  unmapped_columns <- c(
    "dataset", "source_id", "trait", "chr", "pos", "snp", "variant_id",
    "ea", "oa", "eaf", "p", "F", "reference_mapping_status"
  )
  atomic_write_csv(
    unmapped_primary[, unmapped_columns, drop = FALSE], unmapped_primary_path
  )

  version <- system2(plink_binary, "--version", stdout = TRUE, stderr = TRUE)
  receipt <- data.frame(
    completed_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    plink_version = paste(version, collapse = " "),
    reference_build = reference_build,
    reference_ancestry = reference_ancestry,
    reference_variant_count = length(readLines(
      paste0(bfile_prefix, ".bim"), warn = FALSE
    )),
    reference_sample_count = length(readLines(
      paste0(bfile_prefix, ".fam"), warn = FALSE
    )),
    reference_map_sha256 = digest::digest(
      file = reference_map_path, algo = "sha256", serialize = FALSE
    ),
    reference_bed_sha256 = digest::digest(
      file = paste0(bfile_prefix, ".bed"), algo = "sha256", serialize = FALSE
    ),
    reference_bim_sha256 = digest::digest(
      file = paste0(bfile_prefix, ".bim"), algo = "sha256", serialize = FALSE
    ),
    reference_fam_sha256 = digest::digest(
      file = paste0(bfile_prefix, ".fam"), algo = "sha256", serialize = FALSE
    ),
    r2 = config$ld$eur$r2, kb = config$ld$eur$kb,
    min_f = config$instruments$min_f,
    primary_p = config$instruments$primary_p,
    exploratory_p = config$instruments$exploratory_p,
    trait_tier_jobs = nrow(inventory),
    retained_instrument_rows = nrow(instruments),
    inventory_sha256 = digest::digest(
      file = inventory_path, algo = "sha256", serialize = FALSE
    ),
    instrument_sha256 = digest::digest(
      file = instrument_path, algo = "sha256", serialize = FALSE
    ),
    stringsAsFactors = FALSE
  )
  dir.create(dirname(qc_path), recursive = TRUE, showWarnings = FALSE)
  atomic_write_csv(receipt, qc_path)
  invisible(list(inventory = inventory, instruments = as.data.frame(instruments)))
}
