#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) sub("^--file=", "", script_argument[[1L]]) else ""
script_path <- if (nzchar(script_file) && script_file != "-") script_file else file.path("scripts", "20_extract_available_mechanistic_sources.R")
project_root <- normalizePath(file.path(dirname(script_path), ".."))
setwd(project_root)

source(file.path(project_root, "R", "provenance.R"))
source(file.path(project_root, "R", "gwas_schema.R"))
source(file.path(project_root, "R", "outcomes.R"))
source(file.path(project_root, "R", "mechanistic_extension.R"))
source(file.path(project_root, "R", "mechanistic_gwas.R"))

receipt <- extract_available_cytokine_targets(project_root)
message(sprintf(
  "cytokine_sources_extracted=%d requested_rows=%d matched_rows=%d",
  nrow(receipt), sum(receipt$requested_rows), sum(receipt$matched_rows)
))
