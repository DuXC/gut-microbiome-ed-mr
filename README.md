# Gut microbiome–ED MR rebuild

This repository contains the reproducible code, provenance records, frozen
summary results, and manuscript package for an error-controlled bidirectional
Mendelian-randomization study of gut microbial traits and erectile dysfunction.
Third-party GWAS payloads are intentionally excluded; source accessions, URLs,
and cryptographic receipts are retained so authorized users can reconstruct the
analysis.

Citation metadata are provided in `CITATION.cff`, and the public-release scope
is defined in `LICENSE.md`. Code is MIT-licensed; original documentation,
figures, and derived research artifacts are CC BY 4.0. Third-party source terms
continue to apply to external data.

Public repository: https://github.com/DuXC/gut-microbiome-ed-mr

The numbered scripts are the reproducible entry points. There is deliberately
no stale monolithic wrapper: run only the stage whose prerequisite receipts are
already complete, in the order documented below.

Evidence grades:
- Primary: genome-wide (`P < 5×10⁻⁸`) instruments with F > 10, forward BH q < 0.05, all deterministic replication gates defined in `01_protocol/analysis_decisions.md`, and independent validation.
- Strict: Primary plus combined-direction global Bonferroni significance.
- Exploratory: any estimable eligible candidate that uses relaxed instruments (`P < 1×10⁻⁵`) or fails any Primary replication gate; never described with confirmed causal language.
- Insufficient: only an ineligible hypothesis or a hypothesis whose primary effect could not be estimated.

Reverse ED→microbiome analyses are a separate sensitivity family: estimable eligible rows are always Exploratory, ineligible or non-estimable rows are Insufficient, and all carry `analysis_role = reverse_sensitivity`.

Raw GWAS files are immutable and excluded from Git. The freeze is verified from effective no-write mode bits where the filesystem supports them, or from the macOS `uchg` flag on `noowners`/exFAT volumes. AppleDouble `._*` sidecars inside ignored raw paths may be required to persist those flags; pipeline code must never ingest or delete them as GWAS payloads. Every input is recorded in the exact nine-column `MANIFEST.csv` with source, version, size, and SHA-256.

Since 2026-07-20 the project is hosted at the same absolute path on the NAS SMB
share `DuXC_PhD_OS`. SMB does not expose the prior exFAT no-write/`uchg`
semantics reliably, so local mode bits are not accepted as an integrity claim on
the NAS. The versioned `MANIFEST.csv`, its recorded SHA-256 values, upstream MD5
checksums, and the rule that analysis never writes under `03_data/raw/` are the
authoritative integrity boundary. Content verification on this SMB share must
use `verify_frozen = FALSE` only after SHA-256 and upstream checksum validation;
it must never skip content hashes merely because a path exists.

## Download, resume, and full verification

`scripts/02_download_freeze.R` resumes safe smaller `.part` files and promotes an already complete checksum-valid partial without another HTTP request. Each atomic manifest append structurally validates the full ledger but content-verifies only newly added receipt rows, avoiding quadratic rehashing.

curl retains its built-in `--retry 5` handling for default transient failures. A connection must be established within 30 seconds, and a transfer sustained below 32 KiB/s for 120 seconds is treated as stalled so curl can reconnect instead of hanging indefinitely. In addition, the R download layer treats only curl status 18 (an incomplete transfer) as automatically recoverable: it validates that the `.part` remains a non-symlink regular file of a safe size, keeps it writable, and makes at most three extra `--continue-at -` attempts with a one-second delay. A complete valid file is promoted even if curl reported 18; corrupt, oversized, or unsafe partials stop immediately. Permanent HTTP status 22 is not retried by the R layer. Retry logs and terminal errors report the curl status and attempt count.

After all dataset download commands in one completed bulk batch, run one explicit full-file verification:

```bash
/opt/homebrew/bin/Rscript -e 'source("R/provenance.R"); inventory <- read_source_inventory_csv("00_admin/source_inventory.csv"); manifest <- read_manifest_csv("MANIFEST.csv"); stopifnot(verify_manifest(manifest, inventory, getwd(), verify_files = TRUE))'
```

This command intentionally reads every frozen payload twice: once for the local SHA-256 receipt and once for the upstream MD5 checksum. Run it once after the completed bulk batch; do not repeat it after each receipt or dataset append.

## Persistent macOS download supervisor

The checked-in LaunchAgent template `00_admin/com.duxiancheng.gut-ed-download.plist` runs `scripts/02_download_supervisor.R` independently of Codex and Terminal sessions. It waits for a live downloader instead of competing for the lock, reclaims only a dead lock, retries 30 seconds after abnormal exit, completes `microbiome_2026` before `microbiome_2026_hunt`, performs one final full-file verification, and stops after a successful exit. `/usr/bin/caffeinate -ims` prevents idle system and disk sleep while leaving display sleep available.

The installed user agent is `~/Library/LaunchAgents/com.duxiancheng.gut-ed-download.plist`. Inspect it with:

```bash
launchctl print gui/$(id -u)/com.duxiancheng.gut-ed-download
tail -f ~/Library/Logs/gut-ed-download.stderr.log
```

The logs live on the internal APFS volume because launchd cannot open its standard streams directly on this external exFAT project path.

`01_protocol/analysis_decisions.md` is the normative operational source; the README, configuration, and rule engine must not weaken it.

## Current exposure-candidate stage

The complete Swedish and HUNT exposure files remain compressed and immutable.
The analysis streams each payload once and retains the prespecified exploratory
superset (`P < 1×10⁻⁵`) as compact Parquet shards; it does not create multi-TB
fully decompressed copies. The batch is restartable from manifest-bound,
SHA-256-verified shard receipts and uses four workers by default:

```bash
MR_WORKERS=4 MR_SHARD_SIZE=16 /usr/bin/caffeinate -ims /opt/homebrew/bin/Rscript scripts/03_extract_exposure_candidates.R
```

The cached metadata catalog and each shard receipt are bound to the SHA-256 of
both `MANIFEST.csv` and `R/gwas_schema.R`; individual payload existence and
validity are then checked when each accession is opened. This avoids thousands
of redundant SMB metadata calls at every restart without reusing results after
an input-ledger or normalization-code change.

Per-accession sample sizes and trait descriptions come from the matching GWAS
Catalog YAML. Exact Swedish–HUNT biological-label matches are audited in
`08_qc/exposure_replication_map.csv`; unmatched hMGS labels are not treated as
replicated without the study's hMGS-to-genome crosswalk.

## Ancestry-matched instrument construction

Exposure clumping is performed on the exposures' native GRCh37 coordinates;
the project-wide GRCh38 setting governs the downstream outcome/harmonisation
layer and does not authorize mixing builds during LD estimation. The primary LD
source is the official PLINK 2 1000 Genomes Phase 3 GRCh37 release. Its source
files and checksums are recorded in
`08_qc/high_density_ld_source_receipts.csv`.

`scripts/04_prepare_ld_reference.sh` normalizes chromosome labels (`23`/`X`),
selects 503 EUR samples, rejects multiallelic/non-ACGT variants and missing
reference IDs, and creates a candidate-only 171,720-variant BED reference. Run
it only when the candidate set or reference source changes. Then build both
prespecified instrument tiers with:

```bash
MR_WORKERS=8 /usr/bin/caffeinate -ims /opt/homebrew/bin/Rscript scripts/04_build_instruments.R
```

The completed inventory contains separate primary and exploratory rows for all
2,581 exposure traits. Clumping uses `r² = 0.001` within 10,000 kb and retains
only instruments with F > 10. The run receipt binds the PLINK version,
reference-panel hashes, mapping-file hash, inventory hash, and instrument
Parquet hash. Unmapped primary variants remain visible in
`08_qc/ld_reference_unmapped_primary.csv`; they are never silently substituted.

## Outcome assembly and harmonisation

The eight Figshare byte-range parts are intentional chunks, not independent
gzip files. Reassemble and gzip-test the three complete ED 2025 streams, then
extract only the clumped reference IDs together with FinnGen R12:

```bash
/opt/homebrew/bin/Rscript scripts/05_assemble_outcomes.R
MR_WORKERS=4 /usr/bin/caffeinate -ims /opt/homebrew/bin/Rscript scripts/06_extract_outcome_candidates.R
```

FinnGen is the primary log-odds outcome. The ED 2025 files contain METAL Z
scores and weights, so their sensitivity estimates remain on the declared
standardized `Z / sqrt(Weight)` scale and are not presented as odds ratios.
FinnGen's multiallelic rsIDs remain as allele-specific records until exposure
alleles select a unique row.

Harmonisation uses rsID plus allele identity across the declared GRCh37/GRCh38
builds, with chromosome concordance checked independently. Palindromic variants
require MAF at most 0.42 in both datasets and a uniquely concordant effect-allele
frequency within 0.10:

```bash
/usr/bin/caffeinate -ims /opt/homebrew/bin/Rscript scripts/07_harmonise_datasets.R
```

The compact summary and hash receipt is
`08_qc/harmonisation_inventory.csv`; the row-level audit is a compressed,
generated Parquet artifact under `03_data/processed/harmonised/`.

## Forward MR and frozen multiplicity

Run the prespecified estimators in eight independent R sessions; PSOCK is used
because forking an Arrow-loaded process is unsafe on macOS:

```bash
MR_WORKERS=8 /usr/bin/caffeinate -ims /opt/homebrew/bin/Rscript scripts/08_run_mr.R
/opt/homebrew/bin/Rscript scripts/09_apply_forward_multiplicity.R
```

The primary estimator is the Wald ratio for one SNP and constrained
multiplicative random-effects IVW for multiple SNPs. The IVW residual scale is
never allowed below one. Weighted-median bootstraps use deterministic pair-level
seeds; MR-RAPS non-convergence and multiple-root warnings are failures, not
silent estimates. The run receipt records code, input, and output hashes in
`08_qc/mr_run_receipt.csv`.

The currently frozen FinnGen forward-primary family contains 230 Swedish
microbiome traits. Of these, 218 were estimable and seven had nominal
`P < 0.05`; none survived BH FDR (`q < 0.05`, minimum `q = 0.942`). The two
nominal candidates with exact HUNT trait matches did not validate (`P = 0.427`
and `P = 0.175`).

## Reverse MR and final decision

The reverse exposure is the 2025 EUR ED meta-analysis on its declared
standardized `Z / sqrt(Weight)` scale. Of 479 genome-wide-significant variants,
437 mapped by rsID, chromosome, and alleles to the 503-sample EUR LD panel; LD
clumping retained 24 independent instruments (`r² = 0.001`, 10,000 kb; minimum
F = 30.21). Run the restartable outcome extraction, reverse analysis, and final
decision in order:

```bash
MR_WORKERS=8 /usr/bin/caffeinate -ims /opt/homebrew/bin/Rscript scripts/10_build_reverse_ed_instruments.R
MR_WORKERS=8 /usr/bin/caffeinate -ims /opt/homebrew/bin/Rscript scripts/11_extract_reverse_microbiome_outcomes.R
MR_WORKERS=8 /usr/bin/caffeinate -ims /opt/homebrew/bin/Rscript scripts/12_run_reverse_analysis.R
/opt/homebrew/bin/Rscript scripts/13_finalize_analysis.R
```

The extractor accepts both compressed `.tsv.gz` and uncompressed `.tsv`
accessions, propagates upstream pipe failures, records one hash-bound receipt
per trait, and uses one-accession dynamic scheduling so interrupted tail work
continues across all workers. It recovered 26,366 candidate rows from all 1,572
Swedish traits. Harmonisation retained 24,794 rows (15--17 instruments per
trait), excluded one frequency-unresolvable palindromic instrument per trait,
and found no allele mismatches.

All 1,572 reverse primary effects were estimable. Seventy-seven had nominal
`P < 0.05`, but none survived the frozen reverse BH family (minimum
`P = 0.001861`; minimum `q = 0.967`). The combined family therefore contains
230 forward and 1,572 reverse tests, with a global Bonferroni threshold of
`2.774695×10⁻⁵`. No forward or reverse effect passed its direction-specific
FDR, no forward signal met the independent-replication gates, and the frozen
decision is `NO-GO`. The one-row decision and all upstream/output hashes are in
`08_qc/final_analysis_receipt.csv`.

## Reproducible environment

Restore the exact locked R environment and ensure the pinned project-local PLINK binary:

```bash
/opt/homebrew/bin/Rscript scripts/00_bootstrap.R
```

Deliberately refresh dependencies only when updating the lockfile:

```bash
/opt/homebrew/bin/Rscript scripts/00_bootstrap.R --refresh-lock
```

Refresh mode intentionally changes `renv.lock`; review and commit that diff. Normal bootstrap mode restores from the existing lockfile and must not change it.

Run the environment and toolchain checks with:

```bash
/opt/homebrew/bin/Rscript -e 'testthat::test_file("tests/testthat/test-environment.R", stop_on_failure = TRUE)'
/opt/homebrew/bin/Rscript -e 'source("R/toolchain.R"); verify_plink()'
quarto --version
```

## Repository metadata

Git metadata is stored externally at `/Users/duxiancheng/.codex/gitdirs/04_GUT_ED_MR_REBUILD_20260710.git` because the project volume emits AppleDouble sidecars. Normal Git commands continue to work from the project root on the NAS.

## IJIR manuscript package

The frozen NO-GO decision for a positive causal claim has been preserved. A
separate transparent-negative manuscript package was built on 2026-07-20 under
`06_manuscript/ijir_v0_1_20260720/`. It contains the main manuscript, title
page, cover letter, STROBE-MR checklist, two editable main-table workbooks, two
600-dpi figures, and a ten-sheet supplementary data workbook. The package is
author-confirmation ready; see its `07_qc/IJIR_v0_1_QC_Report.md` and
`01_sources/AUTHOR_CONFIRMATION_REQUIRED_v0_1.md` before submission.
