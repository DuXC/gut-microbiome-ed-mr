source("R/gwas_schema.R")
source("R/exposure_candidates.R")
source("R/harmonization.R")
source("R/mr_core.R")
source("R/multiplicity.R")
source("R/reverse_analysis.R")

workers <- suppressWarnings(as.integer(Sys.getenv("MR_WORKERS", unset = "8")))
if (is.na(workers) || workers <= 0L) {
  stop("MR_WORKERS must be a positive integer", call. = FALSE)
}
cat("Harmonising the reverse ED-to-microbiome family\n")
harmonised <- build_reverse_harmonised_layer()
print(harmonised$inventory)
cat(sprintf("Running reverse MR with %d workers\n", workers))
result <- run_all_reverse_mr(workers = workers, nboot = 1000L)
write_reverse_run_receipt(workers = workers, nboot = 1000L)
cat(sprintf(
  "Reverse MR complete: N=%d, estimable=%d, BH q<0.05=%d\n",
  nrow(result$registry),
  sum(result$multiplicity$analysis_status == "estimated"),
  sum(result$multiplicity$fdr_significant)
))
