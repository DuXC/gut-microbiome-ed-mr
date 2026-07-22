# IJIR v0.3 pre-submission revision changelog

Date: 22 July 2026

Target journal: *International Journal of Impotence Research*

Version: v0.3 / repository release candidate v0.3.0

## 1. Files revised or created

- Rewrote the main manuscript, title page and cover letter; rebuilt all three
  DOCX files and the STROBE-MR checklist from versioned Markdown/CSV sources.
- Rebuilt Table 1 and Table 2 as editable XLSX workbooks.
- Replaced the former supplementary workbook with a 26-sheet v0.3 workbook
  containing S1–S10 plus multiplicity, 2025 ED-sensitivity, closure-audit and
  data-dictionary sheets.
- Updated Figures 1 and 2 and created main Figure 3.
- Created Supplementary Figures S1–S5 and a combined supplementary-figure PDF.
- Added machine-readable QA receipts, final-file SHA-256 checksums and final
  rendered DOCX previews.

## 2. Analyses rerun and scripts used

- `scripts/28_build_hunt_same_snp_validation_v0_3.R`: audited the two legacy
  HUNT instrument sets and performed exact-label, same-position, allele-aligned
  lookup of each Swedish lead SNP in HUNT.
- `scripts/29_run_v0_3_methodological_analyses.R`: regenerated source-study-wide
  threshold MR, power/MDE, estimable-only BH, nested/duplicate-signal BH,
  2025 ED-outcome sensitivities, instrument architecture and the complete
  prespecified-analysis closure audit.
- `scripts/30_build_mechanistic_enriched_v0_3.R`: rebuilt the complete
  seven-family mechanistic screen, retained all non-estimable rows and applied
  the CCL11 source-heterogeneity sensitivity.
- `scripts/31_build_nominal_locus_annotation_v0_3.R`: created exact-rsID GWAS
  Catalog/Ensembl annotations for the five unique nominal SNPs.
- `02_builder/prepare_ijir_table_data_v0_3.R` and
  `build_ijir_workbooks_v0_3.mjs`: generated the two main tables and 26-sheet
  supplementary workbook directly from frozen CSV/Parquet outputs.
- `02_builder/build_ijir_figures_v0_3.R`: generated all three main and five
  supplementary figures at 600 dpi plus PDF/SVG/TIFF/source-data versions.
- `02_builder/build_ijir_documents_v0_3.py`: generated the final DOCX files,
  enforced word limits and inserted final STROBE-MR page/line locations.
- `02_builder/run_final_qa_v0_3.py`: compared the submission artifacts against
  frozen analysis outputs and generated checksums.

## 3. Numerical changes and newly reported results

- The primary forward and reverse results did not change: 230 forward-eligible
  traits (218 estimable; seven nominal; minimum primary q=0.9416) and 1 572
  reverse traits (77 nominal; minimum q=0.9673), with no FDR association in
  either direction.
- HUNT audit: *Fimisoma avicola* and UBA644 sp900547165 had zero HUNT
  instruments at P<5×10⁻⁸. Their earlier HUNT-selected analyses used 23 and 20
  post-clump SNPs at P<1×10⁻⁵, respectively.
- Same-SNP HUNT validation: 97/97 exact-label Swedish lead SNPs were recovered
  and allele-compatible; 76/97 directions were concordant (78.4%; descriptive
  exact-binomial 95% CI 68.8%–86.1%). The focal HUNT associations were weak:
  P=0.965, F=0.002 and P=0.671, F=0.180.
- Multiplicity sensitivities remained negative: estimable-only BH denominator
  218, minimum q=0.8925; unique-signal-cluster denominator 225, minimum q=0.9605.
- Source-study-wide thresholds retained 27 eligible traits, of which 23 were
  estimable; minimum P=0.1533, minimum q=1 and zero FDR associations.
- Across 218 estimable forward traits, approximate R² median was 0.00203 (IQR
  0.00168–0.00274; range 0.00137–0.00760). Median 80%-power MDE ORs were 2.17
  at α=0.05, 2.89 at 0.05/230 and 3.09 at 0.05/1 802. The corresponding ranges
  were 1.61–2.43, 1.98–3.29 and 2.09–3.53.
- The 2025 known-overlap sensitivity estimated 158 European, 108 African and
  165 cross-ancestry tests. European and cross-ancestry analyses each contained
  eight FDR rows; the African analysis contained none. These results remain
  sensitivity evidence because FinnGen contributes to the 2025 data and the
  METAL Z/√weight scale is not a clinical ED log-odds scale.
- The bounded mechanistic workbook contains all 544 planned rows, including 185
  non-estimable rows. No family had an FDR association. CCL11-to-ED was nominal
  (P=0.0358; q=1) but its cis lead had I²=86.8% and source-heterogeneity P=0.00587,
  so it was excluded in the predefined sensitivity.
- The seven nominal trait rows map to five unique SNPs. Four had no exact-rsID
  GWAS Catalog association identified; rs62103891 was associated with programmed
  cell death protein 5 measurement, creating a possible but unresolved
  pleiotropy concern. No locus was within 1 Mb of FUT2, LCT or ABO.

## 4. Wording downgraded or removed

- Deleted “independent replication” from the title and positive evidence
  descriptions. HUNT is now described as “cross-cohort same-SNP
  exposure-association validation” plus an “exploratory exact-label HUNT
  sensitivity analysis”.
- Replaced formal “causal mediation” wording with “prespecified bounded
  mechanistic screening” or “two-step MR mechanistic screening”.
- Removed causal labels such as risk/protective taxa and stated that seven
  nominal rows are not seven independent causal taxa.
- Replaced engineering language including evidence geometry, no-go decision,
  frozen family, gate, cryptographic receipts and stopping rule in the
  manuscript with ordinary methodological wording.
- Explicitly stated that failure to survive multiplicity correction does not
  prove absence of a causal effect and that small or feature-specific effects
  cannot be excluded.

## 5. Suggestions not executed because evidence was insufficient

- No independent MR replication claim was retained because HUNT supplied an
  exposure cohort but FinnGen remained the outcome.
- Same-SNP HUNT/FinnGen Wald ratios were not promoted as MR results because the
  focal HUNT SNP–exposure associations were weak instruments.
- Swedish presence and HUNT normalized-abundance MR OR magnitudes were not
  compared because the exposure scales differ.
- A unique liability-scale R² was not asserted for presence traits; source
  prevalence and prevalence±0.10 scenarios are supplied instead.
- Steiger, MR-PRESSO, single-SNP heterogeneity, leave-one-out and publication-
  bias plots were not produced because their prespecified triggers or minimum
  instrument counts were not met.
- Colocalization was not run because no exposure-to-mediator and mediator-to-ED
  component pair jointly passed the predefined FDR criteria.
- No additional metabolite, immune-cell, microbial-subgroup or pathway screen
  was added, and no decorative single-SNP scatter/funnel/network plots were
  created.

## 6. Verification

- Repository tests: 847 passed, 0 failed, 0 warnings, 0 skipped.
- Submission machine QA: 30 passed, 0 failed.
- Final limits: abstract 189 words; main text 2 230 words; 30 references; three
  main figures; two main tables.
- Final renders: main manuscript 16 pages; title page 1; cover letter 1;
  STROBE-MR checklist 1.
