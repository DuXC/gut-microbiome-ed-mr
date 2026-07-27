#!/usr/bin/env python3
"""Set creator/version metadata in the final IJIR v0.3.5 XLSX files."""

from __future__ import annotations

import os
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "06_manuscript" / "ijir_v0_3_5_20260728"
FILES = {
    PACKAGE / "05_tables" / "IJIR_Table_1_Data_Sources_v0_3_5.xlsx":
        "IJIR Table 1: Data sources v0.3.5",
    PACKAGE
    / "05_tables"
    / "IJIR_Table_2_Forward_Nominal_Associations_v0_3_5.xlsx":
        "IJIR Table 2: Forward nominal associations v0.3.5",
    PACKAGE
    / "06_supplement"
    / "IJIR_Supplementary_Data_v0_3_5.xlsx":
        "IJIR Supplementary Data v0.3.5",
}

NS_REL = "http://schemas.openxmlformats.org/package/2006/relationships"
NS_CT = "http://schemas.openxmlformats.org/package/2006/content-types"
CORE_REL = (
    "http://schemas.openxmlformats.org/package/2006/relationships/"
    "metadata/core-properties"
)
CORE_TYPE = (
    "application/vnd.openxmlformats-package.core-properties+xml"
)


def core_xml(title: str) -> bytes:
    text = f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties
 xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:dcterms="http://purl.org/dc/terms/"
 xmlns:dcmitype="http://purl.org/dc/dcmitype/"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
 <dc:title>{escape(title)}</dc:title>
 <dc:subject>International Journal of Impotence Research submission v0.3.5</dc:subject>
 <dc:creator>Xiancheng Du et al.</dc:creator>
 <cp:keywords>Mendelian randomization; gut microbiome; erectile dysfunction</cp:keywords>
 <dc:description>Submission-associated workbook; frozen primary results are unchanged.</dc:description>
 <cp:lastModifiedBy>Xiancheng Du</cp:lastModifiedBy>
 <cp:revision>1</cp:revision>
 <dcterms:created xsi:type="dcterms:W3CDTF">2026-07-28T00:00:00Z</dcterms:created>
 <dcterms:modified xsi:type="dcterms:W3CDTF">2026-07-28T00:00:00Z</dcterms:modified>
 <cp:category>Article submission</cp:category>
 <cp:version>v0.3.5</cp:version>
</cp:coreProperties>"""
    return text.encode("utf-8")


def set_metadata(path: Path, title: str) -> None:
    with zipfile.ZipFile(path, "r") as source:
        payload = {name: source.read(name) for name in source.namelist()}

    relationships = ET.fromstring(
        payload["_rels/.rels"].lstrip(b"\xef\xbb\xbf")
    )
    if not any(rel.get("Type") == CORE_REL for rel in relationships):
        used = {rel.get("Id") for rel in relationships}
        relationship_id = "rIdCoreProperties"
        while relationship_id in used:
            relationship_id += "_"
        ET.SubElement(
            relationships,
            f"{{{NS_REL}}}Relationship",
            {
                "Id": relationship_id,
                "Type": CORE_REL,
                "Target": "/docProps/core.xml",
            },
        )
    payload["_rels/.rels"] = ET.tostring(
        relationships, encoding="utf-8", xml_declaration=True
    )

    content_types = ET.fromstring(
        payload["[Content_Types].xml"].lstrip(b"\xef\xbb\xbf")
    )
    if not any(
        item.get("PartName") == "/docProps/core.xml"
        for item in content_types
        if item.tag == f"{{{NS_CT}}}Override"
    ):
        ET.SubElement(
            content_types,
            f"{{{NS_CT}}}Override",
            {
                "PartName": "/docProps/core.xml",
                "ContentType": CORE_TYPE,
            },
        )
    payload["[Content_Types].xml"] = ET.tostring(
        content_types, encoding="utf-8", xml_declaration=True
    )
    payload["docProps/core.xml"] = core_xml(title)

    with tempfile.NamedTemporaryFile(
        prefix=path.stem + ".",
        suffix=".xlsx",
        dir=path.parent,
        delete=False,
    ) as handle:
        temporary = Path(handle.name)
    try:
        with zipfile.ZipFile(
            temporary,
            "w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=6,
        ) as output:
            for name, content in payload.items():
                output.writestr(name, content)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


for workbook, workbook_title in FILES.items():
    set_metadata(workbook, workbook_title)
    print(f"Updated metadata: {workbook}")
