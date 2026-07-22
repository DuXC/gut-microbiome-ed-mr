# IJIR v0.3 final QA report

Date: 22 July 2026

Target: *International Journal of Impotence Research* Article

## Executive decision

The primary conclusion did not change:

> No association met the predefined multiplicity-controlled criteria for a
> robust causal interpretation in either direction.

This is a multiplicity-controlled negative reassessment, not proof that gut
microbial traits have no causal effect on erectile dysfunction.

## 1. HUNT instrument and evidence audit

- Neither *Fimisoma avicola* nor UBA644 sp900547165 had a HUNT instrument at
  P<5×10⁻⁸.
- The legacy HUNT-specific analyses used HUNT-selected exploratory instruments
  at P<1×10⁻⁵: 23 and 20 post-clump SNPs.
- The v0.3 same-SNP analysis queried each Swedish lead SNP in its exact-label
  HUNT GWAS. All 97 were found and allele-compatible; 76 directions were
  concordant. This proportion and its exact-binomial interval are descriptive
  because microbial traits are correlated.
- Final evidence names are “cross-cohort same-SNP exposure-association
  validation” and “exploratory exact-label HUNT sensitivity analysis”. Neither
  is called independent MR replication.
- The two focal same-SNP HUNT associations were weak (F=0.002 and 0.180) and
  therefore did not support interpretable same-SNP MR validation.

## 2. Power and minimum detectable effects

- Analysis included all 218 estimable forward traits and used FinnGen's 2 886
  cases and 215 272 controls.
- Approximate R² median: 0.00203; IQR 0.00168–0.00274; range
  0.00137–0.00760.
- Median 80%-power MDE ORs:
  - nominal α=0.05: 2.17 (IQR 2.01–2.29; range 1.61–2.43);
  - forward 0.05/230: 2.89 (IQR 2.63–3.08; range 1.98–3.29);
  - global 0.05/1 802: 3.09 (IQR 2.81–3.29; range 2.09–3.53).
- At nominal, forward-family and global thresholds, 54, 1 and 0 traits,
  respectively, had 80% power for OR≥2. The negative result therefore weighs
  against large effects mainly among the best-instrumented traits but cannot
  exclude small or moderate effects.
- R² is a summary-data approximation. Presence traits include source
  prevalence and prevalence±0.10 liability-scale scenarios; no unique clinical
  liability-scale R² is claimed.

## 3. Source-study-wide threshold sensitivity

The source thresholds were 1.7×10⁻⁸ for diversity, 5.4×10⁻¹¹ for species and
higher taxa, and 4.3×10⁻¹⁰ for functions. Twenty-seven traits remained eligible,
23 were estimable and four non-estimable. No result was nominally significant;
minimum P=0.1533, minimum q=1 and zero FDR associations.

## 4. Multiplicity and duplicate-signal audit

- Primary families remained fixed at 230 forward and 1 572 reverse tests;
  12 non-estimable forward rows were retained at P=1.
- Estimable-only forward BH: n=218, minimum q=0.8925, zero FDR.
- Unique-signal-cluster BH: n=225, minimum q=0.9605, zero FDR.
- Peptococcaceae, Peptococcales and Peptococcia are explicitly marked as a
  nested cluster with identical SNPs and estimates, not three independent
  biological signals.

## 5. Prespecified-analysis closure

All 16 Methods/protocol analysis entries have a result or an explicit reason
for non-estimation/non-triggering:

- 2025 European, African-ancestry and cross-ancestry ED sensitivities:
  completed and reported as known-overlap screening evidence.
- Weighted median and MR-Egger: each estimated for six eligible multi-SNP
  traits; other rows are explicit non-estimable results.
- MR-RAPS: 23 forward estimates plus one explicit failure; reverse-method
  failures are retained in Supplementary Table S4.
- Steiger and MR-PRESSO: not triggered; the absence of a diagnostic estimate is
  not treated as favourable evidence.
- HUNT: same-SNP validation plus exploratory HUNT-selected sensitivity reported.
- Bounded mechanistic screen: seven families and all 544 rows reported.
- CCL11 source heterogeneity: completed and applied.
- Source-study-wide and both multiplicity sensitivities: completed.
- Power/MDE: completed for 218 traits.
- Colocalization: not triggered because component FDR criteria failed.

## 6. Figures and tables

Main figures:

1. Figure 1 — Study design and evidence roles.
2. Figure 2 — Ranked P values and predefined multiplicity boundaries.
3. Figure 3 — Effect estimates, cross-cohort validation and detectability.

Supplementary figures:

1. S1 — Instrument architecture and strength.
2. S2 — P-value calibration and multiplicity sensitivities.
3. S3 — Swedish–HUNT exact-label same-SNP exposure validation.
4. S4 — Source-study-wide significance sensitivity.
5. S5 — Mechanistic-screening evidence map.

All eight PNGs have verified 600-dpi metadata. The main manuscript contains
three figures and two tables, for five display items in total.

## 7. Supplementary data completeness

- 26 worksheets are present.
- S1 contains 43 295 instrument rows.
- S2 and S3 contain complete forward and reverse primary families.
- S4 retains robust-method estimates, non-estimable rows and explicit failures.
- S5 contains power summaries, trait-level MDEs and instrument-level inputs.
- S6 contains 97 same-SNP HUNT lookups and the two focal legacy HUNT audits.
- S7 contains source-study-wide results and the strict instrument inventory.
- S8 contains the seven trait rows/five unique-SNP pleiotropy audit.
- S9 contains all 544 mechanistic rows, family summaries and CCL11 sensitivity.
- S10 contains provenance/checksums and the software environment.

## 8. Cross-file and formatting QA

- Table 2 and Figure 3 OR, P, q and F values matched frozen CSV output for 7/7
  nominal rows.
- Figure 2 contained all 230 forward and 1 572 reverse tests; exactly 12
  non-estimable forward rows were displayed at P=1.
- No formula error, TODO/TBD/placeholder, local `/Volumes/...` path or
  comma-formatted thousand was detected in the submission artifacts.
- HUNT DOI was corrected to `10.1038/s41588-026-02502-4`; Swedish DOI remains
  `10.1038/s41588-026-02512-2`.
- Abstract: 189 words. Main text: 2 230 words. References: 30. Cover letter:
  445 whitespace-delimited words.
- Final rendered pages: manuscript 16, title page 1, cover letter 1, STROBE-MR
  checklist 1. STROBE-MR locations use the final page and continuous line
  numbers.
- Repository test suite: 847/847 passed. Submission checks: 30/30 passed.
- SHA-256 values are recorded in
  `07_qc/FINAL_DELIVERABLE_CHECKSUMS_v0_3.csv`.

## 9. Remaining reviewer-facing limitations

1. Sparse instruments: 194/218 estimable forward traits (89%) and all seven
   nominal rows used one SNP, limiting horizontal-pleiotropy diagnostics.
2. Power: small and moderate causal effects remain difficult to exclude,
   especially after family/global multiplicity control.
3. HUNT: Swedish presence and HUNT normalized abundance have different scales;
   same-SNP direction may be compared but beta and MR OR magnitude may not.
4. Outcome definition and overlap: FinnGen preferentially captures recognised,
   treated ED. The larger 2025 EUR/cross-ancestry sensitivities include FinnGen,
   substantially overlap each other and retain a screening Z/√weight scale.
5. Ancestry: primary instruments are European; the African sensitivity has
   lower coverage and does not establish cross-ancestry transportability.
6. Pleiotropy: rs62103891 has a catalogued programmed-cell-death-protein-5
   association; the relevance to ED is unresolved. “Not identified” for four
   other SNPs does not establish absence of pleiotropy.
7. Mechanistic screening: all families were negative after correction; CCL11
   failed source-heterogeneity sensitivity, no component pair passed joint
   criteria and colocalization was not triggered.
8. Public archive: the stable all-version Zenodo concept DOI is
   `10.5281/zenodo.21456670`. A v0.3.0 version-specific DOI must be reported only
   after the matching GitHub/Zenodo release is verifiably published.

## Final status

The local v0.3 submission package is internally consistent and technically
ready for author review. Journal upload and approval of any portal-generated
reviewer PDF remain separate author-controlled steps.
