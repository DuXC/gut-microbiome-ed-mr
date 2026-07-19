#!/bin/zsh
set -euo pipefail

cache=${MR_LD_CACHE:-08_qc/download_cache/ld_reference_high_density}
candidate_root=${MR_CANDIDATE_ROOT:-03_data/processed/exposure_candidates}
output_prefix=${MR_EUR_BFILE:-03_data/processed/ld_reference_high_density/eur_candidate_chr_normalized_v2}
plink2=${MR_PLINK2_BINARY:-$cache/plink2/plink2}
pgen_zst=$cache/all_phase3.pgen.zst
pgen=$cache/all_phase3.pgen
pvar_zst=$cache/all_phase3.pvar.zst
psam=$cache/all_phase3.psam
coordinates=$cache/candidate_coordinates.tsv
matches=$cache/candidate_pvar_matches_chr_normalized.tsv
variant_ids=$cache/candidate_pgen_ids_chr_normalized_v2.txt
eur_samples=$cache/eur_samples.keep

require_file() {
  if [[ ! -f "$1" ]]; then
    print -u2 "Missing required file: $1"
    exit 1
  fi
}

for path in "$pgen_zst" "$pvar_zst" "$psam" "$plink2"; do
  require_file "$path"
done

if [[ ! -f "$pgen" ]]; then
  "$plink2" --zst-decompress "$pgen_zst" "$pgen"
fi

MR_CANDIDATE_ROOT="$candidate_root" MR_COORDINATE_PATH="$coordinates" \
  /opt/homebrew/bin/Rscript - <<'RS'
source("R/gwas_schema.R")
source("R/instruments.R")
x <- read_exposure_candidate_shards(Sys.getenv("MR_CANDIDATE_ROOT"))
coordinates <- unique(x[, c("chr", "pos")])
chromosome_order <- suppressWarnings(as.integer(coordinates$chr))
chromosome_order[is.na(chromosome_order) & coordinates$chr == "X"] <- 23L
chromosome_order[is.na(chromosome_order) & coordinates$chr == "Y"] <- 24L
chromosome_order[is.na(chromosome_order)] <- 99L
coordinates <- coordinates[order(chromosome_order, coordinates$pos), ]
data.table::fwrite(
  coordinates, Sys.getenv("MR_COORDINATE_PATH"), sep = "\t",
  col.names = FALSE, quote = FALSE
)
RS

temporary_matches=${matches}.tmp-$$
/opt/homebrew/bin/zstd -dc "$pvar_zst" | \
  awk 'BEGIN{FS=OFS="\t"}
       NR==FNR {need[$1 FS $2]=1; next}
       /^#/ {next}
       {
         c=$1
         if(c=="X") c="23"
         else if(c=="Y") c="24"
         else if(c=="XY") c="25"
         else if(c=="MT" || c=="M") c="26"
         k=c FS $2
         if(k in need) print c,$2,$3,$4,$5
       }' "$coordinates" - > "$temporary_matches"
mv "$temporary_matches" "$matches"

temporary_ids=${variant_ids}.tmp-$$
LC_ALL=C awk '
  $3!="." && $3!="" &&
  length($4)==1 && $4~/^[ACGT]$/ &&
  length($5)==1 && $5~/^[ACGT]$/ {print $3}
' "$matches" | LC_ALL=C sort -u > "$temporary_ids"
mv "$temporary_ids" "$variant_ids"

awk 'BEGIN{FS=OFS="\t"}
     NR==1 {print "#IID"; next}
     $5=="EUR" {print $1}' "$psam" > "$eur_samples"

mkdir -p "${output_prefix:h}"
"$plink2" \
  --pfile "${pgen:r}" vzs \
  --keep "$eur_samples" \
  --extract "$variant_ids" \
  --max-alleles 2 \
  --snps-only just-acgt \
  --threads "${MR_WORKERS:-8}" \
  --make-bed \
  --out "$output_prefix"

print "Prepared ancestry-matched candidate LD reference: $output_prefix"
/usr/bin/stat -f '%z %N' "$output_prefix.bed" "$output_prefix.bim" "$output_prefix.fam"
/usr/bin/shasum -a 256 "$output_prefix.bed" "$output_prefix.bim" "$output_prefix.fam"
