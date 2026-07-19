# NAS migration audit, 2026-07-20

## Scope

The completed `04_GUT_ED_MR_REBUILD_20260710` project was moved from the prior
external volume to the NAS SMB share mounted at the unchanged absolute path:

`/Volumes/DuXC_PhD_OS/04_PAPERS_论文发表/04_GUT_ED_MR_REBUILD_20260710`

The share is mounted from `DXP4800PRO-DUXC` over SMB. Git metadata remains on the
internal APFS volume at
`/Users/duxiancheng/.codex/gitdirs/04_GUT_ED_MR_REBUILD_20260710.git`.

## Audit results

- Source inventory rows: 5,177.
- Manifest receipt rows: 5,177.
- Manifest bytes: 345,357,963,685.
- Missing payloads after migration: 0.
- Payload size mismatches after migration: 0.
- Deterministic cross-dataset SHA-256 sample: 13 files, 2.149 GB.
- Sample SHA-256 matches: 13/13.
- Machine-readable sample audit:
  `08_qc/nas_migration_hash_sample_20260720.csv`.

All 345.358 GB had passed the explicit full SHA-256 and upstream-MD5 verification
before the migration. The post-migration audit adds complete path/size validation
and a deterministic cross-dataset content-hash sample; it does not claim that the
entire 345.358 GB was rehashed again after copying.

## Integrity boundary on SMB

The SMB mount reports payloads as writable mode `0777` and does not preserve or
expose the prior local `uchg` evidence. Therefore filesystem mode or flags are not
used as proof of immutability on the NAS.

The authoritative integrity controls are:

1. the Git-versioned nine-column `MANIFEST.csv`;
2. the receipt SHA-256 for every payload;
3. the upstream MD5 checksum in `00_admin/source_inventory.csv`;
4. the rule that code never writes to `03_data/raw/`;
5. all derived data are written to `03_data/processed/` or later output folders;
6. any content verification on SMB disables only the filesystem-freeze check and
   still validates size, SHA-256, and upstream MD5.

AppleDouble `._*` files created by macOS/SMB are metadata sidecars. They remain
excluded from Git and must never be ingested as GWAS payloads.
