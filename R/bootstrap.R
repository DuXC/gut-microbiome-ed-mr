bootstrap_mode <- function(args, lock_exists) {
  if (length(args) > 1L || (length(args) == 1L && args != "--refresh-lock")) {
    stop("Usage: Rscript scripts/00_bootstrap.R [--refresh-lock]", call. = FALSE)
  }

  refresh_lock <- identical(args, "--refresh-lock")
  if (!lock_exists && !refresh_lock) {
    stop(
      "renv.lock is missing; rerun with --refresh-lock to create it explicitly.",
      call. = FALSE
    )
  }

  if (refresh_lock) "refresh" else "restore"
}
