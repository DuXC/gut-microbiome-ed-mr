project_root <- normalizePath(testthat::test_path("..", ".."))
source(file.path(project_root, "R", "gwas_schema.R"))

fixture_path <- function(name) {
  testthat::test_path("..", "fixtures", name)
}

test_that("heterogeneous headers normalize to one canonical schema", {
  exposure <- normalize_gwas(
    fixture_path("exposure.tsv"), role = "exposure", build = "GRCh37",
    ancestry = "EUR", sample_size = 16017, source_id = "GCST-fixture",
    trait = "fixture trait"
  )
  outcome <- normalize_gwas(
    fixture_path("outcome.tsv"), role = "outcome", build = "GRCh38",
    ancestry = "EUR", source_id = "outcome-fixture", trait = "ED"
  )

  expect_identical(names(exposure), names(outcome))
  expect_identical(names(exposure), GWAS_CANONICAL_COLUMNS)
  expect_equal(exposure$snp, c("rs1", "rs2", "rs3"))
  expect_equal(exposure$n, rep(16017, 3L))
  expect_equal(outcome$ea, c("A", "T"))
  expect_equal(outcome$n, rep(913194, 2L))
})

test_that("HUNT position identifiers receive orientation-independent keys", {
  hunt <- normalize_gwas(
    fixture_path("hunt_exposure.tsv"), role = "exposure", build = "GRCh37",
    ancestry = "EUR", sample_size = 12648, source_id = "HUNT-fixture",
    trait = "fixture trait"
  )

  expect_true(all(is.na(hunt$snp)))
  expect_equal(hunt$variant_id, c("1_100_G_A", "1_400_C_T"))
  expect_equal(hunt$variant_key, c("1:100:A:G", "1:400:C:T"))
})

test_that("invalid alleles and impossible statistics fail closed", {
  bad <- data.frame(
    snp = "rs1", variant_id = "rs1", variant_key = "1:1:A:N",
    chr = 1L, pos = 1L, ea = "N", oa = "A", beta = 0, se = 0,
    z = NA_real_, eaf = 0.2, p = 2, n = 10,
    build = "GRCh37", ancestry = "EUR", role = "exposure",
    source_id = "fixture", trait = "fixture", stringsAsFactors = FALSE
  )
  expect_error(validate_gwas(bad), "allele|standard error|p-value")
})

test_that("candidate extraction filters before full parsing", {
  candidates <- extract_gwas_candidates(
    fixture_path("exposure.tsv"), p_threshold = 1e-5,
    role = "exposure", build = "GRCh37", ancestry = "EUR",
    sample_size = 16017, source_id = "GCST-fixture",
    trait = "fixture trait"
  )

  expect_equal(candidates$snp, c("rs1", "rs2"))
  expect_true(all(candidates$p < 1e-5))
})

test_that("AppleDouble inputs and ambiguous header mappings are rejected", {
  expect_error(
    extract_gwas_candidates(
      file.path(tempdir(), "._payload.tsv.gz"), p_threshold = 1e-5,
      role = "exposure", build = "GRCh37", ancestry = "EUR",
      sample_size = 100, source_id = "x", trait = "x"
    ),
    "AppleDouble"
  )

  path <- tempfile(fileext = ".tsv")
  on.exit(unlink(path), add = TRUE)
  writeLines(
    c(
      "chromosome\tCHR\tbase_pair_location\teffect_allele\tother_allele\tbeta\tstandard_error\teffect_allele_frequency\tp_value\trs_id",
      "1\t1\t100\tA\tG\t0.1\t0.02\t0.2\t1e-9\trs1"
    ),
    path
  )
  expect_error(
    normalize_gwas(
      path, role = "exposure", build = "GRCh37", ancestry = "EUR",
      sample_size = 100, source_id = "x", trait = "x"
    ),
    "Ambiguous"
  )
})

test_that("Swedish and HUNT trait descriptions map by biological label", {
  swedish <- c(
    "Gut microbiome alpha diversity abundance (Shannon diversity)",
    "Gut microbiome species abundance (Agathobacter rectalis, GCA_000020605.1)"
  )
  hunt <- c(
    "Gut microbiota alpha diversity (Shannon index)",
    "Gut microbiota relative abundance (hMGS.00001: Agathobacter rectalis)"
  )

  expect_equal(
    canonicalize_microbiome_trait(swedish),
    canonicalize_microbiome_trait(hunt)
  )
  expect_equal(
    canonicalize_microbiome_trait(swedish),
    c("alpha:shannon", "taxon:agathobacter rectalis")
  )
})

test_that("nested functional descriptions use their stable module identifier", {
  expect_equal(
    canonicalize_microbiome_trait(
      "Gut microbiome function abundance (Glycolysis (preparatory phase), MF0067)"
    ),
    "function:mf0067"
  )
})

test_that("metadata parsing preserves accession-specific sample size", {
  path <- tempfile(fileext = ".yaml")
  on.exit(unlink(path), add = TRUE)
  writeLines(c(
    "gwas_id: GCST99999999",
    "trait_description:",
    "  - Gut microbiota alpha diversity (Richness)",
    "genome_assembly: GRCh37",
    "samples:",
    "  - sample_ancestry_category: [European]",
    "    sample_size: 12652",
    "data_file_name: GCST99999999.tsv.gz"
  ), path)

  metadata <- read_gwas_metadata(path, dataset = "microbiome_2026_hunt")
  expect_equal(metadata$sample_size, 12652)
  expect_equal(metadata$canonical_trait_id, "alpha:richness")
  expect_equal(metadata$data_file_name, "GCST99999999.tsv.gz")
})

test_that("ambiguous discovery labels remain explicit replication blocks", {
  catalog <- data.frame(
    dataset = c(
      "microbiome_2026", "microbiome_2026", "microbiome_2026_hunt"
    ),
    source_id = c("GCST1", "GCST2", "GCST3"),
    trait = c("taxon A genome 1", "taxon A genome 2", "taxon A HUNT"),
    canonical_trait_id = rep("taxon:a", 3L),
    stringsAsFactors = FALSE
  )
  matches <- match_microbiome_replication_traits(catalog)

  expect_equal(matches$discovery_match_count, 2L)
  expect_equal(matches$match_status, "ambiguous_discovery_label")
  expect_equal(matches$discovery_source_id, "GCST1;GCST2")
})

test_that("the same variant may appear in separate GWAS sources", {
  first <- normalize_gwas(
    fixture_path("exposure.tsv"), role = "exposure", build = "GRCh37",
    ancestry = "EUR", sample_size = 16017, source_id = "source-1",
    trait = "trait 1"
  )
  second <- first
  second$source_id <- "source-2"
  second$trait <- "trait 2"

  expect_true(validate_gwas(rbind(first, second)))
})

test_that("coordinate-allele keys preserve upstream variants without rsIDs", {
  path <- tempfile(fileext = ".tsv")
  on.exit(unlink(path), add = TRUE)
  writeLines(c(
    "chromosome\tbase_pair_location\teffect_allele\tother_allele\tbeta\tstandard_error\teffect_allele_frequency\tp_value\trs_id",
    "6\t31313339\tA\tG\t0.1\t0.02\t0.2\t5.359e-6\t#NA"
  ), path)
  result <- normalize_gwas(
    path, role = "exposure", build = "GRCh37", ancestry = "EUR",
    sample_size = 16017, source_id = "source", trait = "trait"
  )

  expect_true(is.na(result$snp))
  expect_true(is.na(result$variant_id))
  expect_equal(result$variant_key, "6:31313339:A:G")
})
