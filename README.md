# Gut microbiome–ED MR rebuild

Primary command: `Rscript scripts/03_run_pipeline.R`.

Evidence grades:
- Primary: genome-wide (`P < 5×10⁻⁸`) instruments with F > 10, forward BH q < 0.05, all deterministic replication gates defined in `01_protocol/analysis_decisions.md`, and independent validation.
- Strict: Primary plus combined-direction global Bonferroni significance.
- Exploratory: any estimable eligible candidate that uses relaxed instruments (`P < 1×10⁻⁵`) or fails any Primary replication gate; never described with confirmed causal language.
- Insufficient: only an ineligible hypothesis or a hypothesis whose primary effect could not be estimated.

Reverse ED→microbiome analyses are a separate sensitivity family: estimable eligible rows are always Exploratory, ineligible or non-estimable rows are Insufficient, and all carry `analysis_role = reverse_sensitivity`.

Raw GWAS files are immutable and excluded from Git. The freeze is verified from effective no-write mode bits where the filesystem supports them, or from the macOS `uchg` flag on `noowners`/exFAT volumes. AppleDouble `._*` sidecars inside ignored raw paths may be required to persist those flags; pipeline code must never ingest or delete them as GWAS payloads. Every input is recorded in the exact nine-column `MANIFEST.csv` with source, version, size, and SHA-256.

## Download, resume, and full verification

`scripts/02_download_freeze.R` resumes safe smaller `.part` files and promotes an already complete checksum-valid partial without another HTTP request. Each atomic manifest append structurally validates the full ledger but content-verifies only newly added receipt rows, avoiding quadratic rehashing.

curl retains its built-in `--retry 5` handling for default transient failures. In addition, the R download layer treats only curl status 18 (an incomplete transfer) as automatically recoverable: it validates that the `.part` remains a non-symlink regular file of a safe size, keeps it writable, and makes at most three extra `--continue-at -` attempts with a one-second delay. A complete valid file is promoted even if curl reported 18; corrupt, oversized, or unsafe partials stop immediately. Permanent HTTP status 22 is not retried by the R layer. Retry logs and terminal errors report the curl status and attempt count.

After all dataset download commands in one completed bulk batch, run one explicit full-file verification:

```bash
/opt/homebrew/bin/Rscript -e 'source("R/provenance.R"); inventory <- read_source_inventory_csv("00_admin/source_inventory.csv"); manifest <- read_manifest_csv("MANIFEST.csv"); stopifnot(verify_manifest(manifest, inventory, getwd(), verify_files = TRUE))'
```

This command intentionally reads every frozen payload twice: once for the local SHA-256 receipt and once for the upstream MD5 checksum. Run it once after the completed bulk batch; do not repeat it after each receipt or dataset append.

`01_protocol/analysis_decisions.md` is the normative operational source; the README, configuration, and rule engine must not weaken it.

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

Git metadata is stored externally at `/Users/duxiancheng/.codex/gitdirs/04_GUT_ED_MR_REBUILD_20260710.git` because this external volume emits AppleDouble sidecars. Normal Git commands continue to work from the project root.
