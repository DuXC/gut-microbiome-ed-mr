# Approved analysis decisions

## Normative status

This file is the normative operational source for analysis eligibility, multiplicity, replication, evidence grading, and stopping decisions. The README, configuration, and rule engine must implement these decisions and must not weaken them.

## Instrument thresholds

- Primary instruments must meet `P < 5×10⁻⁸`, use ancestry-matched LD clumping with `r² < 0.001` in a 10,000 kb window, and have F-statistic > 10.
- Palindromic SNPs that cannot be harmonized reliably are removed.
- If a microbial phenotype lacks enough genome-wide significant instruments, an exploratory analysis may use `P < 1×10⁻⁵` only when it is explicitly labelled exploratory, is replicated in independent exposure or outcome data, uses weak-instrument-robust methods, and is not combined with the primary evidence grade.

## Multiplicity family

- Analysis eligibility is frozen before inspecting MR association P values, using only prespecified source, QC, and instrument criteria.
- Forward microbiome→ED primary tests and reverse ED→microbiome tests are two separate, prespecified BH-FDR families. Each family is controlled at 5%, and its denominator (`N_forward` or `N_reverse`) is recorded.
- The strict global Bonferroni threshold is `0.05 / (N_forward + N_reverse)` across all eligible tests in both directions.
- Species, higher taxonomic units, functional modules, diversity indices, or any other strata may be displayed separately, but strata never reduce either denominator.
- Reverse ED→microbiome analyses remain a frozen separate BH family for directionality and sensitivity assessment. They do not use the forward independent-replication gate and can never receive `primary` or `strict` evidence labels.

## Replication rule

A candidate association is replicated and may enter the main text only if every gate below is met:

1. Discovery has BH `q < 0.05` in the forward microbiome→ED primary family.
2. Validation uses an outcome or exposure dataset whose overlap class is exactly `none_known`. Validation with known or possible overlap is sensitivity-only.
3. The validation beta has the same sign as the discovery beta, its two-sided `P < 0.05`, and its 95% CI excludes the null in the same direction.
4. At least one prespecified robust estimator in discovery—weighted median or MR-RAPS when estimable—has the same sign as the primary estimate. Significance of the robust estimator is not required.
5. There is no statistically supported Steiger reversal at `P < 0.05` in either discovery or validation when Steiger is computable. Unavailable Steiger data are reported and are not silently interpreted as support.
6. There is no severe horizontal pleiotropy in either dataset. Severe horizontal pleiotropy is defined as MR-Egger intercept `P < 0.05`, or MR-PRESSO global `P < 0.05` with unresolved outliers, an outlier-corrected estimate that changes sign, or an outlier-corrected estimate that cannot be estimated. Tests that are not estimable are explicitly reported and are not treated as passing evidence.

Anything missing a gate is not replicated or main-text eligible and remains exploratory in the supplementary material.

## Evidence labels

- Forward `exploratory`: any estimable eligible forward candidate that uses exploratory instruments or fails any Primary replication gate.
- Reverse `exploratory`: every estimable eligible reverse row, with `analysis_role = reverse_sensitivity`, irrespective of replication fields.
- `insufficient`: only an ineligible hypothesis or a hypothesis whose primary effect could not be estimated; reverse rows retain `analysis_role = reverse_sensitivity`.
- `primary`: a forward primary-tier estimable row that passes every replication gate.
- `strict`: a forward Primary row that additionally passes the combined-direction global Bonferroni threshold.

## Colocalization rule

- Main-text candidate signals undergo local colocalization, preferentially with methods that use complete regional summary statistics.
- PP0–PP4, or equivalent probabilities, are reported.
- Colocalization support is not claimed when only one instrument SNP is available or the regional data are incomplete.

## MVMR covariates and stopping rules

- MVMR is restricted to replicated candidate microbial features and to the following covariates: BMI/obesity, type 2 diabetes, and coronary heart disease or atherosclerotic cardiovascular disease.
- Every covariate must have an explicit causal-diagram rationale; unbounded batch MVMR is prohibited.
- Conditional F-statistics and instrument collinearity are checked before estimation. A model stops when instruments are weak or collinearity is severe.
- MVMR provides mechanistic or independence support and does not override the primary univariable MR result.

## Go, Conditional-Go, and No-Go decisions

- `GO`: at least one Primary replicated signal exists.
- `CONDITIONAL GO`: no Primary replicated signal exists, but at least one genome-wide-instrument candidate that does not depend on `P < 1×10⁻⁵` instruments has nominal discovery `P < 0.05`, independent validation `P < 0.05` with a same-direction non-null 95% CI, and passes every other robust-estimator, directionality, pleiotropy, and overlap gate. Only an exploratory methods/replication short report is allowed, without confirmed-causal language.
- `NO-GO`: neither the GO nor Conditional-Go pattern exists; or positive findings depend entirely on `P < 1×10⁻⁵` instruments; or directionality, pleiotropy, or colocalization invalidates the signal; or the new data provide no identifiable methodological or data increment over the published literature.

At No-Go, the deliverables are a complete analysis report and all reproducible code and result tables; positive findings are not manufactured.
