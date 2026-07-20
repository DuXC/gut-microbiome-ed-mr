BEGIN { FS = OFS = "\t" }

NR == FNR {
  if ($1 == "TARGET") {
    targets[$2 SUBSEP $3] = 1
  } else if ($1 == "REGION") {
    region_chr = $2
    region_start = $3 + 0
    region_end = $4 + 0
  }
  next
}

FNR == 1 {
  for (i = 1; i <= NF; i++) {
    header = tolower($i)
    if (header == "markername") marker_column = i
    if (header == "p-value" || header == "p_value" || header == "pval") {
      p_column = i
    }
  }
  if (!marker_column || !p_column || !region_chr) {
    print "SCALLOP extraction plan or header is invalid" > "/dev/stderr"
    exit 42
  }
  print
  next
}

{
  count = split($marker_column, marker, ":")
  if (count < 3) next
  chromosome = marker[1]
  position = marker[2] + 0
  key = chromosome SUBSEP position
  in_region = chromosome == region_chr && position >= region_start && \
    position <= region_end && $p_column != "" && $p_column != "NA" && \
    ($p_column + 0) < threshold
  if ((key in targets) || in_region) print
}
