# Gut microbiome–ED MR rebuild

Primary command: `Rscript scripts/03_run_pipeline.R`.

Evidence grades:
- Primary: genome-wide (`P < 5×10⁻⁸`) instruments with F > 10, forward BH q < 0.05, all deterministic replication gates defined in `01_protocol/analysis_decisions.md`, and independent validation.
- Strict: Primary plus combined-direction global Bonferroni significance.
- Exploratory: any estimable eligible candidate that uses relaxed instruments (`P < 1×10⁻⁵`) or fails any Primary replication gate; never described with confirmed causal language.
- Insufficient: only an ineligible hypothesis or a hypothesis whose primary effect could not be estimated.

Reverse ED→microbiome analyses are a separate sensitivity family: estimable eligible rows are always Exploratory, ineligible or non-estimable rows are Insufficient, and all carry `analysis_role = reverse_sensitivity`.

Raw GWAS files are immutable and excluded from Git. Every input is recorded in `MANIFEST.csv` with source, version, size, and SHA-256.

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
