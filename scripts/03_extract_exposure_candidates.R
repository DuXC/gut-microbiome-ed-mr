source("R/gwas_schema.R")
source("R/exposure_candidates.R")

integer_env <- function(name, default) {
  value <- Sys.getenv(name, unset = as.character(default))
  parsed <- suppressWarnings(as.integer(value))
  if (is.na(parsed) || parsed <= 0L) {
    stop(name, " must be a positive integer", call. = FALSE)
  }
  parsed
}

workers <- integer_env("MR_WORKERS", 4L)
shard_size <- integer_env("MR_SHARD_SIZE", 16L)

cat(sprintf(
  "Starting exposure candidate extraction with %d workers and %d accessions per shard\n",
  workers, shard_size
))
run_exposure_candidate_extraction(workers = workers, shard_size = shard_size)
cat("Exposure candidate extraction complete\n")
