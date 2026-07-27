# FINAL QA REPORT — IJIR v0.3.5

Final status: **READY FOR AUTHOR PORTAL REVIEW**

## Scientific consistency

- Primary result changed: **No**.
- Forward frozen result: 230 eligible; 218 estimable; seven nominal; zero FDR.
- Reverse frozen result: 1 572 tests; 77 nominal; zero FDR.
- HUNT: 97 exact labels; 90 unique lead rsIDs; 76/97 and 69/90 direction-concordant; not independent MR replication.
- 2025 outcomes: separate 230-trait BH families with non-estimable P=1; EUR=8, AFR=0, cross=8.
- Redundancy audit: eight trait rows → three high-LD lead SNPs → one chr2q21 LCT/MCM6 region; no locus-level P or q was created.
- METAL cumulative effective-sample-size weights and beta-star/SE-star transformation were numerically reproduced.
- Formal colocalization was not feasible under the available ED fields and scale; exact-rsID annotation was not presented as colocalization.

## Manuscript and layout

- Abstract word count: 194.
- Main-text word count: 2823.
- References: 34.
- Main displays: three figures and two tables.
- Combined Article PDF: 22 pages; title page first; abstract second.
- Table 1: one landscape page, complete note.
- Table 2: one landscape page, seven intact rows, complete note.
- Nine PNG figures: 600 dpi.
- Supplementary Figures PDF: six pages in S1–S6 order.
- Supplementary Data: 46 sheets; no formulas or spreadsheet error tokens.
- Visual clipping: none detected in final S3/S6 boundary checks or rendered Article pages.

## Language and evidence safeguards

- No positive “independent replication” claim.
- Non-estimable results are not interpreted as negative evidence.
- Database non-return is not interpreted as absence of pleiotropy.
- LCT/MCM6 annotation raises pleiotropy concerns but does not prove horizontal pleiotropy or microbial mediation.
- The exact authorized Codex disclosure is present and has no reference 24.
- Authors, order, affiliations, correspondents, ORCIDs and submission contact were unchanged from the baseline.

## Reproducibility and security

- Machine checks passed: 43; failed: 0.
- Failed checks: none.
- Public archive aligned: yes.
- Credential scan: PASS; no JWT or bearer header found in scanned repository, history, logs, receipts, environment/configuration or submission files.
- OpenGWAS token revocation: not verified; author action remains.

## Remaining reviewer-facing vulnerabilities

- Most forward estimates and all seven nominal rows are single-SNP Wald ratios.
- Winner’s curse may make discovery F/R²/MDE optimistic and attenuate single-SNP Wald ratios.
- The non-overlapping African-ancestry sensitivity has limited coverage and uncertain instrument transportability.
- FinnGen captures recognized and pharmacologically treated ED and may misclassify untreated or some non-ED PDE5-inhibitor use.
- The 2025 METAL screening scale is not a clinical ED log-odds or OR scale.

The IJIR portal must remain unapproved until the author inspects the final uploaded files and generated reviewer PDF.
