source("R/exposure_candidates.R")
source("R/finalize_analysis.R")

result <- finalize_analysis()
write_final_analysis_receipt()
print(result$decision)
