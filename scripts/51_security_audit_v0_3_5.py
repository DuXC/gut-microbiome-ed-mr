#!/usr/bin/env python3
"""Credential scan for the IJIR v0.3.5 repository and submission package.

Only file paths and hit counts are reported. Secret-like text is never printed.
"""

from __future__ import annotations

import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "06_manuscript" / "ijir_v0_3_5_20260728"
QC = PACKAGE / "07_qc"
DELIVERY = PACKAGE / "09_final_delivery_v0_3_5"
QC.mkdir(parents=True, exist_ok=True)
DELIVERY.mkdir(parents=True, exist_ok=True)

JWT = re.compile(
    rb"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}"
)
JWT_PREFIX = re.compile(rb"eyJ[A-Za-z0-9_-]{50,}")
AUTH_HEADER = re.compile(
    rb"(?i)authorization\s*:\s*bearer\s+[A-Za-z0-9._-]{20,}"
)
TEXT_SUFFIXES = {
    ".r",
    ".R",
    ".py",
    ".js",
    ".mjs",
    ".sh",
    ".zsh",
    ".md",
    ".txt",
    ".csv",
    ".tsv",
    ".json",
    ".ndjson",
    ".yaml",
    ".yml",
    ".toml",
    ".ini",
    ".env",
    ".ipynb",
    ".cff",
    ".lock",
    ".profile",
}
SCAN_ROOTS = [
    ROOT / "R",
    ROOT / "scripts",
    ROOT / "config",
    ROOT / "00_admin",
    ROOT / "01_protocol",
    ROOT / "02_literature",
    ROOT / "05_results",
    PACKAGE,
]


def secret_kinds(data: bytes) -> list[str]:
    kinds: list[str] = []
    if JWT.search(data):
        kinds.append("complete_jwt_pattern")
    elif JWT_PREFIX.search(data):
        kinds.append("long_jwt_prefix_pattern")
    if AUTH_HEADER.search(data):
        kinds.append("authorization_bearer_pattern")
    return kinds


working_hits: list[dict[str, str]] = []
scanned_files = 0
for scan_root in SCAN_ROOTS:
    if not scan_root.exists():
        continue
    for path in scan_root.rglob("*"):
        if (
            not path.is_file()
            or path.suffix not in TEXT_SUFFIXES
            or path.stat().st_size > 50 * 1024 * 1024
        ):
            continue
        scanned_files += 1
        for kind in secret_kinds(path.read_bytes()):
            working_hits.append(
                {"path": str(path.relative_to(ROOT)), "kind": kind}
            )

history_hits: list[dict[str, str]] = []
history_paths = [
    Path.home() / ".zsh_history",
    Path.home() / ".bash_history",
]
log_root = Path.home() / "Library" / "Logs"
if log_root.exists():
    for path in log_root.rglob("*"):
        if (
            path.is_file()
            and path.stat().st_size <= 50 * 1024 * 1024
            and any(
                key in path.name.lower()
                for key in ("gut", "ijir", "opengwas")
            )
        ):
            history_paths.append(path)
for path in history_paths:
    if not path.is_file() or path.stat().st_size > 50 * 1024 * 1024:
        continue
    for kind in secret_kinds(path.read_bytes()):
        history_hits.append({"path": str(path), "kind": kind})

git_history_hits: list[dict[str, str]] = []
revisions = subprocess.run(
    ["git", "rev-list", "--all"],
    cwd=ROOT,
    check=True,
    capture_output=True,
    text=True,
).stdout.splitlines()
git_pattern = (
    r"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\."
    r"[A-Za-z0-9_-]{20,}"
)
for revision in revisions:
    result = subprocess.run(
        ["git", "grep", "-I", "-l", "-E", git_pattern, revision],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr.strip() or "git grep failed")
    for line in result.stdout.splitlines():
        _, _, path = line.partition(":")
        git_history_hits.append(
            {
                "revision": revision[:12],
                "path": path or line,
                "kind": "complete_jwt_pattern",
            }
        )

receipt_path = (
    ROOT
    / "05_results"
    / "v0_3_2_1_opengwas_20260723"
    / "opengwas_query_receipt_v0_3_2_1.json"
)
receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
receipt_safe = str(receipt.get("jwt_storage", "")).lower().startswith(
    "not persisted"
)

all_hits = working_hits + history_hits + git_history_hits
status = "PASS" if not all_hits and receipt_safe else "FAIL"
result = {
    "version": "v0.3.5",
    "generated_utc": datetime.now(timezone.utc).isoformat(),
    "status": status,
    "working_tree_files_scanned": scanned_files,
    "git_revisions_scanned": len(revisions),
    "working_tree_hits": working_hits,
    "operational_history_hits": history_hits,
    "git_history_hits": git_history_hits,
    "opengwas_receipt_jwt_storage_safe": receipt_safe,
    "token_revocation_verified": False,
    "author_action_required": (
        "Revoke and regenerate the OpenGWAS JWT after the completed audit; "
        "revocation has not been verified by this workflow."
    ),
    "scope_note": (
        "Repository text, Git history, selected operational logs and shell "
        "histories, configuration text, notebooks, receipts, and "
        "submission-associated text files were scanned. The conversation "
        "service is not exported into the repository and was not claimed as "
        "scanned."
    ),
}
(QC / "SECURITY_SCAN_v0_3_5.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

report = f"""# SECURITY QA — IJIR v0.3.5

Status: **{status}**

- Working-tree text files scanned: {scanned_files}
- Git revisions scanned: {len(revisions)}
- JWT-like or bearer-header hits in the working tree: {len(working_hits)}
- JWT-like or bearer-header hits in selected shell/log history: {len(history_hits)}
- JWT-like hits in committed Git history: {len(git_history_hits)}
- OpenGWAS query receipt states that the JWT was not persisted: {"yes" if receipt_safe else "no"}
- Token revocation verified: **no**

No token string, truncated token, or authentication header is reproduced in
this report. The scan covered repository text, Git history, selected
operational logs and shell histories, environment/configuration text,
notebooks, receipts, and submission-associated files. The conversation
service is not exported into the repository and is not claimed as scanned.

Author action after the audit: **revoke and regenerate the OpenGWAS JWT**.
This workflow has not performed or verified revocation.
"""
for output in [
    DELIVERY / "SECURITY_QA_v0_3_5.md",
    DELIVERY / "SECURITY_QA.md",
]:
    output.write_text(report, encoding="utf-8")

print(
    f"{status}: scanned {scanned_files} files and {len(revisions)} "
    f"revisions; hits={len(all_hits)}"
)
raise SystemExit(0 if status == "PASS" else 1)
