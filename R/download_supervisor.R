dataset_receipts_complete <- function(dataset, inventory, manifest) {
  required <- c("dataset", "source_id", "file_name")
  if (!is.character(dataset) || length(dataset) != 1L || is.na(dataset) ||
      !nzchar(dataset) || !all(required %in% names(inventory)) ||
      !all(required %in% names(manifest))) {
    return(FALSE)
  }
  target <- inventory[inventory$dataset == dataset, required, drop = FALSE]
  if (!nrow(target)) return(FALSE)
  received <- manifest[manifest$dataset == dataset, required, drop = FALSE]
  key <- function(x) paste(x$dataset, x$source_id, x$file_name, sep = "\r")
  target_keys <- key(target)
  received_keys <- key(received)
  !anyDuplicated(target_keys) && !anyDuplicated(received_keys) &&
    setequal(target_keys, received_keys)
}

reclaim_dead_download_lock <- function(lock_path) {
  if (!dir.exists(lock_path)) return(invisible(FALSE))
  token <- acquire_download_lock(lock_path, stale_after = 0)
  release_download_lock(lock_path, token)
  if (dir.exists(lock_path)) {
    stop("Dead download lock reclamation did not remove the lock", call. = FALSE)
  }
  invisible(TRUE)
}

wait_for_download_lock <- function(
  lock_path,
  owner_alive = default_lock_owner_alive,
  sleeper = Sys.sleep,
  reclaimer = reclaim_dead_download_lock,
  poll_seconds = 30,
  logger = message
) {
  dependencies <- list(owner_alive, sleeper, reclaimer, logger)
  if (!all(vapply(dependencies, is.function, logical(1))) ||
      !is.numeric(poll_seconds) || length(poll_seconds) != 1L ||
      is.na(poll_seconds) || !is.finite(poll_seconds) || poll_seconds <= 0) {
    stop("Download supervisor lock dependencies are invalid", call. = FALSE)
  }
  while (dir.exists(lock_path)) {
    owner <- read_lock_owner(lock_path)
    if (length(owner) == 1L && isTRUE(owner_alive(owner))) {
      logger("A live downloader owns the lock; waiting ", poll_seconds, " seconds")
      sleeper(poll_seconds)
      next
    }
    reclaimer(lock_path)
    break
  }
  invisible(TRUE)
}

supervise_downloads <- function(
  datasets,
  inventory,
  manifest_reader,
  lock_waiter,
  dataset_runner,
  final_verifier,
  logger = message
) {
  dependencies <- list(
    manifest_reader, lock_waiter, dataset_runner, final_verifier, logger
  )
  if (!is.character(datasets) || !length(datasets) || anyNA(datasets) ||
      any(!nzchar(datasets)) || !all(vapply(dependencies, is.function, logical(1)))) {
    stop("Download supervisor dependencies are invalid", call. = FALSE)
  }
  for (dataset in datasets) {
    manifest <- manifest_reader()
    if (dataset_receipts_complete(dataset, inventory, manifest)) {
      logger("Dataset already complete: ", dataset)
      next
    }
    lock_waiter()
    status <- dataset_runner(dataset)
    if (!is.numeric(status) || length(status) != 1L || is.na(status) ||
        as.integer(status) != 0L) {
      stop(
        "Supervised dataset download failed for ", dataset,
        " with status ", if (length(status)) status[[1L]] else "unknown",
        call. = FALSE
      )
    }
    if (!dataset_receipts_complete(dataset, inventory, manifest_reader())) {
      stop("Dataset process exited successfully without complete receipts: ", dataset,
           call. = FALSE)
    }
  }
  if (!isTRUE(final_verifier())) {
    stop("Final full-file verification failed", call. = FALSE)
  }
  logger("All supervised datasets and final verification completed")
  TRUE
}

run_download_supervisor <- function(project_root) {
  project_root <- normalizePath(project_root, mustWork = TRUE)
  inventory_path <- file.path(project_root, "00_admin", "source_inventory.csv")
  manifest_path <- file.path(project_root, "MANIFEST.csv")
  freeze_script <- file.path(project_root, "scripts", "02_download_freeze.R")
  lock_path <- file.path(project_root, ".download-freeze.lock")
  rscript <- file.path(R.home("bin"), "Rscript")
  inventory <- read_source_inventory_csv(inventory_path)
  validate_source_inventory(inventory, inventory_path)

  supervise_downloads(
    datasets = c("microbiome_2026", "microbiome_2026_hunt"),
    inventory = inventory,
    manifest_reader = function() read_manifest_csv(manifest_path),
    lock_waiter = function() wait_for_download_lock(lock_path),
    dataset_runner = function(dataset) {
      result <- safe_system2(rscript, c(freeze_script, "--dataset", dataset))
      command_result_status(result)
    },
    final_verifier = function() {
      manifest <- read_manifest_csv(manifest_path)
      verify_manifest(
        manifest, inventory, project_root,
        verify_files = TRUE, verify_frozen = TRUE
      )
    }
  )
}
