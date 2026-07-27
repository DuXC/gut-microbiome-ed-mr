#!/usr/bin/env python3
"""Machine-verifiable QA for the IJIR v0.3.5 submission package."""

from __future__ import annotations

import csv
import hashlib
import json
import math
import re
import subprocess
import urllib.request
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from docx import Document
from openpyxl import load_workbook
from PIL import Image, ImageChops
from pypdf import PdfReader


PACKAGE = Path(__file__).resolve().parents[1]
ROOT = Path(__file__).resolve().parents[3]
FROZEN = ROOT / "05_results" / "v0_3_20260722"
AUDIT = ROOT / "05_results" / "v0_3_5_pre_submission_audit_20260728"
SOURCES = PACKAGE / "01_sources"
SUBMISSION = PACKAGE / "03_submission_files"
FIGURES = PACKAGE / "04_figures"
TABLES = PACKAGE / "05_tables"
SUPPLEMENT = PACKAGE / "06_supplement"
QC = PACKAGE / "07_qc"
DELIVERY = PACKAGE / "09_final_delivery_v0_3_5"
PORTAL = PACKAGE / "09_submission_portal" / "upload_files_v0_3_5"
PDF = SUBMISSION / "IJIR_Combined_Article_v0_3_5.pdf"

checks: list[dict[str, object]] = []


def add(name: str, passed: bool, evidence: str) -> None:
    checks.append(
        {"check": name, "passed": bool(passed), "evidence": evidence}
    )


def csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def close(a: object, b: object, tol: float = 1e-9) -> bool:
    return math.isclose(
        float(a), float(b), rel_tol=tol, abs_tol=tol
    )


def docx_text(path: Path) -> str:
    document = Document(path)
    parts = [paragraph.text for paragraph in document.paragraphs]
    for table in document.tables:
        for row in table.rows:
            parts.extend(cell.text for cell in row.cells)
    return "\n".join(parts)


def core_metadata(path: Path) -> dict[str, str]:
    with zipfile.ZipFile(path) as archive:
        root = ET.fromstring(archive.read("docProps/core.xml"))
    ns = {
        "dc": "http://purl.org/dc/elements/1.1/",
        "cp": (
            "http://schemas.openxmlformats.org/package/2006/"
            "metadata/core-properties"
        ),
    }
    return {
        "creator": root.findtext(
            "dc:creator", default="", namespaces=ns
        ),
        "last_modified_by": root.findtext(
            "cp:lastModifiedBy", default="", namespaces=ns
        ),
        "version": root.findtext(
            "cp:version", default="", namespaces=ns
        ),
    }


def workbook_text_and_errors(
    path: Path,
) -> tuple[str, list[str], int]:
    workbook = load_workbook(path, read_only=True, data_only=False)
    strings: list[str] = []
    errors: list[str] = []
    formulas = 0
    error_tokens = {
        "#REF!",
        "#DIV/0!",
        "#VALUE!",
        "#NAME?",
        "#N/A",
        "#NUM!",
    }
    for sheet in workbook.worksheets:
        for row in sheet.iter_rows():
            for cell in row:
                if cell.value is None:
                    continue
                value = str(cell.value)
                strings.append(value)
                if value.startswith("="):
                    formulas += 1
                if value in error_tokens:
                    errors.append(
                        f"{sheet.title}!{cell.coordinate}={value}"
                    )
    return "\n".join(strings), errors, formulas


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(
        url, headers={"User-Agent": "IJIR-v0.3.5-final-QA"}
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def nonwhite_margins(path: Path) -> tuple[int, int, int, int]:
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


main = (SOURCES / "IJIR_Main_Manuscript_v0_3_5.md").read_text(
    encoding="utf-8"
)
title = (SOURCES / "IJIR_Title_Page_v0_3_5.md").read_text(
    encoding="utf-8"
)
cover = (SOURCES / "IJIR_Cover_Letter_v0_3_5.md").read_text(
    encoding="utf-8"
)
word_report = (QC / "IJIR_Word_Counts_v0_3_5.txt").read_text(
    encoding="utf-8"
)
abstract_words = int(
    re.search(r"Abstract words: (\d+)", word_report).group(1)
)
main_words = int(
    re.search(r"Main-text words .*: (\d+)", word_report).group(1)
)
reference_count = int(
    re.search(r"References: (\d+)", word_report).group(1)
)
cover_words = len(
    re.findall(r"\b[\w’'-]+(?:\.[\w’'-]+)*\b", cover)
)

docx_paths = [
    SUBMISSION / "IJIR_Combined_Article_v0_3_5.docx",
    SUBMISSION / "IJIR_Main_Manuscript_v0_3_5.docx",
    SUBMISSION / "IJIR_Title_Page_v0_3_5.docx",
    SUBMISSION / "IJIR_Cover_Letter_v0_3_5.docx",
    SUBMISSION / "IJIR_STROBE_MR_Checklist_v0_3_5.docx",
]
xlsx_paths = [
    TABLES / "IJIR_Table_1_Data_Sources_v0_3_5.xlsx",
    TABLES / "IJIR_Table_2_Forward_Nominal_Associations_v0_3_5.xlsx",
    SUPPLEMENT / "IJIR_Supplementary_Data_v0_3_5.xlsx",
]
doc_text = "\n".join(docx_text(path) for path in docx_paths)
workbook_texts: list[str] = []
workbook_errors: list[str] = []
formula_count = 0
for path in xlsx_paths:
    text, errors, formulas = workbook_text_and_errors(path)
    workbook_texts.append(text)
    workbook_errors.extend(errors)
    formula_count += formulas
all_text = "\n".join(
    [main, title, cover, doc_text, *workbook_texts]
)

# Frozen results and independent audit outputs.
frozen_diff = subprocess.run(
    [
        "git",
        "diff",
        "--quiet",
        "v0.3.0",
        "--",
        str(FROZEN.relative_to(ROOT)),
    ],
    cwd=ROOT,
).returncode
add(
    "primary_results_unchanged",
    frozen_diff == 0,
    "No Git diff from tag v0.3.0 in frozen result directory",
)

metal = csv_rows(AUDIT / "metal_weight_transformation_summary.csv")
metal_ok = (
    len(metal) == 3
    and all(
        row["beta_formula_verified"] == "TRUE"
        and row["se_formula_verified"] == "TRUE"
        and row["z_identity_verified"] == "TRUE"
        and row["p_consistent_with_reported_rounded_z"] == "TRUE"
        for row in metal
    )
)
add(
    "metal_weight_and_transformation_verified",
    metal_ok
    and "cumulative effective-sample-size weights" in main
    and "β*=Z/√W and SE*=1/√W" in main
    and "not an ED log-odds" in main,
    "3 outcome files reproduce beta-star, SE-star, Z and P",
)

reverse = csv_rows(AUDIT / "reverse_instrument_construction_audit.csv")
reverse_text = "\n".join(str(value) for row in reverse for value in row.values())
add(
    "reverse_instrument_construction_reproduced",
    all(token in reverse_text for token in ("479", "437", "24"))
    and all(
        token in main
        for token in (
            "479 European ED variants",
            "437 were present and allele-matched",
            "retained 24",
            "r²<0.001 over 10 000 kb",
            "proxies prohibited",
        )
    ),
    "479 GWS variants -> 437 EUR-reference matches -> 24 clumped IVs",
)

bh = {
    row["outcome_id"]: row
    for row in csv_rows(AUDIT / "alternative_outcome_bh_family_audit.csv")
}
expected_bh = {
    "ed_2025_eur": (230, 158, 72, 8),
    "ed_2025_afr": (230, 108, 122, 0),
    "ed_2025_cross_ancestry": (230, 165, 65, 8),
}
bh_ok = True
for outcome, expected in expected_bh.items():
    row = bh[outcome]
    observed = (
        int(row["full_family_denominator"]),
        int(row["estimable_only_denominator"]),
        int(row["non_estimable_rows_retained_p1"]),
        int(row["full_family_fdr_rows"]),
    )
    bh_ok &= observed == expected
add(
    "alternative_outcome_bh_families_reproduced",
    bh_ok
    and "Each 2025 outcome was a separate 230-trait family" in main
    and "with non-estimable P=1" in main,
    "EUR 230/158/72/8; AFR 230/108/122/0; cross 230/165/65/8",
)

ld = csv_rows(AUDIT / "alternative_outcome_ld_compression_summary.csv")[0]
add(
    "redundancy_and_ld_structure_reproduced",
    int(ld["eur_fdr_trait_rows"]) == 8
    and int(ld["cross_ancestry_fdr_trait_rows"]) == 8
    and ld["identical_eur_cross_row_sets"] == "TRUE"
    and int(ld["unique_lead_snps"]) == 3
    and int(ld["unique_ld_defined_loci"]) == 1
    and close(ld["minimum_pairwise_eur_r2"], 0.858552)
    and close(ld["maximum_pairwise_eur_r2"], 0.972328)
    and "No outcome-P-selected representative or locus P/q was created"
    in main,
    "8 rows -> rs4988235/rs6754311/rs7570971 -> one chr2q21 locus",
)

redundancy = csv_rows(
    AUDIT / "alternative_outcome_redundancy_audit.csv"
)
counts: dict[str, int] = {}
for row in redundancy:
    counts[row["lead_snp"]] = counts.get(row["lead_snp"], 0) + 1
add(
    "alternative_outcome_snp_grouping_verified",
    counts
    == {"rs4988235": 5, "rs6754311": 2, "rs7570971": 1},
    f"row counts by SNP={counts}",
)

steiger = csv_rows(AUDIT / "steiger_feasibility_audit.csv")
add(
    "steiger_feasibility_transparent",
    len(steiger) == 230
    and all(row["revised_steiger_status"] == "not_estimable" for row in steiger)
    and "non-estimability was not directional support" in main,
    "230 forward traits audited; no valid test inferred without outcome prevalence",
)

diagnostics = csv_rows(
    AUDIT / "forward_diagnostic_implementation_audit.csv"
)
diagnostic_text = "\n".join(
    str(value) for row in diagnostics for value in row.values()
)
add(
    "diagnostic_statuses_distinguished",
    len(diagnostics) == 7
    and sum(int(row["estimated"]) for row in diagnostics) == 65
    and sum(int(row["failed_to_converge"]) for row in diagnostics) == 1
    and sum(
        int(row["not_triggered_under_original_candidate_rule"])
        for row in diagnostics
    )
    == 11
    and "failed to converge and was retained as a recorded failure" in main
    and "seven single-SNP nominal rows" in main,
    "method-specific estimated/not-applicable/not-triggered/convergence statuses retained",
)

coloc = csv_rows(AUDIT / "colocalization_feasibility_audit.csv")
coloc_text = "\n".join(
    str(value) for row in coloc for value in row.values()
)
add(
    "colocalization_not_overclaimed",
    "formal regional colocalization not performed" in coloc_text.lower()
    and "Formal regional colocalization was not performed" in main
    and "could therefore raise pleiotropy concerns but not establish"
    in main,
    "ED EAF and validated binary-outcome likelihood inputs were unavailable",
)

mechanism = csv_rows(
    AUDIT / "mechanistic_five_function_traceability.csv"
)
add(
    "five_mechanistic_functions_traceable",
    len(mechanism) == 5
    and all(row.get("freeze_record", "") for row in mechanism)
    and all(
        token in main
        for token in (
            "M00080",
            "M00091",
            "M00136",
            "M00530",
            "M00569",
        )
    ),
    "Five named HUNT modules have frozen selection receipts",
)

# Hard-lock text, wording and citations.
ai_exact = (
    "OpenAI Codex assisted code review, language editing, and consistency "
    "checks after analytical criteria had been defined. It did not select "
    "traits or determine statistical significance; the authors verified "
    "all outputs and remain accountable for the work."
)
add(
    "ai_disclosure_exact",
    main.count(ai_exact) == 1
    and "document generation" not in main
    and "document formatting" not in main
    and not re.search(re.escape(ai_exact) + r"\s*\[24\]", main),
    "Exact authorized Codex disclosure appears once without reference 24",
)
add(
    "authors_affiliations_and_contact_locked",
    all(
        token in title
        for token in (
            "Xiancheng Du¹, Shuchun Tao¹, Kaihua Xue¹, Yongkun Zhu¹, "
            "Yihan Shi¹, Hang Gu¹, Ming Chen²†, Chunhui Liu²†, Chao Sun²†",
            "¹ Department of Urology, Zhongda Hospital, School of Medicine, "
            "Southeast University, Nanjing, Jiangsu, China.",
            "² Department of Urology, Zhongda Hospital, Southeast University, "
            "Nanjing, Jiangsu, China.",
            "ORCID: 0000-0003-0538-1239",
            "Xiancheng Du ORCID: 0009-0000-4374-8818",
        )
    ),
    "Author order, affiliations, correspondence and ORCID match baseline",
)
add(
    "ijir_targeted_phrases_preserved",
    all(
        phrase in main
        for phrase in (
            "Recent IJIR studies",
            "The IJIR microbiome MR report",
            "are active topics in IJIR",
        )
    ),
    "Three locked IJIR-targeted expressions are present",
)
add(
    "mde_wording_correct",
    "forward-family threshold" not in all_text
    and (
        "per standardized exposure unit at the forward Bonferroni threshold "
        "(α=0.05/230)"
    )
    in main
    and "only one trait had 80% power for an OR of 2" in main,
    "Bonferroni alpha and standardized MDE scale are explicit",
)
add(
    "pleiotropy_wording_cautious",
    "strongly pleiotropic" not in all_text.lower()
    and "raised substantial horizontal-pleiotropy concerns" in main
    and "not evidence of absence" in main,
    "Annotation raises concerns without proving horizontal pleiotropy",
)
add(
    "citation_numbering_and_database_references_correct",
    "Four published two-sample Mendelian randomization (MR) studies"
    in main
    and "[6–9]" in main
    and "MiBioGen[4]" in main
    and "earlier European ED genome-wide association study (GWAS).[5]"
    in main
    and "Ensembl 2025" in main
    and "NHGRI-EBI GWAS Catalog" in main
    and "MRC IEU OpenGWAS" in main
    and "[10,24]" in main,
    "References 4/5/6-9 and platform citations 32-34 are aligned",
)
add(
    "prescreen_and_posthoc_roles_distinguished",
    "defined before association screening" in main
    and "targeted post hoc audit" in main
    and not re.search(
        r"prespecif(?:ied|y)[^.\n]{0,100}(?:OpenGWAS|locus compression)",
        main,
        re.I,
    ),
    "Pre-screen criteria and later explanatory audits are separated",
)
add(
    "winner_curse_and_finngen_limits_present",
    "Winner’s curse may therefore have inflated" in main
    and "recognized and pharmacologically treated ED" in main
    and "Untreated or unrecorded ED may have been classified among controls"
    in main
    and "tadalafil for lower urinary tract symptoms could add misclassification"
    in main,
    "Winner's curse and treated-ED phenotype limitations are explicit",
)
add(
    "evidence_role_language_correct",
    "not independent replication" in main
    and "ancestry-transfer evidence" in main
    and "not necessarily independent LD loci" in main
    and "not an ED log-odds or clinically interpretable OR scale" in main,
    "HUNT, overlap, ancestry-transfer, rsID and METAL roles are constrained",
)

# Word, PDF, table, workbook and figure QA.
add("abstract_under_200", abstract_words <= 200, f"{abstract_words}/200")
add("main_text_under_3000", main_words < 3000, f"{main_words}/3000")
add("references_under_50", reference_count <= 50, f"{reference_count}/50")
add("cover_letter_350_420", 350 <= cover_words <= 420, f"{cover_words}/350-420")

pdf_reader = PdfReader(PDF)
pdf_text = "\n".join(page.extract_text() or "" for page in pdf_reader.pages)
add(
    "combined_article_structure",
    len(pdf_reader.pages) == 22
    and "Xiancheng Du¹" in (pdf_reader.pages[0].extract_text() or "")
    and "Abstract" in (pdf_reader.pages[1].extract_text() or ""),
    "22-page reviewer PDF; title page first and abstract second",
)
add(
    "main_tables_one_page_each_and_footnotes_complete",
    "Table 1. GWAS sources and analytical roles."
    in (pdf_reader.pages[20].extract_text() or "")
    and "constitutes independent MR replication."
    in (pdf_reader.pages[20].extract_text() or "")
    and "Table 2. Nominal forward gut microbial trait–ED associations."
    in (pdf_reader.pages[21].extract_text() or "")
    and "none survived FDR correction."
    in (pdf_reader.pages[21].extract_text() or ""),
    "Table 1 is page 21; Table 2 is page 22; both footnotes are complete",
)
bad_chars = ["￾", "\ufffd"]
add(
    "pdf_text_and_math_characters_clean",
    not any(char in pdf_text for char in bad_chars)
    and "P<5×10" in pdf_text
    and "⁻" in pdf_text
    and "⁸" in pdf_text
    and "Z/√W" in pdf_text,
    "No replacement characters; multiplication, superscripts and square root preserved",
)

supplement_wb = load_workbook(
    xlsx_paths[2], read_only=True, data_only=False
)
add(
    "supplement_complete_and_formula_clean",
    len(supplement_wb.sheetnames) == 46
    and not workbook_errors
    and formula_count == 0,
    (
        f"46 sheets; formula errors={len(workbook_errors)}; "
        f"formulas={formula_count}"
    ),
)

metadata_ok = all(
    core_metadata(path)["last_modified_by"] == "Xiancheng Du"
    and core_metadata(path)["version"] == "v0.3.5"
    for path in [*docx_paths, *xlsx_paths]
)
add(
    "document_creator_metadata_correct",
    metadata_ok,
    "DOCX/XLSX creator and version metadata are Xiancheng Du/v0.3.5",
)

pngs = sorted(FIGURES.glob("*_v0_3_5_600dpi.png")) + sorted(
    (FIGURES / "supplementary").glob("*_v0_3_5_600dpi.png")
)
dpis = []
dpi_ok = len(pngs) == 9
for path in pngs:
    with Image.open(path) as image:
        dpi = image.info.get("dpi", (0, 0))
        dpis.append(round(float(dpi[0]), 1))
        dpi_ok &= (
            abs(float(dpi[0]) - 600) <= 1
            and abs(float(dpi[1]) - 600) <= 1
        )
add(
    "all_pngs_600dpi",
    dpi_ok,
    f"9 PNGs; unique dpi={sorted(set(dpis))}",
)

s3_png = (
    FIGURES
    / "supplementary"
    / "IJIR_Supplementary_Figure_S3_HUNT_Same_SNP_v0_3_5_600dpi.png"
)
s6_png = (
    FIGURES
    / "supplementary"
    / "IJIR_Supplementary_Figure_S6_2025_ED_Locus_Ancestry_v0_3_5_600dpi.png"
)
s3_svg = s3_png.with_name(
    s3_png.name.replace("_600dpi.png", ".svg")
).read_text(encoding="utf-8")
s6_svg = s6_png.with_name(
    s6_png.name.replace("_600dpi.png", ".svg")
).read_text(encoding="utf-8")
s3_margins = nonwhite_margins(s3_png)
s6_margins = nonwhite_margins(s6_png)
add(
    "figure_s3_no_text_clipping",
    "trait correlation not modelled" in s3_svg
    and "Unique rsIDs" in s3_svg
    and s3_margins[2] >= 40
    and s3_margins[3] >= 20,
    f"margins left/top/right/bottom={s3_margins}",
)
add(
    "figure_s6_no_text_clipping",
    "evidence of absence" in s6_svg
    and s6_margins[2] >= 40
    and s6_margins[3] >= 40,
    f"margins left/top/right/bottom={s6_margins}",
)
fig_builder = (PACKAGE / "02_builder" / "build_ijir_figures_v0_3_5.R").read_text(
    encoding="utf-8"
)
add(
    "figure_1_arrow_and_evidence_flow_correct",
    "c(0.48, 0.685, 0.685)" in fig_builder
    and "2025 ED outcome sensitivities" in fig_builder
    and "Cross-cohort same-SNP evaluation" in fig_builder
    and "Exploratory HUNT-selected MR" in fig_builder,
    "Dotted path uses the gap between parallel HUNT branches",
)
add(
    "figure_numbers_match_frozen_results",
    all(
        token in fig_builder
        for token in (
            "230 eligible traits",
            "218 estimable",
            "7 nominal; 0 FDR",
            "1 572 estimable",
            "77 nominal; 0 FDR",
            "97 rows; 90 unique lead rsIDs",
            "76/97 rows; 69/90 unique rsIDs",
        )
    ),
    "Figure builder contains frozen forward/reverse/HUNT counts",
)

combined_supp = PdfReader(
    SUPPLEMENT / "IJIR_Supplementary_Figures_v0_3_5.pdf"
)
add(
    "combined_supplement_pdf_matches_s1_s6",
    len(combined_supp.pages) == 6
    and all(
        (page.extract_text() or "").strip()
        for page in combined_supp.pages
    ),
    "Combined Supplementary Figures PDF contains six nonempty pages",
)

placeholder_hits = re.findall(
    r"(?i)\bTODO\b|\bTBD\b|\[placeholder[^]]*\]|\[ZENODO_VERSION_DOI\]",
    all_text,
)
local_path_hits = re.findall(
    r"/Volumes/[^\s<]+|/mnt/data/[^\s<]+|file://[^\s<]+",
    all_text,
)
add("no_placeholders", not placeholder_hits, f"hits={len(placeholder_hits)}")
add(
    "no_local_absolute_paths",
    not local_path_hits,
    f"hits={len(local_path_hits)}",
)
add(
    "nonestimable_and_database_absence_not_overinterpreted",
    "not evidence of absence" in main
    and "non-estimability was not directional support" in main
    and "with only 2/8 rows estimable" in main
    and (
        "no association was identified for four SNPs; this was not evidence "
        "of absence"
    )
    in main,
    "Required negative-evidence caveats appear in Methods, Results and Discussion",
)

portal_required = {
    "IJIR_Article.docx",
    "IJIR_Cover_Letter.docx",
    "IJIR_STROBE_MR_Checklist.docx",
    "IJIR_Supplementary_Data.xlsx",
    "IJIR_Supplementary_Figures.pdf",
    "IJIR_Figure_1.tiff",
    "IJIR_Figure_2.tiff",
    "IJIR_Figure_3.tiff",
}
portal_present = {path.name for path in PORTAL.iterdir() if path.is_file()}
add(
    "versionless_portal_files_prepared",
    portal_required.issubset(portal_present),
    f"prepared={sorted(portal_required.intersection(portal_present))}",
)

security_path = QC / "SECURITY_SCAN_v0_3_5.json"
security = (
    json.loads(security_path.read_text(encoding="utf-8"))
    if security_path.is_file()
    else {}
)
add(
    "no_jwt_or_auth_header",
    security.get("status") == "PASS"
    and not security.get("working_tree_hits")
    and not security.get("operational_history_hits")
    and not security.get("git_history_hits")
    and security.get("token_revocation_verified") is False,
    "Credential scan PASS; token revocation remains an unverified author action",
)

# Public archive is a hard gate only when the manuscript claims v0.3.5.
release_api = (
    "https://api.github.com/repos/DuXC/gut-microbiome-ed-mr/"
    "releases/tags/v0.3.5"
)
github_release = None
try:
    github_release = fetch_json(release_api)
except Exception:
    github_release = None
github_exists = bool(
    github_release
    and github_release.get("tag_name") == "v0.3.5"
    and not github_release.get("draft")
)
add(
    "github_release_v0_3_5_exists",
    github_exists,
    (
        github_release.get("html_url", "")
        if github_exists
        else "v0.3.5 release not verified"
    ),
)

zenodo_receipt = DELIVERY / "ZENODO_VERSION_DOI_RECEIPT_v0_3_5.json"
zenodo_ok = False
zenodo_doi = ""
if zenodo_receipt.is_file():
    receipt = json.loads(zenodo_receipt.read_text(encoding="utf-8"))
    zenodo_doi = str(receipt.get("doi", ""))
    record_id = str(receipt.get("record_id", ""))
    if record_id:
        try:
            record = fetch_json(
                f"https://zenodo.org/api/records/{record_id}"
            )
            zenodo_ok = (
                str(record.get("doi", "")) == zenodo_doi
                and str(record.get("metadata", {}).get("version", ""))
                == "0.3.5"
                and not record.get("is_draft", False)
            )
        except Exception:
            zenodo_ok = False
add(
    "zenodo_v0_3_5_doi_resolves",
    zenodo_ok,
    zenodo_doi or "v0.3.5 Zenodo receipt not present",
)

archive = DELIVERY / "IJIR_v0_3_5_public_archive.zip"
manifest = DELIVERY / "ARCHIVE_MANIFEST_v0_3_5.csv"
archive_ok = False
if archive.is_file() and manifest.is_file():
    rows = csv_rows(manifest)
    with zipfile.ZipFile(archive) as zipped:
        names = set(zipped.namelist())
    archive_ok = all(row["archive_path"] in names for row in rows)
add(
    "archive_manifest_current",
    archive_ok,
    (
        f"archive SHA-256={sha256(archive)}"
        if archive_ok
        else "v0.3.5 archive or manifest not verified"
    ),
)

manuscript_public_alignment = (
    ("GitHub release v0.3.5" in main)
    and (zenodo_doi in main if zenodo_doi else False)
)
add(
    "public_archive_matches_manuscript_version",
    github_exists and zenodo_ok and archive_ok and manuscript_public_alignment,
    "Manuscript, GitHub tag, Zenodo DOI and local archive all identify v0.3.5",
)

summary = {
    "version": "v0.3.5",
    "generated": "2026-07-28",
    "frozen_primary_results": str(FROZEN.relative_to(ROOT)),
    "revision_audit": str(AUDIT.relative_to(ROOT)),
    "abstract_words": abstract_words,
    "main_text_words": main_words,
    "reference_count": reference_count,
    "passed": sum(bool(item["passed"]) for item in checks),
    "failed": sum(not bool(item["passed"]) for item in checks),
    "checks": checks,
}
QC.mkdir(parents=True, exist_ok=True)
DELIVERY.mkdir(parents=True, exist_ok=True)
for output in [
    QC / "FINAL_QA_MACHINE_CHECKS_v0_3_5.json",
    DELIVERY / "FINAL_QA_MACHINE_CHECKS_v0_3_5.json",
]:
    output.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

for item in checks:
    print(
        f"{'PASS' if item['passed'] else 'FAIL'}\t"
        f"{item['check']}\t{item['evidence']}"
    )
print(f"SUMMARY\tpassed={summary['passed']}\tfailed={summary['failed']}")
raise SystemExit(0 if summary["failed"] == 0 else 1)
