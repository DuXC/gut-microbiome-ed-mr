# IJIR v0.1 manuscript-package QC report

Date: 2026-07-20

## Outcome

The IJIR-first transparent-negative manuscript package is technically complete
and internally consistent. All author-level confirmations were received on
2026-07-20. The remaining operational gate is insertion of the public repository
URL/DOI before portal upload.

The full repository test suite passed after package generation: 785 tests, 0
failures, 0 warnings, and 0 skips.

## Journal limits

- Title: 134 characters; IJIR maximum 150.
- Abstract: 187 words; IJIR maximum 200.
- Main text (Introduction through Discussion): 1,812 words; IJIR maximum 3,000.
- Display items: 2 figures plus 2 tables; IJIR maximum 7 combined.
- References: 24; IJIR maximum 50.

## Numerical and evidential checks

- Forward family: 230 eligible, 218 estimable, 7 nominal, minimum
  P=0.007196, minimum q=0.9416.
- Exact HUNT validation: 97 exact labels; the two nominal exact-label traits had
  P=0.4273 and P=0.1752.
- Reverse family: 1,572 estimable, 77 nominal, minimum P=0.001861, minimum
  q=0.9673; 24 independent ED instruments; minimum F=30.21.
- Global threshold: 2.774695×10−5.
- The text retains the frozen NO-GO boundary for a positive causal claim and
  does not promote any nominal association.
- FinnGen R12 is consistently reported as 2,886 cases and 215,272 controls.
- The 2025 ED meta-analysis is consistently treated as a known-overlap
  sensitivity source on its standardized scale, not independent replication or
  an odds-ratio outcome.

## File and rendering checks

- Main manuscript rendered to 15 pages with continuous line numbering and page
  numbers; title page, cover letter, and two-page STROBE-MR checklist also
  rendered successfully.
- All rendered pages were inspected in montage form; no clipping, blank pages,
  broken glyphs, or overlapping elements were observed.
- Figure 1 and Figure 2 were visually inspected after replacing the unsupported
  arrow glyph. Both TIFFs are 600 dpi (4320×3420 and 4320×2040 pixels), with
  PDF, SVG, PNG, and preview versions retained.
- Table 1 and Table 2 are separate editable XLSX workbooks.
- Supplementary Data 1 contains 10 worksheets: README, Source Summary, GWAS
  Source Ledger, Forward Primary, Forward Replication, Reverse Primary,
  Instrument Inventory, Method Status, Final Receipt, and Data Dictionary.
- All 12 spreadsheet previews were visually inspected. OOXML inspection found
  zero formula cells in all three upload workbooks; therefore there are no
  macros, calculated cells, or external workbook dependencies to resolve.
- Third-party raw GWAS payloads are excluded from the supplementary workbook.

## Authorship and declarations

- Author order matches the lead-author instruction: Xiancheng Du, Shuchun Tao,
  Kaihua Xue, Yongkun Zhu, Ming Chen, Chunhui Liu, Chao Sun.
- Ming Chen, Chunhui Liu, and Chao Sun are listed as manuscript corresponding
  authors; Chao Sun is designated as the sole portal contact if required.
- Funding statements exactly identify ZXFZ2026021 (Chao Sun) and 2024M750457
  (Chunhui Liu).
- No competing interests are declared for all authors.
- The Methods section includes the journal-required transparent LLM-use
  statement and bounds its role to post-freeze editing, document generation,
  and consistency checking.

## Open items before submission

1. Public code/archive URL and DOI for the Data Availability statement. This is
   the only `[TODO: ...]` remaining in the manuscript.
2. Optional ORCIDs for the five authors whose ORCIDs are not yet recorded.

No new database download or new MR analysis is required for this v0.1 package.
