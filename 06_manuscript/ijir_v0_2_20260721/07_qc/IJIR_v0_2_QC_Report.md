# IJIR v0.2 manuscript-package QC report

Date: 2026-07-21

## Outcome

The IJIR-first transparent-negative manuscript package with the prespecified
mechanistic extension is technically complete for author read-through and
portal staging. The v0.1 primary analysis, title, and NO-GO boundary remain
unchanged. The extension is reported as a bounded supplementary falsification
analysis rather than evidence of mediation.

The full repository test suite passed after package generation: 847 tests, 0
failures, 0 warnings, and 0 skips. The final mechanistic validator independently
re-read and verified 49 raw files (15,658,798,006 bytes; 14.583 GiB), seven
result families, 544 result rows, zero FDR signals, and the frozen stopping
decision.

## Journal limits

- Title: 134 characters; IJIR maximum 150.
- Abstract: 187 words; IJIR maximum 200.
- Main text (Introduction through Discussion): 2,449 words; IJIR maximum 3,000.
- Display items: 2 figures plus 2 tables; IJIR maximum 7 combined.
- References: 26; IJIR maximum 50.

## Primary-analysis checks

- Forward family: 230 eligible, 218 estimable, 7 nominal, minimum
  P=0.007196, minimum q=0.9416.
- Exact HUNT validation: 97 exact labels; the two nominal exact-label traits had
  P=0.4273 and P=0.1752.
- Reverse family: 1,572 estimable, 77 nominal, minimum P=0.001861, minimum
  q=0.9673; 24 independent ED instruments; minimum F=30.21.
- Global threshold: 2.774695×10−5.
- No forward or reverse effect survived its direction-specific FDR family, and
  no nominal result is presented as replicated causal evidence.

## Mechanistic-extension checks

- Microbial function to ED: 5/5 estimable; minimum P=0.113883; minimum
  q=0.482172.
- Cytokine to ED: 18/40 estimable; minimum P=0.035812; minimum q=1.000000.
- Microbial function to cytokine: 169/200 estimable; minimum P=0.004728;
  minimum q=0.945612.
- Cytokine indirect effect: 80/200 estimable; minimum P=0.196244; minimum
  q=1.000000.
- Endothelial protein to ED: 7/9 estimable; minimum P=0.071024; minimum
  q=0.395285.
- Microbial function to endothelial protein: 45/45 estimable; minimum
  P=0.010875; minimum q=0.489376.
- Endothelial indirect effect: 35/45 estimable; minimum P=0.310016; minimum
  q=1.000000.
- The nominal CCL11 mediator-to-ED estimate (P=0.0358; q=1.0000) is explicitly
  bounded by partial FinnGen overlap and failure of the prespecified
  source-heterogeneity sensitivity; it is not interpreted as mediation.
- The endothelial screen retained 11 clumped cis-pQTLs across seven of nine
  proteins. PECAM-1 and t-PA were non-estimable.
- No pathway passed the joint component and product gates. Colocalization was
  not triggered, proportion mediated was not calculated, and the workflow
  stopped before broad metabolite or immune-cell expansion as prespecified.

## File and rendering checks

- Main manuscript rendered to 18 pages with continuous line numbering and page
  numbers. The title page and cover letter each rendered to one page, and the
  STROBE-MR checklist rendered to two pages.
- Every rendered DOCX page was visually inspected. No clipping, blank pages,
  broken glyphs, missing text, or overlapping elements were observed.
- Figure 1 and Figure 2 retain the validated v0.1 analysis displays. Both TIFFs
  are 600 dpi, with PDF, SVG, PNG, and preview versions retained.
- Table 1 and Table 2 are separate editable XLSX workbooks.
- Supplementary Data 1 contains 25 worksheets, including the complete seven
  mechanistic result families, denominators, instrument receipt, source
  metadata, overlap matrix, raw manifest, full-validation receipt, stopping
  decision, and data dictionary.
- All 27 spreadsheet previews were visually inspected. OOXML checks found zero
  formula cells, macros, external workbook links, or corrupt ZIP members in the
  three upload workbooks.
- No placeholder markers remain in the submission documents. Third-party raw
  GWAS payloads are not redistributed.
- Exact SHA-256 values and file sizes for all upload artifacts are frozen in
  `IJIR_v0_2_submission_manifest_sha256.csv`.

## Authorship and declarations

- Author order: Xiancheng Du, Shuchun Tao, Kaihua Xue, Yongkun Zhu, Ming Chen,
  Chunhui Liu, Chao Sun.
- Ming Chen, Chunhui Liu, and Chao Sun are listed as manuscript corresponding
  authors; Chao Sun is designated as the sole portal contact if only one is
  accepted.
- Funding identifies ZXFZ2026021 (Chao Sun) and 2024M750457 (Chunhui Liu).
- All authors declare no competing interests.
- The approved CRediT statement, correspondence address, and transparent
  large-language-model statement are retained.

## Archive and submission boundary

- The public Zenodo version DOI `10.5281/zenodo.21456671` remains the frozen
  v0.1 archive. The concept DOI is `10.5281/zenodo.21456670`.
- The v0.2 mechanistic code and receipts are versioned on the development
  branch, but v0.2 must not be described as Zenodo-archived until a separate
  release is created after author approval.
- The package has not been uploaded to or submitted through the IJIR portal.

## Open item before submission

Optional ORCIDs remain blank for Shuchun Tao, Kaihua Xue, Yongkun Zhu, Ming
Chen, and Chunhui Liu. No mandatory author, data, analysis, or database item is
currently missing.
