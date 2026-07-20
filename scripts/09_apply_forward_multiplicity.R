source("R/exposure_candidates.R")
source("R/multiplicity.R")

result <- apply_forward_multiplicity()
cat(sprintf(
  paste0(
    "Forward-primary family frozen: N=%d, estimable=%d, ",
    "nominal P<0.05=%d, BH q<0.05=%d\n"
  ),
  unique(result$n_forward), sum(result$analysis_status == "estimated"),
  sum(result$p < 0.05, na.rm = TRUE), sum(result$fdr_significant)
))
