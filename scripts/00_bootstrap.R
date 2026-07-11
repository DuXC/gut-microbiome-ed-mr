args <- commandArgs(trailingOnly = TRUE)
source("R/bootstrap.R")
mode <- bootstrap_mode(args, file.exists("renv.lock"))

options(repos = c(MRCIEU = "https://mrcieu.r-universe.dev", CRAN = "https://cloud.r-project.org"))
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
source("R/toolchain.R")

if (mode == "restore") {
  renv::restore(prompt = FALSE)
} else {
  if (!file.exists("renv.lock")) renv::init(bare = TRUE)
  renv::install(c(
    "targets", "tarchetypes", "testthat", "data.table", "arrow", "yaml",
    "jsonlite", "digest", "httr2", "rvest", "xml2", "TwoSampleMR",
    "genetics.binaRies",
    "ieugwasr", "mr.raps", "MendelianRandomization", "coloc", "susieR",
    "MVMR", "ggplot2", "patchwork", "quarto", "BiocManager",
    "github::rondolab/MR-PRESSO@3e3c92d7eda6dce0d1d66077373ec0f7ff4f7e87"
  ))
  BiocManager::install("rtracklayer", ask = FALSE, update = FALSE)
  renv::snapshot(type = "all", prompt = FALSE)
}

ensure_plink()
