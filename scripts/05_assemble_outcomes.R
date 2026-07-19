source("R/exposure_candidates.R")
source("R/outcomes.R")

cat("Assembling ED 2025 split gzip outcomes\n")
receipt <- build_ed_outcome_assemblies()
print(receipt[, c(
  "ancestry", "assembled_bytes", "assembled_sha256", "gzip_valid"
)])
cat("ED 2025 outcome assembly complete\n")
