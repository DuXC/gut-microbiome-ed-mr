source("R/gwas_schema.R")
source("R/exposure_candidates.R")
source("R/harmonization.R")

cat("Harmonising exposure instruments to four ED outcome layers\n")
result <- build_harmonised_layer(
  palindromic_maf_max = 0.42,
  eaf_tolerance = 0.10
)
print(result$inventory)
cat("Harmonisation complete\n")
