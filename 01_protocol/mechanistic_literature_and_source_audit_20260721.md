# Mechanistic extension literature and source audit

## Decision

The supervisor's proposed inflammation--metabolism--endothelium mechanism is
biologically plausible, but novelty requires a strictly gated design. A broad
metabolome or immune-cell rescreen would substantially overlap published work.
The v0.2 extension therefore prioritizes newer cytokine data and a small
endothelial panel, while deferring metabolites and broad immune phenotypes.

## Direct competing and adjacent studies

- Wang et al. reported a 196-taxon, 1,400-metabolite gut-microbiota--ED
  mediation analysis and four nominal indirect paths. This prevents a claim of
  novelty based only on adding plasma metabolites.
  https://doi.org/10.1093/sexmed/qfaf076
- Liu et al. assessed 41 cytokines against ED using 8,293-person cytokine data
  and FinnGen R9, reporting nominal IP-10 and IL-1RA associations.
  https://doi.org/10.3389/fimmu.2024.1342658
- Published ED screens already combine 731 immune phenotypes, 91 inflammatory
  proteins, and 1,400 metabolites, often with relaxed instrument or nominal
  significance thresholds. The novelty target must therefore be the
  species/function-resolved exposure layer, strict family denominators,
  no-known-overlap validation, and colocalization rather than panel size.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC11650343/

## First-wave mediator sources

### Forty-cytokine GWAS meta-analysis

Konieczny et al. meta-analysed 40 circulating cytokines in up to 74,783
participants and deposited harmonized summary statistics under
GCST90428399--GCST90428438. The resource contains 19 cis and 150 trans loci but
also reports cross-assay heterogeneity and limitations in recovered pooled
effect sizes. The meta-analysis combines YFS/FINRISK, SCALLOP, and deCODE;
therefore its overlap with FinnGen is known partial rather than independent.

- Article: https://doi.org/10.1038/s42003-025-07453-w
- Data: https://ftp.ebi.ac.uk/pub/databases/gwas/summary_statistics/

The 40 harmonized payloads were reachable during the pre-freeze check and total
approximately 11.6 GiB. Exact sizes and upstream MD5 values are resolved by the
versioned source-audit script rather than copied manually into the protocol.

### SCALLOP CVD-I endothelial panel

SCALLOP provides unrestricted full summary statistics for 90 cardiovascular
proteins in up to 30,931 participants. Nine prespecified endothelial proteins
are selected for wave 1. Their combined compressed size is approximately
3.2 GB.

- Article: https://doi.org/10.1038/s42255-020-00287-2
- Data record: https://doi.org/10.5281/zenodo.2615265
- License recorded by Zenodo: CC BY 2.0.

The complete cohort list must be reconciled against HUNT and FinnGen before the
SCALLOP source can move from `possible_unresolved` to `none_known` overlap.

## Deferred sources

- The 91-protein inflammatory panel from Zhao et al. is retained as a potential
  cross-platform validation source, not a discovery panel, because it has
  already been repeatedly used in ED studies.
- CRP and GlycA remain prespecified chronic-inflammation markers. CRP has a
  large UK Biobank plus CHARGE GWAS, whereas currently convenient OpenGWAS
  access requires a JWT. Exact public files must be frozen before activation.
- deCODE Icelandic protein data are the preferred no-known-overlap validation
  source, but selective assay-level access and terms must be resolved from the
  deCODE download portal before use.
- The 1,400-metabolite panel is not activated in wave 1. Only exact phenotypes
  from the five prespecified metabolic axes may be added through a protocol
  amendment made before association screening.

## Search boundary

The search used PubMed/publisher records, official GWAS Catalog records, Zenodo
record metadata, and source-article data-availability statements. As of
2026-07-21, no exact three-node publication was identified that combines the
current HUNT/shotgun functional layer, the newer ED outcome, the 2025 cytokine
resource, strict frozen FDR families, independent component validation, and
regional colocalization. This is a dated search conclusion, not a permanent
claim of absence.
