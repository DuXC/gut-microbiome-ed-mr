# Changelog

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
