source("R/gwas_schema.R")
source("R/exposure_candidates.R")
source("R/outcomes.R")
source("R/reverse_outcomes.R")

workers <- suppressWarnings(as.integer(Sys.getenv("MR_WORKERS", unset = "8")))
if (is.na(workers) || workers <= 0L) {
  stop("MR_WORKERS must be a positive integer", call. = FALSE)
}
cat(sprintf(
  "Extracting 24 reverse-ED instruments from 1,572 Swedish GWAS files with %d workers\n",
  workers
))
inventory <- extract_reverse_microbiome_outcomes(workers = workers)
cat(sprintf(
  "Reverse outcome extraction complete: %d traits, %d matched rows\n",
  nrow(inventory), sum(inventory$matched_rows)
))
