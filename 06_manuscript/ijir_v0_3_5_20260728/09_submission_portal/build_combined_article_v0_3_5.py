#!/usr/bin/env python3
"""Build the single versionless IJIR Article File requested by the journal.

The submitted title page is retained as page 1. The blinded manuscript body is
appended from its "Abstract" heading onward, so page 2 starts with the abstract
and does not repeat the short-title line already present on the title page.
Original submission files are not modified.
"""

from copy import deepcopy
from pathlib import Path
import argparse

from docx import Document
from docx.oxml import OxmlElement
from docx.oxml.ns import qn


def paragraph_text(element) -> str:
    if element.tag != qn("w:p"):
        return ""
    return "".join(node.text or "" for node in element.iter(qn("w:t"))).strip()


def build(title_path: Path, manuscript_path: Path, output_path: Path) -> None:
    title_doc = Document(title_path)
    manuscript_doc = Document(manuscript_path)

    manuscript_body = manuscript_doc.element.body
    body_elements = list(manuscript_body)
    abstract_index = next(
        (
            index
            for index, element in enumerate(body_elements)
            if paragraph_text(element) == "Abstract"
        ),
        None,
    )
    if abstract_index is None:
        raise RuntimeError('Could not find the exact "Abstract" heading.')

    for element in body_elements[:abstract_index]:
        manuscript_body.remove(element)

    insertion_point = next(
        element
        for element in manuscript_body
        if element.tag != qn("w:sectPr")
    )
    for element in title_doc.element.body:
        if element.tag == qn("w:sectPr"):
            continue
        insertion_point.addprevious(deepcopy(element))

    page_break_paragraph = OxmlElement("w:p")
    page_break_run = OxmlElement("w:r")
    page_break = OxmlElement("w:br")
    page_break.set(qn("w:type"), "page")
    page_break_run.append(page_break)
    page_break_paragraph.append(page_break_run)
    insertion_point.addprevious(page_break_paragraph)

    core = manuscript_doc.core_properties
    core.title = (
        "Bidirectional Mendelian randomization of gut microbial traits and "
        "erectile dysfunction with cross-cohort same-SNP evaluation and "
        "multiplicity control"
    )
    core.subject = "IJIR combined title page, abstract, and article body"
    core.author = "Xiancheng Du"
    core.last_modified_by = "Xiancheng Du"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    manuscript_doc.save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("title_page", type=Path)
    parser.add_argument("manuscript", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.title_page, args.manuscript, args.output)


if __name__ == "__main__":
    main()
