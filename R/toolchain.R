PLINK_GITHUB_COMMIT <- "2fcd3ee3088b729c7eb34cf2aac9dc2e04fe4412"
PLINK_URL <- paste0(
  "https://raw.githubusercontent.com/MRCIEU/genetics.binaRies/",
  PLINK_GITHUB_COMMIT,
  "/binaries/Darwin/plink"
)
PLINK_SHA256 <- "4a0043fd44f12d100cbf2cb1ffa9a703130ba3503fd56cd2dbec9b76314d2859"
PLINK_VERSION <- "PLINK v1.90b6.21 64-bit (19 Oct 2020)"
PLINK_RELATIVE_PATH <- file.path(
  "08_qc", "download_cache", "tools", "plink", "plink"
)

plink_path <- function(project_root = ".") {
  root <- normalizePath(project_root, mustWork = TRUE)
  file.path(root, PLINK_RELATIVE_PATH)
}

plink_sha256 <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("PLINK binary does not exist: %s", path), call. = FALSE)
  }
  digest::digest(path, algo = "sha256", serialize = FALSE, file = TRUE)
}

plink_version <- function(path) {
  if (!file.exists(path)) {
    stop(sprintf("PLINK binary does not exist: %s", path), call. = FALSE)
  }
  output <- suppressWarnings(
    system2(path, "--version", stdout = TRUE, stderr = TRUE)
  )
  status <- attr(output, "status")
  if ((!is.null(status) && status != 0L) || length(output) == 0L) {
    stop(sprintf("PLINK version check failed: %s", path), call. = FALSE)
  }
  output[[1L]]
}

verify_plink <- function(path = plink_path()) {
  if (!file.exists(path)) {
    stop(sprintf("PLINK binary does not exist: %s", path), call. = FALSE)
  }
  if (file.access(path, mode = 1) != 0L) {
    stop(sprintf("PLINK binary is not executable: %s", path), call. = FALSE)
  }

  actual_sha256 <- plink_sha256(path)
  if (!identical(actual_sha256, PLINK_SHA256)) {
    stop(
      sprintf(
        "PLINK SHA-256 mismatch: expected %s, got %s",
        PLINK_SHA256,
        actual_sha256
      ),
      call. = FALSE
    )
  }

  actual_version <- plink_version(path)
  if (!identical(actual_version, PLINK_VERSION)) {
    stop(
      sprintf(
        "PLINK version mismatch: expected '%s', got '%s'",
        PLINK_VERSION,
        actual_version
      ),
      call. = FALSE
    )
  }

  normalizePath(path)
}

ensure_plink <- function(project_root = ".") {
  if (!identical(Sys.info()[["sysname"]], "Darwin")) {
    stop("The pinned PLINK toolchain is currently defined for macOS only.", call. = FALSE)
  }
  if (!startsWith(PLINK_URL, "https://")) {
    stop("PLINK_URL must use HTTPS.", call. = FALSE)
  }

  target <- plink_path(project_root)
  if (file.exists(target)) {
    verified <- try(verify_plink(target), silent = TRUE)
    if (!inherits(verified, "try-error")) {
      return(verified)
    }
  }

  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  part <- paste0(target, ".part")
  if (file.exists(part) && !unlink(part)) {
    stop(sprintf("Could not remove stale partial download: %s", part), call. = FALSE)
  }
  on.exit(unlink(part), add = TRUE)

  status <- utils::download.file(
    PLINK_URL,
    destfile = part,
    method = "libcurl",
    mode = "wb",
    quiet = FALSE
  )
  if (!identical(status, 0L)) {
    stop(sprintf("PLINK download failed with status %s", status), call. = FALSE)
  }

  actual_sha256 <- plink_sha256(part)
  if (!identical(actual_sha256, PLINK_SHA256)) {
    stop(
      sprintf(
        "Downloaded PLINK SHA-256 mismatch: expected %s, got %s",
        PLINK_SHA256,
        actual_sha256
      ),
      call. = FALSE
    )
  }

  Sys.chmod(part, mode = "0755")
  actual_version <- plink_version(part)
  if (!identical(actual_version, PLINK_VERSION)) {
    stop(
      sprintf(
        "Downloaded PLINK version mismatch: expected '%s', got '%s'",
        PLINK_VERSION,
        actual_version
      ),
      call. = FALSE
    )
  }

  if (!file.rename(part, target)) {
    stop(sprintf("Could not atomically install PLINK at %s", target), call. = FALSE)
  }
  verify_plink(target)
}
