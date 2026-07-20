BEGIN { FS = OFS = "\t" }

NR == FNR {
  wanted[$1] = 1
  next
}

FNR == 1 {
  for (i = 1; i <= NF; i++) {
    header = tolower($i)
    sub(/^#/, "", header)
    if (header == "rsid" || header == "rsids" || header == "rs_id") {
      id_column = i
    }
  }
  if (!id_column) {
    print "Outcome header has no rsID/rsids column" > "/dev/stderr"
    exit 42
  }
  print
  next
}

{
  value = $id_column
  if (value in wanted) {
    print
    next
  }
  if (index(value, ",") || index(value, ";")) {
    count = split(value, identifiers, /[,;]/)
    for (i = 1; i <= count; i++) {
      if (identifiers[i] in wanted) {
        print
        next
      }
    }
  }
}
