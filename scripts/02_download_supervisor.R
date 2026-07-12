#!/usr/bin/env Rscript

script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- if (length(script_argument)) {
  sub("^--file=", "", script_argument[[1L]])
} else {
  file.path("scripts", "02_download_supervisor.R")
}
project_root <- normalizePath(file.path(dirname(script_file), ".."))
setwd(project_root)

source(file.path(project_root, "R", "provenance.R"))
source(file.path(project_root, "R", "download.R"))
source(file.path(project_root, "R", "download_supervisor.R"))

run_download_supervisor(project_root)
