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
mechanistic_tables = {
    "mechanistic_x_to_y": pd.read_csv(PROJECT / "05_results/tables/mechanistic_x_to_y_total_effects.csv"),
    "cytokine_m_to_y": pd.read_csv(PROJECT / "05_results/tables/mechanistic_cytokine_m_to_y.csv"),
    "cytokine_x_to_m": pd.read_csv(PROJECT / "05_results/tables/mechanistic_cytokine_x_to_m.csv"),
    "cytokine_indirect": pd.read_csv(PROJECT / "05_results/tables/mechanistic_cytokine_indirect.csv"),
    "endothelial_m_to_y": pd.read_csv(PROJECT / "05_results/tables/mechanistic_endothelial_m_to_y.csv"),
    "endothelial_x_to_m": pd.read_csv(PROJECT / "05_results/tables/mechanistic_endothelial_x_to_m.csv"),
    "endothelial_indirect": pd.read_csv(PROJECT / "05_results/tables/mechanistic_endothelial_indirect.csv"),
}
mechanistic_denominators = pd.read_csv(PROJECT / "08_qc/mechanistic_family_denominators.csv")
mechanistic_endothelial_instruments = pd.read_csv(PROJECT / "08_qc/mechanistic_endothelial_instrument_receipt.csv")
mechanistic_source_metadata = pd.read_csv(PROJECT / "08_qc/mechanistic_source_metadata.csv")
mechanistic_overlap = pd.read_csv(PROJECT / "08_qc/mechanistic_sample_overlap_matrix.csv")
mechanistic_validation = pd.read_csv(PROJECT / "08_qc/mechanistic_full_validation_receipt.csv")
mechanistic_decision = pd.read_csv(PROJECT / "08_qc/mechanistic_extension_decision.csv")
mechanistic_raw_manifest = pd.read_csv(PROJECT / "08_qc/mechanistic_raw_manifest.csv")


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
            "Source": "2025 circulating-cytokine meta-GWAS",
            "Ancestry": "Predominantly European",
            "Sample size": "Up to 74,783",
            "Phenotype/statistic": "40 circulating cytokines; cis leads classified in source article; GRCh37/GRCh38 fields kept separate",
            "Prespecified role": "Mechanistic mediator screening",
            "Independence/scale note": "Known partial FinnGen overlap through FINRISK; screening only",
            "Public source": "https://doi.org/10.1038/s42003-025-07453-w",
        },
        {
            "Source": "SCALLOP CVD-I cardiovascular-protein GWAS",
            "Ancestry": "European",
            "Sample size": "Up to 30,931",
            "Phenotype/statistic": "Nine prespecified endothelial/vascular-injury proteins; GRCh37",
            "Prespecified role": "Mechanistic mediator screening",
            "Independence/scale note": "Overlap with HUNT/FinnGen possible or unresolved; screening only",
            "Public source": "https://doi.org/10.1038/s42255-020-00287-2",
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


mechanistic_labels = {
    "mechanistic_x_to_y": "Microbial function to ED",
    "cytokine_m_to_y": "Cytokine to ED",
    "cytokine_x_to_m": "Microbial function to cytokine",
    "endothelial_m_to_y": "Endothelial protein to ED",
    "endothelial_x_to_m": "Microbial function to endothelial protein",
    "cytokine_indirect": "Cytokine indirect effect",
    "endothelial_indirect": "Endothelial indirect effect",
}
mechanistic_signal_columns = {
    "mechanistic_x_to_y": "fdr_significant",
    "cytokine_m_to_y": "fdr_significant",
    "cytokine_x_to_m": "fdr_significant",
    "endothelial_m_to_y": "fdr_significant",
    "endothelial_x_to_m": "fdr_significant",
    "cytokine_indirect": "product_fdr_significant",
    "endothelial_indirect": "product_fdr_significant",
}
mechanistic_summary_rows = []
for family, df in mechanistic_tables.items():
    denominator = int(df["family_denominator"].iloc[0])
    p_values = pd.to_numeric(df["p"], errors="coerce")
    q_values = pd.to_numeric(df["q"], errors="coerce")
    signal_col = mechanistic_signal_columns[family]
    mechanistic_summary_rows.append(
        {
            "Family": mechanistic_labels[family],
            "Frozen denominator": denominator,
            "Estimable": int(p_values.notna().sum()),
            "FDR-significant": int(df[signal_col].fillna(False).astype(bool).sum()),
            "Minimum P": float(p_values.min()),
            "Minimum q": float(q_values.min()),
        }
    )
mechanistic_summary = pd.DataFrame(mechanistic_summary_rows)


readme = [
    ["Supplementary Data 1", "Frozen bidirectional gut microbiota–erectile dysfunction MR data package"],
    ["Version", "v0.2; 2026-07-21"],
    ["Forward family", "230 eligible traits; 218 estimable; 7 nominal; 0 FDR-significant; minimum q=0.9416"],
    ["Reverse family", "1,572 estimable traits; 77 nominal; 0 FDR-significant; minimum q=0.9673"],
    ["Mechanistic extension", "7 frozen families; 544 result rows; 0 FDR-significant; no pathway passed mediation gates"],
    ["Mechanistic stopping rule", "Stopped before broad metabolite or immune-cell expansion; no colocalization or proportion mediated was triggered"],
    ["Strict global threshold", "2.774695×10^-5 across 1,802 tests"],
    ["Interpretation boundary", "Nominal rows are not replicated causal findings. Reverse and overlap-affected mechanistic rows are sensitivity analyses."],
    ["Raw-data boundary", "Third-party GWAS payloads are not redistributed in this workbook."],
    ["Public code repository", "https://github.com/DuXC/gut-microbiome-ed-mr"],
    ["Archived version DOI", "https://doi.org/10.5281/zenodo.21456671"],
    ["All-version concept DOI", "https://doi.org/10.5281/zenodo.21456670"],
    ["Workbook structure", "Primary-analysis sheets are followed by the complete mechanistic family, source, instrument, overlap, validation, and decision records."],
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
        ["Mech Family Summary", "One row per frozen mechanistic testing family", "Denominator, estimable count, FDR signals, and minimum P and q"],
        ["Mech Family Denoms", "One row per frozen mechanistic testing family", "Multiplicity method, alpha, and handling of non-estimable rows"],
        ["Mech X-Y", "One row per microbial-function total effect", "Five prespecified HUNT KEGG module-to-ED estimates"],
        ["Cyto M-Y", "One row per cytokine", "Complete 40-test cytokine-to-ED family, including non-estimable rows"],
        ["Cyto X-M", "One row per microbial-function and cytokine pair", "Complete 200-test function-to-cytokine family"],
        ["Cyto Indirect", "One row per microbial-function and cytokine pair", "Complete 200-test product-effect family and overlap labels"],
        ["Endo M-Y", "One row per endothelial protein", "Complete nine-test protein-to-ED family"],
        ["Endo X-M", "One row per microbial-function and endothelial-protein pair", "Complete 45-test function-to-protein family"],
        ["Endo Indirect", "One row per microbial-function and endothelial-protein pair", "Complete 45-test product-effect family and overlap labels"],
        ["Endo Instruments", "One row per prespecified endothelial protein", "Cis candidates, GRCh37 LD mapping, clumped counts, hashes, and PLINK version"],
        ["Mech Source Metadata", "One row per cytokine or endothelial source", "Registry label, sample size, genome build, and public source URL"],
        ["Mech Overlap", "One row per assessed dataset pair", "Overlap class, analysis action, and evidence note"],
        ["Mech Validation", "One final validation row", "49-file integrity, 544 result rows, zero FDR signals, and frozen decision"],
        ["Mech Decision", "One frozen stopping-decision row", "Component-gate counts, colocalization trigger, and stopping rule"],
        ["Mech Raw Manifest", "One row per downloaded mediator payload", "Relative path, public URL, license, size, SHA-256, and freeze time"],
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
    "mechanistic_summary": records(mechanistic_summary),
    "mechanistic_denominators": records(mechanistic_denominators),
    "mechanistic_x_to_y": records(mechanistic_tables["mechanistic_x_to_y"]),
    "cytokine_m_to_y": records(mechanistic_tables["cytokine_m_to_y"]),
    "cytokine_x_to_m": records(mechanistic_tables["cytokine_x_to_m"]),
    "cytokine_indirect": records(mechanistic_tables["cytokine_indirect"]),
    "endothelial_m_to_y": records(mechanistic_tables["endothelial_m_to_y"]),
    "endothelial_x_to_m": records(mechanistic_tables["endothelial_x_to_m"]),
    "endothelial_indirect": records(mechanistic_tables["endothelial_indirect"]),
    "mechanistic_endothelial_instruments": records(mechanistic_endothelial_instruments),
    "mechanistic_source_metadata": records(mechanistic_source_metadata),
    "mechanistic_overlap": records(mechanistic_overlap),
    "mechanistic_validation": records(mechanistic_validation),
    "mechanistic_decision": records(mechanistic_decision),
    "mechanistic_raw_manifest": records(mechanistic_raw_manifest),
    "dictionary": records(dictionary),
})
print(f"Prepared table JSON in {TMP}")
