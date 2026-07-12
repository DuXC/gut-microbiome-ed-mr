# Gut Microbiome–ED MR Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a versioned, reproducible pipeline that tests high-resolution gut microbiome GWAS traits against independent and multi-ancestry erectile-dysfunction GWAS outcomes, applies strict multiplicity/replication/colocalization gates, and produces either a submission-ready manuscript package or a documented no-go report.

**Architecture:** The project is an R `targets` pipeline with immutable raw inputs, schema-normalized GWAS files, small focused analysis modules, and script-generated tables/figures/reports. The discovery, replication, colocalization, and MVMR layers are separate so that a failure or change in one layer cannot silently alter another. All source files and outputs are tracked by SHA-256 manifests and Git; large GWAS files remain outside Git.

**Tech Stack:** macOS; Git; R 4.6.0; `renv`; `targets`; `testthat`; `data.table`; `arrow`; `yaml`; `jsonlite`; `digest`; `httr2`; `rvest`; `TwoSampleMR`; `ieugwasr`; `MRPRESSO`; `mr.raps`; `MendelianRandomization`; `coloc`; `susieR`; `MVMR`; `ggplot2`; `patchwork`; Quarto; bundled `micromamba` environment `meta` for Python-based document/QC helpers only.

---

Project root for every command below:

```bash
cd '/Volumes/DuXC_PhD_OS/04_PAPERS_论文发表/04_GUT_ED_MR_REBUILD_20260710'
```

## File map

- `.gitignore` — excludes raw/processed GWAS, caches, credentials, renders, and transient R state.
- `README.md` — reproducible entry points and evidence-grade rules.
- `CHANGELOG.md` — human-readable version history.
- `MANIFEST.csv` — generated file provenance and SHA-256 ledger.
- `config/project.yml` — thresholds, ancestry, genome builds, and go/no-go rules.
- `config/data_sources.yml` — immutable source accessions, APIs, licenses, and cohort-overlap notes.
- `_targets.R` — pipeline graph only; no analysis logic.
- `R/config.R` — validated configuration loader.
- `R/provenance.R` — hashes, source receipts, manifest updates.
- `R/catalog.R` — GWAS Catalog/Figshare/FinnGen discovery.
- `R/gwas_schema.R` — column mapping, build/allele validation, normalized Parquet output.
- `R/instruments.R` — genome-wide and exploratory instrument selection plus ancestry-matched clumping.
- `R/harmonise.R` — exposure/outcome alignment and exclusion audit.
- `R/mr_core.R` — MR estimators and sensitivity analyses.
- `R/multiplicity.R` — BH-FDR, Bonferroni, and evidence grades.
- `R/replication.R` — discovery/validation rule engine.
- `R/coloc.R` — regional data assembly and `coloc.abf`.
- `R/mvmr.R` — conditional strength checks and prespecified MVMR.
- `R/reporting.R` — manuscript tables, figures, claim–evidence map, and go/no-go report.
- `scripts/00_bootstrap.R` — initializes `renv` and locks dependencies.
- `scripts/01_source_inventory.R` — resolves public URLs without downloading large files.
- `scripts/02_download_freeze.R` — resumable download, checksum, and freeze.
- `scripts/03_run_pipeline.R` — executes `targets`, writes session information.
- `tests/testthat/` — unit and integration tests.
- `tests/fixtures/` — synthetic, non-identifying miniature GWAS inputs.
- `01_protocol/` — frozen protocol and decision log.
- `03_data/raw/` — immutable downloaded inputs; Git-ignored.
- `03_data/processed/` — normalized Parquet data; Git-ignored.
- `05_results/` — generated tables, figures, and machine-readable results.
- `06_manuscript/` — generated manuscript source/DOCX and supplement.
- `08_qc/` — manifests, logs, session info, and final checks.

### Task 1: Initialize the project repository and governance files

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `CHANGELOG.md`
- Create: `01_protocol/analysis_decisions.md`
- Track: `docs/superpowers/specs/2026-07-10-gut-ed-mr-rebuild-design.md`
- Track: `docs/superpowers/plans/2026-07-10-gut-ed-mr-rebuild-implementation.md`

- [ ] **Step 1: Initialize Git on `main`**

Run:

```bash
git init -b main
git config user.name 'Duxiancheng Research'
git config user.email 'research.local@localhost'
```

Expected: `Initialized empty Git repository` and no changes outside this project directory.

- [ ] **Step 2: Add a research-safe `.gitignore`**

```gitignore
.DS_Store
._*
.Rhistory
.RData
.Renviron
.Renviron.*
!.Renviron.example
.env
.env.*
!.env.example
.Rproj.user/
renv/library/
renv/staging/
03_data/raw/**
03_data/processed/**
05_results/_targets/
_targets/
08_qc/renders/
08_qc/download_cache/
*.part
*.tmp
*.log
!03_data/raw/.gitkeep
!03_data/processed/.gitkeep
```

- [ ] **Step 3: Write the minimum README contract**

```markdown
# Gut microbiome–ED MR rebuild

Primary command: `Rscript scripts/03_run_pipeline.R`.

Evidence grades:
- Primary: genome-wide (`P < 5×10⁻⁸`) instruments with F > 10, forward BH q < 0.05, all deterministic replication gates defined in `01_protocol/analysis_decisions.md`, and independent validation.
- Strict: Primary plus combined-direction global Bonferroni significance.
- Exploratory: any estimable eligible candidate that uses relaxed instruments (`P < 1×10⁻⁵`) or fails any Primary replication gate; never described with confirmed causal language.
- Insufficient: only an ineligible hypothesis or a hypothesis whose primary effect could not be estimated.

Reverse ED→microbiome analyses are a separate sensitivity family: estimable eligible rows are always Exploratory, ineligible or non-estimable rows are Insufficient, and all carry `analysis_role = reverse_sensitivity`.

Raw GWAS files are immutable and excluded from Git. The freeze is verified from effective no-write mode bits where supported, or from a verified macOS `uchg` flag on `noowners`/exFAT. AppleDouble `._*` sidecars inside ignored raw paths may be required to persist the flag and must never be ingested or deleted as payloads. Every input is recorded in the exact nine-column `MANIFEST.csv` with source, version, size, and SHA-256.

`01_protocol/analysis_decisions.md` is the normative operational source; the README, configuration, and rule engine must not weaken it.

## Repository metadata

Git metadata is stored externally at `/Users/duxiancheng/.codex/gitdirs/04_GUT_ED_MR_REBUILD_20260710.git` because this external volume emits AppleDouble sidecars. Normal Git commands continue to work from the project root.
```

- [ ] **Step 4: Record the approved decision boundary**

Write `01_protocol/analysis_decisions.md` as the normative operational source for the approved instrument thresholds, deterministic multiplicity families, deterministic replication gates, colocalization rule, MVMR covariates, and no-go conditions. The README, configuration, and rule engine must implement it and must not weaken it.

- [ ] **Step 5: Commit the governance baseline**

```bash
git add .gitignore README.md CHANGELOG.md 01_protocol docs/superpowers
git commit -m 'docs: approve gut ED MR rebuild design and plan'
```

Expected: one root commit containing documentation only.

### Task 2: Bootstrap a locked R environment and test harness

**Files:**
- Create: `scripts/00_bootstrap.R`
- Create: `.Rprofile`
- Create: `tests/testthat/test-environment.R`
- Generate: `renv.lock`

- [ ] **Step 1: Write the failing environment test**

```r
# tests/testthat/test-environment.R
test_that("required analysis packages are available", {
  required <- c(
    "targets", "data.table", "arrow", "yaml", "jsonlite", "digest",
    "httr2", "rvest", "TwoSampleMR", "ieugwasr", "genetics.binaRies", "MRPRESSO",
    "mr.raps", "MendelianRandomization", "coloc", "susieR", "MVMR",
    "ggplot2", "patchwork"
  )
  expect_true(all(vapply(required, requireNamespace, logical(1), quietly = TRUE)))
})
```

- [ ] **Step 2: Run the test and confirm it fails before bootstrap**

Run:

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-environment.R")'
```

Expected: FAIL listing one or more missing packages.

- [ ] **Step 3: Implement `scripts/00_bootstrap.R`**

```r
options(repos = c(MRCIEU = "https://mrcieu.r-universe.dev", CRAN = "https://cloud.r-project.org"))
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
if (!file.exists("renv.lock")) renv::init(bare = TRUE)
renv::install(c(
  "targets", "tarchetypes", "testthat", "data.table", "arrow", "yaml",
  "jsonlite", "digest", "httr2", "rvest", "xml2", "TwoSampleMR",
  "genetics.binaRies",
  "ieugwasr", "mr.raps", "MendelianRandomization", "coloc", "susieR",
  "MVMR", "ggplot2", "patchwork", "quarto", "BiocManager",
  "github::rondolab/MR-PRESSO"
))
BiocManager::install("rtracklayer", ask = FALSE, update = FALSE)
renv::snapshot(prompt = FALSE)
```

Create `.Rprofile` with:

```r
source("renv/activate.R")
options(repos = c(MRCIEU = "https://mrcieu.r-universe.dev", CRAN = "https://cloud.r-project.org"))
```

- [ ] **Step 4: Bootstrap and rerun the test**

```bash
/opt/homebrew/bin/Rscript scripts/00_bootstrap.R
/opt/homebrew/bin/Rscript -e 'stopifnot(file.exists(genetics.binaRies::get_plink_binary()))'
quarto --version
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-environment.R")'
```

Expected: PASS and a non-empty `renv.lock`.

- [ ] **Step 5: Commit the locked environment**

```bash
git add scripts/00_bootstrap.R .Rprofile renv.lock tests
git commit -m 'build: lock MR analysis environment'
```

### Task 3: Define and validate project/data-source configuration

**Files:**
- Create: `config/project.yml`
- Create: `config/data_sources.yml`
- Create: `R/config.R`
- Create: `tests/testthat/test-config.R`

- [ ] **Step 1: Write failing validation tests**

```r
source("R/config.R")
test_that("project thresholds are explicit", {
  cfg <- read_project_config("config/project.yml")
  expect_equal(cfg$instruments$primary_p, 5e-8)
  expect_equal(cfg$instruments$exploratory_p, 1e-5)
  expect_equal(cfg$multiple_testing$fdr, 0.05)
  expect_true(cfg$multiple_testing$freeze_eligibility_before_mr_p)
  expect_equal(cfg$multiple_testing$families, c("forward_primary", "reverse"))
  expect_true(cfg$multiple_testing$record_denominators)
  expect_false(cfg$multiple_testing$strata_reduce_denominators)
  expect_equal(cfg$multiple_testing$global_bonferroni$denominator, "N_forward_plus_N_reverse")
  expect_equal(cfg$replication$required_overlap_class, "none_known")
  expect_equal(cfg$replication$validation$two_sided_p_lt, 0.05)
  expect_equal(cfg$replication$robust_estimators, c("weighted_median", "mr_raps"))
  expect_equal(cfg$replication$steiger_reversal_p_lt, 0.05)
  expect_equal(cfg$replication$pleiotropy$egger_intercept_p_lt, 0.05)
  expect_equal(cfg$replication$pleiotropy$presso_global_p_lt, 0.05)
  expect_equal(cfg$replication$non_estimable_tests, "report_not_pass")
  expect_equal(cfg$ld$eur$r2, 0.001)
  expect_equal(cfg$ld$eur$kb, 10000)
})
test_that("data sources include access and overlap metadata", {
  src <- read_source_config("config/data_sources.yml")
  expect_true(all(c("microbiome_2026", "microbiome_2026_hunt", "ed_2025", "finngen_r12", "ld_reference_1kg") %in% names(src)))
  expect_true(all(vapply(src, function(x) nzchar(x$license), logical(1))))
})
```

- [ ] **Step 2: Run and confirm failure**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-config.R")'
```

Expected: FAIL because config files/functions do not exist.

- [ ] **Step 3: Implement configuration files**

```yaml
# config/project.yml
genome_build: GRCh38
instruments: {primary_p: 5.0e-8, exploratory_p: 1.0e-5, min_f: 10, min_snps_mr_presso: 4}
ld:
  eur: {population: EUR, r2: 0.001, kb: 10000}
  afr: {population: AFR, r2: 0.001, kb: 10000}
multiple_testing:
  method: BH
  fdr: 0.05
  freeze_eligibility_before_mr_p: true
  eligibility_criteria: [source, qc, instrument]
  families: [forward_primary, reverse]
  record_denominators: true
  strata_reduce_denominators: false
  global_bonferroni: {alpha: 0.05, denominator: N_forward_plus_N_reverse}
replication:
  discovery_family: forward_primary
  discovery_q_lt: 0.05
  required_overlap_class: none_known
  sensitivity_only_overlap_classes: [known, possible]
  validation: {same_beta_sign: true, two_sided_p_lt: 0.05, ci_excludes_null_same_direction: true}
  robust_estimators: [weighted_median, mr_raps]
  require_one_robust_same_sign: true
  robust_significance_required: false
  steiger_reversal_p_lt: 0.05
  steiger_unavailable: report_not_support
  pleiotropy:
    egger_intercept_p_lt: 0.05
    presso_global_p_lt: 0.05
    unresolved_outliers_fail: true
    corrected_sign_change_fail: true
    corrected_unavailable_fail: true
  non_estimable_tests: report_not_pass
coloc: {prior_p1: 1.0e-4, prior_p2: 1.0e-4, prior_p12: 1.0e-5, pp4_support: 0.80}
mvmr_covariates: [BMI, type_2_diabetes, coronary_artery_disease]
```

```yaml
# config/data_sources.yml
microbiome_2026:
  accessions: {first: GCST90670368, last: GCST90671939}
  article: https://doi.org/10.1038/s41588-026-02512-2
  catalog_root: https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics
  ancestry: EUR
  genome_build: GRCh37
  license: GWAS Catalog CC0 or accession-specific terms
  cohort_membership: [Swedish_discovery_cohorts]
  known_overlap_datasets: []
  replication_role: exposure_discovery
  overlap_note: Swedish discovery cohorts
microbiome_2026_hunt:
  accessions: {first: GCST90666541, last: GCST90667549}
  article: https://doi.org/10.1038/s41588-026-02512-2
  catalog_root: https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics
  ancestry: EUR
  genome_build: GRCh37
  license: GWAS Catalog CC0 or accession-specific terms
  cohort_membership: [HUNT]
  known_overlap_datasets: []
  replication_role: independent_exposure_replication
  overlap_note: Norwegian HUNT independent exposure replication cohort
ed_2025:
  article_id: 30505799
  api: https://api.figshare.com/v2/articles/30505799
  article: https://doi.org/10.1038/s41467-025-66723-7
  ancestry: EUR, AFR, cross-ancestry
  genome_build: GRCh38
  ancestry_file_patterns:
    EUR: '^ed_eur_meta_(aa|ab|ac)\.gz$'
    AFR: '^ed_afr_meta_(aa|ab)\.gz$'
    cross_ancestry: '^ed_cross_ancestry_meta_(aa|ab|ac)\.gz$'
  license: CC BY 4.0 article; file terms recorded from Figshare
  cohort_membership: [UK_Biobank, MVP, FinnGen, All_of_Us, Estonian_Biobank, Partners_HealthCare_Biobank]
  known_overlap_datasets: [finngen_r12]
  replication_role: high_power_outcome_meta_sensitivity
  overlap_note: Meta-analysis includes UK Biobank, MVP, FinnGen, AoU, Estonia, and PHB
finngen_r12:
  manifest: https://storage.googleapis.com/finngen-public-data-r12/summary_stats/finngen_R12_manifest.tsv
  phenotype_regex: (^|_)ERECTILE_DYSFUNCTION$|(^|_)N52($|_)
  ancestry: Finnish
  genome_build: GRCh38
  license: FinnGen public summary-statistics terms
  cohort_membership: [FinnGen]
  known_overlap_datasets: [ed_2025]
  replication_role: outcome_source_known_overlap_with_ed_2025
  overlap_note: FinnGen overlaps the ed_2025 outcome meta-analysis
ld_reference_1kg:
  record: https://doi.org/10.5281/zenodo.6614170
  ancestry_files: [EUR, AFR]
  genome_build: GRCh37
  license: 1000 Genomes open data terms; Zenodo record metadata retained
  cohort_membership: [1000_Genomes]
  known_overlap_datasets: []
  replication_role: external_ld_reference
  overlap_note: External LD reference only
```

- [ ] **Step 4: Implement strict loaders**

```r
# R/config.R
read_yaml_checked <- function(path, keys) {
  if (!file.exists(path)) stop("Missing config: ", path)
  x <- yaml::read_yaml(path)
  missing <- setdiff(keys, names(x))
  if (length(missing)) stop("Missing keys in ", path, ": ", paste(missing, collapse = ", "))
  x
}
read_project_config <- function(path) read_yaml_checked(path, c("genome_build", "instruments", "ld", "multiple_testing", "replication", "coloc", "mvmr_covariates"))
read_source_config <- function(path) read_yaml_checked(path, c("microbiome_2026", "microbiome_2026_hunt", "ed_2025", "finngen_r12", "ld_reference_1kg"))
```

- [ ] **Step 5: Test and commit**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-config.R")'
git add config R/config.R tests/testthat/test-config.R
git commit -m 'feat: define validated analysis configuration'
```

Expected: PASS.

### Task 4: Resolve source URLs and create a provenance inventory

**Files:**
- Create: `R/catalog.R`
- Create: `R/provenance.R`
- Create: `scripts/01_source_inventory.R`
- Create: `tests/testthat/test-catalog.R`
- Generate: `00_admin/source_inventory.csv`

- [ ] **Step 1: Write tests for accession bucketing and Figshare parsing**

```r
source("R/catalog.R")
test_that("GWAS accession maps to the correct 1000-accession bucket", {
  expect_equal(gwas_bucket("GCST90670368"), "GCST90670001-GCST90671000")
  expect_equal(gwas_accession_dir("GCST90670368"), paste0(
    "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/",
    "GCST90670001-GCST90671000/GCST90670368/"
  ))
})
test_that("Figshare file records retain id, original name, source URL and size", {
  x <- parse_figshare_files(list(files = list(list(id = 1, name = "eur.gz", download_url = "https://x/eur.gz", size = 42))))
  expect_equal(names(x), c("source_id", "file_name", "source_url", "expected_bytes"))
  expect_equal(x$expected_bytes, 42)
})
```

- [ ] **Step 2: Run and confirm failure**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-catalog.R")'
```

- [ ] **Step 3: Implement deterministic catalog helpers**

```r
# R/catalog.R
gwas_bucket <- function(accession) {
  n <- as.integer(sub("GCST", "", accession))
  low <- ((n - 1L) %/% 1000L) * 1000L + 1L
  sprintf("GCST%08d-GCST%08d", low, low + 999L)
}
gwas_accession_dir <- function(accession, root = "https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics") {
  sprintf("%s/%s/%s/", root, gwas_bucket(accession), accession)
}
parse_figshare_files <- function(x) {
  data.frame(
    source_id = vapply(x$files, function(z) as.character(z$id), character(1)),
    file_name = vapply(x$files, `[[`, character(1), "name"),
    source_url = vapply(x$files, `[[`, character(1), "download_url"),
    expected_bytes = vapply(x$files, `[[`, numeric(1), "size")
  )
}
```

- [ ] **Step 4: Implement inventory-only network resolution**

`scripts/01_source_inventory.R` must enumerate every Swedish-discovery and HUNT microbiome accession directory and resolve exactly one original summary-statistics file named either `GCST########.tsv.gz` or `GCST########.tsv`, plus the exact matching metadata filename `<data_file_name>-meta.yaml`. It must preserve the upstream filename and compression without downloading, recompressing, or renaming any GWAS payload. Both data candidates are checked with metadata-only HEAD requests: both present and neither present must fail, 404 means an absent candidate, and the chosen file's matching metadata must exist. The script must query the Figshare API, query the FinnGen R12 manifest with the configured phenotype regex, HEAD the resolved FinnGen object for exact size and consistent MD5 headers, resolve the EUR/AFR PLINK reference files and published MD5 values from Zenodo record `6614170`, and write `00_admin/source_inventory.csv` without downloading any GWAS payload. Inventory rows must consume each source's configured `genome_build`, structured cohort membership, overlap links, and replication role directly. Reruns preserve timestamps for unchanged rows and are byte-identical when stable metadata is unchanged; removed rows stop replacement. ED ancestry must be assigned only by a unique match against the named `ancestry_file_patterns`; zero matches, multiple matches, unknown pattern keys, and files outside the configured patterns must fail. The combined `ed_2025.ancestry` label is descriptive metadata and must never be parsed to infer a file's ancestry.

Required columns:

```text
dataset,source_id,file_name,source_url,expected_bytes,ancestry,genome_build,license,overlap_note,cohort_membership,known_overlap_datasets,replication_role,resolved_at_utc,checksum_algorithm,expected_checksum
```

`source_id` is the accession or version identifier and `file_name` is the original source filename. The immutable key `dataset + source_id + file_name` must be unique. These fields, plus `source_url` and `license`, are carried unchanged into the receipt so the download row joins deterministically to this inventory.

- [ ] **Step 5: Run, audit counts, and commit code**

```bash
/opt/homebrew/bin/Rscript scripts/01_source_inventory.R
/opt/homebrew/bin/Rscript -e 'source("R/provenance.R"); x <- read_source_inventory_csv("00_admin/source_inventory.csv"); key <- paste(x$dataset, x$source_id, x$file_name, sep = "\037"); stopifnot(identical(as.integer(table(factor(x$dataset, levels = c("microbiome_2026", "microbiome_2026_hunt", "ed_2025", "finngen_r12", "ld_reference_1kg")))), c(3144L, 2018L, 8L, 1L, 6L)), !anyDuplicated(key), !anyDuplicated(x$source_url), identical(names(x), SOURCE_INVENTORY_REQUIRED_COLUMNS)); validate_source_inventory(x); validate_overlap_symmetry(x)'
git add config/data_sources.yml R/config.R R/catalog.R R/provenance.R scripts/01_source_inventory.R tests/testthat/test-config.R tests/testthat/test-catalog.R 00_admin/source_inventory.csv docs/superpowers/plans/2026-07-10-gut-ed-mr-rebuild-implementation.md
git commit -m 'feat: resolve public GWAS source inventory'
```

Expected: unique downloadable URLs and no GWAS payload downloaded yet.

### Task 5: Download, checksum, and freeze source data

**Files:**
- Create: `scripts/02_download_freeze.R`
- Create: `tests/testthat/test-provenance.R`
- Generate: `MANIFEST.csv`
- Generate: `03_data/raw/**`

The versioned manifest schema is exactly:

```text
dataset,source_id,file_name,path,source_url,license,bytes,sha256,frozen_at_utc
```

`path` is project-relative. The other provenance fields are copied from the uniquely matched source-inventory row, where `source_id` is the accession/version and `file_name` is the original filename, including its upstream-preserved `.tsv.gz` or `.tsv` form. Task 5 download and receipt logic must not assume that every GWAS original is gzip-compressed.

- [ ] **Step 1: Write failing provenance tests**

```r
source("R/provenance.R")
make_receipt_fixture <- function() {
  root <- tempfile(); dir.create(file.path(root, "03_data", "raw"), recursive = TRUE)
  f <- file.path(root, "03_data", "raw", "a.bin"); writeBin(charToRaw("abc"), f)
  inventory_row <- data.frame(
    dataset = "fixture", source_id = "fixture-v1", file_name = "a.bin",
    source_url = "https://example.org/a", license = "CC0"
  )
  r <- file_receipt(f, inventory_row, project_root = root)
  list(root = root, file = f, inventory = inventory_row, receipt = r)
}
test_that("file receipts use project-relative paths and detect hash mismatch", {
  x <- make_receipt_fixture(); r <- x$receipt
  expect_equal(names(r), c("dataset", "source_id", "file_name", "path", "source_url", "license", "bytes", "sha256", "frozen_at_utc"))
  expect_equal(r$path, "03_data/raw/a.bin")
  expect_equal(r$bytes, 3)
  expect_equal(nchar(r$sha256), 64)
  expect_true(validate_receipt(r, project_root = x$root))
  expect_error(validate_receipt(transform(r, sha256 = paste(rep("0", 64), collapse = "")), project_root = x$root), "SHA-256")
})
test_that("manifest and inventory reject duplicate immutable keys", {
  x <- make_receipt_fixture()
  manifest_path <- tempfile(); inventory_path <- tempfile()
  write.csv(rbind(x$receipt, x$receipt), manifest_path, row.names = FALSE)
  write.csv(x$inventory, inventory_path, row.names = FALSE)
  expect_error(verify_manifest(manifest_path, inventory_path, x$root), "Duplicate")
  write.csv(x$receipt, manifest_path, row.names = FALSE)
  write.csv(rbind(x$inventory, x$inventory), inventory_path, row.names = FALSE)
  expect_error(verify_manifest(manifest_path, inventory_path, x$root), "Duplicate")
})
test_that("manifest metadata must match exactly one inventory row", {
  x <- make_receipt_fixture()
  manifest_path <- tempfile(); inventory_path <- tempfile()
  write.csv(x$receipt, manifest_path, row.names = FALSE)
  write.csv(transform(x$inventory, source_url = "https://example.org/changed"), inventory_path, row.names = FALSE)
  expect_error(verify_manifest(manifest_path, inventory_path, x$root), "metadata")
})
test_that("identical downloader receipt is idempotent and conflicts stop", {
  x <- make_receipt_fixture()
  expect_equal(append_receipt_idempotent(x$receipt, x$receipt), x$receipt)
  expect_error(append_receipt_idempotent(x$receipt, transform(x$receipt, bytes = bytes + 1)), "Conflicting")
})
```

- [ ] **Step 2: Implement receipts and validation**

```r
# R/provenance.R
immutable_provenance_fields <- c("dataset", "source_id", "file_name", "source_url", "license")
receipt_key_fields <- c("dataset", "source_id", "file_name")
receipt_key <- function(x) paste(x$dataset, x$source_id, x$file_name, sep = "\037")
assert_unique_receipt_keys <- function(x, label) {
  required <- unique(c(receipt_key_fields, immutable_provenance_fields))
  if (!all(required %in% names(x))) stop(label, " schema incomplete")
  if (anyDuplicated(receipt_key(x))) stop("Duplicate immutable key in ", label)
  invisible(TRUE)
}
file_receipt <- function(path, inventory_row, project_root = ".") {
  required <- immutable_provenance_fields
  if (!all(required %in% names(inventory_row))) stop("Inventory metadata incomplete")
  if (any(!nzchar(as.character(unlist(inventory_row[1, required], use.names = FALSE))))) stop("Inventory metadata contains empty provenance fields")
  absolute <- normalizePath(path, mustWork = TRUE)
  root <- normalizePath(project_root, mustWork = TRUE)
  prefix <- paste0(root, .Platform$file.sep)
  if (!startsWith(absolute, prefix)) stop("File is outside project root: ", path)
  relative <- substring(absolute, nchar(prefix) + 1L)
  data.frame(
    dataset = inventory_row$dataset[1], source_id = inventory_row$source_id[1],
    file_name = inventory_row$file_name[1], path = relative,
    source_url = inventory_row$source_url[1], license = inventory_row$license[1],
    bytes = file.info(absolute)$size,
    sha256 = digest::digest(file = absolute, algo = "sha256"),
    frozen_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
}
validate_receipt <- function(receipt, project_root = ".") {
  required <- c("dataset", "source_id", "file_name", "path", "source_url", "license", "bytes", "sha256", "frozen_at_utc")
  if (!all(required %in% names(receipt))) stop("Receipt schema incomplete")
  if (grepl("^(/|[A-Za-z]:[/\\\\])", receipt$path[1])) stop("Manifest path must be project-relative")
  if (grepl("(^|[/\\\\])\\.\\.([/\\\\]|$)", receipt$path[1])) stop("Manifest path escapes project root")
  path <- file.path(project_root, receipt$path[1])
  if (file.info(path)$size != receipt$bytes) stop("Byte-size mismatch: ", path)
  actual <- digest::digest(file = path, algo = "sha256")
  if (!identical(actual, receipt$sha256)) stop("SHA-256 mismatch: ", path)
  invisible(TRUE)
}
append_receipt_idempotent <- function(manifest, receipt) {
  if (nrow(receipt) != 1L) stop("Expected one receipt")
  assert_unique_receipt_keys(manifest, "manifest")
  key <- receipt_key(receipt)
  hit <- which(receipt_key(manifest) == key)
  if (!length(hit)) return(rbind(manifest, receipt))
  compare <- c(immutable_provenance_fields, "path", "bytes", "sha256")
  same <- all(vapply(compare, function(z) identical(as.character(manifest[[z]][hit]), as.character(receipt[[z]][1])), logical(1)))
  if (!same) stop("Conflicting receipt for immutable key: ", key)
  manifest
}
verify_manifest <- function(manifest_path, inventory_path, project_root = ".") {
  x <- read.csv(manifest_path, stringsAsFactors = FALSE)
  inventory <- read.csv(inventory_path, stringsAsFactors = FALSE)
  assert_unique_receipt_keys(x, "manifest")
  assert_unique_receipt_keys(inventory, "source inventory")
  inventory_keys <- receipt_key(inventory)
  invisible(lapply(seq_len(nrow(x)), function(i) {
    hit <- which(inventory_keys == receipt_key(x[i, , drop = FALSE]))
    if (length(hit) != 1L) stop("Manifest key does not match exactly one inventory row")
    same <- all(vapply(immutable_provenance_fields, function(z) identical(as.character(x[[z]][i]), as.character(inventory[[z]][hit])), logical(1)))
    if (!same) stop("Manifest metadata mismatch for key: ", receipt_key(x[i, , drop = FALSE]))
    validate_receipt(x[i, , drop = FALSE], project_root)
  }))
  TRUE
}
```

- [ ] **Step 3: Implement resumable downloads**

`scripts/02_download_freeze.R` must reject any source or destination basename beginning `._`; use `curl --fail --location --continue-at - --retry 5 --retry-delay 5 --connect-timeout 30 --speed-limit 32768 --speed-time 120 --proto =https --proto-redir =https`; write to a non-symlink regular `*.part`; charge and resume only its missing bytes; promote an exact-size checksum-valid partial without curl; verify expected bytes and the Task 4 checksum; rename atomically; pass the uniquely matched source-inventory row to `file_receipt()`; and update `MANIFEST.csv` through `append_receipt_idempotent()`. A connection must fail within 30 seconds, and a transfer sustained below 32 KiB/s for 120 seconds must be treated as stalled so curl's bounded transient-error retry can reconnect instead of hanging indefinitely. Beyond curl's default transient retry policy, the R layer retries only status 18, at most three extra times with a one-second delay and the same `--continue-at -` target. After every nonzero curl status it must revalidate that `.part` is a non-symlink regular file, is not oversized, is writable when partial, and is checksum-valid when complete; a complete valid file proceeds to promotion, while permanent status 22 and unsafe or corrupt states stop without R-layer retry. Logs and final errors record status and attempt count. Each atomic append structurally validates the full prior and candidate ledgers, enforces monotonic immutable receipts, and content-verifies only newly added rows; it must not rehash all prior payloads. `freeze_raw_file()` first attempts `Sys.chmod(path, "0444")` and verifies effective no-write bits. On `noowners`/exFAT, it falls back to `/usr/bin/chflags uchg` through an argument vector and verifies the flag with `/usr/bin/stat -f %Sf`; failure of both methods stops before manifest replacement. AppleDouble `._*` sidecars in ignored raw paths may be required to persist flags and must never be ingested or deleted by the pipeline. On rerun, an identical key/provenance/path/bytes/hash receipt is a no-op. The same immutable key with any conflicting provenance, path, bytes, or hash stops the run and is never appended or overwritten silently.

- [ ] **Step 4: Run a one-file smoke download before bulk download**

```bash
/opt/homebrew/bin/Rscript scripts/02_download_freeze.R --dataset ld_reference_1kg --file 1000G_EUR.fam --limit 1
/opt/homebrew/bin/Rscript -e 'source("R/provenance.R"); inventory <- read_source_inventory_csv("00_admin/source_inventory.csv"); x <- read_manifest_csv("MANIFEST.csv"); p <- file.path(getwd(), x$path[1]); stopifnot(nrow(x) == 1, identical(x$file_name[1], "1000G_EUR.fam"), file.info(p)$size == 9557, unname(tools::md5sum(p)) == "669a4260fda7a9e1dd7df374aff294ea", nchar(x$sha256[1]) == 64, !grepl("^/", x$path[1]), !startsWith(basename(x$path[1]), "._"), validate_frozen_file(p), verify_manifest(x, inventory, getwd()))'
/opt/homebrew/bin/Rscript scripts/02_download_freeze.R --dataset ld_reference_1kg --file 1000G_EUR.fam --limit 1
```

Expected: one immutable 9,557-byte file with a valid manifest row; the second invocation is a no-op preserving the manifest bytes, mtime, and receipt timestamp. No other payload is downloaded.

- [ ] **Step 5: Download remaining selected payloads and commit receipts only**

```bash
/opt/homebrew/bin/Rscript scripts/02_download_freeze.R --dataset microbiome_2026
/opt/homebrew/bin/Rscript scripts/02_download_freeze.R --dataset microbiome_2026_hunt
/opt/homebrew/bin/Rscript scripts/02_download_freeze.R --dataset ed_2025
/opt/homebrew/bin/Rscript scripts/02_download_freeze.R --dataset finngen_r12
/opt/homebrew/bin/Rscript scripts/02_download_freeze.R --dataset ld_reference_1kg
/opt/homebrew/bin/Rscript -e 'source("R/provenance.R"); inventory <- read_source_inventory_csv("00_admin/source_inventory.csv"); manifest <- read_manifest_csv("MANIFEST.csv"); stopifnot(verify_manifest(manifest, inventory, getwd(), verify_files = TRUE))'
git add MANIFEST.csv scripts/02_download_freeze.R R/download.R R/provenance.R tests/testthat/test-provenance.R README.md docs/superpowers/plans/2026-07-10-gut-ed-mr-rebuild-implementation.md
git commit -m 'feat: freeze and verify public GWAS inputs'
```

The current Task 4 inventory declares 345,357,963,685 bytes across all five datasets. Preserve each upstream `.tsv` or `.tsv.gz` filename exactly. Do not launch this bulk sequence until the reviewed downloader and one-file smoke both pass. Run the explicit full-file `verify_manifest(..., verify_files = TRUE)` once after the completed bulk batch, not after every receipt or dataset append. Task 11 retains the known `ed_2025`/`finngen_r12` overlap as sensitivity-only.

For long-running execution on macOS, install the checked-in `00_admin/com.duxiancheng.gut-ed-download.plist` as the user LaunchAgent `com.duxiancheng.gut-ed-download`. The agent runs `scripts/02_download_supervisor.R` under `/usr/bin/caffeinate -ims`, waits while a live downloader owns the lock, atomically reclaims a dead lock without a 24-hour delay, restarts after abnormal exit, runs Swedish then HUNT, performs the one final full verification, and stops only after successful completion. Keep launchd stdout/stderr under `~/Library/Logs`; launchd cannot reliably open standard streams on the external exFAT project path.

Expected: raw files remain Git-ignored; receipts are versioned.

### Task 6: Normalize GWAS schemas and reject ambiguous inputs

**Files:**
- Create: `R/gwas_schema.R`
- Create: `tests/fixtures/exposure.tsv`
- Create: `tests/fixtures/outcome.tsv`
- Create: `tests/testthat/test-gwas-schema.R`
- Generate: `03_data/processed/*.parquet`

- [ ] **Step 1: Create two miniature fixtures**

```text
# tests/fixtures/exposure.tsv
variant_id	chromosome	base_pair_location	effect_allele	other_allele	beta	standard_error	effect_allele_frequency	p_value	sample_size
rs1	1	100	A	G	0.10	0.02	0.20	1e-9	16017
rs2	1	200	C	T	-0.12	0.03	0.40	2e-7	16017
```

```text
# tests/fixtures/outcome.tsv
SNP	CHR	POS	A1	A2	BETA	SE	EAF	P	N
rs1	1	100	A	G	0.05	0.01	0.20	1e-6	913194
rs2	1	200	T	C	0.02	0.01	0.60	0.04	913194
```

- [ ] **Step 2: Write failing schema tests**

```r
source("R/gwas_schema.R")
test_that("heterogeneous headers normalize to one schema", {
  e <- normalize_gwas("tests/fixtures/exposure.tsv", role = "exposure", build = "GRCh38", ancestry = "EUR")
  o <- normalize_gwas("tests/fixtures/outcome.tsv", role = "outcome", build = "GRCh38", ancestry = "EUR")
  expect_identical(names(e), names(o))
  expect_true(all(c("snp", "chr", "pos", "ea", "oa", "beta", "se", "eaf", "p", "n", "build", "ancestry", "role") %in% names(e)))
})
test_that("invalid alleles and impossible p values fail", {
  bad <- data.frame(snp = "rs1", chr = 1, pos = 1, ea = "N", oa = "A", beta = 0, se = 1, eaf = .2, p = 2, n = 10)
  expect_error(validate_gwas(bad), "allele|p-value")
})
```

- [ ] **Step 3: Implement normalization and validation**

`normalize_gwas()` must map documented synonyms, type columns, uppercase alleles, add metadata, remove exact duplicate SNP rows only when all analytical fields match, and call `validate_gwas()`. `validate_gwas()` must reject missing SNP IDs, non-ACGT alleles, `ea == oa`, `se <= 0`, `p <= 0 | p > 1`, `eaf <= 0 | eaf >= 1`, `n <= 0`, and duplicate SNPs with conflicting values. If builds differ, `lift_gwas_build()` must use the matching UCSC chain through `rtracklayer::liftOver`, retain original and lifted coordinates, and write failed/multi-mapped variants to `08_qc/liftover_exclusions.csv`. `normalize_manifest()` must iterate over verified GWAS receipts, write one Parquet file per GWAS, and emit `08_qc/schema_exclusions.csv` plus `08_qc/normalized_inventory.csv`.

- [ ] **Step 4: Test and batch-normalize to Parquet**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-gwas-schema.R")'
/opt/homebrew/bin/Rscript -e 'source("R/gwas_schema.R"); normalize_manifest("MANIFEST.csv", "03_data/processed")'
```

Expected: PASS; one Parquet file per selected GWAS plus an exclusion log.

- [ ] **Step 5: Commit schema code and fixture tests**

```bash
git add R/gwas_schema.R tests
git commit -m 'feat: normalize and validate GWAS schemas'
```

### Task 7: Select strong instruments and perform ancestry-matched LD clumping

**Files:**
- Create: `R/instruments.R`
- Create: `tests/testthat/test-instruments.R`
- Generate: `05_results/tables/instrument_inventory.csv`

- [ ] **Step 1: Write failing threshold and F-statistic tests**

```r
source("R/instruments.R")
test_that("primary and exploratory tiers never mix", {
  x <- data.frame(snp = c("a", "b"), beta = c(.1, .1), se = c(.01, .02), p = c(1e-9, 1e-6))
  expect_equal(select_by_p(x, 5e-8)$snp, "a")
  expect_equal(select_by_p(x, 1e-5)$snp, c("a", "b"))
})
test_that("weak instruments are removed", {
  x <- data.frame(snp = c("a", "b"), beta = c(.20, .02), se = c(.02, .02), p = c(1e-9, 1e-9))
  expect_equal(add_f_stat(x)$F, c(100, 1))
  expect_equal(filter_strong_iv(x, min_f = 10)$snp, "a")
})
```

- [ ] **Step 2: Implement deterministic selection**

```r
# R/instruments.R
select_by_p <- function(x, threshold) x[is.finite(x$p) & x$p < threshold, , drop = FALSE]
add_f_stat <- function(x) transform(x, F = (beta / se)^2)
filter_strong_iv <- function(x, min_f = 10) subset(add_f_stat(x), F > min_f)
```

- [ ] **Step 3: Implement local clumping wrapper**

`clump_local()` must require an explicit ancestry, the binary returned by `genetics.binaRies::get_plink_binary()`, and a matching 1000 Genomes PLINK prefix; it must fail if the reference ancestry differs from the requested ancestry. It writes the command, PLINK version, retained SNPs, and clumping parameters to `08_qc/clumping/`. `build_instrument_inventory()` must run both prespecified tiers separately for every normalized microbiome trait and never merge tiers.

- [ ] **Step 4: Run tests and create the instrument inventory**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-instruments.R")'
/opt/homebrew/bin/Rscript -e 'source("R/instruments.R"); build_instrument_inventory("03_data/processed", "config/project.yml", "05_results/tables/instrument_inventory.csv")'
```

Expected inventory fields: trait, ancestry, tier, pre-clump SNPs, post-clump SNPs, minimum/mean F, and exclusion reason.

- [ ] **Step 5: Commit**

```bash
git add R/instruments.R tests/testthat/test-instruments.R
git commit -m 'feat: select and audit ancestry-matched instruments'
```

### Task 8: Harmonize exposure/outcome data with an exclusion audit

**Files:**
- Create: `R/harmonise.R`
- Create: `tests/testthat/test-harmonise.R`
- Generate: `05_results/tables/harmonisation_audit.csv`

- [ ] **Step 1: Write allele-orientation tests**

```r
source("R/harmonise.R")
test_that("swapped outcome alleles flip beta", {
  e <- data.frame(snp = "rs1", ea = "A", oa = "G", eaf = .2, beta = .1, se = .02, p = 1e-9)
  o <- data.frame(snp = "rs1", ea = "G", oa = "A", eaf = .8, beta = .3, se = .04, p = .01)
  h <- harmonise_pair(e, o)
  expect_equal(h$beta.outcome, -.3)
  expect_equal(h$effect_allele, "A")
})
test_that("ambiguous palindromes near 0.5 are excluded", {
  e <- data.frame(snp = "rs2", ea = "A", oa = "T", eaf = .49, beta = .1, se = .02, p = 1e-9)
  o <- data.frame(snp = "rs2", ea = "A", oa = "T", eaf = .51, beta = .2, se = .03, p = .01)
  expect_equal(nrow(harmonise_pair(e, o)), 0)
})
```

- [ ] **Step 2: Implement harmonization using `TwoSampleMR::harmonise_data`**

Convert normalized columns to exposure/outcome format, call `harmonise_data(action = 2)`, retain `mr_keep == TRUE`, and write every exclusion with reason: absent outcome SNP, incompatible alleles, ambiguous palindrome, missing frequency, or invalid statistic. `harmonise_all_pairs()` must create one serialized harmonized object per eligible trait/outcome pair and a CSV audit row for every attempted pair, including failures.

- [ ] **Step 3: Add sample-overlap metadata to every pair**

Every harmonized object must carry exposure cohort, outcome cohort, overlap classification (`none_known`, `possible`, `known`), and action (`primary`, `sensitivity_only`, `blocked`). Known overlap may not enter the primary discovery analysis.

- [ ] **Step 4: Test and generate the audit**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-harmonise.R")'
/opt/homebrew/bin/Rscript -e 'source("R/harmonise.R"); harmonise_all_pairs("05_results/tables/instrument_inventory.csv", "05_results/tables/harmonisation_audit.csv")'
```

- [ ] **Step 5: Commit**

```bash
git add R/harmonise.R tests/testthat/test-harmonise.R
git commit -m 'feat: harmonize MR pairs with exclusion audit'
```

### Task 9: Implement core MR and sensitivity analyses

**Files:**
- Create: `R/mr_core.R`
- Create: `tests/testthat/test-mr-core.R`
- Generate: `05_results/tables/mr_raw.csv`
- Generate: `05_results/tables/mr_sensitivity.csv`

- [ ] **Step 1: Write method-selection tests**

```r
source("R/mr_core.R")
test_that("one SNP uses Wald ratio and multiple SNPs use prespecified methods", {
  expect_equal(mr_methods_for_n(1), "mr_wald_ratio")
  expect_equal(mr_methods_for_n(4), c("mr_ivw_mre", "mr_weighted_median", "mr_egger_regression", "mr_raps"))
})
test_that("MR-PRESSO is gated at four instruments", {
  expect_false(can_run_presso(3)); expect_true(can_run_presso(4))
})
```

- [ ] **Step 2: Implement the method registry**

```r
# R/mr_core.R
mr_methods_for_n <- function(n) if (n == 1L) "mr_wald_ratio" else c("mr_ivw_mre", "mr_weighted_median", "mr_egger_regression", "mr_raps")
can_run_presso <- function(n, minimum = 4L) n >= minimum
```

- [ ] **Step 3: Implement `run_mr_pair()`**

The function must return one tidy row per method plus nsnp, OR/CI, tier, ancestry, cohort pair, and overlap class. For multi-SNP pairs it must additionally run heterogeneity, Egger intercept, Steiger directionality, single-SNP, leave-one-out, and MR-PRESSO when allowed. Errors are captured as structured rows with `analysis_status` and `error_message`; no failed pair is silently dropped.

- [ ] **Step 4: Test and run all harmonized pairs**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-mr-core.R")'
/opt/homebrew/bin/Rscript -e 'source("R/mr_core.R"); run_all_mr("05_results/tables/harmonisation_audit.csv", "05_results/tables")'
```

Expected: raw and sensitivity tables with a row for every eligible pair.

- [ ] **Step 5: Commit**

```bash
git add R/mr_core.R tests/testthat/test-mr-core.R
git commit -m 'feat: run prespecified MR and sensitivity methods'
```

### Task 10: Freeze hypothesis families and apply multiplicity

**Files:**
- Create: `R/multiplicity.R`
- Create: `tests/testthat/test-multiplicity.R`
- Consume: `05_results/tables/mr_raw.csv`
- Generate: `05_results/tables/mr_multiplicity.csv`

- [ ] **Step 1: Write frozen-family multiplicity tests**

```r
source("R/multiplicity.R")
test_that("frozen denominators retain eligible failed estimates", {
  x <- data.frame(
    p = c(.001, NA, .2, .00001), tier = "primary",
    family = c("forward_primary", "forward_primary", "reverse", "forward_primary"),
    stratum = c("species", "module", "species", "species"),
    eligible = c(TRUE, TRUE, TRUE, FALSE), eligibility_frozen = TRUE,
    analysis_status = c("estimated", "failed", "estimated", "estimated")
  )
  g <- apply_multiplicity(x, alpha = .05)
  expect_equal(nrow(g), 4L)
  expect_equal(g$q[1], p.adjust(x$p[1], "BH", n = 2L))
  expect_true(is.na(g$q[2]))
  expect_equal(g$q[3], p.adjust(x$p[3], "BH", n = 1L))
  expect_true(is.na(g$q[4]))
  expect_equal(unique(g$n_forward), 2L)
  expect_equal(unique(g$n_reverse), 1L)
  expect_equal(unique(g$bonferroni_threshold), .05 / 3)
  expect_equal(g$analysis_role[3], "reverse_sensitivity")
})
test_that("eligibility must be frozen without using MR P values", {
  x <- data.frame(p = .001, tier = "primary", family = "forward_primary", eligible = TRUE, eligibility_frozen = FALSE)
  expect_error(apply_multiplicity(x), "eligibility")
})
```

- [ ] **Step 2: Implement multiplicity only**

```r
# R/multiplicity.R
apply_multiplicity <- function(x, alpha = .05) {
  required <- c("p", "family", "eligible", "eligibility_frozen")
  if (!all(required %in% names(x)) || !all(x$eligibility_frozen)) {
    stop("Analysis eligibility must be frozen before inspecting MR association P values")
  }
  if (!all(x$family %in% c("forward_primary", "reverse"))) stop("Unknown multiplicity family")
  x$analysis_role <- ifelse(x$family == "reverse", "reverse_sensitivity", "forward_causal")
  x$q <- NA_real_
  for (family in c("forward_primary", "reverse")) {
    frozen <- which(x$eligible & x$family == family)
    estimated <- frozen[is.finite(x$p[frozen])]
    if (length(estimated)) x$q[estimated] <- p.adjust(x$p[estimated], method = "BH", n = length(frozen))
  }
  x$n_forward <- sum(x$eligible & x$family == "forward_primary")
  x$n_reverse <- sum(x$eligible & x$family == "reverse")
  if (x$n_forward + x$n_reverse == 0L) stop("No eligible tests in either multiplicity family")
  x$bonferroni_threshold <- alpha / (x$n_forward + x$n_reverse)
  x$bonferroni_pass <- x$eligible & is.finite(x$p) & x$p < x$bonferroni_threshold
  x
}
```

- [ ] **Step 3: Preserve all tests in the correction family**

Freeze eligibility before inspecting MR association P values, using only prespecified source, QC, and instrument criteria. Retain every frozen hypothesis row. In particular, an eligible hypothesis whose primary estimate failed remains in its direction-specific denominator with `P = NA` and `q = NA`; it is never dropped after the eligibility freeze. Forward microbiome→ED and reverse ED→microbiome are separate BH-FDR families, each controlled at 5% using `p.adjust(..., n = N_family)`; record `N_forward`, `N_reverse`, and all exclusions. The strict threshold is `0.05 / (N_forward + N_reverse)`, and display strata never reduce either denominator.

`apply_and_write_multiplicity()` consumes `05_results/tables/mr_raw.csv`, applies only the frozen-family corrections above, assigns `analysis_role = reverse_sensitivity` to every reverse row, and writes `05_results/tables/mr_multiplicity.csv`. Reverse rows remain a separate directionality/sensitivity family and do not use the forward independent-replication gate. Task 10 does not consume replication output and does not assign final evidence grades.

- [ ] **Step 4: Run tests and grading**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-multiplicity.R")'
/opt/homebrew/bin/Rscript -e 'source("R/multiplicity.R"); apply_and_write_multiplicity("05_results/tables/mr_raw.csv", "05_results/tables/mr_multiplicity.csv")'
```

- [ ] **Step 5: Commit**

```bash
git add R/multiplicity.R tests/testthat/test-multiplicity.R
git commit -m 'feat: freeze hypothesis families and apply multiplicity'
```

### Task 11: Enforce replication gates and finalize evidence grades

**Files:**
- Create: `R/replication.R`
- Create: `tests/testthat/test-replication.R`
- Consume: `05_results/tables/mr_multiplicity.csv`
- Generate: `05_results/tables/replication_matrix.csv`
- Generate: `05_results/tables/mr_graded.csv`

- [ ] **Step 1: Write rule-engine tests**

```r
source("R/replication.R")
valid_pair <- function() list(
  discovery = data.frame(
    trait = "x", family = "forward_primary", beta = .20, q = .01,
    weighted_median_estimable = TRUE, weighted_median_beta = .18,
    mr_raps_estimable = FALSE, mr_raps_beta = NA_real_,
    steiger_estimable = TRUE, steiger_reversal = FALSE, steiger_p = .80,
    egger_estimable = TRUE, egger_intercept_p = .40,
    presso_estimable = TRUE, presso_global_p = .60,
    presso_outliers_resolved = TRUE, presso_corrected_estimable = TRUE,
    presso_corrected_beta = .19
  ),
  validation = data.frame(
    trait = "x", overlap_class = "none_known", beta = .10, p = .01,
    ci_low = .03, ci_high = .17,
    steiger_estimable = TRUE, steiger_reversal = FALSE, steiger_p = .70,
    egger_estimable = TRUE, egger_intercept_p = .50,
    presso_estimable = TRUE, presso_global_p = .50,
    presso_outliers_resolved = TRUE, presso_corrected_estimable = TRUE,
    presso_corrected_beta = .09
  )
)
expect_gate_failure <- function(x, gate) {
  z <- evaluate_replication(x$discovery, x$validation)
  expect_false(z$replicated)
  expect_false(z[[paste0(gate, "_gate")]])
  expect_match(z[[paste0(gate, "_reason")]], ".+")
}
test_that("a replicated candidate passes every deterministic gate", {
  x <- valid_pair(); z <- evaluate_replication(x$discovery, x$validation)
  expect_true(z$replicated)
  expect_true(all(unlist(z[paste0(c("discovery_fdr", "validation_overlap", "validation_effect", "robust_direction", "steiger", "pleiotropy"), "_gate")])))
})
test_that("discovery family and BH q are enforced", {
  x <- valid_pair(); x$discovery$family <- "reverse"; expect_gate_failure(x, "discovery_fdr")
  x <- valid_pair(); x$discovery$q <- .05; expect_gate_failure(x, "discovery_fdr")
})
test_that("validation overlap, sign, P and CI are enforced", {
  x <- valid_pair(); x$validation$overlap_class <- "known"
  expect_gate_failure(x, "validation_overlap")
  expect_equal(evaluate_replication(x$discovery, x$validation)$grade, "sensitivity_only")
  x <- valid_pair(); x$validation$beta <- -.10; expect_gate_failure(x, "validation_effect")
  x <- valid_pair(); x$validation$p <- .05; expect_gate_failure(x, "validation_effect")
  x <- valid_pair(); x$validation$ci_low <- -.01; expect_gate_failure(x, "validation_effect")
})
test_that("a prespecified robust discovery estimator must match direction", {
  x <- valid_pair(); x$discovery$weighted_median_beta <- -.18
  expect_gate_failure(x, "robust_direction")
  x <- valid_pair(); x$discovery$weighted_median_estimable <- FALSE
  expect_gate_failure(x, "robust_direction")
  x <- valid_pair(); x$discovery$weighted_median_estimable <- FALSE
  x$discovery$mr_raps_estimable <- TRUE; x$discovery$mr_raps_beta <- .17
  expect_true(evaluate_replication(x$discovery, x$validation)$robust_direction_gate)
})
test_that("Steiger reversal and unavailable Steiger data are not passing evidence", {
  x <- valid_pair(); x$discovery$steiger_reversal <- TRUE; x$discovery$steiger_p <- .01
  expect_gate_failure(x, "steiger")
  x <- valid_pair(); x$validation$steiger_estimable <- FALSE
  expect_gate_failure(x, "steiger")
})
test_that("Egger and MR-PRESSO severe or unavailable results fail pleiotropy gate", {
  x <- valid_pair(); x$discovery$egger_intercept_p <- .01; expect_gate_failure(x, "pleiotropy")
  x <- valid_pair(); x$validation$presso_global_p <- .01; x$validation$presso_outliers_resolved <- FALSE
  expect_gate_failure(x, "pleiotropy")
  x <- valid_pair(); x$validation$presso_global_p <- .01; x$validation$presso_corrected_beta <- -.09
  expect_gate_failure(x, "pleiotropy")
  x <- valid_pair(); x$validation$presso_global_p <- .01; x$validation$presso_corrected_estimable <- FALSE
  expect_gate_failure(x, "pleiotropy")
  x <- valid_pair(); x$discovery$egger_estimable <- FALSE; expect_gate_failure(x, "pleiotropy")
  x <- valid_pair(); x$validation$presso_estimable <- FALSE; expect_gate_failure(x, "pleiotropy")
})
test_that("final evidence labels distinguish exploratory from insufficient", {
  x <- data.frame(
    eligible = c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE),
    analysis_status = c("estimated", "failed", "estimated", "estimated", "estimated", "estimated"),
    p = c(.01, NA, .01, .01, .01, .001),
    family = rep("forward_primary", 6),
    tier = c("primary", "primary", "exploratory", "primary", "primary", "primary"),
    replicated = c(TRUE, FALSE, TRUE, FALSE, TRUE, TRUE),
    bonferroni_pass = c(TRUE, FALSE, TRUE, FALSE, FALSE, TRUE)
  )
  expect_equal(
    grade_evidence(x)$evidence_label,
    c("insufficient", "insufficient", "exploratory", "exploratory", "primary", "strict")
  )
})
test_that("reverse sensitivity grading ignores missing replication", {
  x <- data.frame(
    eligible = c(TRUE, FALSE), analysis_status = c("estimated", "failed"),
    p = c(.02, NA), family = "reverse", tier = "primary",
    replicated = NA, bonferroni_pass = c(TRUE, FALSE)
  )
  g <- grade_evidence(x)
  expect_equal(g$evidence_label, c("exploratory", "insufficient"))
  expect_equal(g$analysis_role, rep("reverse_sensitivity", 2))
})
test_that("every retained row receives exactly one valid non-missing label", {
  x <- data.frame(
    eligible = c(TRUE, TRUE, TRUE, FALSE, TRUE),
    analysis_status = c("estimated", "estimated", "estimated", "estimated", "failed"),
    p = c(.001, .02, .03, .01, NA),
    family = c("forward_primary", "forward_primary", "reverse", "reverse", "forward_primary"),
    tier = c("primary", "exploratory", "primary", "primary", "primary"),
    replicated = c(TRUE, NA, NA, NA, FALSE),
    bonferroni_pass = c(TRUE, FALSE, TRUE, FALSE, FALSE)
  )
  g <- grade_evidence(x)
  expect_equal(nrow(g), nrow(x))
  expect_false(anyNA(g$evidence_label))
  expect_true(all(g$evidence_label %in% c("strict", "primary", "exploratory", "insufficient")))
})
```

- [ ] **Step 2: Implement `evaluate_replication()`**

Require every normative gate from `01_protocol/analysis_decisions.md`. Report every gate as a boolean plus a gate-specific reason; unavailable tests must remain explicit and must not be treated as passing evidence. Report validation P and CI without replacing the discovery effect.

```r
# R/replication.R
same_sign <- function(a, b) is.finite(a) && is.finite(b) && sign(a) == sign(b) && sign(a) != 0
ci_excludes_null_in_direction <- function(beta, low, high) {
  is.finite(beta) && is.finite(low) && is.finite(high) &&
    ((beta > 0 && low > 0) || (beta < 0 && high < 0))
}
steiger_gate <- function(x, alpha) {
  if (!isTRUE(x$steiger_estimable[1])) return(list(pass = FALSE, reason = "Steiger unavailable"))
  if (!is.finite(x$steiger_p[1]) || is.na(x$steiger_reversal[1])) {
    return(list(pass = FALSE, reason = "Steiger result incomplete"))
  }
  reversal <- isTRUE(x$steiger_reversal[1]) && is.finite(x$steiger_p[1]) && x$steiger_p[1] < alpha
  list(pass = !reversal, reason = if (reversal) "Steiger reversal supported at P < 0.05" else "")
}
pleiotropy_gate <- function(x, primary_beta, alpha) {
  if (!isTRUE(x$egger_estimable[1])) return(list(pass = FALSE, reason = "MR-Egger intercept unavailable"))
  if (!is.finite(x$egger_intercept_p[1]) || x$egger_intercept_p[1] < alpha) {
    return(list(pass = FALSE, reason = "MR-Egger intercept is unavailable or P < 0.05"))
  }
  if (!isTRUE(x$presso_estimable[1]) || !is.finite(x$presso_global_p[1])) {
    return(list(pass = FALSE, reason = "MR-PRESSO global test unavailable"))
  }
  if (x$presso_global_p[1] < alpha) {
    if (!isTRUE(x$presso_outliers_resolved[1])) return(list(pass = FALSE, reason = "MR-PRESSO outliers unresolved"))
    if (!isTRUE(x$presso_corrected_estimable[1]) || !is.finite(x$presso_corrected_beta[1])) {
      return(list(pass = FALSE, reason = "MR-PRESSO corrected estimate unavailable"))
    }
    if (!same_sign(primary_beta, x$presso_corrected_beta[1])) {
      return(list(pass = FALSE, reason = "MR-PRESSO corrected estimate changes sign"))
    }
  }
  list(pass = TRUE, reason = "")
}
evaluate_replication <- function(discovery, validation, alpha = 0.05) {
  overlap <- if ("overlap_class" %in% names(validation)) validation$overlap_class[1] else NA_character_
  discovery_fdr <- identical(discovery$family[1], "forward_primary") && is.finite(discovery$q[1]) && discovery$q[1] < alpha
  validation_overlap <- identical(overlap, "none_known")
  validation_effect <- same_sign(discovery$beta[1], validation$beta[1]) &&
    is.finite(validation$p[1]) && validation$p[1] < alpha &&
    ci_excludes_null_in_direction(validation$beta[1], validation$ci_low[1], validation$ci_high[1])
  robust_available <- c(isTRUE(discovery$weighted_median_estimable[1]), isTRUE(discovery$mr_raps_estimable[1]))
  robust_beta <- c(discovery$weighted_median_beta[1], discovery$mr_raps_beta[1])
  robust_direction <- any(robust_available & vapply(robust_beta, same_sign, logical(1), b = discovery$beta[1]))
  steiger_d <- steiger_gate(discovery, alpha); steiger_v <- steiger_gate(validation, alpha)
  steiger <- steiger_d$pass && steiger_v$pass
  pleio_d <- pleiotropy_gate(discovery, discovery$beta[1], alpha)
  pleio_v <- pleiotropy_gate(validation, validation$beta[1], alpha)
  pleiotropy <- pleio_d$pass && pleio_v$pass
  gates <- c(discovery_fdr, validation_overlap, validation_effect, robust_direction, steiger, pleiotropy)
  reasons <- c(
    if (discovery_fdr) "" else "Discovery is not forward-primary BH q < 0.05",
    if (validation_overlap) "" else "Validation overlap class is not none_known",
    if (validation_effect) "" else "Validation sign, two-sided P, or directional CI gate failed",
    if (robust_direction) "" else "No estimable weighted-median or MR-RAPS estimate matches the primary sign",
    paste(c(steiger_d$reason, steiger_v$reason)[nzchar(c(steiger_d$reason, steiger_v$reason))], collapse = "; "),
    paste(c(pleio_d$reason, pleio_v$reason)[nzchar(c(pleio_d$reason, pleio_v$reason))], collapse = "; ")
  )
  replicated <- all(gates)
  data.frame(
    replicated = replicated,
    discovery_fdr_gate = discovery_fdr, discovery_fdr_reason = reasons[1],
    validation_overlap_gate = validation_overlap, validation_overlap_reason = reasons[2],
    validation_effect_gate = validation_effect, validation_effect_reason = reasons[3],
    robust_direction_gate = robust_direction, robust_direction_reason = reasons[4],
    steiger_gate = steiger, steiger_reason = reasons[5],
    pleiotropy_gate = pleiotropy, pleiotropy_reason = reasons[6],
    reasons = paste(reasons[nzchar(reasons)], collapse = "; "),
    grade = if (overlap %in% c("known", "possible")) "sensitivity_only" else if (replicated) "replicated" else "not_replicated"
  )
}
grade_evidence <- function(x) {
  eligible <- !is.na(x$eligible) & x$eligible
  estimable <- eligible & !is.na(x$analysis_status) & x$analysis_status == "estimated" & is.finite(x$p)
  reverse <- !is.na(x$family) & x$family == "reverse"
  replicated <- !is.na(x$replicated) & x$replicated
  primary_tier <- !is.na(x$tier) & x$tier == "primary"
  bonferroni <- !is.na(x$bonferroni_pass) & x$bonferroni_pass
  label <- ifelse(
    !estimable,
    "insufficient",
    ifelse(
      reverse,
      "exploratory",
      ifelse(!primary_tier | !replicated, "exploratory", ifelse(bonferroni, "strict", "primary"))
    )
  )
  data.frame(
    evidence_label = label,
    analysis_role = ifelse(reverse, "reverse_sensitivity", "forward_causal"),
    stringsAsFactors = FALSE
  )
}
```

- [ ] **Step 3: Build the cross-dataset matrix and final grades**

Rows are microbial traits; columns are Swedish discovery EUR, independent HUNT exposure replication, high-power EUR meta, AFR, cross-ancestry, and FinnGen sensitivity. HUNT is the primary independent exposure-replication path. FinnGen cannot independently validate the 2025 ED meta-analysis because that meta-analysis includes FinnGen; the `ed_2025` to `finngen_r12` pair is `known` overlap and sensitivity-only. Each cell stores effect, CI, P, q, nsnp, overlap class, every gate boolean/reason, and status. Only overlap class exactly `none_known` can support replication; `known` and `possible` are sensitivity-only.

`build_replication_matrix()` consumes `05_results/tables/mr_multiplicity.csv` and applies independent-replication gates only to forward rows. After gate evaluation, `finalize_grades()` joins the gate output back to every multiplicity row and writes `05_results/tables/mr_graded.csv`: `insufficient` is reserved for ineligible or non-estimable primary effects; every estimable eligible reverse row is `exploratory` with `analysis_role = reverse_sensitivity` even when `replicated` is missing; every estimable eligible forward exploratory-tier row or forward row failing any Primary replication gate is `exploratory`; only forward primary-tier estimable rows passing all gates are `primary`, or `strict` when they also pass the combined Bonferroni threshold.

- [ ] **Step 4: Test and generate**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-replication.R")'
/opt/homebrew/bin/Rscript -e 'source("R/replication.R"); build_replication_matrix("05_results/tables/mr_multiplicity.csv", "05_results/tables/replication_matrix.csv"); finalize_grades("05_results/tables/mr_multiplicity.csv", "05_results/tables/replication_matrix.csv", "05_results/tables/mr_graded.csv")'
```

- [ ] **Step 5: Commit**

```bash
git add R/replication.R tests/testthat/test-replication.R
git commit -m 'feat: enforce replication gates and finalize evidence grades'
```

### Task 12: Run colocalization on replicated candidates

**Files:**
- Create: `R/coloc.R`
- Create: `tests/testthat/test-coloc.R`
- Generate: `05_results/tables/coloc_results.csv`

- [ ] **Step 1: Write regional-input tests**

```r
source("R/coloc.R")
test_that("coloc input requires aligned variants and variance", {
  x <- data.frame(snp = c("a", "b"), beta = c(.1, .2), se = c(.02, .03), eaf = c(.2, .3), n = c(1000, 1000))
  d <- coloc_dataset(x, type = "quant")
  expect_equal(d$varbeta, x$se^2)
  expect_equal(d$type, "quant")
})
test_that("PP4 support uses the prespecified threshold", {
  expect_true(coloc_supported(c(PP.H4.abf = .81), .80))
  expect_false(coloc_supported(c(PP.H4.abf = .79), .80))
})
```

- [ ] **Step 2: Implement regional assembly**

For each replicated lead SNP, extract ±500 kb from complete exposure/outcome GWAS, intersect variants, align alleles, remove MAF < 0.01, and require at least 50 shared variants. Record region size and variant count. `run_candidate_coloc()` must process only candidates marked replicated by the rule engine and return a `not_testable` row for every candidate that lacks adequate regional data.

```r
# R/coloc.R
coloc_dataset <- function(x, type, s = NULL) {
  out <- list(beta = x$beta, varbeta = x$se^2, snp = x$snp, MAF = x$eaf, N = unique(x$n), type = type)
  if (type == "cc") out$s <- s
  out
}
coloc_supported <- function(summary, threshold = 0.80) {
  isTRUE(unname(summary["PP.H4.abf"]) >= threshold)
}
```

- [ ] **Step 3: Implement `coloc.abf`**

Use configured priors `p1=1e-4`, `p2=1e-4`, `p12=1e-5`. Store PP0–PP4 and mark support only when PP4 ≥ 0.80. If regional data are incomplete, set `status = "not_testable"`, never `failed` or `supported`.

- [ ] **Step 4: Test and run candidates only**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-coloc.R")'
/opt/homebrew/bin/Rscript -e 'source("R/coloc.R"); run_candidate_coloc("05_results/tables/replication_matrix.csv", "05_results/tables/coloc_results.csv")'
```

- [ ] **Step 5: Commit**

```bash
git add R/coloc.R tests/testthat/test-coloc.R
git commit -m 'feat: add candidate colocalization gate'
```

### Task 13: Run prespecified MVMR only for replicated candidates

**Files:**
- Create: `R/mvmr.R`
- Create: `tests/testthat/test-mvmr.R`
- Generate: `05_results/tables/mvmr_results.csv`

- [ ] **Step 1: Write gating tests**

```r
source("R/mvmr.R")
test_that("MVMR blocks weak conditional instruments", {
  expect_equal(mvmr_gate(c(8, 15), min_f = 10), "blocked_weak_instruments")
  expect_equal(mvmr_gate(c(12, 15), min_f = 10), "eligible")
})
```

- [ ] **Step 2: Implement `mvmr_gate()` and covariance audit**

```r
# R/mvmr.R
mvmr_gate <- function(conditional_f, min_f = 10) if (any(!is.finite(conditional_f) | conditional_f <= min_f)) "blocked_weak_instruments" else "eligible"
```

The module must also stop when exposure correlation is ≥0.90 or required covariance cannot be estimated.

- [ ] **Step 3: Implement BMI/T2D/CAD models**

For each replicated microbial feature, run three separately justified models and one combined model only if strength/correlation gates pass. Report conditional F, Q-statistic, direct effect, CI, P, and comparison with univariable MR. `run_candidate_mvmr()` must preserve blocked models as rows with a specific gate reason.

- [ ] **Step 4: Test and run**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-mvmr.R")'
/opt/homebrew/bin/Rscript -e 'source("R/mvmr.R"); run_candidate_mvmr("05_results/tables/replication_matrix.csv", "05_results/tables/mvmr_results.csv")'
```

- [ ] **Step 5: Commit**

```bash
git add R/mvmr.R tests/testthat/test-mvmr.R
git commit -m 'feat: add strength-gated MVMR analyses'
```

### Task 14: Assemble the `targets` pipeline and end-to-end smoke test

**Files:**
- Create: `_targets.R`
- Create: `scripts/03_run_pipeline.R`
- Create: `tests/testthat/test-pipeline-smoke.R`
- Generate: `08_qc/session_info.txt`

- [ ] **Step 1: Write a fixture-only smoke test**

```r
test_that("fixture pipeline creates graded and replication outputs", {
  Sys.setenv(GUT_ED_PROFILE = "fixture")
  targets::tar_make(callr_function = NULL)
  expect_true(file.exists("05_results/tables/mr_multiplicity.csv"))
  expect_true(file.exists("05_results/tables/mr_graded.csv"))
  expect_true(file.exists("05_results/tables/replication_matrix.csv"))
})
```

- [ ] **Step 2: Define `_targets.R` as orchestration only**

Targets must follow this dependency order:

```text
config -> source inventory -> receipts -> normalized GWAS -> instruments -> harmonized pairs -> MR -> multiplicity -> replication -> final grading -> coloc -> MVMR -> reporting -> QC
```

Use dynamic branching by microbial trait and outcome dataset. Set resource limits so one failed branch does not erase completed branches.

- [ ] **Step 3: Implement the runner**

```r
# scripts/03_run_pipeline.R
options(repos = c(MRCIEU = "https://mrcieu.r-universe.dev", CRAN = "https://cloud.r-project.org"))
renv::restore(prompt = FALSE)
targets::tar_make()
dir.create("08_qc", recursive = TRUE, showWarnings = FALSE)
writeLines(capture.output(sessionInfo()), "08_qc/session_info.txt")
```

- [ ] **Step 4: Run fixture and full unit suite**

```bash
GUT_ED_PROFILE=fixture /opt/homebrew/bin/Rscript -e 'testthat::test_dir("tests/testthat")'
```

Expected: all tests PASS and fixture outputs exist.

- [ ] **Step 5: Commit**

```bash
git add _targets.R scripts/03_run_pipeline.R tests/testthat/test-pipeline-smoke.R
git commit -m 'feat: assemble reproducible MR targets pipeline'
```

### Task 15: Generate tables, figures, claim–evidence map, and go/no-go report

**Files:**
- Create: `R/reporting.R`
- Create: `reports/go_no_go.qmd`
- Create: `reports/analysis_report.qmd`
- Create: `tests/testthat/test-reporting.R`
- Generate: `05_results/tables/main_results.csv`
- Generate: `05_results/figures/*.pdf`
- Generate: `08_qc/claim_evidence_map.csv`
- Generate: `08_qc/go_no_go_report.html`

- [ ] **Step 1: Write reporting integrity tests**

```r
source("R/reporting.R")
test_that("main results contain only primary or strict evidence", {
  x <- data.frame(trait = c("a", "b"), grade = c("primary", "exploratory"))
  expect_equal(select_main_results(x)$trait, "a")
})
test_that("claim map has evidence and boundary", {
  x <- build_claim_map(data.frame(trait = "a", grade = "primary", beta = .1, p = .001, q = .02))
  expect_true(all(c("claim", "evidence", "status", "boundary") %in% names(x)))
})
```

- [ ] **Step 2: Implement deterministic result selection**

```r
# R/reporting.R
select_main_results <- function(x) subset(x, grade %in% c("primary", "strict"))
build_claim_map <- function(x) transform(
  x,
  claim = paste("Genetically predicted", trait, "is associated with ED risk"),
  evidence = sprintf("beta=%.3f; p=%.3g; q=%.3g", beta, p, q),
  status = grade,
  boundary = "MR evidence; not a direct treatment effect"
)
reporting_value_dictionary <- function(tables_dir) {
  x <- read.csv(file.path(tables_dir, "main_results.csv"), stringsAsFactors = FALSE)
  data.frame(
    trait = x$trait,
    effect = sprintf("%.2f (%.2f-%.2f)", x$or, x$or_lci95, x$or_uci95),
    p_text = format(x$p, scientific = TRUE, digits = 3),
    q_text = format(x$q, scientific = TRUE, digits = 3)
  )
}
extract_docx_text <- function(docx_path) {
  td <- tempfile(); dir.create(td)
  unzip(docx_path, files = "word/document.xml", exdir = td)
  xml2::xml_text(xml2::read_xml(file.path(td, "word/document.xml")))
}
verify_manuscript_numbers <- function(docx_path, tables_dir) {
  stopifnot(file.exists(docx_path), dir.exists(tables_dir))
  expected <- reporting_value_dictionary(tables_dir)
  observed <- extract_docx_text(docx_path)
  tokens <- unique(unlist(expected[c("effect", "p_text", "q_text")], use.names = FALSE))
  missing <- tokens[!vapply(tokens, grepl, logical(1), x = observed, fixed = TRUE)]
  if (length(missing)) stop("Unmatched manuscript values: ", paste(missing, collapse = ", "))
  TRUE
}
```

- [ ] **Step 3: Generate publication figures**

Create: study flow diagram, all-trait volcano/Manhattan-style evidence plot, replicated-candidate forest plot, sensitivity panels, and coloc regional plots. All plots must be colorblind-safe, vector PDF/SVG, and derived directly from CSV outputs.

- [ ] **Step 4: Render reports and evaluate the gate**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-reporting.R")'
quarto render reports/go_no_go.qmd --to html
quarto render reports/analysis_report.qmd --to html
```

Expected: the report states exactly one of `GO`, `CONDITIONAL GO`, or `NO-GO`, with machine-verifiable reasons.

- [ ] **Step 5: Commit generated small artifacts and reporting code**

```bash
git add R/reporting.R reports tests/testthat/test-reporting.R 05_results/tables 08_qc/claim_evidence_map.csv
git commit -m 'feat: generate evidence-graded analysis reports'
```

### Task 16: Produce the manuscript package only if the gate is GO/CONDITIONAL GO

**Files:**
- Create: `06_manuscript/manuscript.qmd`
- Create: `06_manuscript/supplement.qmd`
- Create: `06_manuscript/STROBE_MR_checklist.docx`
- Create: `07_submission/cover_letter.docx`
- Create: `08_qc/manuscript_consistency.md`
- Generate: `06_manuscript/gut_ed_mr_rebuild_v01.docx`

- [ ] **Step 1: Assert the gate before authoring**

Run:

```bash
/opt/homebrew/bin/Rscript -e 'x <- jsonlite::read_json("08_qc/go_no_go.json"); stopifnot(x$decision %in% c("GO", "CONDITIONAL GO"))'
```

Expected: PASS. If it fails, skip the remainder of this task and finalize the no-go package.

- [ ] **Step 2: Build the manuscript from frozen results**

Use the section architecture:

```text
Title -> Structured abstract -> Introduction -> Methods -> Results -> Discussion -> Data/Code availability -> Declarations -> References
```

Every numeric statement must be inserted from generated result files; no manual retyping of ORs, CIs, P values, q values, sample sizes, or instrument counts.

- [ ] **Step 3: Build supplement and STROBE-MR checklist**

The supplement must include source metadata, all tested traits, complete MR estimates, instrument lists, exclusions, sensitivity results, replication matrix, coloc, MVMR, and software/session information.

- [ ] **Step 4: Render and visually inspect the DOCX**

Run the document-skill renderer and inspect every page at 100% zoom. Check clipped tables, figure resolution, heading hierarchy, references, and correspondence between captions and files. Record the pass/fail findings in `08_qc/manuscript_consistency.md`.

- [ ] **Step 5: Run final consistency tests and commit**

```bash
/opt/homebrew/bin/Rscript -e 'source("R/reporting.R"); verify_manuscript_numbers("06_manuscript/gut_ed_mr_rebuild_v01.docx", "05_results/tables")'
git add 06_manuscript 07_submission 08_qc/manuscript_consistency.md
git commit -m 'docs: build evidence-linked manuscript package'
```

Expected: no unmatched numeric claim, no placeholder, and clean rendered pages.

### Task 17: Final verification and brain-project handoff

**Files:**
- Create: `08_qc/final_verification.md`
- Create: `00_admin/handoff_brain_ed.md`

- [ ] **Step 1: Run the complete verification suite**

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_dir("tests/testthat")'
/opt/homebrew/bin/Rscript -e 'targets::tar_make()'
git status --short
```

Expected: all tests PASS, `tar_make()` reports no outdated targets, and Git shows only intentionally generated ignored large files.

- [ ] **Step 2: Verify provenance and raw immutability**

```bash
/opt/homebrew/bin/Rscript -e 'source("R/provenance.R"); inventory <- read_source_inventory_csv("00_admin/source_inventory.csv"); manifest <- read_manifest_csv("MANIFEST.csv"); stopifnot(verify_manifest(manifest, inventory, getwd()), all(vapply(file.path(getwd(), manifest$path), validate_frozen_file, logical(1))))'
```

Expected: manifest verification PASS and every raw GWAS file has either verified no-write bits or verified `uchg`.

- [ ] **Step 3: Write final verification evidence**

Record test counts, Git commit, `targets` status, manifest hash, go/no-go decision, delivered files, and any access-blocked dataset in `08_qc/final_verification.md`.

- [ ] **Step 4: Write the brain-project handoff without starting analysis**

`00_admin/handoff_brain_ed.md` must list the rs-fMRI source, ED outcome overlap risk, strict instrument threshold, 191×2 correction requirement, 2026 competing paper, and the condition for writing a separate design spec.

- [ ] **Step 5: Commit and tag the audited checkpoint**

```bash
git add 08_qc/final_verification.md 00_admin/handoff_brain_ed.md
git commit -m 'chore: verify gut ED MR rebuild checkpoint'
git tag -a gut-ed-mr-go-no-go-v1 -m 'Audited gut microbiome ED MR go/no-go checkpoint'
```

Expected: an annotated tag pointing to the verified checkpoint.
