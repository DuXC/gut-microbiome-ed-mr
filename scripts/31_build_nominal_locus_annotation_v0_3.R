#!/usr/bin/env Rscript

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
local_library <- file.path(
  project_root, "renv", "library", "macos", "R-4.6",
  "aarch64-apple-darwin25.4.0"
)
if (dir.exists(local_library)) .libPaths(c(local_library, .libPaths()))

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
  library(digest)
  library(jsonlite)
})
source(file.path(project_root, "R", "exposure_candidates.R"))

output_root <- file.path(project_root, "05_results", "v0_3_20260722")
raw_root <- file.path(
  project_root, "02_literature", "nominal_snp_annotation_20260722"
)
ensembl_root <- file.path(raw_root, "ensembl")
gwas_root <- file.path(raw_root, "gwas_catalog")
query_date <- "2026-07-22"

write_result <- function(x, filename) {
  path <- file.path(output_root, filename)
  atomic_write_csv(as.data.frame(x), path)
  path
}
read_json_list <- function(path) {
  fromJSON(path, simplifyVector = FALSE)
}
nonempty <- function(x) {
  x <- as.character(unlist(x, recursive = TRUE, use.names = FALSE))
  unique(x[!is.na(x) & nzchar(x)])
}

forward <- fread(file.path(
  project_root, "05_results", "tables", "mr_multiplicity_forward.csv"
))
nominal <- forward[analysis_status == "estimated" & is.finite(p) & p < 0.05]
if (nrow(nominal) != 7L || any(nominal$nsnp != 1L)) {
  stop("The frozen nominal forward family is not seven single-SNP rows",
       call. = FALSE)
}
harmonised <- as.data.table(read_parquet(file.path(
  project_root, "03_data", "processed", "harmonised",
  "finngen_r12_erectile_dysfunction.parquet"
)))[
  dataset == "microbiome_2026" & tier == "primary" &
    source_id %in% nominal$source_id & harmonisation_status == "harmonised"
]
instrument <- harmonised[, .(
  source_id, rsid = reference_id, chromosome_grch37 = chr_exposure,
  position_grch37 = pos_exposure, effect_allele = ea_exposure,
  other_allele = oa_exposure, eaf = eaf_exposure,
  exposure_beta = beta_exposure, exposure_se = se_exposure,
  exposure_p = p_exposure, F_statistic = F
)]
if (nrow(instrument) != 7L || anyDuplicated(instrument$source_id)) {
  stop("Nominal instrument ledger is incomplete", call. = FALSE)
}

rsids <- unique(instrument$rsid)
if (!setequal(rsids, c(
  "rs56024701", "rs753593", "rs62103891", "rs2636067", "rs2004141"
))) stop("Nominal rsID freeze drifted", call. = FALSE)

vep_annotation <- lapply(rsids, function(rsid) {
  path <- file.path(ensembl_root, paste0(rsid, ".json"))
  vep <- read_json_list(path)[[1L]]
  transcripts <- vep$transcript_consequences
  symbols <- character()
  gene_ids <- character()
  if (length(transcripts)) {
    symbols <- nonempty(lapply(transcripts, function(x) x$gene_symbol))
    gene_ids <- nonempty(lapply(transcripts, function(x) x$gene_id))
  }
  nearest_gene <- if (length(symbols)) paste(symbols, collapse = "; ") else NA_character_
  nearest_gene_basis <- if (length(symbols)) {
    "overlapping transcript gene in Ensembl VEP"
  } else {
    NA_character_
  }
  nearest_gene_distance_bp <- if (length(symbols)) 0 else NA_real_

  if (rsid == "rs56024701" && !length(symbols) && length(gene_ids)) {
    lookup <- read_json_list(file.path(
      ensembl_root, "gene_ENSG00000265639.json"
    ))
    description <- sub(" \\[Source:.*$", "", lookup$description)
    nearest_gene <- paste0(description, " (", lookup$id, ")")
    nearest_gene_basis <- "overlapping processed-pseudogene transcript in Ensembl VEP"
    nearest_gene_distance_bp <- 0
  }
  if (rsid == "rs62103891") {
    snp <- read_json_list(file.path(gwas_root, paste0(rsid, "_snp.json")))
    closest <- Filter(
      function(x) isTRUE(x$isClosestGene), snp$genomicContexts
    )
    if (length(closest)) {
      nearest_gene <- closest[[1L]]$gene$geneName
      nearest_gene_distance_bp <- as.numeric(closest[[1L]]$distance)
      nearest_gene_basis <- "GWAS Catalog genomic context marked isClosestGene"
    }
  }
  if (rsid == "rs753593") {
    genes <- read_json_list(file.path(ensembl_root, "region_rs753593.json"))
    position <- as.numeric(vep$start)
    distances <- vapply(genes, function(gene) {
      start <- as.numeric(gene$start); end <- as.numeric(gene$end)
      if (position < start) start - position else if (position > end) position - end else 0
    }, numeric(1))
    nearest_index <- which.min(distances)
    nearest <- genes[[nearest_index]]
    nearest_label <- nearest$external_name
    if (is.null(nearest_label) || !nzchar(nearest_label)) nearest_label <- nearest$id
    protein_indices <- which(vapply(
      genes, function(gene) identical(gene$biotype, "protein_coding"), logical(1)
    ))
    protein_index <- protein_indices[which.min(distances[protein_indices])]
    protein <- genes[[protein_index]]
    protein_label <- protein$external_name
    if (is.null(protein_label) || !nzchar(protein_label)) protein_label <- protein$id
    nearest_gene <- sprintf(
      "%s (nearest annotated feature, %.0f bp); %s (nearest protein-coding gene, %.0f bp)",
      nearest_label, distances[[nearest_index]], protein_label,
      distances[[protein_index]]
    )
    nearest_gene_distance_bp <- distances[[nearest_index]]
    nearest_gene_basis <- "distance to Ensembl genes in a +/-500 kb GRCh38 interval"
  }
  data.table(
    rsid = rsid, ensembl_assembly = vep$assembly_name,
    ensembl_chromosome = as.character(vep$seq_region_name),
    ensembl_position = as.numeric(vep$start),
    most_severe_consequence = vep$most_severe_consequence,
    nearest_gene = nearest_gene,
    nearest_gene_distance_bp = nearest_gene_distance_bp,
    nearest_gene_basis = nearest_gene_basis,
    ensembl_query_url = paste0(
      "https://rest.ensembl.org/vep/human/id/", rsid,
      "?content-type=application/json"
    )
  )
})
vep_annotation <- rbindlist(vep_annotation, use.names = TRUE, fill = TRUE)

gwas_annotation <- lapply(rsids, function(rsid) {
  path <- file.path(gwas_root, paste0(rsid, ".json"))
  url <- paste0(
    "https://www.ebi.ac.uk/gwas/rest/api/singleNucleotidePolymorphisms/",
    rsid, "/associations?projection=associationBySnp"
  )
  if (!file.exists(path) || file.info(path)$size == 0) {
    return(data.table(
      rsid = rsid, gwas_catalog_exact_rsid_status =
        "not identified (official exact-rsID association endpoint returned HTTP 404)",
      gwas_catalog_association_count = 0L,
      known_gwas_associations = "not identified",
      minimum_gwas_catalog_p = NA_real_, gwas_catalog_query_url = url
    ))
  }
  response <- read_json_list(path)
  associations <- response$`_embedded`$associations
  traits <- unlist(lapply(associations, function(association) {
    nonempty(lapply(association$efoTraits, function(x) x$trait))
  }), use.names = FALSE)
  pvalues <- vapply(associations, function(x) as.numeric(x$pvalue), numeric(1))
  labels <- vapply(seq_along(associations), function(i) {
    association_traits <- nonempty(lapply(
      associations[[i]]$efoTraits, function(x) x$trait
    ))
    paste0(
      paste(association_traits, collapse = "; "),
      " (P=", format(pvalues[[i]], scientific = TRUE, digits = 4), ")"
    )
  }, character(1))
  data.table(
    rsid = rsid, gwas_catalog_exact_rsid_status = "association record identified",
    gwas_catalog_association_count = length(associations),
    known_gwas_associations = paste(labels, collapse = " | "),
    minimum_gwas_catalog_p = min(pvalues), gwas_catalog_query_url = url
  )
})
gwas_annotation <- rbindlist(gwas_annotation, use.names = TRUE, fill = TRUE)

known_loci <- rbindlist(lapply(c("FUT2", "LCT", "ABO"), function(symbol) {
  gene <- read_json_list(file.path(ensembl_root, paste0(symbol, ".json")))
  data.table(
    locus = symbol, chromosome = as.character(gene$seq_region_name),
    start = as.numeric(gene$start), end = as.numeric(gene$end)
  )
}))

unique_annotation <- merge(
  vep_annotation, gwas_annotation, by = "rsid", all = TRUE, sort = FALSE
)
unique_annotation[, within_1mb_FUT2_LCT_ABO_locus := vapply(
  seq_len(.N), function(i) {
    same_chr <- known_loci[chromosome == ensembl_chromosome[[i]]]
    if (!nrow(same_chr)) return(FALSE)
    any(ensembl_position[[i]] >= same_chr$start - 1e6 &
          ensembl_position[[i]] <= same_chr$end + 1e6)
  }, logical(1)
)]
unique_annotation[, FUT2_LCT_ABO_locus_result := fifelse(
  within_1mb_FUT2_LCT_ABO_locus,
  "within 1 Mb of FUT2, LCT, or ABO coding span",
  "no (not within 1 Mb of FUT2, LCT, or ABO coding span on GRCh38)"
)]

category_patterns <- list(
  BMI = "body mass index|BMI|obesity|adiposity",
  diabetes = "diabet|glycated|glucose|insulin",
  lipids = "cholesterol|triglyceride|lipid|lipoprotein",
  inflammation = "inflamm|C-reactive|cytokine|interleukin|chemokine",
  immune = "immune|leukocyte|lymphocyte|monocyte|neutrophil|immunoglobulin",
  diet = "diet|food|nutrient|alcohol|coffee",
  medication = "medication|drug use|prescription",
  smoking = "smoking|tobacco|cigarette",
  cardiovascular = "cardiovascular|coronary|myocardial|stroke|blood pressure|hypertension"
)
for (category in names(category_patterns)) {
  column <- paste0("association_", category)
  pattern <- category_patterns[[category]]
  unique_annotation[, (column) := fifelse(
    grepl(pattern, known_gwas_associations, ignore.case = TRUE),
    known_gwas_associations, "not identified"
  )]
}
unique_annotation[, horizontal_pleiotropy_concern := fifelse(
  gwas_catalog_association_count > 0L,
  paste0(
    "possible; an exact-variant GWAS association was identified, but whether ",
    "it lies on the microbial-trait-to-ED pathway is unresolved"
  ),
  "not identified in the queried exact-rsID GWAS Catalog records"
)]
unique_annotation[, query_date := query_date]
setorder(unique_annotation, rsid)

annotation <- merge(
  nominal[, .(
    source_id, trait, discovery_mr_beta = beta, discovery_mr_se = se,
    discovery_mr_or = or, discovery_mr_or_ci_lower = or_ci_lower,
    discovery_mr_or_ci_upper = or_ci_upper, nominal_p = p, fdr_q = q
  )],
  instrument, by = "source_id", all.x = TRUE, sort = FALSE
)
annotation <- merge(annotation, unique_annotation, by = "rsid", all.x = TRUE,
                    sort = FALSE)
annotation[, taxonomic_signal_cluster := fifelse(
  source_id %in% c("GCST90671709", "GCST90671773", "GCST90671803"),
  "Peptococcaceae-Peptococcales-Peptococcia nested identical cluster",
  paste0("single trait: ", source_id)
)]
setorder(annotation, nominal_p, source_id)

query_manifest <- unique_annotation[, .(
  rsid, query_date, ensembl_query_url,
  ensembl_response_file = file.path("ensembl", paste0(rsid, ".json")),
  ensembl_response_sha256 = vapply(
    file.path(ensembl_root, paste0(rsid, ".json")), digest,
    character(1), file = TRUE, algo = "sha256", serialize = FALSE
  ),
  gwas_catalog_query_url, gwas_catalog_exact_rsid_status,
  gwas_catalog_response_file = fifelse(
    file.exists(file.path(gwas_root, paste0(rsid, ".json"))),
    file.path("gwas_catalog", paste0(rsid, ".json")), NA_character_
  )
)]

annotation_path <- write_result(
  annotation, "nominal_forward_pleiotropy_annotations.csv"
)
unique_path <- write_result(
  unique_annotation, "nominal_unique_snp_gwas_catalog_audit.csv"
)
manifest_path <- write_result(
  query_manifest, "nominal_snp_annotation_query_manifest.csv"
)

raw_files <- list.files(raw_root, recursive = TRUE, full.names = TRUE)
receipt <- rbindlist(list(
  data.table(
    role = "input", artifact = substring(raw_files, nchar(project_root) + 2L),
    sha256 = vapply(raw_files, digest, character(1), file = TRUE,
                    algo = "sha256", serialize = FALSE)
  ),
  data.table(
    role = "output", artifact = basename(c(
      annotation_path, unique_path, manifest_path
    )),
    sha256 = vapply(c(annotation_path, unique_path, manifest_path), digest,
                    character(1), file = TRUE, algo = "sha256",
                    serialize = FALSE)
  )
))
receipt[, completed_at_utc := format(
  Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"
)]
receipt_path <- write_result(receipt, "nominal_locus_annotation_receipt.csv")

cat(sprintf(
  paste0(
    "Nominal-locus annotation complete: %d trait rows, %d unique SNPs, ",
    "%d exact-rsID GWAS Catalog association records; %d FUT2/LCT/ABO loci.\n"
  ),
  nrow(annotation), nrow(unique_annotation),
  sum(unique_annotation$gwas_catalog_association_count),
  sum(unique_annotation$within_1mb_FUT2_LCT_ABO_locus)
))
