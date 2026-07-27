#!/usr/bin/env python3
"""Prepare v0.3.5 table and supplementary JSON inputs from frozen/derived outputs.

This script does not recompute or select MR results. It deterministically
compresses display columns for the two main tables and appends revision-stage
audit outputs to the supplementary-workbook manifest.
"""

from __future__ import annotations

import csv
import json
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = (
    ROOT
    / "06_manuscript"
    / "ijir_v0_3_5_20260728"
    / "02_builder"
    / "tmp_table_data"
)
AUDIT = ROOT / "05_results" / "v0_3_5_pre_submission_audit_20260728"
PUBLIC_TAG = os.environ.get("IJIR_PUBLIC_TAG", "v0.3.5")
PUBLIC_ZENODO_VERSION = os.environ.get("IJIR_ZENODO_VERSION", "0.3.5")
PUBLIC_ZENODO_DOI = os.environ.get(
    "IJIR_ZENODO_DOI", "10.5281/zenodo.21630442"
)
PUBLIC_ZENODO_CONCEPT_DOI = "10.5281/zenodo.21456670"
PUBLIC_GITHUB_URL = (
    "https://github.com/DuXC/gut-microbiome-ed-mr/releases/tag/"
    f"{PUBLIC_TAG}"
)


def git_output(*args: str) -> str:
    return subprocess.check_output(
        ["git", *args], cwd=ROOT, text=True
    ).strip()


def read_json(name: str):
    return json.loads((DATA / name).read_text(encoding="utf-8"))


def write_json(name: str, rows) -> None:
    (DATA / name).write_text(
        json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def replace_text(value, old: str, new: str):
    if isinstance(value, str):
        return value.replace(old, new)
    if isinstance(value, list):
        return [replace_text(item, old, new) for item in value]
    if isinstance(value, dict):
        return {
            key: replace_text(item, old, new) for key, item in value.items()
        }
    return value


def csv_rows(path: Path):
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def sci(value) -> str:
    value = float(value)
    if 0.001 <= abs(value) < 1000:
        return f"{value:.4f}".rstrip("0").rstrip(".")
    mantissa, exponent = f"{value:.3e}".split("e")
    return f"{float(mantissa):.3g}×10^{int(exponent)}"


table1 = read_json("main_table_1.json")
table1_compact = [
    {
        "GWAS source": row["GWAS source"],
        "Ancestry and sample size": f'{row["Ancestry"]}; {row["Sample size"]}',
        "Phenotype/effect scale": row["Phenotype and effect scale"].replace(
            "Z/sqrt(weight)", "Z/√weight"
        ),
        "Analytical role": row["Analytical role"],
        "Overlap/evidence classification": row[
            "Overlap and evidence classification"
        ],
    }
    for row in table1
]
write_json("main_table_1_v0_3_5.json", table1_compact)


table2 = read_json("main_table_2.json")
table2_compact = []
for row in table2:
    trait = row["Microbial trait"].replace("Gut microbiome ", "", 1)
    scale = (
        "Presence; OR per 1-unit genetically predicted log odds"
        if row["Exposure phenotype"] == "presence"
        else "RIN abundance; OR per 1 standardized unit"
    )
    if row["Exact HUNT match"] == "Yes":
        if row["Swedish lead SNP"] == "rs56024701":
            hunt = (
                "Exact label; same-SNP P=0.965, F=0.002; "
                "exploratory 23-SNP MR P=0.427"
            )
        else:
            hunt = (
                "Exact label; same-SNP P=0.671, F=0.180; "
                "exploratory 20-SNP MR P=0.175"
            )
    else:
        hunt = "No exact label; no fuzzy matching"
    table2_compact.append(
        {
            "Microbial trait": trait,
            "Exposure phenotype/scale": scale,
            "Lead SNP and F statistic": (
                f'{row["Swedish lead SNP"]}; F={float(row["F statistic"]):.2f}'
            ),
            "OR (95% CI)": row["Discovery OR (95% CI)"],
            "Nominal P": sci(row["Nominal P"]),
            "FDR q": f'{float(row["FDR q"]):.4f}',
            "Concise HUNT evaluation": hunt,
            "Taxonomic/signal cluster": row["Taxonomic signal cluster"],
        }
    )
write_json("main_table_2_v0_3_5.json", table2_compact)


notes1 = [
    {
        "Note": (
            "The 2025 European and cross-ancestry analyses include FinnGen; "
            "the African-ancestry stratum does not."
        )
    },
    {
        "Note": (
            "HUNT is an independent exposure cohort, but FinnGen remains the "
            "MR outcome; neither the legacy exploratory analysis nor the "
            "same-SNP lookup constitutes independent MR replication."
        )
    },
    {
        "Note": (
            "Genome build, full instrument thresholds, URLs, and detailed "
            "source notes are provided in Supplementary Data."
        )
    },
]
notes2 = [
    {
        "Note": (
            "These are seven nominal trait-level associations, not seven "
            "independent causal taxa; none survived FDR correction."
        )
    },
    {
        "Note": (
            "Peptococcaceae, Peptococcales, and Peptococcia are nested traits "
            "with the same SNP and identical estimates."
        )
    },
    {
        "Note": (
            "Swedish presence and HUNT normalized relative-abundance scales "
            "are not directly comparable. The two focal exact-label HUNT "
            "GWASs had no genome-wide-significant instruments; legacy 23-SNP "
            "and 20-SNP analyses used P<1×10⁻⁵ and were exploratory. All "
            "Swedish nominal estimates were single-SNP Wald ratios."
        )
    },
]
write_json("main_table_1_v0_3_5_notes.json", notes1)
write_json("main_table_2_v0_3_5_notes.json", notes2)


manifest = read_json("supplement_manifest.json")
for entry in manifest:
    entry["title"] = entry["title"].replace("v0.3.4", "v0.3.5")

readme_rows = read_json("supp_01.json")
readme_updates = {
    "File": "IJIR_Supplementary_Data_v0_3_5.xlsx",
    "Version": "v0.3.5 (2026-07-28)",
    "Primary inference": (
        "Primary FinnGen and reverse analyses produced no FDR association; "
        "separate full 230-trait European and cross-ancestry sensitivities "
        "produced eight trait-level associations surviving FDR correction "
        "that compressed descriptively to three high-LD SNPs in one "
        "chr2q21 LCT/MCM6 region. Broad phenotype associations across the "
        "region raised substantial horizontal-pleiotropy concerns. No "
        "association met the criteria defined before screening for robust "
        "causal interpretation."
    ),
    "Repository": (
        f"GitHub release {PUBLIC_TAG}: {PUBLIC_GITHUB_URL}; Zenodo version DOI "
        f"https://doi.org/{PUBLIC_ZENODO_DOI}; concept DOI "
        f"https://doi.org/{PUBLIC_ZENODO_CONCEPT_DOI}. Frozen v0.3.0 primary "
        "outputs and later derived audits are preserved without overwrite."
    ),
    "Prespecified framework": (
        "Eligibility, instrument strength, per-trait clumping, FinnGen "
        "primary outcome, bidirectional MR, complete BH families, "
        "source-threshold and multiplicity sensitivities, HUNT lookup "
        "design, bounded mechanistic families, power/MDE, and overlap roles "
        "were defined before association screening. Later locus, exact-rsID, "
        "redundancy, and diagnostic-feasibility audits are post hoc."
    ),
}
for row in readme_rows:
    if row["Field"] in readme_updates:
        row["Value"] = readme_updates[row["Field"]]
write_json("supp_01_v0_3_5.json", readme_rows)
manifest[0]["json_file"] = "supp_01_v0_3_5.json"
manifest[0]["rows"] = len(readme_rows)

software_rows = read_json("supp_21.json")
software_updates = {
    "Manuscript package version": "v0.3.5",
    "Local Git branch": git_output("branch", "--show-current"),
    "Local base commit": git_output("rev-parse", "HEAD"),
    "Public GitHub release tag": PUBLIC_TAG,
    "Public GitHub release URL": PUBLIC_GITHUB_URL,
    "Public Zenodo version": PUBLIC_ZENODO_VERSION,
    "Public Zenodo version DOI": PUBLIC_ZENODO_DOI,
    "Public Zenodo concept DOI": PUBLIC_ZENODO_CONCEPT_DOI,
    "Version alignment statement": (
        f"The {PUBLIC_TAG} public archive contains the frozen v0.3.0 primary "
        "outputs, later derived explanatory audits, submission files, "
        "provenance records, and checksums available at that release; "
        "restricted third-party GWAS payloads are not redistributed."
    ),
}
for row in software_rows:
    if row["Field"] in software_updates:
        row["Value"] = software_updates[row["Field"]]
write_json("supp_21_v0_3_5.json", software_rows)
for entry in manifest:
    if entry["sheet_name"] == "S10 Software":
        entry["json_file"] = "supp_21_v0_3_5.json"
        entry["rows"] = len(software_rows)

audit_specs = [
    (
        "R1 METAL Summary",
        "R1. METAL Z and cumulative effective-sample-size weight audit",
        "metal_weight_transformation_summary.csv",
    ),
    (
        "R1 METAL Source",
        "R1. Verified definition and provenance of METAL weight",
        "metal_weight_definition_source.csv",
    ),
    (
        "R2 Reverse IV Build",
        "R2. Reverse ED instrument construction audit",
        "reverse_instrument_construction_audit.csv",
    ),
    (
        "R3 Alt BH Families",
        "R3. Alternative-outcome BH family and non-estimable-row audit",
        "alternative_outcome_bh_family_audit.csv",
    ),
    (
        "R4 Redundancy",
        "R4. Post hoc redundancy-aware audit of alternative-outcome signals",
        "alternative_outcome_redundancy_audit.csv",
    ),
    (
        "R4 LD Compression",
        "R4. Descriptive European-LD locus compression summary",
        "alternative_outcome_ld_compression_summary.csv",
    ),
    (
        "R5 Steiger Audit",
        "R5. Revision-stage Steiger directionality feasibility audit",
        "steiger_feasibility_audit.csv",
    ),
    (
        "R6 Diagnostic Audit",
        "R6. Method-specific diagnostic implementation audit",
        "forward_diagnostic_implementation_audit.csv",
    ),
    (
        "R7 Coloc Feasibility",
        "R7. Formal regional colocalization feasibility audit",
        "colocalization_feasibility_audit.csv",
    ),
    (
        "R8 Mechanism Trace",
        "R8. Five-function mechanistic-screening traceability",
        "mechanistic_five_function_traceability.csv",
    ),
    (
        "R9 Analysis Roles",
        "R9. Analyses defined before screening versus revision-stage audits",
        "analysis_role_classification_audit.csv",
    ),
    (
        "R10 Independence",
        "R10. Operational definition of data independence",
        "acceptable_data_independence_definition.csv",
    ),
]

next_order = max(int(item["order"]) for item in manifest) + 1
for offset, (sheet, title, filename) in enumerate(audit_specs):
    rows = csv_rows(AUDIT / filename)
    json_name = f"supp_revision_{offset + 1:02d}.json"
    write_json(json_name, rows)
    manifest.append(
        {
            "order": next_order + offset,
            "sheet_name": sheet,
            "title": title,
            "json_file": json_name,
            "rows": len(rows),
            "columns": len(rows[0]) if rows else 0,
        }
    )

for entry in manifest:
    if entry["sheet_name"] == "S12 HUNT Unique SNP":
        entry["title"] = (
            "S12. HUNT unique-rsID direction-concordance sensitivity"
        )
        rows = replace_text(
            read_json(entry["json_file"]), "unique-SNP", "unique-rsID"
        )
        write_json("supp_27_v0_3_5.json", rows)
        entry["json_file"] = "supp_27_v0_3_5.json"
    elif entry["sheet_name"] == "S12 HUNT Summary":
        entry["title"] = (
            "S12b. HUNT trait-level and unique-rsID concordance summary"
        )
        rows = replace_text(
            read_json(entry["json_file"]), "unique-SNP", "unique-rsID"
        )
        write_json("supp_28_v0_3_5.json", rows)
        entry["json_file"] = "supp_28_v0_3_5.json"

dictionary_rows = [
    {
        "Sheet": entry["sheet_name"],
        "Title": entry["title"],
        "Rows": entry["rows"],
        "Columns": entry["columns"],
    }
    for entry in manifest
]
write_json("supp_29_v0_3_5.json", dictionary_rows)
for entry in manifest:
    if entry["sheet_name"] == "Data Dictionary":
        entry["title"] = "Supplementary workbook data dictionary"
        entry["json_file"] = "supp_29_v0_3_5.json"
        entry["rows"] = len(dictionary_rows)
        entry["columns"] = 4

write_json("supplement_manifest_v0_3_5.json", manifest)
print(
    f"Prepared two compact main tables and {len(audit_specs)} revision-audit "
    f"supplement sheets ({len(manifest)} sheets total)."
)
