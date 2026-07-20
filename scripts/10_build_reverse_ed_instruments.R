source("R/gwas_schema.R")
source("R/exposure_candidates.R")
source("R/instruments.R")
source("R/outcomes.R")
source("R/harmonization.R")
source("R/reverse_instruments.R")

workers <- suppressWarnings(as.integer(Sys.getenv("MR_WORKERS", unset = "8")))
if (is.na(workers) || workers <= 0L) {
  stop("MR_WORKERS must be a positive integer", call. = FALSE)
}
cat("Extracting genome-wide-significant ED variants\n")
extract_ed_gws_candidates()
cat("Building and clumping the EUR ED LD panel\n")
result <- build_reverse_ed_instruments(workers = workers)
print(result$inventory)
cat("Reverse ED instrument construction complete\n")
