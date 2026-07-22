# Changelog

## 2026-07-22

- Reclassified HUNT evidence after instrument-level audit: the two nominal
  exact-label traits had no HUNT instruments at `P < 5×10⁻⁸`; the earlier
  HUNT-selected analyses used 23 and 20 SNPs at exploratory `P < 1×10⁻⁵`.
  All manuscript and figure language now distinguishes cross-cohort same-SNP
  exposure-association validation from independent MR replication.
- Queried the Swedish lead SNP in all 97 exact-label HUNT GWASs with exact label,
  position and allele alignment. All 97 were recovered; 76 directions were
  concordant, while the two nominal focal same-SNP HUNT associations were weak.
- Added reproducible power and minimum-detectable-effect calculations for all
  218 estimable forward traits, including prevalence scenarios for presence
  traits and nominal, forward-family and global thresholds.
- Added source-study-wide microbial-threshold MR sensitivity, estimable-only BH
  sensitivity, exact duplicate/nested signal clustering, and a complete audit
  of all prespecified analyses.
- Added exact-rsID/Ensembl annotation of the five unique nominal SNPs and
  retained unverified associations as `not identified` rather than absent.
- Completed the seven-family, 544-row bounded mechanistic workbook with all 185
  non-estimable rows and CCL11 source-heterogeneity sensitivity; no family
  produced an FDR association and colocalization was not triggered.
- Rebuilt the IJIR v0.3 manuscript, title page, cover letter, STROBE-MR
  checklist, two editable main tables, 26-sheet supplementary workbook, three
  main figures and five supplementary figures. The 189-word abstract,
  2 230-word main text and 30 references meet the checked IJIR Article limits.
- Passed 847/847 repository tests and 30/30 cross-artifact submission checks;
  Table 2 and Figure 3 were compared directly with frozen P, q, F and OR values.
- Published GitHub release `v0.3.0` at tag commit
  `9c166fde3a7e9f3f9b739cc358566936d705ab1c`, uploaded the 10 949 450-byte
  submission package with SHA-256
  `23094ac5a4bdfd2241cf0b75b00b42d6e96a5064f67fe16978fbc9d51a149206`,
  and verified Zenodo version DOI `10.5281/zenodo.21485253` under concept DOI
  `10.5281/zenodo.21456670`.

## 2026-07-21

- Preserved the released v0.1.0 NO-GO analysis and opened the isolated
  `analysis/v0.2-mechanistic-extension` branch.
- Froze five biologically selected HUNT KEGG functional exposures, 40
  circulating cytokines, nine endothelial proteins, seven family-specific BH
  denominators, and explicit mediation/colocalization compatibility gates.
- Excluded the seven nominal v0.1 taxa from hypothesis selection and deferred
  broad metabolomics, immune-cell scans, CRP, and GlycA until exact source and
  phenotype mappings satisfy the protocol.
- Audited 49 first-wave source files (14.583 GiB) against official GWAS Catalog
  and Zenodo metadata, including URLs, builds, sample sizes, HTTP availability,
  upstream MD5 values, and cohort-overlap classifications.
- Added NAS-safe resumable downloads with expected-size, upstream-MD5, and
  local-SHA-256 validation without claiming unsupported filesystem flags.
- Added a persistent detached-screen supervisor (used because macOS background
  agents block on this user-mounted SMB share), a compact progress command, and
  regression tests that preserve the original immutable-file behavior by
  default.
- Extracted and source-validated the 19 published cytokine cis leads from the
  official supplementary workbook, preserving its GRCh37 coordinates separately
  from the GWAS Catalog harmonized GRCh38 coordinates. Thirteen leads enter the
  prespecified source-heterogeneity exclusion sensitivity, five are retained,
  and IL-18 remains explicitly heterogeneity-not-estimable.
- Froze GRCh37 gene plus/minus 300-kb cis regions for all nine endothelial
  proteins from authoritative gene-coordinate sources before inspecting their
  ED associations.
- Froze the five single-instrument microbial-function total effects; all five
  were estimable against FinnGen and none survived the five-test BH family.
- Added restartable target extraction for the five microbial-function SNPs and
  the cytokine cis leads, with explicit source-missing rows and cross-build
  separation.
- Ran the complete 40-trait cytokine-to-ED screening family: 18 of 19 cis leads
  harmonised to FinnGen, none survived BH FDR, and the sole nominal CCL11 result
  is ineligible for causal interpretation because it fails multiplicity, known
  partial-overlap, and source-heterogeneity gates.
- Added the complete 200-row cytokine X-to-M result skeleton so unavailable
  files remain pending rather than disappearing from the denominator; final FDR
  labels remain disabled until all 40 cytokine sources are verified.
- Added a streaming SCALLOP parser that extracts the five microbial-function
  target variants plus genome-wide-significant, F>10 variants inside each
  frozen endothelial cis interval without fully decompressing multi-gigabyte
  source files.
- Completed and reverified all 49 first-wave files (14.583 GiB) against
  expected bytes, upstream MD5, and local SHA-256; no partial files remain.
- Made cytokine source verification allele-orientation aware and invariant to
  the documented common beta/SE rescaling in indirectly recovered public
  meta-analysis effects, while retaining exact rsID, direction, Z, and P-value
  gates.
- Retained valid SCALLOP indels as pre-LD cis candidates rather than rejecting
  an entire protein extract, then mapped candidates by GRCh37 coordinate and
  alleles to the ancestry-matched 1000G EUR reference.
- Mapped 371 of 1,476 endothelial cis candidates uniquely and clumped them to
  11 independent cis-pQTLs across seven proteins. All 11 harmonised to FinnGen;
  no endothelial M-to-ED or X-to-M effect survived its frozen BH family.
- Completed both product-of-coefficients families: 80 of 200 cytokine and 35 of
  45 endothelial paths were estimable, but none survived FDR and no path passed
  both component gates. Colocalization was not triggered and the prespecified
  stopping rule blocks broad metabolite or immune-cell expansion.

## 2026-07-20

- Preserved the frozen NO-GO decision for positive causal claims while adding
  an explicitly bounded publication path for a transparent negative report.
- Built the IJIR-first v0.1 submission package with a 187-word abstract,
  1,812-word main text, title page, cover letter, STROBE-MR checklist, two
  editable main tables, two 600-dpi figures, and a ten-sheet supplementary
  workbook.
- Added explicit authorship, correspondence, funding, competing-interest,
  data-availability, and post-freeze LLM-use statements; retained author CRediT
  approval and the public repository DOI as visible pre-submission gates.
- Recorded lead-author confirmation of the CRediT statement, correspondence
  address, public repository authorization, and LLM disclosure; replaced the
  ambiguous Markdown asterisk with a dagger correspondence marker so Chunhui
  Liu's name renders in roman type.
- Added public-release metadata (`CITATION.cff`, `.zenodo.json`), dual licensing,
  and a release audit checklist; created the public GitHub repository at
  `https://github.com/DuXC/gut-microbiome-ed-mr` with a repository-scoped deploy
  key instead of granting GitHub CLI access to private repositories.
- Published GitHub release `v0.1.0`; verified Zenodo version DOI
  `10.5281/zenodo.21456671` and concept DOI `10.5281/zenodo.21456670`; inserted
  the live identifiers into the manuscript, cover letter, citation metadata,
  README, and supplementary workbook source.

- Migrated the completed project tree to the `DuXC_PhD_OS` NAS SMB share while
  preserving the original absolute project path.
- Confirmed all 5,177 manifest paths and byte sizes after migration.
- Recomputed SHA-256 for a deterministic 13-file, 2.149-GB cross-dataset sample;
  all values matched the versioned receipts.
- Replaced filesystem-flag assumptions on SMB with an explicit
  manifest-plus-hash integrity boundary; analysis remains prohibited from
  writing under `03_data/raw/`.
- Added schema-validated, stream-filtered exposure candidate extraction with
  four-worker parallelism, atomic Parquet shards, SHA-256 restart receipts, and
  accession-specific YAML metadata.
- Audited Swedish-to-HUNT biological-label mapping without fuzzy matching;
  unmatched hMGS labels remain blocked pending an authoritative crosswalk.
- Preserved valid upstream `#NA` rsID variants by coordinate and alleles for
  later reference-panel mapping instead of silently dropping them.
- Completed the 2,581-accession exposure pass: 237,364 exploratory-superset
  candidates, including 8,719 genome-wide-significant rows, in 163 verified
  Parquet shards (11 MB total) with no zero-candidate traits.
- Bound metadata caches and candidate receipts to both the manifest and schema
  code SHA-256 values so code changes invalidate stale processed outputs.
- Added a reproducible high-density 1000 Genomes Phase 3 GRCh37 EUR reference
  build from the official PLINK 2 source, with source URLs, byte counts, and
  SHA-256 receipts.
- Normalized exposure chromosome `23` to reference chromosome `X`, preventing
  valid X-linked instruments from being misclassified as absent; the final
  candidate reference contains 171,720 biallelic SNPs across 503 EUR samples.
- Completed ancestry-matched LD clumping at `r² = 0.001` within 10,000 kb for
  both prespecified tiers and all 2,581 traits using eight balanced workers.
- Retained 272 primary and 24,867 exploratory instrument rows in the Swedish
  discovery data, and 157 primary and 17,999 exploratory rows in HUNT; only one
  Swedish trait with a genome-wide signal lacked any allele-matched primary
  reference variant.
- Added reference-mapping audits, the complete unmapped-primary ledger, and a
  hash-bound clumping receipt covering 43,295 retained trait-tier instrument
  rows.
- Reassembled all eight ED 2025 byte-range parts into three checksum-bound,
  gzip-valid EUR, AFR, and cross-ancestry outcome streams.
- Extracted the 36,290 distinct clumped reference IDs from FinnGen R12 and the
  three ED 2025 streams without materializing uncompressed whole-outcome files.
- Preserved 92 FinnGen multiallelic rsIDs as allele-specific records instead of
  silently selecting an arbitrary alternate allele.
- Declared FinnGen R12 as the primary log-odds outcome and retained the ED 2025
  METAL Z/weight releases on an explicit standardized sensitivity scale; the
  known FinnGen overlap prevents treating them as independent replication.
- Harmonised all four outcome layers by rsID and alleles across declared genome
  builds, with chromosome checks, auditable multiallelic selection, and strict
  frequency-based palindrome handling. The FinnGen layer retained 41,440 of
  43,295 trait-tier instrument rows (95.72%).
- Ran 11,828 prespecified exposure–outcome–tier pairs with deterministic
  weighted-median bootstraps across eight independent R workers, retaining
  42,944 method rows and explicit non-estimable/failed records.
- Prevented two-SNP underdispersion from creating spuriously precise IVW
  results by bounding the multiplicative random-effects residual scale below at
  one; 117 MR-RAPS rows with non-convergence or multiple-root warnings were
  marked failed.
- Froze the forward-primary family at 230 Swedish microbiome traits before
  association screening. Of 218 estimable primary effects, seven were nominal
  at `P < 0.05` and none survived BH FDR (minimum `q = 0.942`).
- Built 24 independent reverse ED instruments from 479 genome-wide-significant
  EUR candidates; 437 candidates mapped to the ancestry-matched LD reference,
  and retained instruments had minimum F = 30.21.
- Extracted the 24 reverse instruments from all 1,572 Swedish microbiome GWAS
  files with restartable per-accession receipts, explicit `.tsv`/`.tsv.gz`
  handling, pipe-failure propagation, and one-accession dynamic load balancing.
  The final compact layer contains 26,366 matched rows with no empty traits.
- Harmonised 24,794 reverse SNP--trait rows, with 15--17 instruments available
  per trait, one unresolved palindromic SNP excluded per trait, and zero allele
  mismatches.
- Ran 1,572 reverse primary effects and 6,288 total method rows. Seventy-seven
  reverse effects were nominal at `P < 0.05`, none survived BH FDR (minimum
  `q = 0.967`), and 104 MR-RAPS rows with non-convergence or multiple roots were
  retained as explicit failures.
- Combined the frozen 230-test forward and 1,572-test reverse families. The
  global Bonferroni threshold is `2.774695×10⁻⁵`; neither direction had an
  FDR signal, no forward effect passed every replication gate, and the final
  decision is `NO-GO`.
- Added a final receipt binding the forward/reverse inputs, replication audit,
  combined multiplicity table, decision table, and finalization code by SHA-256.

## 2026-07-10

- Established the approved design, implementation plan, and analysis-governance baseline for the gut microbiome–ED MR rebuild.
- Hardened secret exclusions, deterministic multiplicity and replication gates, and project-relative provenance receipts.
- Externalized Git metadata to APFS, removed multiplicity/replication dependency cycles, and made manifest reruns idempotent.
