# Mechanistic extension protocol v0.2

## Status and scope

This protocol was frozen on 2026-07-21 before any mediator-to-ED or
microbial-function-to-mediator association result was inspected. It defines a
bounded mechanistic extension of the public v0.1 gut microbiome--ED MR analysis.
It does not alter, replace, or reinterpret the v0.1 frozen negative result.

The target estimand is evidence compatible with an indirect pathway:

`genetically proxied microbial function (X) -> circulating mediator (M) -> ED (Y)`

The analysis cannot establish biological mediation by itself. In particular,
most eligible microbial-function exposures have one independent instrument, so
variant-specific horizontal pleiotropy cannot be empirically excluded by
multi-instrument sensitivity tests.

## Prespecified microbial-function exposures

The exposure family contains exactly five HUNT KEGG-module traits selected from
biological rationale and genome-wide instrument eligibility, without reference
to ED association P values:

1. M00080: lipopolysaccharide biosynthesis.
2. M00091: phosphatidylcholine biosynthesis.
3. M00136: prokaryotic GABA biosynthesis.
4. M00530: dissimilatory nitrate reduction.
5. M00569: catechol meta-cleavage.

All five have one clumped, genome-wide-significant, F>10 instrument in the
current HUNT layer. They form a five-test microbial-function-to-ED total-effect
family. They are not relabelled as replicated Swedish exposures because the
Swedish and HUNT functional annotations are not exact biological matches.

The seven nominal Swedish microbiome-to-ED findings from v0.1 are prohibited as
a mechanism-selection filter. They were all one-instrument estimates, none
survived the frozen 230-test BH family, and the two exact HUNT taxonomic matches
failed validation. Using them to select mediators would be post-outcome
selection and double use of the ED data.

## Prespecified mediator families

### Family 1: circulating cytokines

All 40 traits from Konieczny et al. (2025), GWAS Catalog accessions
GCST90428399--GCST90428438, are retained as one complete family. The published
meta-analysis includes YFS/FINRISK, SCALLOP, and deCODE components. Because
FinnGen contains legacy FINRISK participants, the 40-trait meta-analysis has
known partial overlap with the primary ED outcome and is a screening/sensitivity
source rather than definitive independent evidence.

Primary causal interpretation requires a no-known-overlap component source,
preferentially deCODE Icelandic data, plus cross-platform concordance where
available. Meta-analysis effect estimates are also interpreted cautiously
because the source article reports assay heterogeneity and indirect recovery of
some pooled effect sizes.

### Family 2: endothelial and vascular-injury proteins

Nine proteins are selected a priori from SCALLOP CVD-I: SELE, ESM-1, PECAM-1,
TIE2, thrombomodulin, LOX-1, VEGF-A, U-PAR, and t-PA. The family is motivated by
endothelial activation, vascular permeability, thrombosis/fibrinolysis, and
angiogenic signalling relevant to erectile physiology.

SCALLOP cohort overlap with HUNT and FinnGen must be resolved at the cohort-list
level before these data can receive a no-known-overlap label. Until then,
SCALLOP-only estimates are exploratory.

### Family 3: chronic systemic inflammation

CRP and GlycA are prespecified secondary markers. They are not activated until
their exact public summary-statistic sources, effect scales, genome builds,
licenses, and cohort overlap are frozen. OpenGWAS-only identifiers that require
an unavailable token are not treated as resolved sources.

### Family 4: targeted microbial-metabolite axes

Broad screening of 1,400 metabolites is prohibited because a 2025 publication
already performed a closely overlapping gut-microbiota--metabolite--ED analysis.
Only the prespecified bile-acid, phosphatidylcholine/TMAO,
tryptophan/kynurenine, arginine/citrulline/NO, and GABA/short-chain-fatty-acid
axes may be activated after exact phenotype and source mapping. This family is
deferred from download wave 1.

### Immune-cell phenotypes

The 731-cell immunophenotype panel is not a primary mediator family because of
its small source sample and extreme multiplicity. A later extension may assess
only prespecified broad blood-cell counts from a larger GWAS. Such an extension
requires a protocol amendment made before outcome association screening.

## Instrument rules

- Microbial-function instruments: P<5e-8, F>10, ancestry-matched LD clumping at
  r2<0.001 in a 10,000-kb window.
- Mediator-to-ED primary instruments: cis-pQTLs at P<5e-8, F>10, clumped at
  r2<0.001 in a 10,000-kb window. For the nine endothelial proteins, cis is
  frozen as the GRCh37 interval spanning the encoding gene plus 300 kb on each
  side. Gene coordinates and source URLs were recorded before inspecting any
  mediator-to-ED association. Trans-pQTLs are sensitivity-only.
- Before any mediator-to-ED result was inspected, the cytokine cis definition
  was operationally frozen to the 19 lead variants explicitly classified as
  cis in Konieczny et al. Supplementary Data S2. The other 21 cytokines remain
  in the 40-test denominator as non-estimable under the cis-only policy.
- Supplementary Data S2 reports the 19 lead coordinates on GRCh37; the public
  GWAS Catalog harmonized files provide their GRCh38 coordinates. Both builds
  are retained in separate fields and are never mixed for regional analyses.
- Because 13 of the 19 cytokine cis leads have HetP<0.05 and one lacks an
  estimable heterogeneity statistic, the complete 19-lead analysis is a
  screening layer. A prespecified heterogeneity sensitivity retains only
  HetP>=0.05 variants, matching the source study's heterogeneity sensitivity;
  the missing-HetP IL-18 lead is reported separately and is
  not silently treated as homogeneous.
- One-instrument estimates use the Wald ratio. Multi-instrument estimates use
  constrained multiplicative random-effects IVW, with weighted median,
  MR-Egger, and MR-RAPS only when their requirements are met.
- MVMR is not a primary mediation method. It may be attempted only when the
  union instrument set is identifiable, conditional F statistics exceed 10,
  and collinearity is not severe. Failure of these gates is a stopping rule.

## Frozen testing families

Eligibility and denominators are frozen before mediator association results:

1. X->Y total effects: 5 tests.
2. Cytokine M->Y effects: 40 tests.
3. Endothelial M->Y effects: 9 tests.
4. Cytokine X->M effects: 5 x 40 = 200 tests.
5. Endothelial X->M effects: 5 x 9 = 45 tests.
6. Cytokine indirect effects: 200 product tests.
7. Endothelial indirect effects: 45 product tests.

Each family uses Benjamini--Hochberg FDR at 5%. Untested or non-estimable rows
remain in the frozen denominator and receive P=1 for multiplicity bookkeeping.
No pathway can be promoted by reducing the denominator after seeing results.

## Analysis sequence

1. Freeze exposure, mediator, source, overlap, and family-denominator records.
2. Audit remote files, licenses, checksums, effect scales, builds, and cohort
   membership.
3. Estimate all prespecified M->Y, X->M, and X->Y effects without using one arm
   to change another arm's testing denominator.
4. Compute indirect effects as `a*b`. When the two component estimates are from
   non-overlapping samples, use the delta-method variance
   `b^2*SE(a)^2 + a^2*SE(b)^2`. If overlap is known or unresolved and its
   covariance cannot be estimated, the indirect P value is sensitivity-only.
5. Perform locus-level colocalization for every pair that passes both component
   FDR gates. Report PP0--PP4; require PP4>=0.80 for supportive evidence. Use a
   multiple-signal method when regional LD and data density permit it.
6. Seek a no-known-overlap component and cross-platform validation before any
   main-text mechanistic claim.

## Evidence labels

A pathway is `compatible_with_mediation` only when all of the following hold:

- X->M passes its frozen FDR family.
- M->Y passes its frozen FDR family using a no-known-overlap source.
- The product effect passes its frozen FDR family.
- Effect directions are internally coherent.
- Regional colocalization supports the relevant molecular locus.
- No supported direction reversal or severe unresolved pleiotropy is present.

Anything missing a gate is `exploratory` or `insufficient`. A non-null indirect
effect is not described as explaining the v0.1 total effect when the total
effect is null.

## Proportion mediated

The proportion mediated is not reported unless the corresponding X->Y total
effect survives the five-test FDR family, the total and indirect effects have
the same direction, the total estimate is not close to zero, and the ratio has
a stable uncertainty interval. Otherwise only the absolute indirect estimate
is shown.

## Sample-overlap policy

`none_known`, `possible_unresolved`, and `known_partial` are distinct labels.
Only `none_known` sources can support a primary mechanistic claim. Known or
possible overlap sources are sensitivity-only until an independent component
analysis resolves the issue. Absence of a named shared cohort is not treated as
proof of independence.

## Publication and stopping rules

- If no mediator survives its M->Y FDR and source-validity gates, stop before
  broad metabolite or immune-cell expansion.
- If no pathway passes all mediation gates, retain the extension as a concise
  supplementary falsification analysis and do not change the v0.1 title or
  abstract conclusion.
- If at least one pathway passes FDR, no-overlap validation, and colocalization,
  reassess whether it belongs in the main manuscript or a separate mechanistic
  report. This decision cannot weaken the reporting of the v0.1 negative total
  effects.
