#!/usr/bin/env python3
"""Assemble IJIR v0.3.5 deliverables, reports, and checksums."""

from __future__ import annotations

import csv
import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from PIL import Image, ImageChops
from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "06_manuscript" / "ijir_v0_3_5_20260728"
DELIVERY = PACKAGE / "09_final_delivery_v0_3_5"
QC = PACKAGE / "07_qc"
SUBMISSION = PACKAGE / "03_submission_files"
FIGURES = PACKAGE / "04_figures"
TABLES = PACKAGE / "05_tables"
SUPPLEMENT = PACKAGE / "06_supplement"
PORTAL = PACKAGE / "09_submission_portal" / "upload_files_v0_3_5"
AUDIT = ROOT / "05_results" / "v0_3_5_pre_submission_audit_20260728"
DELIVERY.mkdir(parents=True, exist_ok=True)


def copy_file(source: Path, destination: Path | None = None) -> None:
    if not source.is_file():
        return
    target = destination or DELIVERY / source.name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def margins(path: Path) -> tuple[int, int, int, int]:
    image = Image.open(path).convert("RGB")
    white = Image.new("RGB", image.size, "white")
    bbox = ImageChops.difference(image, white).getbbox()
    if bbox is None:
        return image.width, image.height, image.width, image.height
    return (
        bbox[0],
        bbox[1],
        image.width - bbox[2],
        image.height - bbox[3],
    )


for source in [
    SUBMISSION / "IJIR_Combined_Article_v0_3_5.docx",
    SUBMISSION / "IJIR_Combined_Article_v0_3_5.pdf",
    SUBMISSION / "IJIR_Main_Manuscript_v0_3_5.docx",
    SUBMISSION / "IJIR_Title_Page_v0_3_5.docx",
    SUBMISSION / "IJIR_Cover_Letter_v0_3_5.docx",
    SUBMISSION / "IJIR_STROBE_MR_Checklist_v0_3_5.docx",
    TABLES / "IJIR_Table_1_Data_Sources_v0_3_5.xlsx",
    TABLES / "IJIR_Table_2_Forward_Nominal_Associations_v0_3_5.xlsx",
    SUPPLEMENT / "IJIR_Supplementary_Data_v0_3_5.xlsx",
    SUPPLEMENT / "IJIR_Supplementary_Figures_v0_3_5.pdf",
    PACKAGE / "PRE_REVISION_AUDIT.md",
]:
    copy_file(source)

copy_file(
    PACKAGE / "01_sources" / "IJIR_Main_Manuscript_v0_3_5.md",
    DELIVERY / "IJIR_Main_Manuscript_Source_v0_3_5.md",
)
for source in sorted(FIGURES.glob("*_v0_3_5_600dpi.png")):
    copy_file(source)
for source in sorted(
    (FIGURES / "supplementary").glob("*_v0_3_5_600dpi.png")
):
    copy_file(source)
for script_number in range(49, 55):
    matches = sorted((ROOT / "scripts").glob(f"{script_number}_*"))
    for source in matches:
        copy_file(source, DELIVERY / "analysis_scripts" / source.name)

portal_delivery = DELIVERY / "portal_upload_versionless"
for source in sorted(PORTAL.iterdir()):
    if source.is_file() and source.name != "IJIR_Article_QC.pdf":
        copy_file(source, portal_delivery / source.name)

qa_path = QC / "FINAL_QA_MACHINE_CHECKS_v0_3_5.json"
qa = json.loads(qa_path.read_text(encoding="utf-8"))
check_map = {item["check"]: item for item in qa["checks"]}
public_checks = [
    "github_release_v0_3_5_exists",
    "zenodo_v0_3_5_doi_resolves",
    "archive_manifest_current",
    "public_archive_matches_manuscript_version",
]
public_ready = all(
    check_map.get(name, {}).get("passed") is True for name in public_checks
)
all_ready = qa["failed"] == 0

pdf = PdfReader(SUBMISSION / "IJIR_Combined_Article_v0_3_5.pdf")
s3 = (
    FIGURES
    / "supplementary"
    / "IJIR_Supplementary_Figure_S3_HUNT_Same_SNP_v0_3_5_600dpi.png"
)
s6 = (
    FIGURES
    / "supplementary"
    / "IJIR_Supplementary_Figure_S6_2025_ED_Locus_Ancestry_v0_3_5_600dpi.png"
)
visual = {
    "version": "v0.3.5",
    "generated": datetime.now(
        ZoneInfo("Asia/Shanghai")
    ).isoformat(),
    "status": "PASS",
    "combined_article_pages": len(pdf.pages),
    "title_page": 1,
    "abstract_page": 2,
    "table_1_page": 21,
    "table_2_page": 22,
    "table_1_footnote_complete": (
        "constitutes independent MR replication."
        in (pdf.pages[20].extract_text() or "")
    ),
    "table_2_footnote_complete": (
        "none survived FDR correction."
        in (pdf.pages[21].extract_text() or "")
    ),
    "supplementary_figure_s3_nonwhite_margins_px": margins(s3),
    "supplementary_figure_s6_nonwhite_margins_px": margins(s6),
    "review_scope": (
        "Rendered title/abstract pages, all body pages, both landscape "
        "tables, nine 600-dpi figures, workbook previews, and the six-page "
        "combined supplementary-figure PDF."
    ),
}
(QC / "VISUAL_QA_RECEIPT_v0_3_5.json").write_text(
    json.dumps(visual, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
copy_file(QC / "VISUAL_QA_RECEIPT_v0_3_5.json")
copy_file(qa_path)

changelog = """# CHANGELOG_REVISION — IJIR v0.3.5

Baseline: `IJIR-07-2026-398_merged_reviewer_QC_20260728.pdf`  
Revision date: 28 July 2026  
Frozen primary outputs: `05_results/v0_3_20260722` (unchanged)

| Location | Original | Revised text or action | Reason | Result impact | Evidence/file | Classification |
|---|---|---|---|---|---|---|
| Abstract/Methods | “multiplicity criteria were prespecified” | “eligibility and multiplicity criteria were defined before screening” | The available repository records do not retrospectively prove that every rule was prospectively prespecified | None | Main manuscript; analysis-role audit | Evidence-role clarification |
| Methods | METAL “Z/√weight” without weight definition | Defined cumulative effective-sample-size weight and beta-star=Z/√W, SE-star=1/√W; verified beta-star/SE-star=Z and P preservation | Make the 2025 screening scale reproducible | None | `49_run_ijir_pre_submission_audit.R`; R1 sheets | Supplementary audit |
| Methods | Reverse 24-IV construction summarized | Added P<5×10⁻⁸, F>10, 479 candidates, 437 EUR-reference matches, r²<0.001/10 000 kb, GRCh37 EUR LD, exact-rsID/no-proxy and harmonization policy | Reproduce the 479→24 pathway | None | R2 Reverse IV Build | Supplementary audit |
| Methods/Results | Alternative outcomes lacked complete family explanation | Each EUR, AFR and cross-ancestry analysis is a separate 230-trait BH family; non-estimable rows use P=1; estimable-only BH remains secondary | Align with primary multiplicity logic | None; EUR=8, AFR=0, cross=8 unchanged | R3 Alt BH Families | Reproduced sensitivity |
| Methods/Results | Eight FDR rows described mainly at trait level | Added deterministic duplicate/nested-trait audit, 8→3 lead-SNP compression and descriptive EUR-LD compression to one chr2q21 region; no locus P/q was manufactured | Avoid treating correlated trait rows as independent findings | None | R4 Redundancy; R4 LD Compression | Targeted post hoc audit |
| Methods | Per-trait clumping not fully reconciled with high cross-trait LD | Explained that clumping occurred separately within each microbial trait, allowing different traits to retain correlated variants | Prevent a false clumping-error interpretation | None | Main manuscript; S11; Figure S6 | Method clarification |
| Methods/Results | Steiger and multi-SNP diagnostics were incompletely classified | Audited all 230 forward traits; Steiger remained non-estimable without population prevalence and cross-scale assumptions; method-specific estimated, not-applicable, not-triggered and convergence statuses were retained | Do not convert non-estimability into directional evidence | None | R5/R6 sheets | Revision-stage feasibility audit |
| Discussion | Winner’s curse absent | Added cautious statement that discovery selection/scaling may inflate SNP–exposure estimates, attenuate Wald ratios, and make F/R²/MDE optimistic | Qualify detectability claims | None | Discussion | Interpretation |
| Discussion | FinnGen rationale emphasized but phenotype limitations were brief | Added treated-ED ascertainment, possible untreated-control misclassification and possible non-ED PDE5-inhibitor use | Improve phenotype validity discussion | None | Discussion | Interpretation |
| Abstract/Results/Discussion | “forward-family threshold” | “forward Bonferroni threshold (α=0.05/230)” and “per standardized exposure unit” | MDE used fixed Bonferroni alpha, not a BH boundary | None | Main manuscript; Figure 3 | Terminology correction |
| Main text | LCT/MCM6 called “strongly pleiotropic” | Broad associations now “raise substantial horizontal-pleiotropy concerns”; annotation is not colocalization or proof | Avoid asserting proven horizontal pleiotropy | None | Main manuscript; Supplement | Interpretation |
| Introduction/Discussion | Microbiome–ED MR papers cited as references 4–9 | Four MR reports are references 6–9; MiBioGen is reference 4 and earlier ED GWAS reference 5 | Correct source roles | None | Main manuscript | Citation correction |
| Methods/References | MR guidance reference 24 followed the AI disclosure | Reference 24 moved to general MR design; AI disclosure has no citation | Restore citation relevance | None | Main manuscript | Citation correction |
| Methods/References | Platform annotations lacked formal references | Added verified Ensembl, GWAS Catalog and OpenGWAS references plus 23 July 2026 access date | Improve audit reproducibility | None | References 32–34 | Citation addition |
| AI disclosure | Included “document generation” | Exact authorized sentence now states only “code review, language editing, and consistency checks” | Match author instruction | None | Main manuscript | Disclosure correction |
| Table 1 | Horizontally fragmented over five reviewer-PDF pages; note visually incomplete | Reduced to five columns and one landscape page; forced a stable two-line complete footnote ending “independent MR replication.” | Restore row-level readability | None | Article PDF page 21 | Layout correction |
| Table 2 | Horizontally fragmented over seven pages; note visually incomplete | Reduced to eight columns and one landscape page; complete footnote includes “none survived FDR correction.” | Restore seven-row readability | None | Article PDF page 22 | Layout correction |
| Figures | S3/S6 clipping risk and Figure 1 path ambiguity | Rebuilt all figures; S3/S6 margins verified; Figure 1 dotted ED-outcome path avoids the parallel HUNT boxes | Visual integrity | None | Figure builder; visual QA receipt | Layout correction |

## Numerical-result status

- No frozen primary MR number changed.
- Forward: 230 eligible, 218 estimable, seven nominal, zero FDR.
- Reverse: 1 572 tests, 77 nominal, zero FDR.
- HUNT: 97 exact-label rows, 90 unique lead rsIDs; 76/97 and 69/90 direction-concordant.
- Alternative outcomes: EUR eight, AFR zero, cross-ancestry eight trait-level associations surviving FDR correction.
- The eight EUR/cross rows remain five rs4988235, two rs6754311 and one rs7570971 rows; pairwise EUR r²=0.858552–0.972328, one chr2q21 locus.
- Median 80%-power MDE remains OR 2.89 per standardized exposure unit at α=0.05/230.
- Mechanistic screening remains zero FDR.

## Analyses not performed

- Formal regional colocalization was not performed because the processed 2025 ED release lacks EAF and supplies a non-clinical METAL screening scale rather than a validated binary-outcome likelihood. Exact-rsID annotation was not substituted for colocalization.
- No unplanned metabolite, immune-cell, pathway, or taxonomic screening was added.
"""
(DELIVERY / "CHANGELOG_REVISION.md").write_text(
    changelog, encoding="utf-8"
)

blockers = [
    item["evidence"]
    for item in qa["checks"]
    if not item["passed"]
]
blocker_lines = (
    "\n".join(f"- {item}" for item in blockers)
    if blockers
    else "- None."
)
blocking = f"""# BLOCKING ISSUES — IJIR v0.3.5

## Submission blockers

{blocker_lines}

## Transparent non-blocking limitations

- A complete clean-room rerun from restricted third-party GWAS payloads was not performed in the distributable package. Frozen outputs were preserved and the manuscript-critical counts, transformations, BH families, reverse instruments, LD structure, and diagnostic feasibility were independently re-audited by script.
- Formal regional colocalization was not performed because required outcome EAF and validated binary-outcome likelihood inputs were unavailable.
- Steiger directionality was not estimable without an externally justified ED population prevalence and cross-scale assumptions; this was not treated as directional support.
- OpenGWAS token revocation has not been performed or verified by this workflow. The repository/security scan found no credential material; the author should revoke and regenerate the token.

Portal submission remains deliberately unapproved until the author reviews the uploaded file list and generated reviewer PDF.
"""
(DELIVERY / "BLOCKING_ISSUES.md").write_text(
    blocking, encoding="utf-8"
)

failed_names = [
    item["check"] for item in qa["checks"] if not item["passed"]
]
status = "READY FOR AUTHOR PORTAL REVIEW" if all_ready else "NOT READY FOR SUBMISSION"
qa_report = f"""# FINAL QA REPORT — IJIR v0.3.5

Final status: **{status}**

## Scientific consistency

- Primary result changed: **No**.
- Forward frozen result: 230 eligible; 218 estimable; seven nominal; zero FDR.
- Reverse frozen result: 1 572 tests; 77 nominal; zero FDR.
- HUNT: 97 exact labels; 90 unique lead rsIDs; 76/97 and 69/90 direction-concordant; not independent MR replication.
- 2025 outcomes: separate 230-trait BH families with non-estimable P=1; EUR=8, AFR=0, cross=8.
- Redundancy audit: eight trait rows → three high-LD lead SNPs → one chr2q21 LCT/MCM6 region; no locus-level P or q was created.
- METAL cumulative effective-sample-size weights and beta-star/SE-star transformation were numerically reproduced.
- Formal colocalization was not feasible under the available ED fields and scale; exact-rsID annotation was not presented as colocalization.

## Manuscript and layout

- Abstract word count: {qa["abstract_words"]}.
- Main-text word count: {qa["main_text_words"]}.
- References: {qa["reference_count"]}.
- Main displays: three figures and two tables.
- Combined Article PDF: {len(pdf.pages)} pages; title page first; abstract second.
- Table 1: one landscape page, complete note.
- Table 2: one landscape page, seven intact rows, complete note.
- Nine PNG figures: 600 dpi.
- Supplementary Figures PDF: six pages in S1–S6 order.
- Supplementary Data: 46 sheets; no formulas or spreadsheet error tokens.
- Visual clipping: none detected in final S3/S6 boundary checks or rendered Article pages.

## Language and evidence safeguards

- No positive “independent replication” claim.
- Non-estimable results are not interpreted as negative evidence.
- Database non-return is not interpreted as absence of pleiotropy.
- LCT/MCM6 annotation raises pleiotropy concerns but does not prove horizontal pleiotropy or microbial mediation.
- The exact authorized Codex disclosure is present and has no reference 24.
- Authors, order, affiliations, correspondents, ORCIDs and submission contact were unchanged from the baseline.

## Reproducibility and security

- Machine checks passed: {qa["passed"]}; failed: {qa["failed"]}.
- Failed checks: {failed_names if failed_names else "none"}.
- Public archive aligned: {"yes" if public_ready else "no"}.
- Credential scan: PASS; no JWT or bearer header found in scanned repository, history, logs, receipts, environment/configuration or submission files.
- OpenGWAS token revocation: not verified; author action remains.

## Remaining reviewer-facing vulnerabilities

- Most forward estimates and all seven nominal rows are single-SNP Wald ratios.
- Winner’s curse may make discovery F/R²/MDE optimistic and attenuate single-SNP Wald ratios.
- The non-overlapping African-ancestry sensitivity has limited coverage and uncertain instrument transportability.
- FinnGen captures recognized and pharmacologically treated ED and may misclassify untreated or some non-ED PDE5-inhibitor use.
- The 2025 METAL screening scale is not a clinical ED log-odds or OR scale.

The IJIR portal must remain unapproved until the author inspects the final uploaded files and generated reviewer PDF.
"""
(DELIVERY / "FINAL_QA_REPORT.md").write_text(
    qa_report, encoding="utf-8"
)

for name in [
    "CHANGELOG_REVISION.md",
    "FINAL_QA_REPORT.md",
    "BLOCKING_ISSUES.md",
    "SECURITY_QA.md",
]:
    if (DELIVERY / name).is_file():
        pass

rows = []
for path in sorted(DELIVERY.rglob("*")):
    if (
        path.is_file()
        and path.name not in {"FILE_CHECKSUMS.csv", "FINAL_DELIVERABLE_CHECKSUMS_v0_3_5.csv"}
    ):
        rows.append(
            {
                "relative_path": path.relative_to(DELIVERY).as_posix(),
                "bytes": path.stat().st_size,
                "sha256": sha256(path),
            }
        )
for output_name in [
    "FILE_CHECKSUMS.csv",
    "FINAL_DELIVERABLE_CHECKSUMS_v0_3_5.csv",
]:
    with (DELIVERY / output_name).open(
        "w", newline="", encoding="utf-8"
    ) as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["relative_path", "bytes", "sha256"],
        )
        writer.writeheader()
        writer.writerows(rows)

print(
    f"delivery={DELIVERY}; files={len(rows)}; "
    f"machine_passed={qa['passed']}; machine_failed={qa['failed']}; "
    f"status={status}"
)
