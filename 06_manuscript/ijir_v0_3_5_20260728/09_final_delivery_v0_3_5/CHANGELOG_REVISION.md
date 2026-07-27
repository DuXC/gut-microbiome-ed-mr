# CHANGELOG_REVISION — IJIR v0.3.5

Baseline: `IJIR-07-2026-398_merged_reviewer_QC_20260728.pdf`  
Revision date: 28 July 2026  
Frozen primary outputs: `05_results/v0_3_20260722` (unchanged)

| Location | Original | Revised text or action | Reason | Result impact | Evidence/file | Classification |
|---|---|---|---|---|---|---|
| Abstract/Methods | “multiplicity criteria were prespecified” | “eligibility and multiplicity criteria were defined before screening” | The available repository records do not retrospectively prove that every rule was prospectively prespecified | None | Main manuscript; analysis-role audit | Evidence-role clarification |
| Methods | METAL “Z/√weight” without weight definition | Defined cumulative effective-sample-size weight and beta-star=Z/√W, SE-star=1/√W; verified beta-star/SE-star=Z and P preservation | Make the 2025 screening scale reproducible | None | `49_run_ijir_pre_submission_audit.R`; R1 sheets | Supplementary audit |
| Methods | Reverse 24-IV construction summarized | Added P<5×10⁻⁸, F>10, 479 candidates, 437 EUR-reference matches, r²<0.001/10 000 kb, GRCh37 EUR LD, exact-rsID/no-proxy and harmonization policy | Reproduce the 479→24 pathway | None | R2 Reverse IV Build | Supplementary audit |
| Methods/Results | Alternative outcomes lacked complete family explanation | Each EUR, AFR and cross-ancestry analysis is a separate 230-trait BH family; non-estimable rows use P=1; estimable-only BH remains secondary | Align with primary multiplicity logic | None; EUR=8, AFR=0, cross=8 unchanged | R3 Alt BH Families | Reproduced sensitivity |
| Methods/Results | Eight FDR rows described mainly at trait level | Added deterministic duplicate/nested-trait audit, 8→3 lead-SNP compression and descriptive EUR-LD compression to one chr2q21 region; no locus P/q was manufactured | Avoid treating correlated trait rows as independent findings | None | R4 Redundancy; R4 LD Compression | Targeted post hoc audit |
| Methods | Per-trait clumping not fully reconciled with high cross-trait LD | Explained that clumping occurred separately within each microbial trait, allowing different traits to retain correlated variants | Prevent a false clumping-error interpretation | None | Main manuscript; S11; Figure S6 | Method clarification |
| Methods/Results | Steiger and multi-SNP diagnostics were incompletely classified | Audited all 230 forward traits; Steiger remained non-estimable without population prevalence and cross-scale assumptions; method-specific estimated, not-applicable, not-triggered and convergence statuses were retained | Do not convert non-estimability into directional evidence | None | R5/R6 sheets | Revision-stage feasibility audit |
| Discussion | Winner’s curse absent | Added cautious statement that discovery selection/scaling may inflate SNP–exposure estimates, attenuate Wald ratios, and make F/R²/MDE optimistic | Qualify detectability claims | None | Discussion | Interpretation |
| Discussion | FinnGen rationale emphasized but phenotype limitations were brief | Added treated-ED ascertainment, possible untreated-control misclassification and possible non-ED PDE5-inhibitor use | Improve phenotype validity discussion | None | Discussion | Interpretation |
| Abstract/Results/Discussion | “forward-family threshold” | “forward Bonferroni threshold (α=0.05/230)” and “per standardized exposure unit” | MDE used fixed Bonferroni alpha, not a BH boundary | None | Main manuscript; Figure 3 | Terminology correction |
| Main text | LCT/MCM6 called “strongly pleiotropic” | Broad associations now “raise substantial horizontal-pleiotropy concerns”; annotation is not colocalization or proof | Avoid asserting proven horizontal pleiotropy | None | Main manuscript; Supplement | Interpretation |
| Introduction/Discussion | Microbiome–ED MR papers cited as references 4–9 | Four MR reports are references 6–9; MiBioGen is reference 4 and earlier ED GWAS reference 5 | Correct source roles | None | Main manuscript | Citation correction |
| Methods/References | MR guidance reference 24 followed the AI disclosure | Reference 24 moved to general MR design; AI disclosure has no citation | Restore citation relevance | None | Main manuscript | Citation correction |
| Methods/References | Platform annotations lacked formal references | Added verified Ensembl, GWAS Catalog and OpenGWAS references plus 23 July 2026 access date | Improve audit reproducibility | None | References 32–34 | Citation addition |
| AI disclosure | Included “document generation” | Exact authorized sentence now states only “code review, language editing, and consistency checks” | Match author instruction | None | Main manuscript | Disclosure correction |
| Table 1 | Horizontally fragmented over five reviewer-PDF pages; note visually incomplete | Reduced to five columns and one landscape page; forced a stable two-line complete footnote ending “independent MR replication.” | Restore row-level readability | None | Article PDF page 21 | Layout correction |
| Table 2 | Horizontally fragmented over seven pages; note visually incomplete | Reduced to eight columns and one landscape page; complete footnote includes “none survived FDR correction.” | Restore seven-row readability | None | Article PDF page 22 | Layout correction |
| Figures | S3/S6 clipping risk and Figure 1 path ambiguity | Rebuilt all figures; S3/S6 margins verified; Figure 1 dotted ED-outcome path avoids the parallel HUNT boxes | Visual integrity | None | Figure builder; visual QA receipt | Layout correction |

## Numerical-result status

- No frozen primary MR number changed.
- Forward: 230 eligible, 218 estimable, seven nominal, zero FDR.
- Reverse: 1 572 tests, 77 nominal, zero FDR.
- HUNT: 97 exact-label rows, 90 unique lead rsIDs; 76/97 and 69/90 direction-concordant.
- Alternative outcomes: EUR eight, AFR zero, cross-ancestry eight trait-level associations surviving FDR correction.
- The eight EUR/cross rows remain five rs4988235, two rs6754311 and one rs7570971 rows; pairwise EUR r²=0.858552–0.972328, one chr2q21 locus.
- Median 80%-power MDE remains OR 2.89 per standardized exposure unit at α=0.05/230.
- Mechanistic screening remains zero FDR.

## Analyses not performed

- Formal regional colocalization was not performed because the processed 2025 ED release lacks EAF and supplies a non-clinical METAL screening scale rather than a validated binary-outcome likelihood. Exact-rsID annotation was not substituted for colocalization.
- No unplanned metabolite, immune-cell, pathway, or taxonomic screening was added.
