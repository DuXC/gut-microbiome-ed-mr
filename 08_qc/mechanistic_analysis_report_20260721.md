# Mechanistic extension analysis report

## Scope and integrity

The first-wave mediator payload is complete: 49 of 49 files, totalling
15,658,798,006 bytes (14.583 GiB). Every file matched its frozen expected byte
count, upstream MD5, and local SHA-256. No `.part` file remains. This wave covers
40 circulating cytokines and nine endothelial/vascular-injury proteins.

CRP, GlycA, targeted metabolite axes, and immune-cell phenotypes were not part
of the 49-file wave. They remain protocol-deferred rather than missing. The
prespecified stopping rule says not to activate those broader families when no
mediator survives the M-to-ED FDR and source-validity gates.

## Frozen analysis results

| Family | Frozen denominator | Estimable | FDR-significant | Minimum P | Minimum q |
|---|---:|---:|---:|---:|---:|
| Microbial function to ED | 5 | 5 | 0 | 0.113883 | 0.482172 |
| Cytokine to ED | 40 | 18 | 0 | 0.035812 | 1.000000 |
| Microbial function to cytokine | 200 | 169 | 0 | 0.004728 | 0.945612 |
| Endothelial protein to ED | 9 | 7 | 0 | 0.071024 | 0.395285 |
| Microbial function to endothelial protein | 45 | 45 | 0 | 0.010875 | 0.489376 |
| Cytokine indirect effect | 200 | 80 | 0 | 0.196244 | 1.000000 |
| Endothelial indirect effect | 45 | 35 | 0 | 0.310016 | 1.000000 |

The nominal cytokine-to-ED result was CCL11 (P=0.0358, q=1). It cannot support
mediation because it fails multiplicity, comes from a source with known partial
FinnGen overlap, and its cis lead is excluded by the prespecified source
heterogeneity sensitivity.

The strongest endothelial-to-ED estimates were ESM-1 (P=0.0710, q=0.395) and
TIE2 (P=0.0878, q=0.395); neither was nominally significant. SCALLOP overlap
with HUNT and FinnGen remains possible/unresolved, so even a positive screening
result would have required independent validation.

## Endothelial instrument audit

All 45 prespecified microbial-function target rows were present in the nine
SCALLOP files. The frozen cis intervals yielded 1,476 genome-wide-significant,
F>10 candidates before LD mapping. Of these, 371 mapped uniquely to the bundled
GRCh37 1000G EUR reference by coordinate and alleles. PLINK v1.90b6.21 retained
11 independent cis-pQTLs at r2<0.001 within 10,000 kb across seven proteins.
All 11 matched and harmonised to the FinnGen ED outcome. PECAM-1 and t-PA had
no eligible mapped and clumped cis instrument and remain non-estimable in the
nine-test denominator.

## Decision

No pathway passed the X-to-M FDR gate, the M-to-ED FDR gate, or the indirect
product FDR gate jointly. Therefore zero pathways meet the compatibility gates
for mediation, no colocalization analysis is triggered, and no proportion
mediated is reported. The extension should be retained only as a concise
supplementary falsification analysis. The parent v0.1 negative conclusion and
title should remain unchanged.

The frozen decision is:
`stop_before_broad_metabolite_or_immune_expansion`.
