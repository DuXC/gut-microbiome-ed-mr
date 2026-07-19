BEGIN { FS = OFS = "\t" }

NR == FNR {
  wanted[$1] = 1
  next
}

FNR == 1 {
  for (i = 1; i <= NF; i++) {
    header = tolower($i)
    sub(/^#/, "", header)
    if (header == "rsid" || header == "rsids") {
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
  count = split($id_column, identifiers, /[,;]/)
  hit = 0
  for (i = 1; i <= count; i++) {
    if (identifiers[i] in wanted) {
      hit = 1
    }
  }
  if (hit) {
    print
  }
}
