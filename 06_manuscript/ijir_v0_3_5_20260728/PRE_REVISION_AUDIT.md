# IJIR pre-revision audit

Audit date: 2026-07-28 (Asia/Shanghai)  
Target journal: *International Journal of Impotence Research*  
Working revision root: `06_manuscript/ijir_v0_3_5_20260728`  
Baseline editable package: `06_manuscript/ijir_v0_3_4_20260724`  
Baseline reviewer PDF: `00_baseline/IJIR-07-2026-398_merged_reviewer_QC_20260728.pdf`  
Baseline reviewer-PDF SHA-256: `717d342ecf7ad58ace9d896966ca4b7ce86b1d14426b3166ab5cc8bd29686c45`

## Reversible checkpoint

- Repository commit at audit start: `be03599afbb836900c1a697cb41b473f8185babb`.
- Branch at audit start: `revision/v0.3-pre-submission`.
- The repository already contained tracked modifications and untracked v0.3.1-v0.3.4 analysis/manuscript assets. Those pre-existing changes were not committed, reset, or overwritten.
- A separate working copy was created at `06_manuscript/ijir_v0_3_5_20260728`. The v0.3.4 package and the reviewer PDF remain unchanged.
- Frozen primary outputs remain in `05_results/v0_3_20260722`. New checks and derived audits will be written to a new versioned results directory.

## Locked numerical results at revision start

| Analysis | Frozen result |
|---|---:|
| Forward eligible traits | 230 |
| Forward estimable traits | 218 |
| Forward nominal trait rows | 7 |
| Primary forward associations surviving FDR correction | 0 |
| Reverse tests | 1 572 |
| Reverse nominal trait rows | 77 |
| Reverse associations surviving FDR correction | 0 |
| HUNT exact-label rows | 97 |
| Unique Swedish lead rsIDs in HUNT evaluation | 90 |
| Direction-concordant HUNT trait rows | 76/97 |
| Direction-concordant unique rsIDs | 69/90 |
| European 2025 outcome-sensitivity FDR rows | 8 |
| Cross-ancestry 2025 outcome-sensitivity FDR rows | 8 |
| African-ancestry 2025 outcome-sensitivity FDR rows | 0 |
| Alternative-outcome compression | 8 rows -> 3 high-LD SNPs -> 1 chr2q21 region |
| Median 80%-power MDE at alpha=0.05/230 | OR 2.89 per standardized exposure unit |
| Mechanistic screening associations surviving FDR correction | 0 |

These numbers are not authorized to change unless a scripted rerun demonstrates a genuine error. Any change must be documented with old value, new value, reason, affected files, and scientific impact.

## Source and analysis inventory

### Manuscript and submission sources

- Main manuscript source: `01_sources/IJIR_Main_Manuscript_v0_3_4.md`
- Title-page source: `01_sources/IJIR_Title_Page_v0_3_4.md`
- Cover-letter source: `01_sources/IJIR_Cover_Letter_v0_3_4.md`
- Author metadata: `01_sources/author_metadata_IJIR_v0_3_4.csv`
- STROBE-MR locations: `01_sources/STROBE_MR_locations_v0_3_4.csv`
- Document builder: `02_builder/build_ijir_documents_v0_3_4.py`
- Combined-article builder: `09_submission_portal/build_combined_article.py`
- Current editable DOCX files: `03_submission_files/`
- Current portal receipt: `09_submission_portal/PORTAL_SUBMISSION_RECEIPT_IJIR-07-2026-398.md`

### Tables, figures, and supplement

- Table source data: `02_builder/tmp_table_data/main_table_1.json`, `main_table_2.json`, and associated note files
- Workbook builder: `02_builder/build_ijir_workbooks_v0_3_4.mjs`
- Main table workbooks: `05_tables/`
- Figure builder: `02_builder/build_ijir_figures_v0_3_4.R`
- Main and supplementary figure source data: `04_figures/source_data/`
- Main figures: `04_figures/`
- Supplementary figures: `04_figures/supplementary/`
- Supplementary Data workbook: `06_supplement/IJIR_Supplementary_Data_v0_3_4.xlsx`
- Combined supplementary-figure PDF: `06_supplement/IJIR_Supplementary_Figures_v0_3_4.pdf`

### Primary and derived analyses

- Main exposure/outcome processing and MR: `scripts/03_extract_exposure_candidates.R` through `scripts/13_finalize_analysis.R`, with functions in `R/`
- Reverse ED instruments: `scripts/10_build_reverse_ed_instruments.R` and `R/reverse_instruments.R`
- HUNT same-SNP exposure evaluation: `scripts/28_build_hunt_same_snp_validation_v0_3.R`
- Power, source-threshold, multiplicity, and diagnostic analyses: `scripts/29_run_v0_3_methodological_analyses.R`
- Nominal-locus annotation: `scripts/31_build_nominal_locus_annotation_v0_3.R`
- Mechanistic screening: `scripts/14_freeze_mechanistic_extension.R` through `scripts/30_build_mechanistic_enriched_v0_3.R`
- Alternative-outcome locus/evidence audit: `scripts/35_build_ijir_v0_3_2_evidence_audit.R`
- OpenGWAS query and derivation: `scripts/36_query_opengwas_pleiotropy_v0_3_2_1.py` and `scripts/37_derive_opengwas_pleiotropy_audit_v0_3_2_1.py`
- Alternative-outcome BH audit: `scripts/39_build_ijir_v0_3_3_alternative_outcome_bh_audit.R`
- Frozen primary results: `05_results/v0_3_20260722`
- Later derived results: `05_results/v0_3_2_derived_20260723`, `05_results/v0_3_2_1_opengwas_20260723`, and `05_results/v0_3_3_derived_20260723`
- Protocol and decision records: `01_protocol/`
- Provenance and checksums: `07_provenance/`, `08_qc/`, and versioned manuscript/release receipts

## Reproducibility status before revision

- The frozen primary result directory contains the expected result tables and methodological receipts.
- The reverse-instrument receipt records 479 genome-wide-significant candidates, 437 allele-matched 1000 Genomes Phase 3 EUR-reference variants, and 24 variants after within-exposure clumping at r2=0.001 and 10 000 kb.
- The HUNT, power/MDE, multiplicity, source-threshold, mechanism, locus, LD, and OpenGWAS-derived audits have scripts and versioned outputs.
- The current project relies on its locked `renv` context; primary reruns must not use `R --vanilla`.
- A complete clean-room rerun had not yet been performed in this revision working copy at audit start. The present revision will add independent audit outputs without overwriting frozen results.

## Methodological items requiring explicit verification

1. **METAL reconstruction.** Project code implements beta-star = Z/sqrt(Weight) and SE-star = 1/sqrt(Weight) per SNP. The original 2025 ED GWAS methods identify the METAL weights as cumulative effective-sample-size weights. Numerical preservation of Z and P will be checked from processed outcomes.
2. **Reverse instruments.** The 479-to-24 derivation, exact-rsID/no-proxy policy, build handling, clumping, allele matching, and palindromic/multiallelic rules require a consolidated audit receipt.
3. **Alternative-outcome redundancy.** The eight European and cross-ancestry rows require code-based exact-estimand, unique-rsID, and European-LD compression with representative selection independent of outcome P.
4. **Steiger directionality.** Existing files record Steiger as not computed when required prevalence/scale inputs were not defined. A feasibility table must distinguish non-estimability from evidence supporting the proposed direction.
5. **Colocalization.** Regional files exist, but the 2025 ED release supplies a METAL screening statistic rather than a validated clinical log-odds effect and lacks outcome allele frequencies. Reliable regional colocalization must not be claimed unless harmonization and likelihood inputs can be justified.
6. **Prespecification wording.** Existing protocol, commit, and release records must be distinguished from later explanatory locus and phenotype-annotation audits. A final release cannot retrospectively prove that every criterion was prospectively prespecified.
7. **References.** No standalone BibTeX/RIS library was identified in the manuscript package. Platform citations and access dates must therefore be verified against primary official sources before insertion.

## Baseline PDF layout findings

- The baseline reviewer PDF contains 36 pages.
- Table 1 is horizontally fragmented across pages 25-29. Its fields cannot be read as intact rows, and its final note is separated/truncated in the reviewer rendering.
- Table 2 is horizontally fragmented across pages 30-36. Seven substantive rows are separated into non-corresponding column blocks, and the first footnote is separated/truncated in the reviewer rendering.
- The final article must embed concise, readable main tables in landscape sections. Table 1 should occupy approximately one page; Table 2 should occupy one page or at most two consecutive pages.
- The complete footnotes must include “independent MR replication.” for Table 1 and “none survived FDR correction.” for Table 2.

## Missing or non-reproducible elements at audit start

- No independently timestamped external protocol proving that every item currently labelled “prespecified” preceded all association screening was identified at audit start.
- Reliable formal regional colocalization is not yet established from the available 2025 ED fields.
- A statistically valid Steiger test cannot be inferred from “not estimable” records; required binary-outcome population prevalence and cross-scale assumptions must not be guessed.
- These limitations are methodological constraints, not evidence against causal effects, and will be carried into `BLOCKING_ISSUES.md` and the final QA report.
