source("R/gwas_schema.R")
source("R/exposure_candidates.R")
source("R/outcomes.R")

workers <- suppressWarnings(as.integer(Sys.getenv("MR_WORKERS", unset = "4")))
if (is.na(workers) || workers <= 0L) {
  stop("MR_WORKERS must be a positive integer", call. = FALSE)
}

cat(sprintf("Extracting outcome candidates with %d workers\n", workers))
inventory <- build_outcome_candidate_layer(workers = workers)
print(inventory[, c(
  "outcome_id", "analysis_role", "effect_scale", "unique_matched_ids",
  "coverage"
)])
cat("Outcome candidate extraction complete\n")
