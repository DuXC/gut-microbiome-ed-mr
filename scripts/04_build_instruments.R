source("R/config.R")
source("R/gwas_schema.R")
source("R/exposure_candidates.R")
source("R/instruments.R")

integer_env <- function(name, default) {
  value <- suppressWarnings(as.integer(Sys.getenv(name, unset = default)))
  if (is.na(value) || value <= 0L) {
    stop(name, " must be a positive integer", call. = FALSE)
  }
  value
}

workers <- integer_env("MR_WORKERS", "4")
plink_binary <- Sys.getenv(
  "MR_PLINK_BINARY", unset = "08_qc/download_cache/tools/plink/plink"
)
bfile_prefix <- Sys.getenv(
  "MR_EUR_BFILE",
  unset = paste0(
    "03_data/processed/ld_reference_high_density/",
    "eur_candidate_chr_normalized_v2"
  )
)

cat(sprintf("Building instrument inventory with %d workers\n", workers))
build_instrument_inventory(
  workers = workers, plink_binary = plink_binary, bfile_prefix = bfile_prefix
)
cat("Instrument inventory complete\n")
