#!/usr/bin/env Rscript

project_root <- normalizePath(file.path(getwd(), "..", "..", ".."),
                              winslash = "/", mustWork = TRUE)
package_root <- normalizePath(file.path(getwd(), ".."), winslash = "/",
                              mustWork = TRUE)
local_library <- file.path(
  project_root, "renv", "library", "macos", "R-4.6",
  "aarch64-apple-darwin25.4.0"
)
if (dir.exists(local_library)) .libPaths(c(local_library, .libPaths()))

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(jsonlite)
})

data_dir <- file.path(getwd(), "tmp_table_data")
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
v03 <- file.path(project_root, "05_results", "v0_3_20260722")

fmt_int <- function(x) {
  gsub(",", " ", format(as.integer(x), big.mark = ",", scientific = FALSE,
                          trim = TRUE))
}
fmt_num <- function(x, digits = 3L) {
  ifelse(is.finite(x), formatC(x, digits = digits, format = "f"), "NA")
}
fmt_p <- function(x) {
  ifelse(!is.finite(x), "NA",
         ifelse(x < 0.001, format(x, scientific = TRUE, digits = 3),
                formatC(x, digits = 4, format = "f")))
}
relativize <- function(x) {
  if (!is.character(x)) return(x)
  gsub(project_root, ".", x, fixed = TRUE)
}
sanitize <- function(x) {
  x <- as.data.table(copy(x))
  for (column in names(x)) x[[column]] <- relativize(x[[column]])
  x
}
write_rows <- function(x, filename) {
  path <- file.path(data_dir, filename)
  writeLines(toJSON(
    as.data.frame(sanitize(x)), dataframe = "rows", na = "null",
    digits = 16, auto_unbox = TRUE, pretty = FALSE
  ), path, useBytes = TRUE)
  filename
}

# Table 1 ----------------------------------------------------------------------
metadata <- fread(file.path(project_root, "08_qc", "exposure_metadata_catalog.csv"))
swedish_n <- unique(metadata[dataset == "microbiome_2026", sample_size])
hunt_n <- max(metadata[dataset == "microbiome_2026_hunt", sample_size])
if (length(swedish_n) != 1L || swedish_n != 16017L || hunt_n != 12652L) {
  stop("Source sample-size ledger drifted", call. = FALSE)
}
finngen <- as.data.table(read_parquet(file.path(
  project_root, "03_data", "processed", "harmonised",
  "finngen_r12_erectile_dysfunction.parquet"
)))
finngen_sizes <- unique(finngen[, .(cases, controls)])
if (nrow(finngen_sizes) != 1L || finngen_sizes$cases != 2886L ||
    finngen_sizes$controls != 215272L) {
  stop("FinnGen sample-size ledger drifted", call. = FALSE)
}
reverse_iv <- fread(file.path(
  project_root, "08_qc", "reverse_ed_instrument_inventory.csv"
))
if (reverse_iv$post_clump_snps != 24L) stop("Reverse IV count drifted", call. = FALSE)

table1 <- data.table(
  `GWAS source` = c(
    "Swedish shotgun-metagenomic GWAS",
    "Norwegian HUNT microbiome GWAS",
    "FinnGen R12 ERECTILE_DYSFUNCTION",
    "2025 ED meta-analysis: EUR",
    "2025 ED meta-analysis: AFR",
    "2025 ED meta-analysis: cross-ancestry",
    "2025 circulating-cytokine meta-GWAS",
    "SCALLOP CVD-I cardiovascular-protein GWAS",
    "1000 Genomes Phase 3 LD reference"
  ),
  Ancestry = c(
    "European", "European", "Finnish", "European", "African",
    "Cross-ancestry", "Predominantly European", "European", "European"
  ),
  `Sample size` = c(
    fmt_int(swedish_n), paste0("up to ", fmt_int(hunt_n)),
    paste0(fmt_int(finngen_sizes$cases), " cases; ",
           fmt_int(finngen_sizes$controls), " controls"),
    "136 867 cases; 776 327 controls",
    "51 599 cases; 73 716 controls",
    "188 466 cases; 850 043 controls",
    "up to 74 783", "up to 30 931", "503"
  ),
  `Genome build` = c(
    "GRCh37", "GRCh37", "GRCh38", "GRCh38", "GRCh38", "GRCh38",
    "source GRCh37/GRCh38 fields retained", "GRCh37", "GRCh37"
  ),
  `Phenotype and effect scale` = c(
    paste0(
      "1 572 microbial presence (log-odds beta), RIN-standardized abundance, ",
      "higher-taxonomic and diversity traits"
    ),
    "normalized relative abundance and functional traits; raw beta magnitude not comparable with Swedish presence traits",
    "repeated PDE5-inhibitor purchases; log odds",
    "EHR-defined ED; METAL Z/sqrt(weight), screening scale only",
    "EHR-defined ED; METAL Z/sqrt(weight), screening scale only",
    "EHR-defined ED; METAL Z/sqrt(weight), screening scale only",
    "40 circulating cytokines; source-standardized protein levels",
    "nine endothelial/vascular-injury proteins; source-standardized levels",
    "ancestry-matched linkage disequilibrium reference"
  ),
  `Instrument or evidence threshold` = c(
    paste0(
      "Primary P<5×10−8; source-study sensitivity: diversity 1.7×10−8, ",
      "species/higher taxa 5.4×10−11, functions 4.3×10−10"
    ),
    paste0(
      "Same-SNP validation used Swedish lead SNPs without HUNT reselection; ",
      "legacy exact-label sensitivity used HUNT-selected P<1×10−5 SNPs. ",
      "Fimisoma and UBA644 had 0 HUNT P<5×10−8 instruments"
    ),
    "Outcome source; no exposure-instrument selection",
    paste0("Forward sensitivity outcome; reverse exposure used ",
           reverse_iv$post_clump_snps, " clumped SNPs at P<5×10−8"),
    "Forward ancestry-transfer sensitivity outcome",
    "Forward cross-ancestry sensitivity outcome",
    "Paper-classified cis leads; source-heterogeneity sensitivity at P<0.05",
    "cis region: encoding gene ±300 kb; P<5×10−8",
    "r²<0.001 within 10 000 kb"
  ),
  `Analytical role` = c(
    "Primary forward exposure; reverse outcome",
    "Cross-cohort same-SNP exposure-association validation and exploratory exact-label sensitivity",
    "Primary forward outcome",
    "Reverse exposure and known-overlap forward sensitivity outcome",
    "Known-overlap ancestry-transfer sensitivity outcome",
    "Known-overlap cross-ancestry sensitivity outcome",
    "Prespecified bounded mechanistic screening",
    "Prespecified bounded mechanistic screening",
    "LD clumping"
  ),
  `Overlap and evidence classification` = c(
    "Discovery exposure cohort",
    "Independent exposure cohort, but FinnGen remained the outcome; not independent MR replication",
    "Overlaps the 2025 ED meta-analysis",
    "Includes FinnGen; not independent outcome replication",
    "Meta-analysis source includes FinnGen; ancestry transfer only",
    "Includes FinnGen and overlaps the EUR result set",
    "Known partial overlap with FinnGen through FINRISK; screening only",
    "Overlap with HUNT/FinnGen possible or unresolved; screening only",
    "External reference panel"
  ),
  `Public source` = c(
    "https://doi.org/10.1038/s41588-026-02512-2",
    "https://doi.org/10.1038/s41588-026-02502-4",
    "https://storage.googleapis.com/finngen-public-data-r12/summary_stats/release/finngen_R12_ERECTILE_DYSFUNCTION.gz",
    rep("https://doi.org/10.1038/s41467-025-66723-7", 3L),
    "https://doi.org/10.1038/s42003-025-07453-w",
    "https://doi.org/10.1038/s42255-020-00287-2",
    "https://doi.org/10.5281/zenodo.6614170"
  )
)
write_rows(table1, "main_table_1.json")
table1_notes <- data.table(
  Note = c(
    "Sample sizes and thresholds are source-specific. Spaces separate thousands.",
    paste0(
      "HUNT provides independent exposure-association evidence only. Because ",
      "FinnGen remained the ED outcome, neither the legacy exploratory analysis ",
      "nor the same-SNP lookup constitutes independent MR replication."
    ),
    paste0(
      "The EUR, AFR and cross-ancestry 2025 outcome analyses are sensitivity ",
      "analyses because the source meta-analysis contains FinnGen."
    )
  )
)
write_rows(table1_notes, "main_table_1_notes.json")

# Table 2 ----------------------------------------------------------------------
annotations <- fread(file.path(v03, "nominal_forward_pleiotropy_annotations.csv"))
hunt_audit <- fread(file.path(v03, "hunt_nominal_trait_audit.csv"))
multiplicity <- fread(file.path(v03, "multiplicity_sensitivity_trait_results.csv"))
table2 <- merge(
  annotations,
  multiplicity[, .(source_id, signal_cluster)],
  by = "source_id", all.x = TRUE, sort = FALSE
)
table2 <- merge(
  table2,
  hunt_audit[, .(
    source_id = discovery_source_id, hunt_source_id, hunt_trait,
    p_threshold_exploratory, candidate_snps_primary,
    post_clump_snps_exploratory, hunt_beta_aligned, hunt_se, hunt_p,
    hunt_F_same_snp, direction_concordant,
    hunt_selected_exploratory_nsnp, hunt_selected_exploratory_mr_or,
    hunt_selected_exploratory_mr_or_ci_lower,
    hunt_selected_exploratory_mr_or_ci_upper,
    hunt_selected_exploratory_mr_p
  )],
  by = "source_id", all.x = TRUE, sort = FALSE
)
table2[, exposure_phenotype := fifelse(
  grepl("presence", trait, ignore.case = TRUE), "presence", "abundance"
)]
table2[, exposure_effect_scale := fifelse(
  exposure_phenotype == "presence",
  "ED OR per one-unit increase in genetically predicted log odds of microbial presence",
  "ED OR per one source RIN-standardized abundance unit"
)]
table2[, exact_hunt_match := fifelse(is.na(hunt_source_id), "No", "Yes")]
table2[, hunt_design := fifelse(
  exact_hunt_match == "Yes",
  "Same Swedish lead-SNP lookup plus legacy HUNT-selected exploratory sensitivity",
  "Not attempted; no exact label match and no fuzzy taxonomic matching"
)]
table2[, hunt_threshold := fifelse(
  exact_hunt_match == "Yes",
  paste0(
    "Same-SNP lookup: no HUNT selection; legacy MR: P<1×10−5 ",
    "(0 SNPs at P<5×10−8)"
  ),
  "Not applicable"
)]
table2[, hunt_status := fifelse(
  exact_hunt_match == "Yes",
  paste0(
    "same SNP found; legacy exploratory instrument set ",
    as.integer(hunt_selected_exploratory_nsnp), " SNPs"
  ),
  "No same-label lookup"
)]
table2[, hunt_result := fifelse(
  exact_hunt_match == "Yes",
  paste0(
    "same-SNP HUNT beta ", fmt_num(hunt_beta_aligned, 4),
    ", SE ", fmt_num(hunt_se, 4), ", P ", fmt_p(hunt_p),
    ", F ", fmt_num(hunt_F_same_snp, 3), "; direction ",
    fifelse(direction_concordant, "concordant", "discordant"),
    "; legacy exploratory MR OR ",
    fmt_num(hunt_selected_exploratory_mr_or, 3), " (",
    fmt_num(hunt_selected_exploratory_mr_or_ci_lower, 3), "–",
    fmt_num(hunt_selected_exploratory_mr_or_ci_upper, 3), "), P ",
    fmt_p(hunt_selected_exploratory_mr_p), "; not validated"
  ),
  "Not applicable"
)]
table2[, cluster_label := fifelse(
  grepl("Peptococc", taxonomic_signal_cluster),
  "Nested Peptococcaceae/Peptococcales/Peptococcia cluster; identical estimate",
  "Distinct trait-level signal"
)]
setorder(table2, nominal_p, source_id)
table2_out <- table2[, .(
  `Swedish accession` = source_id,
  `Microbial trait` = trait,
  `Exposure phenotype` = exposure_phenotype,
  `Exposure effect scale` = exposure_effect_scale,
  `Swedish lead SNP` = rsid,
  `Effect allele` = effect_allele,
  `Swedish SNP-exposure P` = exposure_p,
  `F statistic` = F_statistic,
  `Discovery OR (95% CI)` = paste0(
    fmt_num(discovery_mr_or), " (", fmt_num(discovery_mr_or_ci_lower),
    "–", fmt_num(discovery_mr_or_ci_upper), ")"
  ),
  `Nominal P` = nominal_p,
  `FDR q` = fdr_q,
  `Exact HUNT match` = exact_hunt_match,
  `HUNT validation design` = hunt_design,
  `HUNT instrument threshold` = hunt_threshold,
  `HUNT SNP count or same-SNP status` = hunt_status,
  `HUNT result` = hunt_result,
  `Taxonomic signal cluster` = cluster_label
)]
write_rows(table2_out, "main_table_2.json")
table2_notes <- data.table(
  Note = c(
    "These are seven nominal trait-level associations, not seven independent causal taxa; none survived FDR correction.",
    "Peptococcaceae, Peptococcales and Peptococcia are taxonomically nested traits with the same SNP and identical estimates.",
    "Swedish presence and HUNT normalized relative-abundance phenotypes use different effect scales; beta and MR OR magnitudes are not directly comparable.",
    "The two exact-label HUNT GWASs had no genome-wide-significant instruments. Their legacy 23-SNP and 20-SNP analyses used P<1×10−5 and are exploratory.",
    "All Swedish discovery estimates are single-SNP Wald ratios."
  )
)
write_rows(table2_notes, "main_table_2_notes.json")

# Supplementary Data S1-S10 and supporting audits ------------------------------
instruments <- as.data.table(read_parquet(file.path(
  project_root, "03_data", "processed", "instruments", "instruments.parquet"
)))
forward_primary <- fread(file.path(
  project_root, "05_results", "tables", "mr_multiplicity_forward.csv"
))
reverse_primary <- fread(file.path(
  project_root, "05_results", "tables", "reverse_mr_multiplicity.csv"
))
forward_methods <- fread(file.path(v03, "forward_all_method_results.csv"))
reverse_methods <- fread(file.path(
  project_root, "05_results", "tables", "reverse_mr_raw.csv"
))
forward_diagnostics <- fread(file.path(v03, "forward_diagnostic_trigger_status.csv"))
reverse_diagnostics <- fread(file.path(
  project_root, "05_results", "tables", "reverse_mr_sensitivity.csv"
))
power_summary <- fread(file.path(v03, "power_mde_summary.csv"))
power_traits <- fread(file.path(v03, "power_mde_trait_results.csv"))
power_inputs <- fread(file.path(v03, "power_mde_instrument_inputs.csv"))
hunt_same <- fread(file.path(v03, "hunt_same_snp_validation.csv"))
hunt_nominal <- hunt_audit
setnames(
  hunt_nominal,
  "independent_replication",
  "qualifies_as_independent_MR_replication"
)
strict_results <- fread(file.path(v03, "source_study_wide_mr_primary_results.csv"))
strict_inventory <- fread(file.path(v03, "source_study_wide_instrument_inventory.csv"))
pleiotropy <- annotations
mechanistic_full <- fread(file.path(v03, "mechanistic_screening_full_enriched.csv"))
mechanistic_summary <- fread(file.path(v03, "mechanistic_screening_family_summary.csv"))
ccl11_sensitivity <- fread(file.path(
  v03, "mechanistic_ccl11_source_heterogeneity_sensitivity.csv"
))
multiplicity_summary <- fread(file.path(v03, "multiplicity_sensitivity_summary.csv"))
multiplicity_traits <- fread(file.path(v03, "multiplicity_sensitivity_trait_results.csv"))
outcome_2025 <- fread(file.path(v03, "ed_2025_known_overlap_sensitivity_results.csv"))
closure <- fread(file.path(v03, "prespecified_analysis_closure_audit.csv"))

receipt_files <- c(
  "hunt_same_snp_validation_receipt.csv",
  "v0_3_methodological_analysis_receipt.csv",
  "mechanistic_enriched_v0_3_receipt.csv",
  "nominal_locus_annotation_receipt.csv"
)
provenance <- rbindlist(lapply(receipt_files, function(filename) {
  x <- fread(file.path(v03, filename))
  x[, receipt_source := filename]
  x
}), use.names = TRUE, fill = TRUE)
setcolorder(provenance, c("receipt_source", setdiff(names(provenance), "receipt_source")))

github <- fromJSON(file.path(
  project_root, "08_qc", "v0_3_public_archive", "github_latest_release.json"
))
zenodo <- fromJSON(file.path(
  project_root, "08_qc", "v0_3_public_archive", "zenodo_21456671.json"
))
git_value <- function(args) {
  paste(system2("git", args, stdout = TRUE, stderr = TRUE), collapse = " ")
}
package_version_safe <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) return("not installed")
  as.character(packageVersion(package))
}
plink_path <- Sys.which("plink2")
plink_version <- if (nzchar(plink_path)) {
  paste(system2(plink_path, "--version", stdout = TRUE, stderr = TRUE),
        collapse = " ")
} else {
  "not on PATH; project scripts used the pinned executable recorded in analysis receipts"
}
software <- data.table(
  Field = c(
    "Manuscript package version", "Local Git branch", "Local base commit",
    "R runtime", "Platform", "arrow", "data.table", "TwoSampleMR",
    "ggplot2", "patchwork", "ragg", "svglite", "PLINK2",
    "Public GitHub release tag", "Public GitHub release URL",
    "Public Zenodo version", "Public Zenodo version DOI",
    "Public Zenodo concept DOI", "Version alignment statement"
  ),
  Value = c(
    "v0.3", git_value(c("branch", "--show-current")),
    git_value(c("rev-parse", "HEAD")), R.version.string,
    R.version$platform,
    vapply(c("arrow", "data.table", "TwoSampleMR", "ggplot2", "patchwork",
             "ragg", "svglite"), package_version_safe, character(1)),
    plink_version, github$tag_name, github$html_url,
    zenodo$metadata$version, zenodo$doi, zenodo$conceptdoi,
    paste0(
      "The public archive is frozen at v0.1.0. The v0.3 submission package is ",
      "local and is not described as an already published GitHub/Zenodo release; ",
      "a new public version requires author-approved release after final QA."
    )
  )
)

readme <- data.table(
  Field = c(
    "File", "Version", "Purpose", "Primary inference", "Multiplicity",
    "HUNT evidence", "Mechanistic terminology", "Missing data", "Repository"
  ),
  Value = c(
    "IJIR_Supplementary_Data_v0_3.xlsx", "v0.3 (2026-07-22)",
    "Complete result, instrument, sensitivity and provenance tables for the IJIR submission",
    "No association met the predefined multiplicity-controlled criteria for a robust causal interpretation in either direction.",
    "Primary denominators: forward 230 and reverse 1 572; non-estimable rows retained at P=1.",
    "Cross-cohort same-SNP exposure-association validation plus exploratory exact-label HUNT sensitivity; not independent MR replication.",
    "Prespecified bounded mechanistic screening; not formal causal mediation analysis.",
    "Blank cells indicate unavailable or non-estimable quantities and are retained rather than imputed.",
    "Public reproducibility archive v0.1.0: https://doi.org/10.5281/zenodo.21456671; concept DOI https://doi.org/10.5281/zenodo.21456670"
  )
)

specs <- list(
  list("README", "Supplementary Data v0.3: scope and interpretation", readme),
  list("S1 Instruments", "S1. Complete instrument inventory", instruments),
  list("S2 Forward Primary", "S2. Complete forward primary MR results", forward_primary),
  list("S3 Reverse Primary", "S3. Complete reverse primary MR results", reverse_primary),
  list("S4 Fwd Methods", "S4a. Forward robust-method results and explicit failures", forward_methods),
  list("S4 Rev Methods", "S4b. Reverse robust-method results and explicit failures", reverse_methods),
  list("S4 Fwd Diagnostics", "S4c. Forward diagnostic and trigger status", forward_diagnostics),
  list("S4 Rev Diagnostics", "S4d. Reverse diagnostic and trigger status", reverse_diagnostics),
  list("S5 Power Summary", "S5a. Power and minimum-detectable-OR summary", power_summary),
  list("S5 Power Traits", "S5b. Trait-level power and minimum detectable OR", power_traits),
  list("S5 Power Inputs", "S5c. Instrument-level R-squared inputs and assumptions", power_inputs),
  list("S6 HUNT Same SNP", "S6a. Exact-label same-SNP Swedish-HUNT exposure validation", hunt_same),
  list("S6 HUNT Nominal", "S6b. HUNT evidence audit for the two nominal exact-label traits", hunt_nominal),
  list("S7 Strict Results", "S7a. Source-study-wide threshold MR sensitivity", strict_results),
  list("S7 Strict Inventory", "S7b. Source-study-wide threshold eligibility inventory", strict_inventory),
  list("S8 Pleiotropy", "S8. Nominal-locus pleiotropy annotations", pleiotropy),
  list("S9 Mechanistic Full", "S9a. Full prespecified bounded mechanistic screening", mechanistic_full),
  list("S9 Family Summary", "S9b. Mechanistic testing-family completeness summary", mechanistic_summary),
  list("S9 CCL11 Sens", "S9c. CCL11 source-heterogeneity sensitivity", ccl11_sensitivity),
  list("S10 Provenance", "S10a. Analysis provenance and checksums", provenance),
  list("S10 Software", "S10b. Software environment and archive-version status", software),
  list("Multiplicity", "Multiplicity sensitivity: frozen, estimable-only and unique clusters", multiplicity_traits),
  list("Multiplicity Summary", "Multiplicity sensitivity summary", multiplicity_summary),
  list("2025 ED Sensitivity", "Known-overlap 2025 ED outcome sensitivity analyses", outcome_2025),
  list("Closure Audit", "Prespecified analysis closure audit", closure)
)

manifest_rows <- lapply(seq_along(specs), function(i) {
  spec <- specs[[i]]
  filename <- sprintf("supp_%02d.json", i)
  write_rows(spec[[3L]], filename)
  data.table(
    order = i, sheet_name = spec[[1L]], title = spec[[2L]],
    json_file = filename, rows = nrow(spec[[3L]]), columns = ncol(spec[[3L]])
  )
})
manifest <- rbindlist(manifest_rows)
dictionary <- manifest[, .(
  `Sheet` = sheet_name, `Title` = title, `Rows` = rows, `Columns` = columns
)]
dictionary_file <- sprintf("supp_%02d.json", length(specs) + 1L)
write_rows(dictionary, dictionary_file)
manifest <- rbind(
  manifest,
  data.table(
    order = length(specs) + 1L, sheet_name = "Data Dictionary",
    title = "Supplementary workbook data dictionary", json_file = dictionary_file,
    rows = nrow(dictionary), columns = ncol(dictionary)
  )
)
writeLines(toJSON(
  as.data.frame(manifest), dataframe = "rows", na = "null", digits = 16,
  auto_unbox = TRUE, pretty = TRUE
), file.path(data_dir, "supplement_manifest.json"), useBytes = TRUE)

cat(sprintf(
  paste0(
    "Prepared v0.3 workbook data: Table 1 %d rows, Table 2 %d rows, ",
    "Supplement %d sheets and %s complete instrument rows.\n"
  ),
  nrow(table1), nrow(table2_out), nrow(manifest), fmt_int(nrow(instruments))
))
