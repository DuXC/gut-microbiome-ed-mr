import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const artifactToolDir = process.env.CODEX_ARTIFACT_TOOL_DIR ||
  "/Users/duxiancheng/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool";
const { SpreadsheetFile, Workbook } = await import(
  pathToFileURL(path.join(artifactToolDir, "dist", "artifact_tool.mjs")).href
);

const root = path.resolve(import.meta.dirname, "..");
const dataDir = path.join(import.meta.dirname, "tmp_table_data");
const tableDir = path.join(root, "05_tables");
const supplementDir = path.join(root, "06_supplement");
const previewDir = path.join(root, "07_qc", "xlsx_previews");
const inspectDir = path.join(root, "07_qc", "inspect_logs");
await Promise.all([tableDir, supplementDir, previewDir, inspectDir].map((p) => fs.mkdir(p, { recursive: true })));

const readJson = async (name) => JSON.parse(await fs.readFile(path.join(dataDir, name), "utf8"));
const clean = (value) => {
  if (value === null || value === undefined) return "";
  if (typeof value !== "string") return value;
  return value
    .replaceAll(
      "strongly pleiotropic",
      "showing broad phenotype associations and substantial pleiotropy concerns",
    )
    .replaceAll(
      "Strongly pleiotropic",
      "Broadly associated region with substantial pleiotropy concerns",
    );
};
const colName = (n) => {
  let s = "";
  while (n > 0) { n--; s = String.fromCharCode(65 + (n % 26)) + s; n = Math.floor(n / 26); }
  return s;
};
const matrixFromObjects = (rows) => {
  const headers = rows.length ? Object.keys(rows[0]) : ["No data"];
  return { headers, values: rows.map((r) => headers.map((h) => clean(r[h]))) };
};

function formatSheet(sheet, title, headers, values, widths = []) {
  const lastCol = colName(headers.length);
  const lastRow = 3 + values.length;
  sheet.showGridLines = false;
  sheet.getRange(`A1:${lastCol}1`).merge();
  sheet.getRange("A1").values = [[title]];
  sheet.getRange(`A1:${lastCol}1`).format = {
    fill: "#243447", font: { bold: true, color: "#FFFFFF", size: 13 },
    verticalAlignment: "center", wrapText: true,
  };
  sheet.getRange(`A3:${lastCol}3`).values = [headers];
  sheet.getRange(`A3:${lastCol}3`).format = {
    fill: "#52677D", font: { bold: true, color: "#FFFFFF" },
    verticalAlignment: "center", wrapText: true,
  };
  if (values.length) {
    sheet.getRange(`A4:${lastCol}${lastRow}`).values = values;
    sheet.getRange(`A4:${lastCol}${lastRow}`).format = {
      verticalAlignment: "top", wrapText: true,
      borders: { bottom: { color: "#D9E0E7", style: "thin" } },
    };
    if (values.length <= 10000) {
      sheet.tables.add(`A3:${lastCol}${lastRow}`, true, `T_${sheet.name.replace(/[^A-Za-z0-9]/g, "_")}`);
    }
  }
  headers.forEach((_, i) => {
    sheet.getRange(`${colName(i + 1)}:${colName(i + 1)}`).format.columnWidth = widths[i] || 18;
  });
  headers.forEach((header, i) => {
    const column = colName(i + 1);
    if (values.length && /(?:_at_utc|date)$/i.test(header)) {
      sheet.getRange(`${column}4:${column}${lastRow}`).format.numberFormat = "yyyy-mm-dd hh:mm:ss";
    }
    if (values.length && /(^|[_ ])(?:p|q)(?:$|[_ ])/i.test(header)) {
      sheet.getRange(`${column}4:${column}${lastRow}`).format.numberFormat = "0.000E+00";
    } else if (values.length && /(?:beta|standard error|\bse\b|F statistic|FDR|\beaf\b|\br2\b|odds ratio|\bOR\b)/i.test(header)) {
      sheet.getRange(`${column}4:${column}${lastRow}`).format.numberFormat = "0.000000";
    }
  });
  sheet.getRange("1:1").format.rowHeight = 30;
  sheet.getRange("3:3").format.rowHeight = 32;
  sheet.freezePanes.freezeRows(3);
}

async function verifyAndExport(workbook, outputPath, previewSpecs) {
  const errors = await workbook.inspect({
    kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
    options: { useRegex: true, maxResults: 50 }, summary: "formula error scan",
  });
  await fs.writeFile(path.join(inspectDir, `${path.basename(outputPath)}.inspect.ndjson`), errors.ndjson || "", "utf8");
  for (const spec of previewSpecs) {
    const blob = await workbook.render({ sheetName: spec.sheetName, range: spec.range, scale: 1.1, format: "png" });
    await fs.writeFile(path.join(previewDir, spec.file), new Uint8Array(await blob.arrayBuffer()));
  }
  const output = await SpreadsheetFile.exportXlsx(workbook);
  await output.save(outputPath);
}

async function buildMainTable(jsonName, outputName, title, widths) {
  const rows = await readJson(jsonName);
  const { headers, values } = matrixFromObjects(rows);
  const wb = Workbook.create();
  const sheet = wb.worksheets.add("Table");
  formatSheet(sheet, title, headers, values, widths);
  const notes = await readJson(jsonName.replace(/\.json$/, "_notes.json"));
  const noteSheet = wb.worksheets.add("Notes");
  const noteMatrix = matrixFromObjects(notes);
  formatSheet(noteSheet, `${title}: footnotes`, noteMatrix.headers, noteMatrix.values, [105]);
  await verifyAndExport(wb, path.join(tableDir, outputName), [{
    sheetName: "Table", range: `A1:${colName(headers.length)}${Math.min(values.length + 3, 15)}`,
    file: outputName.replace(/\.xlsx$/, "_preview.png"),
  }, {
    sheetName: "Notes", range: `A1:A${Math.min(noteMatrix.values.length + 3, 12)}`,
    file: outputName.replace(/\.xlsx$/, "_notes_preview.png"),
  }]);
}

await buildMainTable(
  "main_table_1_v0_3_5.json", "IJIR_Table_1_Data_Sources_v0_3_5.xlsx",
  "Table 1. GWAS sources and analytical roles",
  [30, 28, 46, 36, 42],
);
await buildMainTable(
  "main_table_2_v0_3_5.json", "IJIR_Table_2_Forward_Nominal_Associations_v0_3_5.xlsx",
  "Table 2. Nominal forward gut microbial trait–ED associations",
  [40, 35, 22, 22, 15, 15, 42, 36],
);

const supplementManifest = await readJson("supplement_manifest_v0_3_5.json");
const wb = Workbook.create();
const previews = [];
for (const spec of supplementManifest) {
  const rows = await readJson(spec.json_file);
  const { headers, values } = matrixFromObjects(rows);
  const sheetName = spec.sheet_name;
  const title = spec.title;
  const sheet = wb.worksheets.add(sheetName);
  const widths = headers.map((h) => {
    if (/url|path|note|trait|description|status|message|reason|interpretation|association|scale|method|artifact/i.test(h)) return 40;
    if (/sha256/i.test(h)) return 56;
    return 18;
  });
  formatSheet(sheet, title, headers, values, widths);
  previews.push({
    sheetName, range: `A1:${colName(Math.min(headers.length, 12))}${Math.min(values.length + 3, 15)}`,
    file: `IJIR_Supplement_${sheetName.replace(/[^A-Za-z0-9]/g, "_")}_preview.png`,
  });
}
await verifyAndExport(
  wb,
  path.join(supplementDir, "IJIR_Supplementary_Data_v0_3_5.xlsx"),
  previews,
);

console.log("Created IJIR v0.3.5 main-table and supplementary workbooks with previews.");
