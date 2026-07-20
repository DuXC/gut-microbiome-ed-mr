source("R/exposure_candidates.R")
source("R/mr_core.R")

workers <- suppressWarnings(as.integer(Sys.getenv("MR_WORKERS", unset = "8")))
if (is.na(workers) || workers <= 0L) {
  stop("MR_WORKERS must be a positive integer", call. = FALSE)
}
cat(sprintf("Running prespecified MR estimators with %d workers\n", workers))
result <- run_all_mr(workers = workers, nboot = 1000L)
cat(sprintf(
  "MR complete: %d pairs, %d method rows, %d estimated method rows\n",
  nrow(result$registry), nrow(result$estimates),
  sum(result$estimates$analysis_status == "estimated")
))
