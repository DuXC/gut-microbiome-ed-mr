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
const clean = (value) => value === null || value === undefined ? "" : value;
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
    sheet.tables.add(`A3:${lastCol}${lastRow}`, true, `T_${sheet.name.replace(/[^A-Za-z0-9]/g, "_")}`);
  }
  headers.forEach((_, i) => {
    sheet.getRange(`${colName(i + 1)}:${colName(i + 1)}`).format.columnWidth = widths[i] || 18;
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
  await verifyAndExport(wb, path.join(tableDir, outputName), [{
    sheetName: "Table", range: `A1:${colName(headers.length)}${Math.min(values.length + 3, 15)}`,
    file: outputName.replace(/\.xlsx$/, "_preview.png"),
  }]);
}

await buildMainTable(
  "main_table_1.json", "IJIR_Table_1_Data_Sources_v0_1.xlsx",
  "Table 1. GWAS sources and their prespecified analytical roles",
  [30, 14, 15, 42, 34, 36, 42],
);
await buildMainTable(
  "main_table_2.json", "IJIR_Table_2_Forward_Nominal_Associations_v0_1.xlsx",
  "Table 2. Nominal forward gut microbiota-to-erectile-dysfunction associations",
  [19, 32, 14, 23, 14, 14, 17, 19, 14, 23, 14],
);

const supplement = await readJson("supplement.json");
const wb = Workbook.create();
const specs = [
  ["README", "README", supplement.readme, [28, 85]],
  ["Source Summary", "GWAS source summary", supplement.source_summary],
  ["GWAS Source Ledger", "GWAS source and checksum ledger", supplement.source_ledger],
  ["Forward Primary", "Forward primary Mendelian randomization results", supplement.forward_primary],
  ["Forward Replication", "Exact-label HUNT forward replication results", supplement.forward_replication],
  ["Reverse Primary", "Reverse primary Mendelian randomization results", supplement.reverse_primary],
  ["Instrument Inventory", "Harmonized instrument inventory", supplement.instrument_inventory],
  ["Method Status", "Method execution and failure status", supplement.method_status],
  ["Final Receipt", "Frozen-analysis receipt", supplement.final_receipt],
  ["Data Dictionary", "Supplementary data dictionary", supplement.dictionary],
];
const previews = [];
for (const [sheetName, title, rows, fixedWidths] of specs) {
  let headers, values;
  if (Array.isArray(rows[0])) {
    headers = ["Field", "Value"];
    values = rows.map((r) => r.map(clean));
  } else {
    ({ headers, values } = matrixFromObjects(rows));
  }
  const sheet = wb.worksheets.add(sheetName);
  const widths = fixedWidths || headers.map((h) => /url|path|note|trait|description|status|message|reason/i.test(h) ? 38 : 18);
  formatSheet(sheet, title, headers, values, widths);
  previews.push({
    sheetName, range: `A1:${colName(Math.min(headers.length, 12))}${Math.min(values.length + 3, 15)}`,
    file: `IJIR_Supplement_${sheetName.replace(/[^A-Za-z0-9]/g, "_")}_preview.png`,
  });
}
await verifyAndExport(
  wb,
  path.join(supplementDir, "IJIR_Supplementary_Data_1_v0_1.xlsx"),
  previews,
);

console.log("Created IJIR main-table and supplementary workbooks with previews.");
