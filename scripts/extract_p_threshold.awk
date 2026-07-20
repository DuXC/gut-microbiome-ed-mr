BEGIN { FS = OFS = "\t" }

NR == 1 {
  for (i = 1; i <= NF; i++) {
    header = tolower($i)
    if (header == "p-value" || header == "pval" || header == "p_value") {
      p_column = i
    }
    if (header == "rsid" || header == "rsids") {
      id_column = i
    }
  }
  if (!p_column || !id_column) {
    print "GWAS header lacks P-value or rsID column" > "/dev/stderr"
    exit 42
  }
  print
  next
}

$id_column != "" && $id_column != "." && $id_column != "NA" &&
  ($p_column + 0) < threshold {
  print
}
