# Gut microbiome and erectile dysfunction: frozen bidirectional MR analysis report

## Decision

The prespecified decision is **NO-GO**. No forward microbiome-to-erectile-
dysfunction (ED) association survived its frozen BH-FDR family, no forward
association satisfied all independent-replication and diagnostic gates, and no
reverse ED-to-microbiome association survived its separate frozen BH-FDR
family. This report preserves the complete null analysis without promoting
nominal findings to causal claims.

## Evidence geometry

- Forward discovery: 230 Swedish microbiome traits with genome-wide-significant,
  ancestry-matched instruments; FinnGen R12 ED was the primary log-odds outcome.
- Independent exposure validation: exact biological-label mappings to HUNT,
  with unmatched hMGS labels left unmapped rather than assigned fuzzily.
- Outcome sensitivities: the 2025 EUR, AFR, and cross-ancestry ED meta-analysis
  files on their standardized `Z / sqrt(Weight)` scale; they were not treated as
  odds ratios or independent replication because FinnGen contributes to the
  meta-analysis.
- Reverse sensitivity family: 1,572 Swedish microbiome traits, using 24
  independent, strong EUR ED instruments (minimum F = 30.21).

## Methods frozen before association screening

Instruments used `P < 5×10⁻⁸`, F > 10, and ancestry-matched LD clumping at
`r² = 0.001` within 10,000 kb. Harmonisation required rsID, chromosome, and
allele compatibility across declared genome builds. Palindromic variants were
retained only when both effect-allele frequencies permitted a unique
orientation under the prespecified MAF and tolerance rules.

One-SNP analyses used the Wald ratio. Multi-SNP primary analyses used
multiplicative random-effects IVW with the residual scale bounded below by one.
Weighted median, MR-Egger, and MR-RAPS were prespecified robustness estimators
when estimable. MR-RAPS non-convergence or multiple-root warnings were recorded
as failures. Direction-specific BH-FDR was controlled at 5%; the strict global
threshold was `0.05 / (230 + 1,572) = 2.774695×10⁻⁵`.

## Forward results

Of 230 frozen primary traits, 218 were estimable. Seven primary estimates had
nominal `P < 0.05`, but none survived BH-FDR (minimum `q = 0.9416`). All seven
nominal findings were one-SNP estimates and therefore could not satisfy the
prespecified robust-estimator and pleiotropy gates. Only two had exact HUNT
trait matches; neither validated (`P = 0.4273` and `P = 0.1752`). No forward
association qualified as replicated or conditional-go evidence.

## Reverse results

The 24 ED instruments yielded 26,366 matched rows across all 1,572 microbiome
GWAS files. Harmonisation retained 24,794 rows: every trait remained estimable
with 15--17 instruments, 11,362 requested rows were absent from the applicable
microbiome file, 1,572 palindromic rows were excluded, and no allele mismatch
was detected.

All 1,572 IVW primary estimates were estimable. Seventy-seven had nominal
`P < 0.05`; none survived BH-FDR (minimum `P = 0.001861`, minimum `q = 0.9673`).
Across 6,288 method rows, 6,184 were estimated and 104 MR-RAPS rows were retained
as explicit failures under the warning policy. Reverse estimates remain
exploratory directionality/sensitivity results regardless of P value.

## Interpretation

Within the available instruments, outcome definitions, ancestry geometry, and
prespecified multiplicity/replication rules, the analysis does not support a
robust causal effect in either direction. The nominal associations are
compatible with chance under the frozen testing families and should appear, if
reported, only in transparent supplementary tables. The analysis cannot prove
absence of small effects; its main constraints include sparse forward
instruments, incomplete exact HUNT trait mapping, unavailable ED exposure
effect-allele frequencies for reverse palindromes, and unavailable
prespecified population prevalence for a defensible binary-outcome Steiger
calculation.

## Auditable outputs

- `05_results/tables/mr_multiplicity_forward.csv`: frozen forward family.
- `05_results/tables/forward_replication_audit.csv`: every replication gate.
- `05_results/tables/reverse_mr_multiplicity.csv`: frozen reverse family.
- `05_results/tables/mr_multiplicity.csv`: combined evidence labels and global
  threshold.
- `05_results/tables/analysis_decision.csv`: one-row decision.
- `08_qc/final_analysis_receipt.csv`: SHA-256 binding of final inputs, outputs,
  and code.
