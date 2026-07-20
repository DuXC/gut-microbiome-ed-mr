# Public release checklist

Version: 0.1.0  
Date: 2026-07-20

## Completed before publication

- [x] Repository history and current tree scanned for common private-key,
  GitHub-token, cloud-key, and Zenodo-token patterns.
- [x] No files under `03_data/raw/` are tracked.
- [x] No compressed GWAS, PLINK, VCF/BCF, or Parquet payloads are tracked.
- [x] Largest tracked blob is below GitHub's 100 MB single-file limit.
- [x] Author order, affiliations, two available ORCIDs, funding, and competing
  interests are confirmed.
- [x] `CITATION.cff`, `.zenodo.json`, and dual-license scope are present.
- [x] Frozen NO-GO decision for positive causal claims is preserved.
- [x] Repository test suite: 785 passed, 0 failed, 0 warned, 0 skipped.

## Required at release

- [x] Insert the public GitHub URL into `CITATION.cff` and README.
- [x] Enable the GitHub repository in Zenodo before creating the release.
- [x] Create GitHub release/tag `v0.1.0`.
- [x] Verify the Zenodo deposit metadata and publish the record.
- [x] Insert the minted concept/version DOI in the manuscript Data Availability
  statement, `CITATION.cff`, README, and supplementary source summary.
- [x] Rebuild and rerender the manuscript after DOI insertion.

Published identifiers:

- Version DOI: `10.5281/zenodo.21456671`
- Concept DOI: `10.5281/zenodo.21456670`

## Explicitly excluded

- Third-party raw GWAS summary statistics.
- Local credentials, tokens, browser/session data, and `.env` files.
- Generated temporary shards and package libraries.
