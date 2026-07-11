project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "provenance.R"))
if (file.exists(file.path(project_root, "R", "download.R"))) {
  source(file.path(project_root, "R", "download.R"))
}

fixture_inventory <- function() {
  payloads <- c("alpha\n", "bravo\n")
  paths <- vapply(payloads, function(payload) {
    path <- tempfile()
    writeChar(payload, path, eos = NULL)
    path
  }, character(1))
  checksums <- unname(tools::md5sum(paths))
  unlink(paths)
  data.frame(
    dataset = rep("ld_reference_1kg", 2L),
    source_id = c("source-a", "source-b"),
    file_name = c("source-a.tsv", "source-b.tsv.gz"),
    source_url = c(
      paste0(
        "https://zenodo.org/api/records/6614170/files/",
        "source-a.tsv/content"
      ),
      paste0(
        "https://zenodo.org/api/records/6614170/files/",
        "source-b.tsv.gz/content"
      )
    ),
    expected_bytes = as.numeric(nchar(payloads, type = "bytes")),
    ancestry = rep("EUR", 2L),
    genome_build = rep("GRCh37", 2L),
    license = rep("test license", 2L),
    overlap_note = rep("External LD reference only", 2L),
    cohort_membership = rep("1000_Genomes", 2L),
    known_overlap_datasets = rep("", 2L),
    replication_role = rep("external_ld_reference", 2L),
    resolved_at_utc = rep("2026-07-11T06:36:28Z", 2L),
    checksum_algorithm = rep("md5", 2L),
    expected_checksum = checksums,
    stringsAsFactors = FALSE
  )
}

empty_manifest_fixture <- function() {
  result <- as.data.frame(
    setNames(replicate(length(MANIFEST_COLUMNS), character(), simplify = FALSE),
             MANIFEST_COLUMNS),
    stringsAsFactors = FALSE
  )
  result$bytes <- numeric()
  result
}

make_project <- function() {
  root <- tempfile("download-project-")
  dir.create(root)
  root
}

make_spaced_project <- function() {
  root <- tempfile("download project with spaces ")
  dir.create(root)
  root
}

fake_resume_curl <- function(expected_url) {
  script <- tempfile("fake curl with spaces ", fileext = ".sh")
  lines <- c(
    "#!/bin/sh",
    "output=",
    "last=",
    "while [ \"$#\" -gt 0 ]; do",
    "  last=$1",
    "  if [ \"$1\" = \"--output\" ]; then",
    "    shift",
    "    output=$1",
    "  fi",
    "  shift",
    "done",
    paste0("[ \"$last\" = ", shQuote(expected_url), " ] || exit 91"),
    "[ -n \"$output\" ] || exit 92",
    "printf 'pha\\n' >> \"$output\""
  )
  writeLines(lines, script, useBytes = TRUE)
  Sys.chmod(script, "0755")
  script
}

payload_runner <- function(payload, status = 0L, capture = NULL) {
  force(payload)
  force(status)
  force(capture)
  function(command, args) {
    if (!is.null(capture)) {
      capture$command <- command
      capture$args <- args
    }
    output_index <- match("--output", args)
    if (!is.na(output_index)) {
      writeChar(payload, args[[output_index + 1L]], eos = NULL)
    }
    status
  }
}

append_payload_runner <- function(payload, status = 0L, capture = NULL) {
  force(payload)
  force(status)
  force(capture)
  function(command, args) {
    if (!is.null(capture)) {
      capture$command <- command
      capture$args <- args
    }
    output_index <- match("--output", args)
    if (!is.na(output_index) && nzchar(payload)) {
      connection <- file(args[[output_index + 1L]], open = "ab")
      on.exit(close(connection), add = TRUE)
      writeBin(charToRaw(payload), connection)
    }
    status
  }
}

receipt_for_payload <- function(row, root, payload, timestamp = "2026-07-11T07:00:00Z") {
  path <- safe_raw_relative_path(row)
  final <- file.path(root, path)
  dir.create(dirname(final), recursive = TRUE, showWarnings = FALSE)
  writeChar(payload, final, eos = NULL)
  receipt <- file_receipt(row, path, final, timestamp)
  Sys.chmod(final, mode = "0444")
  receipt
}

many_receipt_fixture <- function(n) {
  inventory <- fixture_inventory()[rep(1L, n), , drop = FALSE]
  inventory$source_id <- sprintf("source-%03d", seq_len(n))
  inventory$file_name <- sprintf("source-%03d.tsv", seq_len(n))
  inventory$source_url <- paste0(
    "https://zenodo.org/api/records/6614170/files/",
    inventory$file_name, "/content"
  )
  rownames(inventory) <- NULL
  root <- make_project()
  receipts <- lapply(seq_len(n), function(index) {
    receipt_for_payload(inventory[index, , drop = FALSE], root, "alpha\n")
  })
  list(
    inventory = inventory,
    root = root,
    receipts = do.call(rbind, receipts)
  )
}

test_that("receipt schema, scalar types, UTC and raw path are strict", {
  inventory <- fixture_inventory()
  root <- make_project()
  receipt <- receipt_for_payload(inventory[1L, ], root, "alpha\n")

  expect_identical(names(receipt), MANIFEST_COLUMNS)
  expect_true(is.numeric(receipt$bytes))
  expect_invisible(validate_receipt(receipt, inventory, root))

  bad <- receipt[c(MANIFEST_COLUMNS[-1L], "frozen_at_utc")]
  names(bad)[1L] <- "wrong"
  expect_error(validate_receipt(bad, inventory, root), "exactly")
  bad <- receipt
  bad$bytes <- as.character(bad$bytes)
  expect_error(validate_receipt(bad, inventory, root), "bytes")
  bad <- receipt
  bad$frozen_at_utc <- "2026-07-11 07:00:00"
  expect_error(validate_receipt(bad, inventory, root), "UTC")
})

test_that("raw receipt paths reject traversal, absolute, control and AppleDouble names", {
  row <- fixture_inventory()[1L, ]
  expect_identical(
    safe_raw_relative_path(row),
    "03_data/raw/ld_reference_1kg/source-a/source-a.tsv"
  )
  attacks <- c(
    "../03_data/raw/x", "/03_data/raw/x", "03_data/raw/../x",
    "03_data/raw/a/b/._x", "03_data/raw/a/b/x\n"
  )
  for (attack in attacks) {
    expect_error(validate_raw_relative_path(attack), "safe raw path", info = attack)
  }
  bad <- row
  bad$source_id <- "../source-a"
  expect_error(safe_raw_relative_path(bad), "safe basename")
  bad <- row
  bad$file_name <- "._source-a.tsv"
  expect_error(safe_raw_relative_path(bad), "safe basename")

  root <- make_project()
  outside <- tempfile("outside-raw-")
  dir.create(outside)
  dir.create(file.path(root, "03_data"))
  expect_true(file.symlink(outside, file.path(root, "03_data", "raw")))
  expect_error(
    raw_absolute_path(root, safe_raw_relative_path(row)),
    "escapes project root"
  )
})

test_that("source row must be an exact Task 4 inventory row with safe basenames", {
  inventory <- fixture_inventory()
  expect_invisible(validate_download_source(inventory[1L, ], inventory))
  changed <- inventory[1L, ]
  changed$license <- "changed"
  expect_error(validate_download_source(changed, inventory), "exact Task 4 inventory row")
  changed <- inventory[1L, ]
  changed$file_name <- "../unsafe.tsv"
  expect_error(validate_download_source(changed, inventory), "safe basename")
})

test_that("receipt append is idempotent and duplicate/conflicting keys stop", {
  inventory <- fixture_inventory()
  root <- make_project()
  receipt <- receipt_for_payload(inventory[1L, ], root, "alpha\n")
  manifest <- append_receipt_idempotent(empty_manifest_fixture(), receipt)
  later <- receipt
  later$frozen_at_utc <- "2026-07-11T08:00:00Z"
  expect_identical(append_receipt_idempotent(manifest, later), manifest)

  conflict <- receipt
  conflict$sha256 <- strrep("0", 64L)
  expect_error(append_receipt_idempotent(manifest, conflict), "conflicting receipt")
  expect_error(
    validate_receipt(rbind(receipt, receipt), inventory, root),
    "duplicate immutable receipt key"
  )
})

test_that("receipt metadata and destination path must match Task 4 exactly", {
  inventory <- fixture_inventory()
  root <- make_project()
  receipt <- receipt_for_payload(inventory[1L, ], root, "alpha\n")
  bad <- receipt
  bad$source_url <- inventory$source_url[[2L]]
  expect_error(validate_receipt(bad, inventory, root), "source metadata")
  bad <- receipt
  bad$path <- sub("source-a.tsv$", "renamed.tsv", bad$path)
  expect_error(validate_receipt(bad, inventory, root), "raw path")
})

test_that("curl uses an argument vector with strict HTTPS and exact resume flags", {
  row <- fixture_inventory()[1L, ]
  capture <- new.env(parent = emptyenv())
  part <- tempfile(fileext = ".part")
  status <- run_curl_download(row, part, runner = payload_runner("alpha\n", capture = capture))
  expect_identical(status, 0L)
  expect_identical(capture$command, "curl")
  expect_true(all(c(
    "--fail", "--location", "--continue-at", "-", "--retry", "5",
    "--retry-delay", "5", "--proto", "=https", "--proto-redir", "=https"
  ) %in% capture$args))
  expect_false(any(grepl("insecure|no-check-certificate", capture$args, ignore.case = TRUE)))
  expect_identical(tail(capture$args, 1L), row$source_url)
  bad <- row
  bad$source_url <- "http://example.test/file"
  expect_error(run_curl_download(bad, part, runner = payload_runner("")), "HTTPS")
})

test_that("safe command runner preserves every argv element literally", {
  executable <- tempfile("argv echo with spaces ", fileext = ".sh")
  writeLines(c(
    "#!/bin/sh",
    "for argument in \"$@\"; do printf '%s\\n' \"$argument\"; done"
  ), executable, useBytes = TRUE)
  Sys.chmod(executable, "0755")
  arguments <- c(
    "path with spaces/file.part",
    "https://example.test/data?x=1&y=2",
    "literal;$HOME&value"
  )
  expect_identical(
    safe_system2(executable, arguments, stdout = TRUE, stderr = TRUE),
    arguments
  )
})

test_that("expected byte mismatch leaves writable part and no final or manifest", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, manifest_path, root,
      runner = payload_runner("wrong"), clock = function() "2026-07-11T07:00:00Z"
    ),
    "expected bytes"
  )
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  expect_false(file.exists(final))
  expect_true(file.exists(paste0(final, ".part")))
  expect_equal(unname(file.access(paste0(final, ".part"), 2L)), 0L)
  expect_false(file.exists(manifest_path))
})

test_that("expected MD5 mismatch prevents final rename and manifest update", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, manifest_path, root,
      runner = payload_runner("omega\n"), clock = function() "2026-07-11T07:00:00Z"
    ),
    "md5 mismatch"
  )
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  expect_false(file.exists(final))
  expect_true(file.exists(paste0(final, ".part")))
  expect_false(file.exists(manifest_path))
})

test_that("curl failure leaves only a writable part", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, manifest_path, root,
      runner = payload_runner("al", status = 22L)
    ),
    "curl failed with status 22"
  )
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  expect_false(file.exists(final))
  expect_true(file.exists(paste0(final, ".part")))
  expect_equal(unname(file.access(paste0(final, ".part"), 2L)), 0L)
})

test_that("curl status 18 resumes within the same download call", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  calls <- 0L
  runner <- function(command, args) {
    calls <<- calls + 1L
    output_index <- match("--output", args)
    output <- args[[output_index + 1L]]
    if (calls == 1L) {
      writeChar("al", output, eos = NULL)
      return(18L)
    }
    connection <- file(output, open = "ab")
    on.exit(close(connection), add = TRUE)
    writeBin(charToRaw("pha\n"), connection)
    0L
  }
  result <- download_inventory_row(
    inventory[1L, ], inventory, manifest_path, root,
    runner = runner,
    clock = function() "2026-07-11T07:00:00Z",
    curl_retry_delay_seconds = 0,
    curl_sleep = function(seconds) expect_identical(seconds, 0),
    curl_retry_logger = function(text) expect_match(text, "status 18.*attempt 1")
  )
  expect_identical(calls, 2L)
  expect_identical(result$status, "completed")
  expect_identical(result$bytes, 6)
})

test_that("curl status 18 exhausts a bounded and observable retry policy", {
  inventory <- fixture_inventory()
  root <- make_project()
  calls <- 0L
  sleeps <- numeric()
  logs <- character()
  runner <- function(command, args) {
    calls <<- calls + 1L
    output <- args[[match("--output", args) + 1L]]
    if (!file.exists(output)) writeChar("al", output, eos = NULL)
    18L
  }
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, file.path(root, "MANIFEST.csv"), root,
      runner = runner,
      curl_max_extra_attempts = 2,
      curl_retry_delay_seconds = 7,
      curl_sleep = function(seconds) sleeps <<- c(sleeps, seconds),
      curl_retry_logger = function(text) logs <<- c(logs, text)
    ),
    "status 18 after 3 attempts"
  )
  expect_identical(calls, 3L)
  expect_identical(sleeps, c(7, 7))
  expect_length(logs, 2L)
  expect_true(all(grepl("status 18.*attempt", logs)))
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  expect_equal(unname(file.access(paste0(final, ".part"), 2L)), 0L)
})

test_that("permanent curl status 22 is inspected but never retried", {
  inventory <- fixture_inventory()
  root <- make_project()
  calls <- 0L
  runner <- function(command, args) {
    calls <<- calls + 1L
    output <- args[[match("--output", args) + 1L]]
    writeChar("al", output, eos = NULL)
    22L
  }
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, file.path(root, "MANIFEST.csv"), root,
      runner = runner,
      curl_sleep = function(...) stop("permanent status must not sleep"),
      curl_retry_logger = function(...) stop("permanent status must not log retry")
    ),
    "status 22 after 1 attempt"
  )
  expect_identical(calls, 1L)
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  expect_true(file.exists(paste0(final, ".part")))
  expect_equal(unname(file.access(paste0(final, ".part"), 2L)), 0L)
})

test_that("permanent status 22 never promotes even a complete valid part", {
  inventory <- fixture_inventory()
  root <- make_project()
  calls <- 0L
  runner <- function(command, args) {
    calls <<- calls + 1L
    output <- args[[match("--output", args) + 1L]]
    writeChar("alpha\n", output, eos = NULL)
    22L
  }
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, file.path(root, "MANIFEST.csv"), root,
      runner = runner,
      curl_sleep = function(...) stop("status 22 must not sleep"),
      curl_retry_logger = function(...) stop("status 22 must not log retry")
    ),
    "status 22 after 1 attempt"
  )
  expect_identical(calls, 1L)
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  expect_false(file.exists(final))
  expect_true(file.exists(paste0(final, ".part")))
  expect_false(file.exists(file.path(root, "MANIFEST.csv")))
})

test_that("status 18 with a complete valid part promotes without another call", {
  inventory <- fixture_inventory()
  root <- make_project()
  calls <- 0L
  logs <- character()
  runner <- function(command, args) {
    calls <<- calls + 1L
    output <- args[[match("--output", args) + 1L]]
    writeChar("alpha\n", output, eos = NULL)
    18L
  }
  result <- download_inventory_row(
    inventory[1L, ], inventory, file.path(root, "MANIFEST.csv"), root,
    runner = runner,
    curl_sleep = function(...) stop("complete part must not retry"),
    curl_retry_logger = function(text) logs <<- c(logs, text),
    clock = function() "2026-07-11T07:00:00Z"
  )
  expect_identical(calls, 1L)
  expect_length(logs, 1L)
  expect_match(logs[[1L]], "status 18 after attempt 1.*complete.*valid")
  expect_identical(result$status, "completed")
  expect_true(verify_manifest(
    read_manifest_csv(file.path(root, "MANIFEST.csv")), inventory, root
  ))
})

test_that("retry rejects a part changed to an unsafe or corrupt node", {
  inventory <- fixture_inventory()
  cases <- c("directory", "symlink", "oversized", "complete-corrupt")
  expected <- c(
    directory = "regular file",
    symlink = "symbolic link",
    oversized = "larger than expected",
    `complete-corrupt` = "md5 mismatch"
  )
  for (case in cases) {
    root <- make_project()
    calls <- 0L
    outside <- tempfile("retry-outside-")
    writeChar("outside", outside, eos = NULL)
    runner <- function(command, args) {
      calls <<- calls + 1L
      part <- args[[match("--output", args) + 1L]]
      if (calls == 1L) {
        writeChar("al", part, eos = NULL)
        return(18L)
      }
      unlink(part, recursive = TRUE)
      if (identical(case, "directory")) dir.create(part)
      if (identical(case, "symlink")) file.symlink(outside, part)
      if (identical(case, "oversized")) writeChar("alpha\nX", part, eos = NULL)
      if (identical(case, "complete-corrupt")) writeChar("omega\n", part, eos = NULL)
      18L
    }
    expect_error(
      download_inventory_row(
        inventory[1L, ], inventory, file.path(root, "MANIFEST.csv"), root,
        runner = runner,
        curl_retry_delay_seconds = 0,
        curl_sleep = function(seconds) invisible(NULL),
        curl_retry_logger = function(text) invisible(NULL)
      ),
      paste0("status 18 after attempt 2.*", unname(expected[[case]])),
      info = case
    )
    expect_identical(calls, 2L, info = case)
    expect_false(file.exists(file.path(root, "MANIFEST.csv")), info = case)
  }
})

test_that("pre-existing part symlink is rejected before the command runner", {
  inventory <- fixture_inventory()
  root <- make_project()
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  dir.create(dirname(final), recursive = TRUE)
  outside <- tempfile("outside-part-")
  writeChar("outside", outside, eos = NULL)
  expect_true(file.symlink(outside, paste0(final, ".part")))
  called <- FALSE
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, file.path(root, "MANIFEST.csv"), root,
      runner = function(...) {
        called <<- TRUE
        0L
      }
    ),
    "symbolic link"
  )
  expect_false(called)
  expect_identical(readChar(outside, nchars = 7L), "outside")
})

test_that("zero and smaller partial files are charged by remaining bytes and resumed", {
  inventory <- fixture_inventory()
  cases <- list(
    list(prefix = "", suffix = "alpha\n", remaining = 6),
    list(prefix = "al", suffix = "pha\n", remaining = 4)
  )
  for (case in cases) {
    root <- make_project()
    manifest_path <- file.path(root, "MANIFEST.csv")
    final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
    part <- paste0(final, ".part")
    dir.create(dirname(part), recursive = TRUE)
    if (nzchar(case$prefix)) {
      writeChar(case$prefix, part, eos = NULL)
    } else {
      file.create(part)
    }
    preflight <- preflight_download_space(
      inventory[1L, ], empty_manifest_fixture(), root,
      free_space_provider = function(path) 1000, reserve_bytes = 100,
      inventory = inventory
    )
    expect_identical(preflight$download_bytes, as.numeric(case$remaining))
    result <- download_inventory_row(
      inventory[1L, ], inventory, manifest_path, root,
      runner = append_payload_runner(case$suffix),
      clock = function() "2026-07-11T07:00:00Z"
    )
    expect_identical(result$status, "completed")
    expect_identical(result$bytes, as.numeric(case$remaining))
    expect_identical(readChar(final, nchars = 6L), "alpha\n")
    expect_false(file.exists(part))
  }
})

test_that("exact valid partial promotes without curl with or without old receipt", {
  inventory <- fixture_inventory()
  for (with_receipt in c(FALSE, TRUE)) {
    root <- make_project()
    manifest_path <- file.path(root, "MANIFEST.csv")
    final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
    part <- paste0(final, ".part")
    dir.create(dirname(part), recursive = TRUE)
    if (with_receipt) {
      receipt <- receipt_for_payload(inventory[1L, ], root, "alpha\n")
      unlink(final)
      utils::write.csv(receipt, manifest_path, row.names = FALSE)
      manifest_before <- readBin(
        manifest_path, "raw", n = file.info(manifest_path)$size
      )
    }
    writeChar("alpha\n", part, eos = NULL)
    preflight <- preflight_download_space(
      inventory[1L, ], read_manifest_csv(manifest_path), root,
      free_space_provider = function(path) 100, reserve_bytes = 100,
      inventory = inventory
    )
    expect_identical(preflight$download_bytes, 0)
    result <- download_inventory_row(
      inventory[1L, ], inventory, manifest_path, root,
      runner = function(...) stop("curl must not be called for complete part"),
      clock = function() "2026-07-11T07:00:00Z"
    )
    expect_identical(result$status, "completed")
    expect_identical(result$bytes, 0)
    expect_true(file.exists(final))
    expect_false(file.exists(part))
    expect_true(verify_manifest(read_manifest_csv(manifest_path), inventory, root))
    if (with_receipt) {
      expect_identical(
        readBin(manifest_path, "raw", n = file.info(manifest_path)$size),
        manifest_before
      )
    }
  }
})

test_that("post-freeze validation catches mutation inside the freeze hook", {
  inventory <- fixture_inventory()
  for (with_receipt in c(FALSE, TRUE)) {
    root <- make_spaced_project()
    manifest_path <- file.path(root, "MANIFEST.csv")
    final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
    part <- paste0(final, ".part")
    dir.create(dirname(part), recursive = TRUE)
    if (with_receipt) {
      receipt <- receipt_for_payload(inventory[1L, ], root, "alpha\n")
      unlink(final)
      utils::write.csv(receipt, manifest_path, row.names = FALSE)
    } else {
      receipt <- empty_manifest_fixture()
    }
    writeChar("alpha\n", part, eos = NULL)
    expect_error(
      download_inventory_row(
        inventory[1L, ], inventory, manifest_path, root,
        runner = function(...) stop("curl must not be called"),
        chmod_file = function(path, mode) {
          if (identical(mode, "0444")) {
            writeChar("omega\n", path, eos = NULL)
          }
          Sys.chmod(path, mode)
        }
      ),
      "changed during promotion|md5 mismatch|SHA-256"
    )
    expect_false(file.exists(final))
    expect_true(file.exists(part))
    expect_identical(read_manifest_csv(manifest_path), receipt)
  }
})

test_that("spaced project paths cover preflight resume complete promotion and uchg", {
  inventory <- fixture_inventory()
  inventory$source_url[[1L]] <- paste0(inventory$source_url[[1L]], "?x=1&y=2")
  root <- make_spaced_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  final_a <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  final_b <- ""
  on.exit({
    frozen <- c(final_a, final_b)
    frozen <- frozen[nzchar(frozen) & file.exists(frozen)]
    if (length(frozen)) {
      try(safe_system2("/usr/bin/chflags", c("nouchg", frozen)), silent = TRUE)
    }
  }, add = TRUE)
  part_a <- paste0(final_a, ".part")
  dir.create(dirname(part_a), recursive = TRUE)
  writeChar("al", part_a, eos = NULL)
  fake_curl <- fake_resume_curl(inventory$source_url[[1L]])
  runner <- function(command, args, ...) {
    safe_system2(fake_curl, args, ...)
  }
  fallback_chmod <- function(path, mode) {
    if (identical(mode, "0444")) return(FALSE)
    Sys.chmod(path, mode)
  }
  preflight <- preflight_download_space(
    inventory[1L, ], empty_manifest_fixture(), root,
    free_space_provider = default_free_space_provider,
    reserve_bytes = 0, inventory = inventory
  )
  expect_identical(preflight$download_bytes, 4)
  result_a <- download_inventory_row(
    inventory[1L, ], inventory, manifest_path, root,
    runner = runner,
    chmod_file = fallback_chmod,
    clock = function() "2026-07-11T07:00:00Z"
  )
  expect_identical(result_a$bytes, 4)
  expect_true(validate_frozen_file(final_a))

  final_b <- file.path(root, safe_raw_relative_path(inventory[2L, ]))
  part_b <- paste0(final_b, ".part")
  dir.create(dirname(part_b), recursive = TRUE)
  writeChar("bravo\n", part_b, eos = NULL)
  preflight_b <- preflight_download_space(
    inventory[2L, ], read_manifest_csv(manifest_path), root,
    free_space_provider = default_free_space_provider,
    reserve_bytes = 0, inventory = inventory
  )
  expect_identical(preflight_b$download_bytes, 0)
  result_b <- download_inventory_row(
    inventory[2L, ], inventory, manifest_path, root,
    runner = function(...) stop("curl must not run for a complete partial"),
    chmod_file = fallback_chmod,
    clock = function() "2026-07-11T07:00:01Z"
  )
  expect_identical(result_b$bytes, 0)
  expect_true(validate_frozen_file(final_b))
  expect_true(verify_manifest(read_manifest_csv(manifest_path), inventory, root))
})

test_that("manifest writer failure is recovered by adopting the frozen final", {
  inventory <- fixture_inventory()
  root <- make_spaced_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, manifest_path, root,
      runner = payload_runner("alpha\n"),
      manifest_writer = function(...) stop("injected manifest failure"),
      clock = function() "2026-07-11T07:00:00Z"
    ),
    "injected manifest failure"
  )
  expect_true(file.exists(final))
  expect_true(validate_frozen_file(final))
  expect_false(file.exists(manifest_path))
  recovered <- download_inventory_row(
    inventory[1L, ], inventory, manifest_path, root,
    runner = function(...) stop("curl must not run while adopting final"),
    clock = function() "2026-07-11T07:00:01Z"
  )
  expect_identical(recovered$status, "adopted")
  expect_true(verify_manifest(read_manifest_csv(manifest_path), inventory, root))
})

test_that("rollback rename failure is explicit and never writes a receipt", {
  inventory <- fixture_inventory()
  root <- make_spaced_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  part <- paste0(final, ".part")
  dir.create(dirname(part), recursive = TRUE)
  writeChar("alpha\n", part, eos = NULL)
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, manifest_path, root,
      runner = function(...) stop("curl must not run"),
      chmod_file = function(path, mode) {
        if (identical(mode, "0444")) writeChar("omega\n", path, eos = NULL)
        Sys.chmod(path, mode)
      },
      rollback_rename = function(from, to) FALSE
    ),
    "could not be restored to its \\.part path"
  )
  expect_true(file.exists(final))
  expect_false(file.exists(manifest_path))
  expect_false(file.exists(part))
})

test_that("complete corrupt and oversized partials fail before free-space or curl", {
  inventory <- fixture_inventory()
  cases <- list(
    list(payload = "omega\n", error = "md5 mismatch"),
    list(payload = "alpha\nX", error = "larger than expected")
  )
  for (case in cases) {
    root <- make_project()
    final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
    part <- paste0(final, ".part")
    dir.create(dirname(part), recursive = TRUE)
    writeChar(case$payload, part, eos = NULL)
    free_called <- FALSE
    expect_error(
      preflight_download_space(
        inventory[1L, ], empty_manifest_fixture(), root,
        free_space_provider = function(path) {
          free_called <<- TRUE
          1000
        },
        reserve_bytes = 0, inventory = inventory
      ),
      case$error
    )
    expect_false(free_called)
    runner_called <- FALSE
    expect_error(
      download_inventory_row(
        inventory[1L, ], inventory, file.path(root, "MANIFEST.csv"), root,
        runner = function(...) {
          runner_called <<- TRUE
          0L
        }
      ),
      case$error
    )
    expect_false(runner_called)
    expect_true(file.exists(part))
    expect_identical(file.info(part)$size, as.numeric(nchar(case$payload)))
  }
})

test_that("directory and FIFO partial nodes are rejected as non-regular", {
  inventory <- fixture_inventory()
  for (kind in c("directory", "fifo")) {
    root <- make_project()
    final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
    part <- paste0(final, ".part")
    dir.create(dirname(part), recursive = TRUE)
    if (identical(kind, "directory")) {
      dir.create(part)
    } else {
      status <- safe_system2("mkfifo", part)
      expect_identical(status, 0L)
    }
    expect_error(
      download_inventory_row(
        inventory[1L, ], inventory, file.path(root, "MANIFEST.csv"), root,
        runner = function(...) stop("runner must not be called")
      ),
      "regular file"
    )
  }
})

test_that("regular partial detection safely handles paths containing spaces", {
  path <- tempfile(pattern = "regular partial ")
  file.create(path)
  expect_true(default_regular_file_provider(path))
})

test_that("successful download verifies, atomically renames and chmods final 0444", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  result <- download_inventory_row(
    inventory[1L, ], inventory, manifest_path, root,
    runner = payload_runner("alpha\n"), clock = function() "2026-07-11T07:00:00Z"
  )
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  expect_identical(result$status, "completed")
  expect_true(file.exists(final))
  expect_false(file.exists(paste0(final, ".part")))
  expect_identical(as.character(file.info(final)$mode), "444")
  manifest <- read_manifest_csv(manifest_path)
  expect_true(verify_manifest(manifest, inventory, root))
})

test_that("raw freeze verifies chmod-effective mode or a safe uchg fallback", {
  path <- tempfile("freeze-raw-")
  writeChar("x", path, eos = NULL)
  mode <- strtoi("644", base = 8L)
  expect_true(freeze_raw_file(
    path,
    chmod_file = function(path, mode_text) {
      mode <<- strtoi("444", base = 8L)
      TRUE
    },
    mode_provider = function(path) mode,
    command_runner = function(...) stop("chflags must not be called")
  ))

  mode <- strtoi("700", base = 8L)
  flags <- "-"
  calls <- list()
  runner <- function(command, args, ...) {
    calls[[length(calls) + 1L]] <<- list(command = command, args = args)
    if (identical(command, "/usr/bin/chflags")) {
      flags <<- "uchg"
      return(0L)
    }
    structure(flags, status = 0L)
  }
  expect_true(freeze_raw_file(
    path,
    chmod_file = function(path, mode_text) TRUE,
    mode_provider = function(path) mode,
    command_runner = runner
  ))
  expect_true(validate_frozen_file(
    path, mode_provider = function(path) mode, command_runner = runner
  ))
  expect_identical(calls[[1L]]$command, "/usr/bin/chflags")
  expect_identical(calls[[1L]]$args, c("uchg", path))
})

test_that("raw freeze stops when chflags fails or uchg cannot be verified", {
  path <- tempfile("freeze-raw-")
  writeChar("x", path, eos = NULL)
  writable <- function(path) strtoi("700", base = 8L)
  expect_error(
    freeze_raw_file(
      path, chmod_file = function(...) TRUE, mode_provider = writable,
      command_runner = function(command, args, ...) 1L
    ),
    "chflags uchg failed"
  )
  runner <- function(command, args, ...) {
    if (identical(command, "/usr/bin/chflags")) return(0L)
    structure("-", status = 0L)
  }
  expect_error(
    freeze_raw_file(
      path, chmod_file = function(...) TRUE, mode_provider = writable,
      command_runner = runner
    ),
    "verified uchg"
  )
})

test_that("download stops before manifest when neither 0444 nor uchg is effective", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, manifest_path, root,
      runner = payload_runner("alpha\n"),
      chmod_file = function(path, mode) TRUE,
      mode_provider = function(path) strtoi("700", base = 8L),
      freeze_runner = function(command, args, ...) 1L,
      clock = function() "2026-07-11T07:00:00Z"
    ),
    "chflags uchg failed"
  )
  expect_false(file.exists(manifest_path))
})

test_that("identical final and receipt rerun is a timestamp-preserving no-op", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  download_inventory_row(
    inventory[1L, ], inventory, manifest_path, root,
    runner = payload_runner("alpha\n"), clock = function() "2026-07-11T07:00:00Z"
  )
  before <- readBin(manifest_path, "raw", n = file.info(manifest_path)$size)
  timestamp <- read_manifest_csv(manifest_path)$frozen_at_utc
  mtime <- file.info(manifest_path)$mtime
  result <- download_inventory_row(
    inventory[1L, ], inventory, manifest_path, root,
    runner = function(...) stop("runner must not be called"),
    clock = function() "2026-07-11T09:00:00Z"
  )
  expect_identical(result$status, "skipped")
  expect_identical(readBin(manifest_path, "raw", n = file.info(manifest_path)$size), before)
  expect_identical(file.info(manifest_path)$mtime, mtime)
  expect_identical(read_manifest_csv(manifest_path)$frozen_at_utc, timestamp)

  drifted_inventory <- inventory
  drifted_inventory$expected_checksum[[1L]] <- strrep("0", 32L)
  expect_error(
    download_inventory_row(
      drifted_inventory[1L, ], drifted_inventory, manifest_path, root,
      runner = function(...) stop("runner must not be called")
    ),
    "md5 mismatch"
  )
})

test_that("existing final without receipt is safely adopted only if upstream-valid", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  final <- file.path(root, safe_raw_relative_path(inventory[1L, ]))
  dir.create(dirname(final), recursive = TRUE)
  writeChar("alpha\n", final, eos = NULL)
  result <- download_inventory_row(
    inventory[1L, ], inventory, manifest_path, root,
    runner = function(...) stop("runner must not be called"),
    clock = function() "2026-07-11T07:00:00Z"
  )
  expect_identical(result$status, "adopted")
  expect_true(verify_manifest(read_manifest_csv(manifest_path), inventory, root))

  root2 <- make_project()
  final2 <- file.path(root2, safe_raw_relative_path(inventory[1L, ]))
  dir.create(dirname(final2), recursive = TRUE)
  writeChar("omega\n", final2, eos = NULL)
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, file.path(root2, "MANIFEST.csv"), root2,
      runner = function(...) stop("runner must not be called")
    ),
    "md5 mismatch"
  )
})

test_that("manifest receipt conflict stops before download", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  receipt <- receipt_for_payload(inventory[1L, ], root, "alpha\n")
  receipt$bytes <- receipt$bytes + 1
  utils::write.csv(receipt, manifest_path, row.names = FALSE)
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, manifest_path, root,
      runner = function(...) stop("runner must not be called")
    ),
    "bytes"
  )

  unlink(file.path(root, receipt$path))
  expect_error(
    download_inventory_row(
      inventory[1L, ], inventory, manifest_path, root,
      runner = function(...) stop("runner must not be called")
    ),
    "bytes"
  )
})

test_that("missing file is redownloaded only when new SHA equals old receipt", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  receipt <- receipt_for_payload(inventory[1L, ], root, "alpha\n")
  final <- file.path(root, receipt$path)
  unlink(final)
  utils::write.csv(receipt, manifest_path, row.names = FALSE)
  before <- readBin(manifest_path, "raw", n = file.info(manifest_path)$size)
  result <- download_inventory_row(
    inventory[1L, ], inventory, manifest_path, root,
    runner = payload_runner("alpha\n")
  )
  expect_identical(result$status, "completed")
  expect_identical(readBin(manifest_path, "raw", n = file.info(manifest_path)$size), before)

  unlink(final)
  inventory_changed <- inventory
  inventory_changed$expected_checksum[[1L]] <- unname(tools::md5sum({
    p <- tempfile(); writeChar("omega\n", p, eos = NULL); p
  }))
  expect_error(
    download_inventory_row(
      inventory_changed[1L, ], inventory_changed, manifest_path, root,
      runner = payload_runner("omega\n")
    ),
    "receipt source metadata|receipt SHA-256"
  )
  expect_false(file.exists(final))
})

test_that("atomic manifest candidate failure preserves previous bytes", {
  inventory <- fixture_inventory()
  root <- make_project()
  manifest_path <- file.path(root, "MANIFEST.csv")
  old <- receipt_for_payload(inventory[1L, ], root, "alpha\n")
  utils::write.csv(old, manifest_path, row.names = FALSE)
  before <- readBin(manifest_path, "raw", n = file.info(manifest_path)$size)
  bad <- rbind(old, transform(old, source_id = "source-b", file_name = "source-b.tsv.gz",
                             path = safe_raw_relative_path(inventory[2L, ]),
                             source_url = inventory$source_url[[2L]]))
  expect_error(write_manifest_atomic(bad, manifest_path, inventory, root), "missing")
  expect_identical(readBin(manifest_path, "raw", n = file.info(manifest_path)$size), before)

  expect_error(
    write_manifest_atomic(empty_manifest_fixture(), manifest_path, inventory, root),
    "remove immutable receipt"
  )
  expect_identical(readBin(manifest_path, "raw", n = file.info(manifest_path)$size), before)

  later <- old
  later$frozen_at_utc <- "2026-07-11T08:00:00Z"
  expect_error(
    write_manifest_atomic(later, manifest_path, inventory, root),
    "conflicts with immutable receipt"
  )
  expect_identical(readBin(manifest_path, "raw", n = file.info(manifest_path)$size), before)
})

test_that("atomic manifest append hashes only newly added receipt rows", {
  fixture <- many_receipt_fixture(3L)
  path <- file.path(fixture$root, "MANIFEST.csv")
  sha_calls <- 0L
  checksum_calls <- 0L
  sha_provider <- function(path) {
    sha_calls <<- sha_calls + 1L
    sha256_file(path)
  }
  checksum_provider <- function(path, algorithm) {
    checksum_calls <<- checksum_calls + 1L
    checksum_file(path, algorithm)
  }

  manifest <- empty_manifest_fixture()
  for (index in 1:2) {
    manifest <- append_receipt_idempotent(
      manifest, fixture$receipts[index, , drop = FALSE]
    )
    write_manifest_atomic(
      manifest, path, fixture$inventory, fixture$root,
      sha256_provider = sha_provider,
      checksum_provider = checksum_provider
    )
  }
  expect_identical(sha_calls, 2L)
  expect_identical(checksum_calls, 2L)

  conflict <- manifest
  conflict$sha256[[1L]] <- strrep("a", 64L)
  expect_error(
    write_manifest_atomic(
      conflict, path, fixture$inventory, fixture$root,
      sha256_provider = sha_provider,
      checksum_provider = checksum_provider
    ),
    "immutable receipt"
  )
  expect_identical(sha_calls, 2L)
  expect_identical(checksum_calls, 2L)
})

test_that("100 sequential manifest appends perform linear file verification", {
  fixture <- many_receipt_fixture(100L)
  path <- file.path(fixture$root, "MANIFEST.csv")
  sha_calls <- 0L
  checksum_calls <- 0L
  manifest <- empty_manifest_fixture()
  for (index in seq_len(100L)) {
    manifest <- append_receipt_idempotent(
      manifest, fixture$receipts[index, , drop = FALSE]
    )
    write_manifest_atomic(
      manifest, path, fixture$inventory, fixture$root,
      sha256_provider = function(path) {
        sha_calls <<- sha_calls + 1L
        sha256_file(path)
      },
      checksum_provider = function(path, algorithm) {
        checksum_calls <<- checksum_calls + 1L
        checksum_file(path, algorithm)
      }
    )
  }
  expect_identical(sha_calls, 100L)
  expect_identical(checksum_calls, 100L)
  expect_true(verify_manifest(
    path, fixture$inventory, fixture$root, verify_files = FALSE,
    sha256_provider = function(path) stop("structural verify must not hash"),
    checksum_provider = function(path, algorithm) {
      stop("structural verify must not checksum")
    }
  ))
  full_sha_calls <- 0L
  full_checksum_calls <- 0L
  expect_true(verify_manifest(
    path, fixture$inventory, fixture$root, verify_files = TRUE,
    sha256_provider = function(path) {
      full_sha_calls <<- full_sha_calls + 1L
      sha256_file(path)
    },
    checksum_provider = function(path, algorithm) {
      full_checksum_calls <<- full_checksum_calls + 1L
      checksum_file(path, algorithm)
    }
  ))
  expect_identical(full_sha_calls, 100L)
  expect_identical(full_checksum_calls, 100L)
})

test_that("5,177-row structural validation constructs the inventory index once", {
  inventory <- read_source_inventory_csv(
    file.path(project_root, "00_admin", "source_inventory.csv")
  )
  receipt <- data.frame(
    dataset = inventory$dataset,
    source_id = inventory$source_id,
    file_name = inventory$file_name,
    path = vapply(seq_len(nrow(inventory)), function(index) {
      safe_raw_relative_path(inventory[index, , drop = FALSE])
    }, character(1)),
    source_url = inventory$source_url,
    license = inventory$license,
    bytes = as.numeric(inventory$expected_bytes),
    sha256 = rep(strrep("a", 64L), nrow(inventory)),
    frozen_at_utc = rep("2026-07-11T07:00:00Z", nrow(inventory)),
    stringsAsFactors = FALSE
  )
  calls <- 0L
  indexed_rows <- 0L
  expect_invisible(validate_receipt_structure(
    receipt,
    inventory,
    inventory_key_provider = function(x) {
      calls <<- calls + 1L
      indexed_rows <<- indexed_rows + nrow(x)
      inventory_key(x)
    }
  ))
  expect_identical(calls, 1L)
  expect_identical(indexed_rows, 5177L)
})

test_that("disk preflight uses injected free space and a safety reserve", {
  inventory <- fixture_inventory()
  root <- make_project()
  expect_error(
    preflight_download_space(
      inventory, empty_manifest_fixture(), root,
      free_space_provider = function(path) 100,
      reserve_bytes = 100
    ),
    "required=112.*free=100"
  )
  result <- preflight_download_space(
    inventory, empty_manifest_fixture(), root,
    free_space_provider = function(path) 1000,
    reserve_bytes = 100
  )
  expect_identical(result$download_bytes, 12)
  expect_identical(result$required_bytes, 112)
})

test_that("CLI filters are strict, unique and preserve inventory order", {
  inventory <- fixture_inventory()[c(2L, 1L), ]
  selected <- select_download_rows(
    inventory,
    c("--dataset", "ld_reference_1kg", "--file", "source-a.tsv", "--limit", "1")
  )
  expect_identical(selected$file_name, "source-a.tsv")
  expect_identical(
    select_download_rows(inventory, c("--dataset", "ld_reference_1kg"))$file_name,
    inventory$file_name
  )
  expect_error(select_download_rows(inventory, "--unknown"), "unknown argument")
  expect_error(
    select_download_rows(inventory, c("--dataset", "ld_reference_1kg", "--dataset", "x")),
    "duplicate --dataset"
  )
  expect_error(select_download_rows(inventory, c("--dataset", "missing")), "no inventory rows")
  expect_error(select_download_rows(inventory, c("--file", "missing.tsv")), "no inventory rows")
  expect_error(select_download_rows(inventory, c("--limit", "0")), "positive integer")
})

test_that("download selection reports exact current immutable key on failure", {
  inventory <- fixture_inventory()
  root <- make_project()
  expect_error(
    download_selected_rows(
      inventory[1L, ], inventory, file.path(root, "MANIFEST.csv"), root,
      runner = payload_runner("wrong"), reserve_bytes = 0,
      free_space_provider = function(path) 1000
    ),
    "ld_reference_1kg/source-a/source-a.tsv"
  )

  manifest_path <- file.path(root, "MANIFEST.csv")
  receipt <- receipt_for_payload(inventory[1L, ], root, "alpha\n")
  receipt$sha256 <- strrep("a", 64L)
  utils::write.csv(receipt, manifest_path, row.names = FALSE)
  expect_error(
    download_selected_rows(
      inventory[1L, ], inventory, manifest_path, root,
      runner = function(...) stop("runner must not be called"), reserve_bytes = 0,
      free_space_provider = function(path) 1000
    ),
    "ld_reference_1kg/source-a/source-a.tsv"
  )
})

test_that("download lock rejects live owner, reclaims stale lock and cleans up", {
  root <- make_project()
  lock <- file.path(root, ".download.lock")
  token <- acquire_download_lock(lock, token = "first", age_provider = function(path) 0)
  expect_identical(token, "first")
  expect_error(
    acquire_download_lock(lock, token = "second", age_provider = function(path) 0),
    "already held"
  )
  release_download_lock(lock, token)
  expect_false(dir.exists(lock))

  dir.create(lock)
  writeLines("old", file.path(lock, "owner"))
  token <- acquire_download_lock(
    lock, token = "new", stale_after = 60,
    age_provider = function(path) 61,
    owner_alive_provider = function(owner) FALSE
  )
  expect_identical(readLines(file.path(lock, "owner")), "new")
  release_download_lock(lock, token)

  dir.create(lock)
  writeLines("live", file.path(lock, "owner"))
  expect_error(
    acquire_download_lock(
      lock, token = "blocked", stale_after = 60,
      age_provider = function(path) 61,
      owner_alive_provider = function(owner) TRUE
    ),
    "already held"
  )
  unlink(lock, recursive = TRUE)

  expect_error(
    with_download_lock(
      lock,
      code = function() stop("boom"),
      token = "scoped",
      age_provider = function(path) 0
    ),
    "boom"
  )
  expect_false(dir.exists(lock))
})

test_that("stale lock reclaim never deletes a lock after losing the rename race", {
  root <- make_project()
  lock <- file.path(root, ".download.lock")
  dir.create(lock)
  writeLines("old", file.path(lock, "owner"))
  removed <- character()
  expect_error(
    acquire_download_lock(
      lock, token = "contender", stale_after = 60,
      age_provider = function(path) 61,
      owner_alive_provider = function(owner) FALSE,
      rename_lock_dir = function(from, to) FALSE,
      remove_lock_dir = function(path) {
        removed <<- c(removed, path)
        unlink(path, recursive = TRUE)
      }
    ),
    "already held"
  )
  expect_identical(readLines(file.path(lock, "owner")), "old")
  expect_length(removed, 0L)
})

test_that("failed atomic shlock guard never renames the current lock", {
  root <- make_project()
  lock <- file.path(root, ".download.lock")
  dir.create(lock)
  writeLines("old", file.path(lock, "owner"))
  captured <- new.env(parent = emptyenv())
  renamed <- FALSE
  expect_error(
    acquire_download_lock(
      lock, token = "contender", stale_after = 60,
      age_provider = function(path) 61,
      owner_alive_provider = function(owner) FALSE,
      shlock_runner = function(command, args) {
        captured$command <- command
        captured$args <- args
        1L
      },
      rename_lock_dir = function(from, to) {
        renamed <<- TRUE
        FALSE
      }
    ),
    "transition guard"
  )
  expect_identical(captured$command, "/usr/bin/shlock")
  expect_identical(
    captured$args,
    c("-f", reclaim_guard_path(lock), "-p", as.character(Sys.getpid()))
  )
  expect_false(renamed)
  expect_identical(readLines(file.path(lock, "owner")), "old")
})

test_that("create-after-rename failure removes quarantine but preserves new owner", {
  root <- make_project()
  lock <- file.path(root, ".download.lock")
  quarantine <- paste0(lock, ".stale-test")
  dir.create(lock)
  writeLines("old", file.path(lock, "owner"))
  create_calls <- 0L
  removed <- character()
  expect_error(
    acquire_download_lock(
      lock, token = "contender", stale_after = 60,
      age_provider = function(path) 61,
      owner_alive_provider = function(owner) FALSE,
      quarantine_factory = function(path) quarantine,
      create_lock_dir = function(path) {
        create_calls <<- create_calls + 1L
        if (create_calls <= 2L) return(FALSE)
        dir.create(path)
        writeLines("other-owner", file.path(path, "owner"))
        FALSE
      },
      remove_lock_dir = function(path) {
        removed <<- c(removed, path)
        unlink(path, recursive = TRUE)
      }
    ),
    "already held"
  )
  expect_identical(readLines(file.path(lock, "owner")), "other-owner")
  expect_identical(removed, quarantine)
  expect_false(dir.exists(quarantine))
})

test_that("quarantine cleanup failure removes only the exact newly owned lock", {
  root <- make_project()
  lock <- file.path(root, ".download.lock")
  quarantine <- paste0(lock, ".stale-cleanup-test")
  dir.create(lock)
  writeLines("old", file.path(lock, "owner"))
  expect_error(
    acquire_download_lock(
      lock, token = "contender", stale_after = 60,
      age_provider = function(path) 61,
      owner_alive_provider = function(owner) FALSE,
      quarantine_factory = function(path) quarantine,
      remove_lock_dir = function(path) {
        if (identical(path, quarantine)) return(FALSE)
        default_remove_lock_dir(path)
      }
    ),
    "Could not remove stale download-lock quarantine"
  )
  expect_identical(read_lock_owner(lock), "old")
  expect_false(dir.exists(quarantine))
  expect_false(file.exists(reclaim_guard_path(lock)))
})

test_that("guard release preserves a successor created after verified unlink", {
  root <- make_project()
  lock <- file.path(root, ".download.lock")
  guard_path <- reclaim_guard_path(lock)
  writeLines(as.character(Sys.getpid()), guard_path)
  guard <- list(path = guard_path, pid = as.integer(Sys.getpid()))
  expect_true(release_reclaim_guard(
    guard,
    remove_file = function(path) {
      unlink(path)
      writeLines("999999", path)
      0L
    }
  ))
  expect_identical(readLines(guard_path), "999999")
  unlink(guard_path)
})

test_that("owner-write failure cleans only a lock proven owned by the attempt", {
  root <- make_project()
  lock <- file.path(root, ".download.lock")
  expect_error(
    acquire_download_lock(
      lock, token = "failed-owner",
      owner_writer = function(path, token) stop("owner write failed")
    ),
    "owner write failed"
  )
  expect_false(dir.exists(lock))

  expect_error(
    acquire_download_lock(
      lock, token = "failed-owner",
      owner_writer = function(path, token) {
        writeLines("other-owner", file.path(path, "owner"))
        stop("owner write failed")
      }
    ),
    "owner write failed"
  )
  expect_true(dir.exists(lock))
  expect_identical(readLines(file.path(lock, "owner")), "other-owner")
  unlink(lock, recursive = TRUE)
})

test_that("lock tokens and quarantine paths are sanitized", {
  root <- make_project()
  lock <- file.path(root, ".download.lock")
  expect_error(acquire_download_lock(lock, token = "../bad"), "token")
  expect_false(dir.exists(lock))

  dir.create(lock)
  writeLines("old", file.path(lock, "owner"))
  expect_error(
    acquire_download_lock(
      lock, token = "new", stale_after = 60,
      age_provider = function(path) 61,
      owner_alive_provider = function(owner) FALSE,
      quarantine_factory = function(path) file.path(dirname(root), "outside")
    ),
    "quarantine"
  )
  expect_identical(readLines(file.path(lock, "owner")), "old")
})

test_that("24 processes reclaim one stale lock with exactly one owner", {
  root <- make_project()
  for (round in 1:3) {
    lock <- file.path(root, paste0(".stress-", round, ".lock"))
    dir.create(lock)
    writeLines("old", file.path(lock, "owner"))
    results <- parallel::mclapply(
      seq_len(24L),
      function(index) {
        token <- sprintf("worker-%02d", index)
        tryCatch({
          acquire_download_lock(
            lock, token = token, stale_after = 60,
            age_provider = function(path) {
              owner_path <- file.path(path, "owner")
              owner <- if (file.exists(owner_path)) readLines(owner_path) else character()
              if (identical(owner, "old")) 61 else 0
            },
            owner_alive_provider = function(owner) FALSE
          )
          token
        }, error = function(error) NA_character_)
      },
      mc.cores = 24L,
      mc.preschedule = FALSE
    )
    winners <- unlist(results, use.names = FALSE)
    winners <- winners[!is.na(winners)]
    expect_length(winners, 1L)
    expect_identical(readLines(file.path(lock, "owner")), winners)
    expect_length(
      list.files(root, pattern = paste0("^\\.stress-", round, "\\.lock\\.stale-")),
      0L
    )
    expect_error(release_download_lock(lock, "not-owner"), "another process")
    expect_true(release_download_lock(lock, winners))
    expect_false(dir.exists(lock))
  }
})

test_that("a delayed stale reclaimer cannot move a successor lock", {
  root <- make_project()
  lock <- file.path(root, ".delayed.lock")
  ready <- file.path(root, "reclaimer-ready")
  proceed <- file.path(root, "reclaimer-proceed")
  dir.create(lock)
  writeLines("old", file.path(lock, "owner"))
  age <- function(path) {
    if (identical(read_lock_owner(path), "old")) 61 else 0
  }
  first <- parallel::mcparallel(tryCatch({
    acquire_download_lock(
      lock, token = "first-reclaimer", stale_after = 60,
      age_provider = age,
      owner_alive_provider = function(owner) FALSE,
      quarantine_factory = function(path) {
        file.create(ready)
        deadline <- Sys.time() + 5
        while (!file.exists(proceed) && Sys.time() < deadline) Sys.sleep(0.001)
        if (!file.exists(proceed)) stop("barrier timeout")
        default_lock_quarantine_path(path)
      }
    )
    "first-reclaimer"
  }, error = function(error) NA_character_), silent = TRUE)
  deadline <- Sys.time() + 5
  while (!file.exists(ready) && Sys.time() < deadline) Sys.sleep(0.001)
  expect_true(file.exists(ready))
  second <- tryCatch({
    acquire_download_lock(
      lock, token = "second-reclaimer", stale_after = 60,
      age_provider = age,
      owner_alive_provider = function(owner) FALSE
    )
    "second-reclaimer"
  }, error = function(error) NA_character_)
  file.create(proceed)
  first_result <- unname(parallel::mccollect(first)[[1L]])
  winners <- c(first_result, second)
  winners <- winners[!is.na(winners)]
  expect_length(winners, 1L)
  expect_identical(read_lock_owner(lock), winners)
  expect_true(release_download_lock(lock, winners))
})

test_that("exact-owner release guard prevents deletion of a successor", {
  root <- make_project()
  lock <- file.path(root, ".release-race.lock")
  ready <- file.path(root, "release-ready")
  proceed <- file.path(root, "release-proceed")
  token <- acquire_download_lock(lock, token = "original-owner")
  release_process <- parallel::mcparallel(tryCatch({
    release_download_lock(
      lock, token,
      remove_lock_dir = function(path) {
        file.create(ready)
        deadline <- Sys.time() + 5
        while (!file.exists(proceed) && Sys.time() < deadline) Sys.sleep(0.001)
        if (!file.exists(proceed)) stop("barrier timeout")
        default_remove_lock_dir(path)
      }
    )
  }, error = function(error) error), silent = TRUE)
  deadline <- Sys.time() + 5
  while (!file.exists(ready) && Sys.time() < deadline) Sys.sleep(0.001)
  expect_true(file.exists(ready))
  expect_error(
    acquire_download_lock(
      lock, token = "would-be-successor", stale_after = 60,
      age_provider = function(path) 61,
      owner_alive_provider = function(owner) FALSE
    ),
    "transition guard"
  )
  expect_identical(read_lock_owner(lock), token)
  file.create(proceed)
  released <- unname(parallel::mccollect(release_process)[[1L]])
  expect_true(isTRUE(released))
  expect_false(dir.exists(lock))
  expect_false(file.exists(reclaim_guard_path(lock)))
})
