#!/usr/bin/env python3
"""Build the curated, deterministic IJIR v0.3.5 public archive."""

from __future__ import annotations

import csv
import hashlib
import shutil
import stat
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "06_manuscript" / "ijir_v0_3_5_20260728"
DELIVERY = PACKAGE / "09_final_delivery_v0_3_5"
STAGING = Path(tempfile.mkdtemp(prefix="v0_3_5_public_archive_"))
ARCHIVE = DELIVERY / "IJIR_v0_3_5_public_archive.zip"
MANIFEST = DELIVERY / "ARCHIVE_MANIFEST_v0_3_5.csv"
SHA_FILE = DELIVERY / "IJIR_v0_3_5_public_archive.zip.sha256"
ARCHIVE_ROOT = "gut-microbiome-ed-mr-v0.3.5"
FIXED_TIME = (2026, 7, 28, 12, 0, 0)


def excluded(path: Path) -> bool:
    name = path.name
    joined = "/".join(path.parts)
    return (
        name == ".DS_Store"
        or name.startswith("._")
        or name == "__pycache__"
        or name.endswith(".pyc")
        or name.endswith(".inspect.ndjson")
        or name.endswith("_preview.png")
        or "tmp_table_data" in path.parts
        or "rendered_final_" in joined
        or "contact_sheets" in path.parts
        or "xlsx_previews" in path.parts
        or "inspect_logs" in path.parts
        or name == ARCHIVE.name
    )


def copy_file(src: Path, rel: Path) -> None:
    if not src.is_file() or excluded(src):
        return
    dst = STAGING / ARCHIVE_ROOT / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def copy_tree(src: Path, rel: Path) -> None:
    if not src.is_dir():
        return
    for item in sorted(src.rglob("*")):
        if item.is_file() and not excluded(item):
            copy_file(item, rel / item.relative_to(src))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def evidence_role(path: Path) -> str:
    text = path.as_posix()
    if "05_results/v0_3_20260722" in text:
        return "frozen primary output"
    if "05_results/v0_3_5_pre_submission_audit_20260728" in text:
        return "revision-stage derived audit"
    if (
        "05_results/v0_3_2" in text
        or "05_results/v0_3_3" in text
    ):
        return "derived explanatory audit"
    return "submission, code, configuration, or provenance"


def main() -> None:
    (STAGING / ARCHIVE_ROOT).mkdir(parents=True)
    DELIVERY.mkdir(parents=True, exist_ok=True)

    for name in [
        ".Rprofile",
        ".gitignore",
        ".zenodo.json",
        "CITATION.cff",
        "LICENSE.md",
        "README.md",
        "renv.lock",
    ]:
        copy_file(ROOT / name, Path(name))

    for directory in ["R", "config", "scripts", "tests"]:
        copy_tree(ROOT / directory, Path(directory))

    copy_tree(ROOT / "01_protocol", Path("01_protocol"))

    for result_dir in [
        "v0_3_20260722",
        "v0_3_2_derived_20260723",
        "v0_3_2_1_opengwas_20260723",
        "v0_3_3_derived_20260723",
        "v0_3_5_pre_submission_audit_20260728",
    ]:
        copy_tree(
            ROOT / "05_results" / result_dir,
            Path("05_results") / result_dir,
        )

    for directory in [
        "01_sources",
        "02_builder",
        "03_submission_files",
        "04_figures",
        "05_tables",
        "06_supplement",
    ]:
        copy_tree(
            PACKAGE / directory,
            Path("submission_v0_3_5") / directory,
        )

    copy_file(
        PACKAGE / "PRE_REVISION_AUDIT.md",
        Path("submission_v0_3_5") / "PRE_REVISION_AUDIT.md",
    )
    for name in [
        "IJIR_Figure_Output_Manifest_v0_3_5.csv",
        "IJIR_Word_Counts_v0_3_5.txt",
        "SECURITY_SCAN_v0_3_5.json",
        "FINAL_QA_MACHINE_CHECKS_v0_3_5.json",
        "VISUAL_QA_RECEIPT_v0_3_5.json",
    ]:
        copy_file(
            PACKAGE / "07_qc" / name,
            Path("submission_v0_3_5/07_qc") / name,
        )
    for name in [
        "CHANGELOG_REVISION.md",
        "FINAL_QA_REPORT.md",
        "BLOCKING_ISSUES.md",
        "SECURITY_QA.md",
        "FILE_CHECKSUMS.csv",
    ]:
        copy_file(
            DELIVERY / name,
            Path("submission_v0_3_5/09_final_delivery") / name,
        )

    rows = []
    archive_base = STAGING / ARCHIVE_ROOT
    for path in sorted(archive_base.rglob("*")):
        if path.is_file():
            rows.append(
                {
                    "archive_path": path.relative_to(STAGING).as_posix(),
                    "bytes": path.stat().st_size,
                    "sha256": sha256(path),
                    "evidence_role": evidence_role(path),
                }
            )

    with MANIFEST.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "archive_path",
                "bytes",
                "sha256",
                "evidence_role",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)
    copy_file(MANIFEST, Path(MANIFEST.name))

    if ARCHIVE.exists():
        ARCHIVE.unlink()
    with zipfile.ZipFile(
        ARCHIVE,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
        allowZip64=True,
    ) as archive:
        for path in sorted(archive_base.rglob("*")):
            if not path.is_file():
                continue
            arcname = path.relative_to(STAGING).as_posix()
            info = zipfile.ZipInfo(arcname, FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(
                info,
                path.read_bytes(),
                compresslevel=9,
            )

    archive_sha = sha256(ARCHIVE)
    SHA_FILE.write_text(
        f"{archive_sha}  {ARCHIVE.name}\n",
        encoding="utf-8",
    )
    print(f"archive={ARCHIVE}")
    print(f"members={len(rows) + 1}")
    print(f"bytes={ARCHIVE.stat().st_size}")
    print(f"sha256={archive_sha}")


if __name__ == "__main__":
    main()
