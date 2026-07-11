project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "catalog.R"))
source(file.path(project_root, "R", "provenance.R"))

test_that("GWAS accession maps to the correct 1000-accession bucket", {
  expect_equal(gwas_bucket("GCST90670368"), "GCST90670001-GCST90671000")
  expect_equal(gwas_accession_dir("GCST90670368"), paste0(
    "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/",
    "GCST90670001-GCST90671000/GCST90670368/"
  ))
})

test_that("Figshare file records retain id, original name, source URL and size", {
  x <- parse_figshare_files(list(files = list(list(
    id = 1,
    name = "eur.gz",
    download_url = "https://x/eur.gz",
    size = 42
  ))))
  expect_equal(
    names(x),
    c("source_id", "file_name", "source_url", "expected_bytes")
  )
  expect_equal(x$expected_bytes, 42)
})

test_that("GWAS accession syntax and inclusive ranges are strict", {
  expect_equal(
    expand_gwas_accessions("GCST90670999", "GCST90671001"),
    c("GCST90670999", "GCST90671000", "GCST90671001")
  )
  expect_error(gwas_bucket("gcst90670368"), "GCST followed by 8 digits")
  expect_error(gwas_bucket("GCST906703680"), "GCST followed by 8 digits")
  expect_error(
    expand_gwas_accessions("GCST90671001", "GCST90670999"),
    "must not exceed"
  )
})

test_that("gzip GWAS original and its exact metadata are selected", {
  accession <- "GCST90670368"
  files <- c(
    paste0(accession, ".tsv.gz"),
    paste0(accession, ".tsv.gz-meta.yaml"),
    "harmonised/", "md5sum.txt"
  )
  expect_equal(
    select_gwas_original_files(files, accession),
    c(
      paste0(accession, ".tsv.gz"),
      paste0(accession, ".tsv.gz-meta.yaml")
    )
  )
})

test_that("uncompressed GWAS original and its exact metadata are selected", {
  accession <- "GCST90671726"
  files <- c(
    paste0(accession, ".tsv"),
    paste0(accession, ".tsv-meta.yaml"),
    "harmonised/", "md5sum.txt"
  )
  expect_equal(
    select_gwas_original_files(files, accession),
    c(
      paste0(accession, ".tsv"),
      paste0(accession, ".tsv-meta.yaml")
    )
  )
})

test_that("GWAS original selection rejects ambiguity and mismatched metadata", {
  accession <- "GCST90671726"
  gz <- paste0(accession, ".tsv.gz")
  plain <- paste0(accession, ".tsv")
  gz_meta <- paste0(gz, "-meta.yaml")
  plain_meta <- paste0(plain, "-meta.yaml")

  expect_error(
    select_gwas_original_files(c(gz, plain, gz_meta, plain_meta), accession),
    "exactly one original summary-statistics file"
  )
  expect_error(
    select_gwas_original_files(c(gz_meta, plain_meta), accession),
    "exactly one original summary-statistics file"
  )
  expect_error(
    select_gwas_original_files(c(plain, gz_meta), accession),
    "exact matching metadata"
  )
  expect_error(
    select_gwas_original_files(c(plain, plain_meta, "harmonised.tsv.gz"), accession),
    "unexpected GWAS data-like file"
  )
  expect_error(
    select_gwas_original_files(c(plain, plain_meta, "analysis.log.tsv.gz"), accession),
    "unexpected GWAS data-like file"
  )
  expect_error(
    select_gwas_original_files(c(plain, plain_meta, "index.tsv"), accession),
    "unexpected GWAS data-like file"
  )
})

test_that("ED ancestry uses only configured patterns and exactly one match", {
  patterns <- list(
    EUR = "^ed_eur_(aa|ab)\\.gz$",
    AFR = "^ed_afr_(aa|ab)\\.gz$",
    cross_ancestry = "^ed_cross_(aa|ab)\\.gz$"
  )
  expect_equal(
    classify_ed_ancestry(
      c("ed_eur_aa.gz", "ed_afr_ab.gz", "ed_cross_aa.gz"), patterns
    ),
    c("EUR", "AFR", "cross_ancestry")
  )
  expect_error(classify_ed_ancestry("European ancestry.gz", patterns), "zero")
  expect_error(
    classify_ed_ancestry(
      "ed_eur_aa.gz",
      c(patterns, list(UNKNOWN = "^never$"))
    ),
    "unknown ancestry pattern keys"
  )
  ambiguous <- patterns
  ambiguous$AFR <- "^ed_eur_(aa|ab)\\.gz$"
  expect_error(classify_ed_ancestry("ed_eur_aa.gz", ambiguous), "multiple")
})

test_that("FinnGen manifest extraction is regex-bound and unique", {
  manifest <- data.frame(
    phenocode = c("N52_ERECTILE_DYSFUNCTION", "OTHER"),
    phenotype = c("Erectile dysfunction", "Other"),
    path_https = c("https://x/ed.gz", "https://x/other.gz"),
    stringsAsFactors = FALSE
  )
  row <- extract_finngen_manifest_rows(
    manifest,
    "(^|_)ERECTILE_DYSFUNCTION$|(^|_)N52($|_)"
  )
  expect_equal(row$phenocode, "N52_ERECTILE_DYSFUNCTION")
  expect_equal(row$path_https, "https://x/ed.gz")
  expect_error(
    extract_finngen_manifest_rows(manifest, "NO_MATCH"),
    "no FinnGen manifest rows"
  )
  expect_error(
    extract_finngen_manifest_rows(rbind(manifest[1L, ], manifest[1L, ]), "N52"),
    "duplicate FinnGen source identities"
  )
})

test_that("Zenodo parser selects exact EUR and AFR PLINK trios with checksums", {
  make_file <- function(population, extension, index) {
    list(
      id = paste0("id-", index),
      key = paste0("1000G_", population, ".", extension),
      size = index,
      checksum = paste0("md5:", strrep(as.character(index), 32L)),
      links = list(self = paste0(
        "https://zenodo.org/api/records/6614170/files/1000G_",
        population, ".", extension, "/content"
      ))
    )
  }
  files <- Map(
    make_file,
    rep(c("EUR", "AFR"), each = 3L),
    rep(c("bed", "bim", "fam"), 2L),
    1:6
  )
  x <- parse_zenodo_plink_files(list(id = 6614170, files = files), c("EUR", "AFR"))
  expect_equal(nrow(x), 6L)
  expect_setequal(x$ancestry, c("EUR", "AFR"))
  expect_true(all(x$checksum_algorithm == "md5"))
  expect_true(all(grepl("^[1-6]{32}$", x$expected_checksum)))
  expect_error(
    parse_zenodo_plink_files(
      list(id = 6614170, files = files[-1L]), c("EUR", "AFR")
    ),
    "exactly one Zenodo file"
  )
})

test_that("Zenodo DOI URL resolves the numeric record identity", {
  expect_equal(
    zenodo_record_id("https://doi.org/10.5281/zenodo.6614170"),
    "6614170"
  )
  expect_error(
    zenodo_record_id("https://doi.org/10.5281/not-zenodo.6614170"),
    "Zenodo DOI URL"
  )
})

valid_inventory <- function() {
  data.frame(
    dataset = c("microbiome_2026", "ed_2025"),
    source_id = c("GCST90670368", "59218637"),
    file_name = c("GCST90670368.tsv.gz", "ed_eur_meta_ac.gz"),
    source_url = c(
      paste0(
        "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/",
        "GCST90670001-GCST90671000/GCST90670368/GCST90670368.tsv.gz"
      ),
      "https://ndownloader.figshare.com/files/59218637"
    ),
    expected_bytes = c(NA_real_, 42),
    ancestry = c("EUR", "EUR"),
    genome_build = c("GRCh37", "GRCh38"),
    license = c("terms", "CC BY 4.0"),
    overlap_note = c("note a", "note b"),
    cohort_membership = c("Swedish_discovery_cohorts", "UK_Biobank;FinnGen"),
    known_overlap_datasets = c("", ""),
    replication_role = c(
      "exposure_discovery", "high_power_outcome_meta_sensitivity"
    ),
    resolved_at_utc = rep("2026-07-11T01:02:03Z", 2L),
    checksum_algorithm = c("", "md5"),
    expected_checksum = c("", "496e438d23ea49737e4816796cbc3ff5"),
    stringsAsFactors = FALSE
  )
}

test_that("inventory validation enforces schema, values, URLs and identity", {
  expect_invisible(validate_source_inventory(valid_inventory()))

  bad <- valid_inventory()
  bad$source_url[[1L]] <- "http://x/a"
  expect_error(validate_source_inventory(bad), "valid HTTPS")

  bad <- valid_inventory()
  bad$expected_bytes[[2L]] <- 1.5
  expect_error(validate_source_inventory(bad), "nonnegative integers")

  bad <- rbind(valid_inventory()[1L, ], valid_inventory()[1L, ])
  expect_error(validate_source_inventory(bad), "duplicate immutable keys")

  bad <- valid_inventory()
  bad$source_url[[2L]] <- bad$source_url[[1L]]
  expect_error(validate_source_inventory(bad), "duplicate source_url")

  bad <- valid_inventory()
  bad$resolved_at_utc[[1L]] <- "2026-07-11 01:02:03"
  expect_error(validate_source_inventory(bad), "UTC timestamp")
})

test_that("inventory sorting is stable and deterministic", {
  inventory <- valid_inventory()[c(2L, 1L), ]
  inventory <- rbind(inventory, transform(
    inventory[2L, ],
    file_name = "GCST90670368.tsv.gz-meta.yaml",
    source_url = "https://x/c"
  ))
  sorted <- sort_source_inventory(
    inventory,
    dataset_order = c("microbiome_2026", "ed_2025")
  )
  expect_equal(
    sorted$file_name,
    c(
      "GCST90670368.tsv.gz",
      "GCST90670368.tsv.gz-meta.yaml",
      "ed_eur_meta_ac.gz"
    )
  )
})

test_that("metadata retries are limited to transient HTTP statuses", {
  expect_true(all(is_transient_http_status(c(408L, 425L, 429L, 500L, 503L))))
  expect_false(any(is_transient_http_status(c(200L, 301L, 400L, 404L))))
})

test_that("metadata rate delay enforces a monotonic request interval", {
  expect_equal(metadata_rate_delay(10, 10, 6), 1 / 6)
  expect_equal(metadata_rate_delay(10, 10.1, 6), 1 / 6 - 0.1)
  expect_equal(metadata_rate_delay(10, 11, 6), 0)
})

test_that("inventory rejects unsafe basenames and dataset URL boundary escapes", {
  unsafe_names <- c(
    "../evil.tsv.gz", "folder/file.tsv.gz", "folder\\file.tsv.gz",
    "._hidden.tsv.gz", "bad name.tsv.gz", paste0("bad", "\n", ".tsv.gz")
  )
  for (file_name in unsafe_names) {
    bad <- valid_inventory()
    bad$file_name[[1L]] <- file_name
    expect_error(validate_source_inventory(bad), "safe basename", info = file_name)
  }

  bad_urls <- c(
    "https://localhost/pub/databases/gwas/summary_statistics/a",
    "https://127.0.0.1/pub/databases/gwas/summary_statistics/a",
    "https://evil.example/pub/databases/gwas/summary_statistics/a",
    "https://ftp.ebi.ac.uk/private/GCST90670368.tsv.gz"
  )
  for (url in bad_urls) {
    bad <- valid_inventory()
    bad$source_url[[1L]] <- url
    expect_error(validate_source_inventory(bad), "approved source prefix", info = url)
  }
})

test_that("structured overlap vectors round-trip and pair classification is symmetric", {
  metadata <- data.frame(
    dataset = c(
      "microbiome_2026", "microbiome_2026_hunt", "ed_2025", "finngen_r12"
    ),
    cohort_membership = c(
      "Swedish_discovery_cohorts", "HUNT",
      paste(c(
        "UK_Biobank", "MVP", "FinnGen", "All_of_Us",
        "Estonian_Biobank", "Partners_HealthCare_Biobank"
      ), collapse = ";"),
      "FinnGen"
    ),
    known_overlap_datasets = c("", "", "finngen_r12", "ed_2025"),
    replication_role = c(
      "exposure_discovery", "independent_exposure_replication",
      "high_power_outcome_meta_sensitivity",
      "outcome_source_known_overlap_with_ed_2025"
    ),
    stringsAsFactors = FALSE
  )
  expect_invisible(validate_overlap_symmetry(metadata))
  known <- classify_dataset_pair("ed_2025", "finngen_r12", metadata)
  expect_equal(known$overlap_class, "known")
  expect_equal(known$action, "sensitivity_only")
  independent <- classify_dataset_pair(
    "microbiome_2026", "microbiome_2026_hunt", metadata
  )
  expect_equal(independent$overlap_class, "none_known")
  expect_equal(independent$action, "independent_exposure_replication")

  broken <- metadata
  broken$known_overlap_datasets[broken$dataset == "finngen_r12"] <- ""
  expect_error(validate_overlap_symmetry(broken), "not symmetric")
  expect_equal(
    decode_provenance_vector(encode_provenance_vector(c("A", "B"))),
    c("A", "B")
  )
})

test_that("inventory reconciliation preserves stable timestamps and marks drift", {
  previous <- valid_inventory()
  current <- previous
  current$resolved_at_utc <- "2026-07-12T01:02:03Z"
  unchanged <- reconcile_source_inventory(current, previous)
  expect_equal(unchanged$inventory$resolved_at_utc, previous$resolved_at_utc)
  expect_length(unchanged$changed_keys, 0L)

  changed <- current
  changed$expected_bytes[[2L]] <- 43
  changed <- rbind(changed, transform(
    changed[1L, ],
    source_id = "GCST90670369",
    file_name = "GCST90670369.tsv.gz",
    source_url = paste0(
      "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/",
      "GCST90670001-GCST90671000/GCST90670369/GCST90670369.tsv.gz"
    )
  ))
  drift <- reconcile_source_inventory(changed, previous)
  expect_equal(drift$inventory$resolved_at_utc[1:2], c(
    previous$resolved_at_utc[[1L]], "2026-07-12T01:02:03Z"
  ))
  expect_equal(drift$inventory$resolved_at_utc[[3L]], "2026-07-12T01:02:03Z")
  expect_length(drift$changed_keys, 1L)
  expect_length(drift$new_keys, 1L)

  removed <- reconcile_source_inventory(previous[1L, ], previous)
  expect_length(removed$removed_keys, 1L)
})

test_that("unchanged rebuild is byte-identical and removed rows stop replacement", {
  path <- tempfile(fileext = ".csv")
  write_source_inventory_atomic(
    valid_inventory(), path,
    dataset_order = c("microbiome_2026", "ed_2025")
  )
  before <- readBin(path, "raw", n = file.info(path)$size)
  before_mtime <- file.info(path)$mtime
  replacements <- 0L
  rerun <- valid_inventory()
  rerun$resolved_at_utc <- "2026-07-12T01:02:03Z"
  write_source_inventory_atomic(
    rerun, path,
    dataset_order = c("microbiome_2026", "ed_2025"),
    replace_file = function(from, to) {
      replacements <<- replacements + 1L
      file.rename(from, to)
    }
  )
  expect_identical(readBin(path, "raw", n = file.info(path)$size), before)
  expect_identical(file.info(path)$mtime, before_mtime)
  expect_identical(replacements, 0L)

  expect_error(
    write_source_inventory_atomic(
      rerun[1L, ], path,
      dataset_order = c("microbiome_2026", "ed_2025")
    ),
    "removed rows"
  )
  expect_identical(readBin(path, "raw", n = file.info(path)$size), before)
})

test_that("invalid reconciled prior timestamp stops before replacement", {
  path <- tempfile(fileext = ".csv")
  write_source_inventory_atomic(
    valid_inventory(), path,
    dataset_order = c("microbiome_2026", "ed_2025")
  )
  prior <- read_source_inventory_csv(path)
  prior$resolved_at_utc[[1L]] <- "NOT_UTC"
  utils::write.csv(prior, path, row.names = FALSE, na = "")
  before <- readBin(path, "raw", n = file.info(path)$size)
  replacements <- 0L

  error <- expect_error(
    write_source_inventory_atomic(
      valid_inventory(), path,
      dataset_order = c("microbiome_2026", "ed_2025"),
      replace_file = function(from, to) {
        replacements <<- replacements + 1L
        file.rename(from, to)
      }
    )
  )
  expect_match(conditionMessage(error), path, fixed = TRUE)
  expect_match(conditionMessage(error), "resolved_at_utc", fixed = TRUE)
  expect_identical(readBin(path, "raw", n = file.info(path)$size), before)
  expect_identical(replacements, 0L)
})

test_that("duplicate prior inventory stops before reconciliation", {
  path <- tempfile(fileext = ".csv")
  write_source_inventory_atomic(
    valid_inventory(), path,
    dataset_order = c("microbiome_2026", "ed_2025")
  )
  prior <- read_source_inventory_csv(path)
  prior <- rbind(prior, prior[1L, , drop = FALSE])
  utils::write.csv(prior, path, row.names = FALSE, na = "")
  before <- readBin(path, "raw", n = file.info(path)$size)
  before_mtime <- file.info(path)$mtime
  replacements <- 0L

  error <- expect_error(
    write_source_inventory_atomic(
      valid_inventory(), path,
      dataset_order = c("microbiome_2026", "ed_2025"),
      replace_file = function(from, to) {
        replacements <<- replacements + 1L
        FALSE
      }
    )
  )
  expect_match(conditionMessage(error), path, fixed = TRUE)
  expect_match(conditionMessage(error), "duplicate immutable keys", fixed = TRUE)
  expect_identical(readBin(path, "raw", n = file.info(path)$size), before)
  expect_identical(file.info(path)$mtime, before_mtime)
  expect_identical(replacements, 0L)
})

test_that("asymmetric prior overlap stops before reconciliation", {
  path <- tempfile(fileext = ".csv")
  write_source_inventory_atomic(
    valid_inventory(), path,
    dataset_order = c("microbiome_2026", "ed_2025")
  )
  prior <- read_source_inventory_csv(path)
  prior$known_overlap_datasets[prior$dataset == "ed_2025"] <-
    "microbiome_2026"
  utils::write.csv(prior, path, row.names = FALSE, na = "")
  before <- readBin(path, "raw", n = file.info(path)$size)
  before_mtime <- file.info(path)$mtime
  replacements <- 0L

  error <- expect_error(
    write_source_inventory_atomic(
      valid_inventory(), path,
      dataset_order = c("microbiome_2026", "ed_2025"),
      replace_file = function(from, to) {
        replacements <<- replacements + 1L
        FALSE
      }
    )
  )
  expect_match(conditionMessage(error), path, fixed = TRUE)
  expect_match(conditionMessage(error), "not symmetric", fixed = TRUE)
  expect_identical(readBin(path, "raw", n = file.info(path)$size), before)
  expect_identical(file.info(path)$mtime, before_mtime)
  expect_identical(replacements, 0L)
})

test_that("atomic replacement failure preserves the prior CSV", {
  path <- tempfile(fileext = ".csv")
  write_source_inventory_atomic(
    valid_inventory(), path,
    dataset_order = c("microbiome_2026", "ed_2025")
  )
  before <- readBin(path, "raw", n = file.info(path)$size)
  changed <- valid_inventory()
  changed$expected_bytes[[2L]] <- 43
  changed$resolved_at_utc <- "2026-07-12T01:02:03Z"
  expect_error(
    write_source_inventory_atomic(
      changed, path,
      dataset_order = c("microbiome_2026", "ed_2025"),
      replace_file = function(from, to) FALSE
    ),
    "Atomic source inventory rename failed"
  )
  expect_identical(readBin(path, "raw", n = file.info(path)$size), before)
})

test_that("metadata control flow handles statuses, retries and transform failures", {
  fixture <- function(status, retry_after = NULL) {
    list(status = status, headers = list(`retry-after` = retry_after))
  }
  status_of <- function(response) response$status
  header_of <- function(response, name, default = NULL) {
    value <- response$headers[[tolower(name)]]
    if (is.null(value)) default else value
  }
  run <- function(results, allow_not_found = FALSE, transform = identity) {
    calls <- 0L
    sleeps <- numeric()
    performer <- function(request) {
      calls <<- calls + 1L
      value <- results[[calls]]
      if (inherits(value, "condition")) stop(value)
      value
    }
    output <- perform_metadata(
      "https://example.org/file", "HEAD", "fixture", transform,
      allow_not_found = allow_not_found,
      performer = performer,
      sleeper = function(seconds) sleeps <<- c(sleeps, seconds),
      clock = local({ value <- 0; function() { value <<- value + 1; value } }),
      jitter = function() 0,
      status_of = status_of,
      header_of = header_of,
      max_starts_per_second = Inf,
      request_builder = function(url, method) list(url = url, method = method)
    )
    list(output = output[[1L]], calls = calls, sleeps = sleeps)
  }

  expect_equal(run(list(fixture(200)), transform = function(x) "ok")$output, "ok")
  expect_equal(run(list(fixture(404)), TRUE)$output$status, 404)
  expect_error(run(list(fixture(404))), "HTTP 404")
  retry <- run(list(fixture(429, "7"), fixture(503), fixture(200)))
  expect_equal(retry$calls, 3L)
  expect_true(7 %in% retry$sleeps)
  expect_error(run(rep(list(fixture(503)), 3L)), "after 3 attempts")
  expect_error(run(list(fixture(400))), "HTTP 400")
  expect_equal(run(list(NULL, simpleError("TLS"), fixture(200)))$calls, 3L)

  transform_calls <- 0L
  expect_error(
    run(list(fixture(200)), transform = function(x) {
      transform_calls <<- transform_calls + 1L
      stop("transform failed")
    }),
    "transform failed"
  )
  expect_equal(transform_calls, 1L)
})

test_that("FinnGen HEAD metadata requires consistent length and MD5 headers", {
  md5 <- "cdb92e57e4c62d4336be808ce8b423e2"
  raw_md5 <- as.raw(strtoi(substring(md5, seq(1, 31, 2), seq(2, 32, 2)), 16L))
  headers <- list(
    `content-length` = "809561836",
    etag = paste0('"', md5, '"'),
    `x-goog-hash` = "crc32c=0rrKBw=="
  )
  parsed <- parse_finngen_head_metadata(headers)
  expect_equal(parsed$expected_bytes, 809561836)
  expect_equal(parsed$expected_checksum, md5)
  bad <- headers
  bad$etag <- '"00000000000000000000000000000000"'
  bad$`x-goog-hash` <- paste0(
    "crc32c=0rrKBw==,md5=", jsonlite::base64_enc(raw_md5)
  )
  expect_error(parse_finngen_head_metadata(bad), "inconsistent")
})
