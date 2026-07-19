# Changelog

## 2026-07-20

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

## 2026-07-10

- Established the approved design, implementation plan, and analysis-governance baseline for the gut microbiome–ED MR rebuild.
- Hardened secret exclusions, deterministic multiplicity and replication gates, and project-relative provenance receipts.
- Externalized Git metadata to APFS, removed multiplicity/replication dependency cycles, and made manifest reruns idempotent.
