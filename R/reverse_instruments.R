extract_ed_gws_candidates <- function(
  input_path = "03_data/processed/outcomes/ed_2025/ed_eur_meta.gz",
  output_path = "03_data/processed/reverse/ed_2025_eur_gws.tsv",
  threshold = 5e-8,
  awk_script = "scripts/extract_p_threshold.awk"
) {
  input_path <- normalizePath(input_path, mustWork = TRUE)
  awk_script <- normalizePath(awk_script, mustWork = TRUE)
  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(output_path, ".tmp-", Sys.getpid())
  log_path <- paste0(output_path, ".log-", Sys.getpid())
  on.exit(unlink(c(temporary, log_path)), add = TRUE)
  command <- paste(
    "LC_ALL=C /usr/bin/gzip -dc", shQuote(input_path), "|",
    "LC_ALL=C /usr/bin/awk -v",
    paste0("threshold=", format(
      threshold, scientific = TRUE, digits = 17L
    )),
    "-f", shQuote(awk_script), "-"
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
    stop("ED instrument extraction failed: ", details, call. = FALSE)
  }
  if (!file.rename(temporary, output_path)) {
    stop("Could not atomically replace ED GWS extract", call. = FALSE)
  }
  invisible(output_path)
}

normalize_reverse_ed_candidates <- function(x) {
  normalized <- normalize_ed_meta_outcome(
    x, outcome_id = "ed_2025_eur", ancestry = "EUR",
    cases = 136867, controls = 913194 - 136867
  )
  result <- data.frame(
    snp = normalized$rsid,
    variant_id = paste(
      normalized$chr, normalized$pos, normalized$oa, normalized$ea, sep = "_"
    ),
    variant_key = make_variant_key(
      normalized$chr, normalized$pos, normalized$oa, normalized$ea
    ),
    chr = normalized$chr, pos = normalized$pos,
    ea = normalized$ea, oa = normalized$oa,
    beta = normalized$beta, se = normalized$se, z = normalized$z,
    eaf = normalized$eaf, p = normalized$p,
    n = normalized$sample_weight, build = normalized$build,
    ancestry = "EUR", role = "exposure", source_id = "ed_2025_eur",
    trait = "Erectile dysfunction", dataset = "ed_2025",
    effect_scale = normalized$effect_scale,
    analysis_role = "reverse_sensitivity",
    stringsAsFactors = FALSE
  )
  result <- add_f_stat(result)
  if (anyDuplicated(result$snp)) {
    stop("ED GWS candidates contain duplicate rsIDs", call. = FALSE)
  }
  result
}

read_bim_variant_map <- function(path) {
  x <- data.table::fread(
    path, header = FALSE, data.table = FALSE,
    col.names = c("reference_chr", "reference_id", "cm", "reference_pos",
                  "reference_a1", "reference_a2"),
    colClasses = c("character", "character", "numeric", "numeric",
                   "character", "character"),
    showProgress = FALSE
  )
  x$reference_chr <- normalize_match_chromosome(x$reference_chr)
  x$reference_a1 <- toupper(x$reference_a1)
  x$reference_a2 <- toupper(x$reference_a2)
  if (anyDuplicated(x$reference_id)) {
    stop("ED LD panel BIM has duplicate reference IDs", call. = FALSE)
  }
  x
}

map_reverse_ed_to_ld_panel <- function(candidates, reference_map) {
  index <- match(candidates$snp, reference_map$reference_id)
  result <- candidates
  result$reference_id <- reference_map$reference_id[index]
  result$reference_chr <- reference_map$reference_chr[index]
  result$reference_pos <- reference_map$reference_pos[index]
  result$reference_a1 <- reference_map$reference_a1[index]
  result$reference_a2 <- reference_map$reference_a2[index]
  same_chromosome <- normalize_match_chromosome(result$chr) ==
    result$reference_chr
  exact <- (result$ea == result$reference_a1 &
              result$oa == result$reference_a2) |
    (result$ea == result$reference_a2 & result$oa == result$reference_a1)
  complement <- (complement_allele(result$ea) == result$reference_a1 &
                   complement_allele(result$oa) == result$reference_a2) |
    (complement_allele(result$ea) == result$reference_a2 &
       complement_allele(result$oa) == result$reference_a1)
  result$reference_mapping_status <- ifelse(
    is.na(index), "not_in_reference",
    ifelse(!same_chromosome, "chromosome_mismatch",
           ifelse(exact | complement, "allele_match", "allele_mismatch"))
  )
  result$reference_id[
    result$reference_mapping_status != "allele_match"
  ] <- NA_character_
  result
}

build_reverse_ed_instruments <- function(
  gws_extract_path = "03_data/processed/reverse/ed_2025_eur_gws.tsv",
  output_root = "03_data/processed/reverse",
  full_pfile_prefix =
    "08_qc/download_cache/ld_reference_high_density/all_phase3",
  eur_keep_path =
    "08_qc/download_cache/ld_reference_high_density/eur_samples.keep",
  plink2_binary =
    "08_qc/download_cache/ld_reference_high_density/plink2/plink2",
  plink1_binary = "08_qc/download_cache/tools/plink/plink",
  inventory_path = "08_qc/reverse_ed_instrument_inventory.csv",
  receipt_path = "08_qc/reverse_ed_instrument_receipt.csv",
  threshold = 5e-8, r2 = 0.001, kb = 10000, workers = 8L
) {
  raw <- data.table::fread(
    gws_extract_path, data.table = FALSE, check.names = FALSE,
    showProgress = FALSE
  )
  candidates <- normalize_reverse_ed_candidates(raw)
  candidates <- candidates[candidates$p < threshold & candidates$F > 10, ]
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)
  candidate_path <- file.path(output_root, "ed_2025_eur_gws.parquet")
  write_candidate_parquet_atomic(candidates, candidate_path)
  id_path <- file.path(output_root, "ed_2025_eur_gws_ids.txt")
  writeLines(sort(unique(candidates$snp)), id_path, useBytes = TRUE)

  panel_prefix <- file.path(output_root, "ed_2025_eur_ld_panel")
  log_path <- paste0(panel_prefix, ".build.log")
  status <- system2(
    plink2_binary,
    c(
      "--pfile", shQuote(full_pfile_prefix), "vzs",
      "--keep", shQuote(eur_keep_path),
      "--extract", shQuote(id_path), "--max-alleles", "2",
      "--snps-only", "just-acgt", "--threads", as.character(workers),
      "--make-bed", "--out", shQuote(panel_prefix)
    ),
    stdout = log_path, stderr = log_path
  )
  if (!identical(as.integer(status), 0L)) {
    stop(
      "PLINK2 reverse ED panel build failed:\n",
      paste(tail(readLines(log_path, warn = FALSE), 30L), collapse = "\n"),
      call. = FALSE
    )
  }
  reference <- read_bim_variant_map(paste0(panel_prefix, ".bim"))
  mapped <- map_reverse_ed_to_ld_panel(candidates, reference)
  retained_ids <- clump_local(
    mapped, requested_ancestry = "EUR", reference_ancestry = "EUR",
    plink_binary = plink1_binary, bfile_prefix = panel_prefix,
    p_threshold = threshold, r2 = r2, kb = kb
  )
  instruments <- mapped[match(retained_ids, mapped$reference_id), ]
  instruments <- instruments[!is.na(instruments$reference_id), ]
  instruments$tier <- "primary"
  instruments$p_threshold <- threshold
  instrument_path <- file.path(output_root, "reverse_ed_instruments.parquet")
  write_candidate_parquet_atomic(instruments, instrument_path)

  inventory <- data.frame(
    exposure_id = "ed_2025_eur", ancestry = "EUR", genome_build = "GRCh38",
    effect_scale = unique(candidates$effect_scale), p_threshold = threshold,
    candidate_snps = nrow(candidates), strong_snps = sum(candidates$F > 10),
    reference_panel_snps = nrow(reference),
    allele_mapped_snps = sum(mapped$reference_mapping_status == "allele_match"),
    post_clump_snps = nrow(instruments), min_F = min(instruments$F),
    mean_F = mean(instruments$F), r2 = r2, kb = kb,
    stringsAsFactors = FALSE
  )
  atomic_write_csv(inventory, inventory_path)
  panel_paths <- paste0(panel_prefix, c(".bed", ".bim", ".fam"))
  receipt <- data.frame(
    gws_extract_sha256 = digest::digest(
      file = gws_extract_path, algo = "sha256", serialize = FALSE
    ),
    candidate_sha256 = digest::digest(
      file = candidate_path, algo = "sha256", serialize = FALSE
    ),
    instrument_sha256 = digest::digest(
      file = instrument_path, algo = "sha256", serialize = FALSE
    ),
    panel_bed_sha256 = digest::digest(
      file = panel_paths[[1L]], algo = "sha256", serialize = FALSE
    ),
    panel_bim_sha256 = digest::digest(
      file = panel_paths[[2L]], algo = "sha256", serialize = FALSE
    ),
    panel_fam_sha256 = digest::digest(
      file = panel_paths[[3L]], algo = "sha256", serialize = FALSE
    ),
    plink2_version = paste(system2(plink2_binary, "--version", stdout = TRUE),
                           collapse = " "),
    plink1_version = paste(system2(plink1_binary, "--version", stdout = TRUE),
                           collapse = " "),
    source_reference_build = "GRCh37",
    association_build = "GRCh38",
    matching_basis = "rsID_chromosome_and_alleles_across_declared_builds",
    completed_at_utc = format(
      Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
    ), stringsAsFactors = FALSE
  )
  atomic_write_csv(receipt, receipt_path)
  invisible(list(inventory = inventory, instruments = instruments))
}
