GWAS_CANONICAL_COLUMNS <- c(
  "snp", "variant_id", "variant_key", "chr", "pos", "ea", "oa",
  "beta", "se", "z", "eaf", "p", "n", "build", "ancestry", "role",
  "source_id", "trait"
)

GWAS_HEADER_ALIASES <- list(
  snp = c("snp", "rs_id", "rsid", "rsids"),
  variant_id = c("variant_id", "markername"),
  chr = c("chr", "chrom", "chromosome"),
  pos = c("pos", "bp", "base_pair_location"),
  ea = c("ea", "a1", "effect_allele", "allele1", "alt"),
  oa = c("oa", "a2", "other_allele", "allele2", "ref"),
  beta = "beta",
  se = c("se", "standard_error", "sebeta"),
  z = c("z", "zscore"),
  eaf = c("eaf", "effect_allele_frequency", "af_alt"),
  p = c("p", "p_value", "pval"),
  n = c("n", "sample_size")
)

normalize_gwas_header <- function(x) {
  x <- sub("^#", "", trimws(as.character(x)))
  x <- tolower(gsub("[^A-Za-z0-9]+", "_", x))
  gsub("^_+|_+$", "", x)
}

map_gwas_headers <- function(headers) {
  normalized <- normalize_gwas_header(headers)
  mapped <- lapply(names(GWAS_HEADER_ALIASES), function(field) {
    which(normalized %in% GWAS_HEADER_ALIASES[[field]])
  })
  names(mapped) <- names(GWAS_HEADER_ALIASES)

  ambiguous <- names(mapped)[lengths(mapped) > 1L]
  if (length(ambiguous)) {
    details <- vapply(ambiguous, function(field) {
      paste(headers[mapped[[field]]], collapse = ", ")
    }, character(1))
    stop(
      "Ambiguous GWAS header mapping for ",
      paste(sprintf("%s [%s]", ambiguous, details), collapse = "; "),
      call. = FALSE
    )
  }
  mapped
}

gwas_column <- function(x, mapping, field, default = NA) {
  index <- mapping[[field]]
  if (!length(index)) {
    return(rep(default, nrow(x)))
  }
  x[[index]]
}

as_gwas_number <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

extract_first_rsid <- function(x) {
  x <- as.character(x)
  searchable <- x
  searchable[is.na(searchable)] <- ""
  match <- regexpr("(?i)rs[0-9]+", searchable, perl = TRUE)
  match_length <- attr(match, "match.length")
  result <- rep(NA_character_, length(x))
  hit <- match > 0L
  result[hit] <- tolower(substr(
    searchable[hit], match[hit], match[hit] + match_length[hit] - 1L
  ))
  result
}

make_variant_key <- function(chr, pos, ea, oa) {
  first <- pmin(ea, oa)
  second <- pmax(ea, oa)
  paste(chr, format(pos, scientific = FALSE, trim = TRUE), first, second, sep = ":")
}

validate_gwas_context <- function(role, build, ancestry, sample_size, source_id, trait) {
  if (!is.character(role) || length(role) != 1L || is.na(role) ||
      !role %in% c("exposure", "outcome")) {
    stop("GWAS role must be exposure or outcome", call. = FALSE)
  }
  for (value in list(build = build, ancestry = ancestry,
                     source_id = source_id, trait = trait)) {
    if (!is.character(value) || length(value) != 1L || is.na(value) ||
        !nzchar(trimws(value))) {
      stop("GWAS build, ancestry, source_id, and trait must be non-empty strings",
           call. = FALSE)
    }
  }
  if (!is.null(sample_size) &&
      (!is.numeric(sample_size) || length(sample_size) != 1L ||
       is.na(sample_size) || !is.finite(sample_size) || sample_size <= 0)) {
    stop("GWAS sample_size must be one positive finite number", call. = FALSE)
  }
  invisible(TRUE)
}

normalize_gwas_frame <- function(
  x, role, build, ancestry, sample_size = NULL, source_id, trait
) {
  validate_gwas_context(role, build, ancestry, sample_size, source_id, trait)
  if (!is.data.frame(x)) {
    stop("GWAS input must be a data frame", call. = FALSE)
  }
  mapping <- map_gwas_headers(names(x))
  required <- c("chr", "pos", "ea", "oa", "p")
  missing <- required[lengths(mapping[required]) == 0L]
  if (length(missing)) {
    stop("Missing required GWAS columns: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  if (!length(mapping$snp) && !length(mapping$variant_id)) {
    stop("Missing required GWAS variant identifier", call. = FALSE)
  }

  raw_id <- gwas_column(x, mapping, "snp", NA_character_)
  snp <- extract_first_rsid(raw_id)
  variant_id <- as.character(gwas_column(x, mapping, "variant_id", NA_character_))
  variant_id[is.na(variant_id) | !nzchar(variant_id)] <- NA_character_

  chr <- toupper(sub("^chr", "", as.character(
    gwas_column(x, mapping, "chr")
  ), ignore.case = TRUE))
  pos <- as_gwas_number(gwas_column(x, mapping, "pos"))
  ea <- toupper(as.character(gwas_column(x, mapping, "ea")))
  oa <- toupper(as.character(gwas_column(x, mapping, "oa")))
  observed_n <- as_gwas_number(gwas_column(x, mapping, "n"))
  if (!length(mapping$n) && !is.null(sample_size)) {
    observed_n <- rep(as.numeric(sample_size), nrow(x))
  }

  result <- data.frame(
    snp = snp,
    variant_id = variant_id,
    variant_key = make_variant_key(chr, pos, ea, oa),
    chr = chr,
    pos = pos,
    ea = ea,
    oa = oa,
    beta = as_gwas_number(gwas_column(x, mapping, "beta")),
    se = as_gwas_number(gwas_column(x, mapping, "se")),
    z = as_gwas_number(gwas_column(x, mapping, "z")),
    eaf = as_gwas_number(gwas_column(x, mapping, "eaf")),
    p = as_gwas_number(gwas_column(x, mapping, "p")),
    n = observed_n,
    build = rep(build, nrow(x)),
    ancestry = rep(ancestry, nrow(x)),
    role = rep(role, nrow(x)),
    source_id = rep(source_id, nrow(x)),
    trait = rep(trait, nrow(x)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  result <- result[, GWAS_CANONICAL_COLUMNS, drop = FALSE]
  result <- result[!duplicated(result), , drop = FALSE]
  rownames(result) <- NULL
  validate_gwas(result)
  result
}

validate_gwas <- function(x) {
  if (!is.data.frame(x) || !identical(names(x), GWAS_CANONICAL_COLUMNS)) {
    stop("GWAS table does not have the canonical schema", call. = FALSE)
  }
  if (!nrow(x)) {
    return(invisible(TRUE))
  }
  if (any(is.na(x$chr) | !nzchar(x$chr)) ||
      any(is.na(x$pos) | !is.finite(x$pos) | x$pos <= 0 | x$pos != floor(x$pos))) {
    stop("Invalid chromosome or base-pair position", call. = FALSE)
  }
  valid_allele <- function(value) !is.na(value) & grepl("^[ACGT]$", value)
  if (any(!valid_allele(x$ea)) || any(!valid_allele(x$oa)) ||
      any(x$ea == x$oa, na.rm = TRUE)) {
    stop("Invalid allele encoding in GWAS table", call. = FALSE)
  }
  if (any(is.na(x$p) | !is.finite(x$p) | x$p <= 0 | x$p > 1)) {
    stop("Invalid p-value in GWAS table", call. = FALSE)
  }
  if (any(is.na(x$n) | !is.finite(x$n) | x$n <= 0)) {
    stop("Invalid sample size in GWAS table", call. = FALSE)
  }
  if (any(!is.na(x$eaf) & (!is.finite(x$eaf) | x$eaf <= 0 | x$eaf >= 1))) {
    stop("Invalid effect-allele frequency in GWAS table", call. = FALSE)
  }

  exposure <- x$role == "exposure"
  if (any(exposure & (is.na(x$beta) | !is.finite(x$beta)))) {
    stop("Exposure GWAS is missing a finite beta", call. = FALSE)
  }
  if (any(exposure & (is.na(x$se) | !is.finite(x$se) | x$se <= 0))) {
    stop("Exposure GWAS has an invalid standard error", call. = FALSE)
  }
  if (any(exposure & (is.na(x$eaf) | !is.finite(x$eaf)))) {
    stop("Exposure GWAS is missing effect-allele frequency", call. = FALSE)
  }

  outcome <- x$role == "outcome"
  has_beta_se <- !is.na(x$beta) & is.finite(x$beta) &
    !is.na(x$se) & is.finite(x$se) & x$se > 0
  has_z <- !is.na(x$z) & is.finite(x$z)
  if (any(outcome & !has_beta_se & !has_z)) {
    stop("Outcome GWAS requires beta and standard error or a finite z score",
         call. = FALSE)
  }
  if (any(!is.na(x$se) & (!is.finite(x$se) | x$se <= 0))) {
    stop("GWAS has an invalid standard error", call. = FALSE)
  }
  source_variant_key <- paste(x$source_id, x$variant_key, sep = "\r")
  if (anyDuplicated(source_variant_key)) {
    stop("Duplicate orientation-independent variant keys within one GWAS",
         call. = FALSE)
  }
  invisible(TRUE)
}

validate_gwas_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !nzchar(path)) {
    stop("GWAS path must be one non-empty string", call. = FALSE)
  }
  if (startsWith(basename(path), "._")) {
    stop("AppleDouble metadata files are not valid GWAS inputs", call. = FALSE)
  }
  if (!file.exists(path)) {
    stop("Missing GWAS input: ", path, call. = FALSE)
  }
  resolved <- normalizePath(path, mustWork = TRUE)
  if (grepl("[\r\n]", resolved)) {
    stop("GWAS path contains a forbidden control character", call. = FALSE)
  }
  resolved
}

read_gwas_table <- function(path) {
  path <- validate_gwas_path(path)
  if (grepl("\\.gz$", path, ignore.case = TRUE)) {
    command <- paste("/usr/bin/gzip -dc", shQuote(path))
    return(data.table::fread(
      cmd = command, data.table = FALSE, check.names = FALSE,
      showProgress = FALSE
    ))
  }
  data.table::fread(
    path, data.table = FALSE, check.names = FALSE, showProgress = FALSE
  )
}

normalize_gwas <- function(
  path, role, build, ancestry, sample_size = NULL, source_id, trait
) {
  normalize_gwas_frame(
    read_gwas_table(path), role = role, build = build, ancestry = ancestry,
    sample_size = sample_size, source_id = source_id, trait = trait
  )
}

read_gwas_header <- function(path) {
  path <- validate_gwas_path(path)
  connection <- if (grepl("\\.gz$", path, ignore.case = TRUE)) {
    gzfile(path, open = "rt")
  } else {
    file(path, open = "rt")
  }
  on.exit(close(connection), add = TRUE)
  line <- readLines(connection, n = 1L, warn = FALSE)
  if (!length(line)) {
    stop("GWAS input is empty: ", path, call. = FALSE)
  }
  strsplit(line, "\t", fixed = TRUE)[[1L]]
}

read_gwas_candidates <- function(path, p_threshold) {
  path <- validate_gwas_path(path)
  if (!is.numeric(p_threshold) || length(p_threshold) != 1L ||
      is.na(p_threshold) || !is.finite(p_threshold) ||
      p_threshold <= 0 || p_threshold > 1) {
    stop("Candidate p_threshold must be a finite number in (0, 1]",
         call. = FALSE)
  }
  headers <- read_gwas_header(path)
  mapping <- map_gwas_headers(headers)
  if (!length(mapping$p)) {
    stop("Missing required GWAS p-value column", call. = FALSE)
  }

  reader <- if (grepl("\\.gz$", path, ignore.case = TRUE)) {
    paste("/usr/bin/gzip -dc", shQuote(path))
  } else {
    paste("/bin/cat", shQuote(path))
  }
  threshold <- format(p_threshold, scientific = TRUE, digits = 17L)
  awk <- paste0(
    "/usr/bin/awk -F '\\t' -v OFS='\\t' -v c=", mapping$p,
    " -v th=", threshold,
    " 'NR == 1 { print; next } ",
    "$c != \"\" && $c != \"NA\" && ($c + 0) < th { print }'"
  )
  data.table::fread(
    cmd = paste(reader, "|", awk), data.table = FALSE,
    check.names = FALSE, showProgress = FALSE
  )
}

extract_gwas_candidates <- function(
  path, p_threshold, role, build, ancestry, sample_size = NULL,
  source_id, trait
) {
  normalize_gwas_frame(
    read_gwas_candidates(path, p_threshold), role = role, build = build,
    ancestry = ancestry, sample_size = sample_size, source_id = source_id,
    trait = trait
  )
}

canonicalize_microbiome_trait <- function(trait) {
  if (!is.character(trait) || anyNA(trait) || any(!nzchar(trimws(trait)))) {
    stop("Microbiome trait descriptions must be non-empty strings", call. = FALSE)
  }
  vapply(trait, function(value) {
    value <- trimws(value)
    opening <- regexpr("(", value, fixed = TRUE)
    if (opening < 1L || !endsWith(value, ")")) {
      stop("Unrecognized microbiome trait description: ", value, call. = FALSE)
    }
    label <- substr(value, opening + 1L, nchar(value) - 1L)
    if (grepl("alpha diversity", value, ignore.case = TRUE)) {
      label <- tolower(trimws(label))
      if (grepl("^shannon(?: diversity| index)?$", label)) {
        return("alpha:shannon")
      }
      if (identical(label, "richness")) {
        return("alpha:richness")
      }
      label <- gsub("[^a-z0-9]+", "_", label)
      return(paste0("alpha:", gsub("^_+|_+$", "", label)))
    }

    if (grepl("function abundance", value, ignore.case = TRUE)) {
      identifier <- sub(
        "^.*[,;]\\s*([A-Za-z][A-Za-z0-9_.-]*[0-9])\\s*$", "\\1", label,
        perl = TRUE
      )
      if (identical(identifier, label)) {
        stop("Microbiome function is missing a stable identifier: ", value,
             call. = FALSE)
      }
      return(paste0("function:", tolower(identifier)))
    }

    label <- sub("^hMGS\\.[0-9]+:\\s*", "", label, ignore.case = TRUE)
    label <- sub(
      ",\\s*(?:GCA|GCF)_[0-9]+(?:\\.[0-9]+)?\\s*$", "", label,
      ignore.case = TRUE, perl = TRUE
    )
    label <- tolower(gsub("[[:space:]]+", " ", trimws(label)))
    if (!nzchar(label)) {
      stop("Microbiome trait description has an empty taxon: ", value,
           call. = FALSE)
    }
    paste0("taxon:", label)
  }, character(1), USE.NAMES = FALSE)
}

read_gwas_metadata <- function(path, dataset = NA_character_) {
  path <- validate_gwas_path(path)
  metadata <- tryCatch(
    yaml::read_yaml(
      path, handlers = list(int = function(value) as.numeric(value))
    ),
    error = function(error) {
      stop("Invalid GWAS metadata YAML: ", conditionMessage(error), call. = FALSE)
    }
  )
  required <- c(
    "gwas_id", "trait_description", "genome_assembly", "samples",
    "data_file_name"
  )
  missing <- required[vapply(required, function(key) {
    is.null(metadata[[key]])
  }, logical(1))]
  if (length(missing)) {
    stop("GWAS metadata is missing: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  trait <- unlist(metadata$trait_description, use.names = FALSE)
  if (!is.character(trait) || length(trait) != 1L || is.na(trait) ||
      !nzchar(trimws(trait))) {
    stop("GWAS metadata must describe exactly one trait", call. = FALSE)
  }
  samples <- metadata$samples
  if (!is.list(samples) || !length(samples)) {
    stop("GWAS metadata must contain sample records", call. = FALSE)
  }
  sample_sizes <- vapply(samples, function(sample) {
    value <- suppressWarnings(as.numeric(sample$sample_size))
    if (length(value) != 1L || is.na(value) || !is.finite(value) || value <= 0) {
      stop("GWAS metadata has an invalid sample_size", call. = FALSE)
    }
    value
  }, numeric(1))
  ancestry <- unique(unlist(lapply(samples, function(sample) {
    sample$sample_ancestry_category
  }), use.names = FALSE))
  ancestry <- ancestry[!is.na(ancestry) & nzchar(ancestry)]

  data.frame(
    dataset = as.character(dataset),
    source_id = as.character(metadata$gwas_id),
    trait = trait,
    canonical_trait_id = canonicalize_microbiome_trait(trait),
    sample_size = sum(sample_sizes),
    genome_build = as.character(metadata$genome_assembly),
    ancestry_description = paste(ancestry, collapse = "; "),
    data_file_name = as.character(metadata$data_file_name),
    metadata_path = path,
    stringsAsFactors = FALSE
  )
}

build_microbiome_metadata_catalog <- function(
  manifest_path = "MANIFEST.csv", project_root = getwd(), workers = 1L
) {
  if (!is.numeric(workers) || length(workers) != 1L || is.na(workers) ||
      !is.finite(workers) || workers <= 0 || workers != floor(workers)) {
    stop("Metadata workers must be a positive integer", call. = FALSE)
  }
  workers <- as.integer(workers)
  manifest <- data.table::fread(
    manifest_path, data.table = FALSE, check.names = FALSE,
    showProgress = FALSE
  )
  required <- c("dataset", "source_id", "file_name", "path")
  missing <- setdiff(required, names(manifest))
  if (length(missing)) {
    stop("Manifest is missing: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  datasets <- c("microbiome_2026", "microbiome_2026_hunt")
  metadata_rows <- manifest[
    manifest$dataset %in% datasets & grepl("-meta\\.yaml$", manifest$file_name),
    , drop = FALSE
  ]
  payload_rows <- manifest[
    manifest$dataset %in% datasets & !grepl("-meta\\.yaml$", manifest$file_name),
    , drop = FALSE
  ]
  key <- function(x) paste(x$dataset, x$source_id, sep = "\r")
  if (anyDuplicated(key(metadata_rows)) || anyDuplicated(key(payload_rows)) ||
      !setequal(key(metadata_rows), key(payload_rows))) {
    stop("Manifest must contain exactly one payload and metadata file per microbiome accession",
         call. = FALSE)
  }

  parse_row <- function(index) {
    row <- metadata_rows[index, , drop = FALSE]
    metadata_path <- file.path(project_root, row$path)
    parsed <- read_gwas_metadata(metadata_path, dataset = row$dataset)
    if (!identical(parsed$source_id, row$source_id)) {
      stop("Metadata accession does not match manifest: ", row$source_id,
           call. = FALSE)
    }
    payload <- payload_rows[key(payload_rows) == key(row), , drop = FALSE]
    if (!identical(parsed$data_file_name, payload$file_name)) {
      stop("Metadata payload filename does not match manifest: ", row$source_id,
           call. = FALSE)
    }
    parsed$data_path <- normalizePath(
      file.path(project_root, payload$path), mustWork = TRUE
    )
    parsed
  }
  rows <- if (workers > 1L && .Platform$OS.type == "unix") {
    parallel::mclapply(
      seq_len(nrow(metadata_rows)), parse_row,
      mc.cores = workers, mc.preschedule = TRUE
    )
  } else {
    lapply(seq_len(nrow(metadata_rows)), parse_row)
  }
  failed <- vapply(rows, inherits, logical(1), what = "try-error")
  if (any(failed)) {
    stop("Failed to parse microbiome metadata: ", rows[[which(failed)[1L]]],
         call. = FALSE)
  }
  catalog <- do.call(rbind, rows)
  catalog <- catalog[order(catalog$dataset, catalog$source_id), , drop = FALSE]
  rownames(catalog) <- NULL
  catalog
}

match_microbiome_replication_traits <- function(catalog) {
  required <- c("dataset", "source_id", "trait", "canonical_trait_id")
  if (!is.data.frame(catalog) || length(setdiff(required, names(catalog)))) {
    stop("Microbiome catalog is missing required columns", call. = FALSE)
  }
  discovery <- catalog[catalog$dataset == "microbiome_2026", , drop = FALSE]
  replication <- catalog[
    catalog$dataset == "microbiome_2026_hunt", , drop = FALSE
  ]
  if (anyDuplicated(replication$canonical_trait_id)) {
    stop("HUNT canonical microbiome trait identifiers must be unique",
         call. = FALSE)
  }
  rows <- lapply(seq_len(nrow(replication)), function(index) {
    hits <- which(
      discovery$canonical_trait_id == replication$canonical_trait_id[[index]]
    )
    status <- if (!length(hits)) {
      "unmatched"
    } else if (length(hits) == 1L) {
      "matched"
    } else {
      "ambiguous_discovery_label"
    }
    data.frame(
      canonical_trait_id = replication$canonical_trait_id[[index]],
      discovery_source_id = paste(discovery$source_id[hits], collapse = ";"),
      discovery_trait = paste(discovery$trait[hits], collapse = " | "),
      replication_source_id = replication$source_id[[index]],
      replication_trait = replication$trait[[index]],
      discovery_match_count = length(hits),
      match_status = status,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}
