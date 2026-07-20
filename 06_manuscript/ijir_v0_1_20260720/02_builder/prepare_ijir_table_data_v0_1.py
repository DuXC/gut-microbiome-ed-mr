from pathlib import Path
import json

import numpy as np
import pandas as pd


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT = SCRIPT_DIR.parents[2]
TMP = SCRIPT_DIR / "tmp_table_data"
TMP.mkdir(parents=True, exist_ok=True)


def clean_scalar(value):
    if value is None or (isinstance(value, float) and np.isnan(value)):
        return None
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.floating,)):
        return float(value)
    if isinstance(value, (np.bool_,)):
        return bool(value)
    return value


def records(df):
    return [{str(k): clean_scalar(v) for k, v in row.items()} for row in df.to_dict(orient="records")]


def save(name, payload):
    (TMP / name).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


forward = pd.read_csv(PROJECT / "05_results/tables/mr_multiplicity_forward.csv")
replication = pd.read_csv(PROJECT / "05_results/tables/forward_replication_audit.csv")
reverse = pd.read_csv(PROJECT / "05_results/tables/reverse_mr_multiplicity.csv")
source_inventory = pd.read_csv(PROJECT / "00_admin/source_inventory.csv")
exposure_metadata = pd.read_csv(PROJECT / "08_qc/exposure_metadata_catalog.csv")
instrument_inventory = pd.read_csv(PROJECT / "05_results/tables/instrument_inventory.csv")
final_receipt = pd.read_csv(PROJECT / "08_qc/final_analysis_receipt.csv")
mr_raw = pd.read_csv(PROJECT / "05_results/tables/mr_raw.csv")
reverse_raw = pd.read_csv(PROJECT / "05_results/tables/reverse_mr_raw.csv")


main_table_1 = pd.DataFrame(
    [
        {
            "Source": "Swedish shotgun-metagenomic GWAS",
            "Ancestry": "European",
            "Sample size": "16,017",
            "Phenotype/statistic": "1,572 microbial presence, abundance, higher-taxonomic, and diversity traits; GRCh37",
            "Prespecified role": "Forward exposure; reverse outcome",
            "Independence/scale note": "Discovery source",
            "Public source": "https://www.ebi.ac.uk/gwas/",
        },
        {
            "Source": "Norwegian HUNT microbiome GWAS",
            "Ancestry": "European",
            "Sample size": "Up to 12,652",
            "Phenotype/statistic": "Shotgun-metagenomic relative abundance and functional traits; GRCh37",
            "Prespecified role": "Independent forward exposure validation",
            "Independence/scale note": "Exact biological-label matches only",
            "Public source": "https://www.ebi.ac.uk/gwas/",
        },
        {
            "Source": "FinnGen R12 ERECTILE_DYSFUNCTION",
            "Ancestry": "Finnish",
            "Sample size": "2,886 cases; 215,272 controls",
            "Phenotype/statistic": "Sex-specific repeated PDE5-inhibitor purchases; log odds; GRCh38",
            "Prespecified role": "Primary forward outcome",
            "Independence/scale note": "Overlaps 2025 ED meta-analysis",
            "Public source": "https://storage.googleapis.com/finngen-public-data-r12/summary_stats/release/finngen_R12_ERECTILE_DYSFUNCTION.gz",
        },
        {
            "Source": "2025 ED GWAS meta-analysis: EUR",
            "Ancestry": "European",
            "Sample size": "136,867 cases; 776,327 controls",
            "Phenotype/statistic": "EHR-defined ED; METAL Z and weight; GRCh38",
            "Prespecified role": "Reverse exposure; forward sensitivity outcome",
            "Independence/scale note": "Known FinnGen overlap; standardized scale, not OR",
            "Public source": "https://doi.org/10.1038/s41467-025-66723-7",
        },
        {
            "Source": "2025 ED GWAS meta-analysis: AFR",
            "Ancestry": "African",
            "Sample size": "51,599 cases; 73,716 controls",
            "Phenotype/statistic": "EHR-defined ED; METAL Z and weight; GRCh38",
            "Prespecified role": "Forward ancestry-transfer sensitivity outcome",
            "Independence/scale note": "Known FinnGen overlap; standardized scale, not OR",
            "Public source": "https://doi.org/10.1038/s41467-025-66723-7",
        },
        {
            "Source": "2025 ED GWAS meta-analysis: cross-ancestry",
            "Ancestry": "Cross-ancestry",
            "Sample size": "188,466 cases; 850,043 controls",
            "Phenotype/statistic": "EHR-defined ED; METAL Z and weight; GRCh38",
            "Prespecified role": "Forward cross-ancestry sensitivity outcome",
            "Independence/scale note": "Known FinnGen overlap; standardized scale, not OR",
            "Public source": "https://doi.org/10.1038/s41467-025-66723-7",
        },
        {
            "Source": "1000 Genomes Phase 3 EUR panel",
            "Ancestry": "European",
            "Sample size": "503 participants",
            "Phenotype/statistic": "GRCh37 linkage-disequilibrium reference",
            "Prespecified role": "Ancestry-matched clumping",
            "Independence/scale note": "Reference panel only",
            "Public source": "https://doi.org/10.5281/zenodo.6614170",
        },
    ]
)


nominal = replication.loc[replication["p"].notna() & (replication["p"] < 0.05)].copy()
nominal["Discovery OR (95% CI)"] = nominal.apply(
    lambda x: f'{x["or"]:.3f} ({x["or_ci_lower"]:.3f}–{x["or_ci_upper"]:.3f})', axis=1
)
nominal["Exact HUNT match"] = np.where(nominal["replication_source_id"].fillna("") != "", "Yes", "No")
nominal["HUNT OR (95% CI)"] = nominal.apply(
    lambda x: (
        f'{np.exp(x["validation_beta"]):.3f} ({np.exp(x["validation_ci_lower"]):.3f}–{np.exp(x["validation_ci_upper"]):.3f})'
        if pd.notna(x["validation_beta"]) else "NA"
    ), axis=1
)
nominal["HUNT P"] = nominal["validation_p"]
main_table_2 = nominal[
    ["source_id", "trait", "nsnp", "Discovery OR (95% CI)", "p", "q", "Exact HUNT match", "replication_source_id", "validation_nsnp", "HUNT OR (95% CI)", "HUNT P"]
].rename(
    columns={
        "source_id": "Swedish accession",
        "trait": "Microbial trait",
        "nsnp": "Discovery SNPs",
        "p": "Discovery P",
        "q": "FDR q",
        "replication_source_id": "HUNT accession",
        "validation_nsnp": "HUNT SNPs",
    }
)


data_file_rows = source_inventory.loc[~source_inventory["file_name"].str.endswith("-meta.yaml", na=False)].copy()
exposure_ledger = exposure_metadata.merge(
    data_file_rows[["dataset", "source_id", "source_url", "expected_checksum", "checksum_algorithm"]],
    on=["dataset", "source_id"], how="left", validate="one_to_one"
)
outcome_ledger = data_file_rows.loc[data_file_rows["dataset"].isin(["finngen_r12", "ed_2025", "ld_reference_1kg"])].copy()


method_status = pd.concat(
    [
        mr_raw.assign(direction="forward").groupby(["direction", "analysis_role", "method", "analysis_status"], dropna=False).size().reset_index(name="rows"),
        reverse_raw.assign(direction="reverse").groupby(["direction", "analysis_role", "method", "analysis_status"], dropna=False).size().reset_index(name="rows"),
    ], ignore_index=True
)


readme = [
    ["Supplementary Data 1", "Frozen bidirectional gut microbiota–erectile dysfunction MR data package"],
    ["Version", "v0.1; 2026-07-20"],
    ["Forward family", "230 eligible traits; 218 estimable; 7 nominal; 0 FDR-significant; minimum q=0.9416"],
    ["Reverse family", "1,572 estimable traits; 77 nominal; 0 FDR-significant; minimum q=0.9673"],
    ["Strict global threshold", "2.774695×10^-5 across 1,802 tests"],
    ["Interpretation boundary", "Nominal rows are not replicated causal findings. Reverse rows are sensitivity analyses."],
    ["Raw-data boundary", "Third-party GWAS payloads are not redistributed in this workbook."],
    ["Public code repository", "https://github.com/DuXC/gut-microbiome-ed-mr"],
    ["Archived version DOI", "https://doi.org/10.5281/zenodo.21456671"],
    ["All-version concept DOI", "https://doi.org/10.5281/zenodo.21456670"],
    ["Workbook structure", "Source Summary; GWAS Source Ledger; Forward Primary; Forward Replication; Reverse Primary; Instrument Inventory; Method Status; Final Receipt; Data Dictionary"],
]


dictionary = pd.DataFrame(
    [
        ["Source Summary", "One row per major data source", "Prespecified evidence role, sample size, scale, independence, and public source"],
        ["GWAS Source Ledger", "One row per microbiome accession plus ED/reference source file", "Trait metadata, source URL, and upstream checksum where available"],
        ["Forward Primary", "One row per frozen forward hypothesis", "Primary FinnGen effect, instrument count, P, q, and global decision fields"],
        ["Forward Replication", "One row per frozen forward hypothesis", "Exact HUNT mapping and all prespecified replication gates"],
        ["Reverse Primary", "One row per frozen reverse hypothesis", "Primary reverse IVW effect, instrument count, P, q, and status"],
        ["Instrument Inventory", "One row per dataset, trait, and tier", "Candidate, strong, mapped, and post-clump instrument counts"],
        ["Method Status", "One row per direction, method, and status", "Count of estimated and explicitly failed method rows"],
        ["Final Receipt", "One frozen decision row", "Hashes binding final inputs, outputs, and code"],
    ], columns=["Sheet", "Row meaning", "Key content"]
)


save("main_table_1.json", records(main_table_1))
save("main_table_2.json", records(main_table_2))
save("supplement.json", {
    "readme": readme,
    "source_summary": records(main_table_1),
    "source_ledger": records(pd.concat([exposure_ledger, outcome_ledger], ignore_index=True, sort=False)),
    "forward_primary": records(forward),
    "forward_replication": records(replication),
    "reverse_primary": records(reverse),
    "instrument_inventory": records(instrument_inventory),
    "method_status": records(method_status),
    "final_receipt": records(final_receipt),
    "dictionary": records(dictionary),
})
print(f"Prepared table JSON in {TMP}")
