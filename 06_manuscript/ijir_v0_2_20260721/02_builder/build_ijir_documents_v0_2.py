#!/usr/bin/env python3
from pathlib import Path
import re
from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK, WD_LINE_SPACING
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "01_sources"
OUT = ROOT / "03_submission_files"
OUT.mkdir(parents=True, exist_ok=True)

def set_cell_shading(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tcPr.append(shd)

def set_repeat_header(row):
    trPr = row._tr.get_or_add_trPr()
    el = OxmlElement("w:tblHeader")
    el.set(qn("w:val"), "true")
    trPr.append(el)

def add_page_number(section):
    p = section.footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run()
    begin = OxmlElement("w:fldChar"); begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText"); instr.set(qn("xml:space"), "preserve"); instr.text = " PAGE "
    end = OxmlElement("w:fldChar"); end.set(qn("w:fldCharType"), "end")
    run._r.extend([begin, instr, end])

def enable_line_numbers(section):
    sectPr = section._sectPr
    ln = sectPr.find(qn("w:lnNumType"))
    if ln is None:
        ln = OxmlElement("w:lnNumType")
        sectPr.append(ln)
    ln.set(qn("w:countBy"), "1")
    ln.set(qn("w:start"), "1")
    ln.set(qn("w:restart"), "continuous")

def setup(doc, double=True, line_numbers=False):
    section = doc.sections[0]
    section.top_margin = section.bottom_margin = Inches(1)
    section.left_margin = section.right_margin = Inches(1)
    for name in ["Normal", "Title", "Heading 1", "Heading 2", "Heading 3"]:
        style = doc.styles[name]
        style.font.name = "Times New Roman"
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "Times New Roman")
        style.font.color.rgb = RGBColor(0, 0, 0)
    normal = doc.styles["Normal"]
    normal.font.size = Pt(12)
    pf = normal.paragraph_format
    pf.space_after = Pt(0)
    pf.line_spacing_rule = WD_LINE_SPACING.DOUBLE if double else WD_LINE_SPACING.SINGLE
    for h in ["Heading 1", "Heading 2", "Heading 3"]:
        st = doc.styles[h]
        st.font.size = Pt(12); st.font.bold = True
        st.paragraph_format.space_before = Pt(12); st.paragraph_format.space_after = Pt(0)
        st.paragraph_format.keep_with_next = True
    add_page_number(section)
    if line_numbers: enable_line_numbers(section)

def add_inline(p, text):
    # Small Markdown subset: bold and italics.
    pos = 0
    for m in re.finditer(r"(\*\*[^*]+\*\*|\*[^*]+\*)", text):
        if m.start() > pos: p.add_run(text[pos:m.start()])
        token = m.group(0)
        if token.startswith("**"):
            r = p.add_run(token[2:-2]); r.bold = True
        else:
            r = p.add_run(token[1:-1]); r.italic = True
        pos = m.end()
    if pos < len(text): p.add_run(text[pos:])

def add_markdown(doc, md, skip_title=False):
    lines = md.splitlines(); paragraph = []
    def flush():
        nonlocal paragraph
        if paragraph:
            p = doc.add_paragraph(); add_inline(p, " ".join(x.strip() for x in paragraph))
            paragraph = []
    for i, line in enumerate(lines):
        if not line.strip(): flush(); continue
        if line.startswith("# "):
            flush()
            if skip_title: continue
            p = doc.add_paragraph(style="Title"); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            add_inline(p, line[2:])
        elif line.startswith("## "):
            flush(); doc.add_paragraph(line[3:], style="Heading 1")
        elif line.startswith("### "):
            flush(); doc.add_paragraph(line[4:], style="Heading 2")
        else:
            paragraph.append(line)
    flush()

def count_words(text):
    return len(re.findall(r"\b[\w'’–-]+\b", re.sub(r"[#*]", "", text), flags=re.UNICODE))

main_md = (SRC / "IJIR_Main_Manuscript_v0_2.md").read_text()
title_md = (SRC / "IJIR_Title_Page_v0_2.md").read_text()
cover_md = (SRC / "IJIR_Cover_Letter_v0_2.md").read_text()
abstract = re.search(r"## Abstract\n\n(.*?)\n\nKeywords:", main_md, re.S).group(1)
main_block = re.search(r"## Introduction\n(.*?)\n\n## Data availability", main_md, re.S).group(1)
abstract_wc, main_wc = count_words(abstract), count_words(main_block)
title_md = title_md.replace("[generated during build]", str(abstract_wc), 1).replace("[generated during build]", str(main_wc), 1)

doc = Document(); setup(doc, double=True, line_numbers=True)
add_markdown(doc, title_md)
doc.add_page_break()
add_markdown(doc, main_md, skip_title=True)
doc.core_properties.title = "Bidirectional MR of gut microbiota and erectile dysfunction"
doc.core_properties.author = "Xiancheng Du et al."
doc.save(OUT / "IJIR_Main_Manuscript_v0_2.docx")

doc = Document(); setup(doc, double=True, line_numbers=True)
add_markdown(doc, title_md)
doc.save(OUT / "IJIR_Title_Page_v0_2.docx")

doc = Document(); setup(doc, double=False, line_numbers=False)
doc.styles["Normal"].font.size = Pt(11)
add_markdown(doc, cover_md)
doc.save(OUT / "IJIR_Cover_Letter_v0_2.docx")

checklist = [
 ("1", "Title and abstract", "Title; Abstract", "MR design, directions, sources, instrument criteria, multiplicity and principal results stated."),
 ("2", "Background", "Introduction, paragraphs 1–3", "Clinical rationale, prior evidence and reproducibility problem described."),
 ("3", "Objectives", "Introduction, final paragraph", "Bidirectional, error-controlled reassessment stated."),
 ("4", "Study design and data sources", "Methods: Study design; GWAS data sources", "Summary-data design, cohorts, ancestry, phenotype and evidence roles specified."),
 ("5", "Participants", "Methods: GWAS data sources; Table 1", "Source-specific sample sizes and participant populations reported."),
 ("6", "Genetic variants", "Methods: Instrument construction", "Selection threshold, F statistic, clumping and LD reference reported."),
 ("7", "Variables and measurement", "Methods: GWAS data sources", "Microbial phenotypes, ED definitions and effect scales reported."),
 ("8", "MR assumptions", "Methods; Discussion", "Relevance enforced; independence/exclusion assessed through design and bounded sensitivity interpretation."),
 ("9", "Statistical methods", "Methods: MR estimation, sensitivity analyses, multiplicity; Prespecified mechanistic extension", "Wald ratio, IVW, robust estimators, family-wise FDR, product effects and gated colocalization prespecified."),
 ("10", "Missing data and harmonization", "Methods: Instrument construction and harmonization", "Build, allele, multiallelic and palindromic handling reported."),
 ("11", "Sensitivity analyses", "Methods; Results", "HUNT validation, known-overlap ED and mediator sources, robust methods, product-effect caveats and failure handling reported."),
 ("12", "Descriptive data", "Results: Instrument and harmonization geometry; Supplementary Data", "Eligible, estimable and harmonized counts reported."),
 ("13", "Main results", "Results: Forward, reverse and mechanistic analyses; Figure 2; Table 2", "Effect estimates, P values, FDR results, family denominators and expected nominal counts reported."),
 ("14", "Additional analyses", "Results: Mechanistic extension; Supplementary Data", "Replication results and all seven mechanistic families, instruments, overlap labels, receipts and stopping decision supplied."),
 ("15", "Key results", "Discussion, paragraph 1", "Results interpreted against objectives without promoting nominal findings."),
 ("16", "Limitations", "Discussion", "Sparse instruments, pleiotropy, matching, phenotype, mediator overlap, product-effect covariance and ancestry limitations described."),
 ("17", "Interpretation", "Discussion, final paragraph", "Conclusions bounded to tested instruments, traits and populations."),
 ("18", "Generalisability", "Discussion", "European-ancestry dominance and taxonomy/measurement transfer limitations stated."),
 ("19", "Funding", "Funding", "Grant numbers, recipients and funder role stated."),
 ("20", "Data, code and transparency", "Data availability; Software, reproducibility, and LLM use", "Source terms, public version DOI, hash receipts and LLM role reported."),
]
doc = Document(); setup(doc, double=False, line_numbers=False)
p = doc.add_paragraph(style="Title"); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run("STROBE-MR checklist").bold = True
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.add_run("Bidirectional Mendelian randomization of gut microbiota and erectile dysfunction with independent replication and multiplicity control")
doc.add_paragraph("This author-prepared checklist maps the manuscript to the STROBE-MR reporting domains. Page and line numbers should be refreshed from the final accepted-layout manuscript immediately before submission.")
table = doc.add_table(rows=1, cols=4); table.style = "Table Grid"
headers = ["Item", "Reporting domain", "Manuscript location", "Implementation note"]
for i, h in enumerate(headers):
    c = table.rows[0].cells[i]; c.text = h; set_cell_shading(c, "52677D")
    for r in c.paragraphs[0].runs: r.font.color.rgb = RGBColor(255,255,255); r.bold = True
set_repeat_header(table.rows[0])
for row in checklist:
    cells = table.add_row().cells
    for i, val in enumerate(row):
        cells[i].text = val; cells[i].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.TOP
        for p in cells[i].paragraphs:
            p.paragraph_format.space_after = Pt(0)
            for r in p.runs: r.font.name = "Times New Roman"; r.font.size = Pt(9)
widths = [0.45, 1.35, 2.15, 3.25]
for row in table.rows:
    for i, w in enumerate(widths): row.cells[i].width = Inches(w)
doc.save(OUT / "IJIR_STROBE_MR_Checklist_v0_2.docx")

print(f"Created DOCX files. Abstract words={abstract_wc}; main-text words={main_wc}.")
