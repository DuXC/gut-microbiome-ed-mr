#!/usr/bin/env Rscript

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this builder with Rscript.")
script_path <- normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE)
script_dir <- dirname(script_path)
project_root <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
package_root <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)
output_dir <- file.path(package_root, "04_figures")
supplement_dir <- file.path(output_dir, "supplementary")
source_dir <- file.path(output_dir, "source_data")
qc_dir <- file.path(package_root, "07_qc")
dir.create(supplement_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)

local_library <- file.path(
  project_root, "renv", "library", "macos", "R-4.6",
  "aarch64-apple-darwin25.4.0"
)
if (dir.exists(local_library)) .libPaths(c(local_library, .libPaths()))

required_packages <- c(
  "data.table", "digest", "ggplot2", "patchwork", "ragg", "scales",
  "svglite"
)
missing_packages <- required_packages[!vapply(
  required_packages, requireNamespace, logical(1), quietly = TRUE
)]
if (length(missing_packages)) {
  stop("Missing required R packages: ", paste(missing_packages, collapse = ", "))
}
suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(patchwork)
})

font_family <- "Arial"
palette <- c(
  neutral_dark = "#252525", neutral_mid = "#737373",
  neutral_light = "#D9D9D9", neutral_pale = "#F3F3F3",
  blue = "#2C7FB8", blue_light = "#A6CEE3", orange = "#D95F0E",
  teal = "#238B8E"
)

theme_ijir <- function(base_size = 7.0) {
  theme_classic(base_size = base_size, base_family = font_family) +
    theme(
      axis.line = element_line(linewidth = 0.40, colour = "black"),
      axis.ticks = element_line(linewidth = 0.40, colour = "black"),
      axis.title = element_text(size = base_size),
      axis.text = element_text(size = base_size - 0.4, colour = "black"),
      legend.title = element_text(size = base_size - 0.2),
      legend.text = element_text(size = base_size - 0.5),
      strip.background = element_blank(),
      strip.text = element_text(size = base_size + 0.2, face = "bold",
                                hjust = 0),
      plot.title = element_text(size = base_size + 0.8, face = "bold",
                                hjust = 0),
      plot.subtitle = element_text(size = base_size - 0.2, colour = "#404040"),
      plot.caption = element_text(size = base_size - 0.8, colour = "#404040",
                                  hjust = 0),
      plot.tag = element_text(size = 9, face = "bold"),
      panel.grid = element_blank(),
      legend.key.height = grid::unit(3.5, "mm")
    )
}
theme_set(theme_ijir())

write_source <- function(x, filename) {
  path <- file.path(source_dir, filename)
  data.table::fwrite(as.data.frame(x), path, na = "")
  path
}

export_records <- list()
register_export <- function(stem, width_mm, height_mm, folder, source_files) {
  formats <- c("pdf", "svg", "tiff", "png", "preview.png")
  files <- c(
    file.path(folder, paste0(stem, ".pdf")),
    file.path(folder, paste0(stem, ".svg")),
    file.path(folder, paste0(stem, ".tiff")),
    file.path(folder, paste0(stem, "_600dpi.png")),
    file.path(folder, paste0(stem, "_preview.png"))
  )
  export_records[[length(export_records) + 1L]] <<- data.table(
    figure = stem, format = formats,
    file = substring(files, nchar(package_root) + 2L),
    width_mm = width_mm, height_mm = height_mm,
    dpi = c(NA, NA, 600, 600, 300),
    bytes = file.info(files)$size,
    sha256 = vapply(files, digest::digest, character(1), file = TRUE,
                    algo = "sha256", serialize = FALSE),
    source_data = paste(basename(source_files), collapse = ";")
  )
}

save_gg <- function(plot, stem, width_mm, height_mm, folder = output_dir,
                    source_files = character()) {
  width_in <- width_mm / 25.4
  height_in <- height_mm / 25.4
  svglite::svglite(file.path(folder, paste0(stem, ".svg")),
                   width = width_in, height = height_in)
  print(plot); grDevices::dev.off()
  grDevices::cairo_pdf(file.path(folder, paste0(stem, ".pdf")),
                       width = width_in, height = height_in,
                       family = font_family)
  print(plot); grDevices::dev.off()
  ragg::agg_tiff(file.path(folder, paste0(stem, ".tiff")),
                 width = width_in, height = height_in, units = "in",
                 res = 600, compression = "lzw", background = "white")
  print(plot); grDevices::dev.off()
  ragg::agg_png(file.path(folder, paste0(stem, "_600dpi.png")),
                width = width_in, height = height_in, units = "in", res = 600,
                background = "white")
  print(plot); grDevices::dev.off()
  ragg::agg_png(file.path(folder, paste0(stem, "_preview.png")),
                width = width_in, height = height_in, units = "in", res = 300,
                background = "white")
  print(plot); grDevices::dev.off()
  register_export(stem, width_mm, height_mm, folder, source_files)
}

save_grid <- function(draw_fun, stem, width_mm, height_mm,
                      source_files = character()) {
  width_in <- width_mm / 25.4
  height_in <- height_mm / 25.4
  devices <- list(
    function() svglite::svglite(file.path(output_dir, paste0(stem, ".svg")),
                                width = width_in, height = height_in),
    function() grDevices::cairo_pdf(
      file.path(output_dir, paste0(stem, ".pdf")), width = width_in,
      height = height_in, family = font_family
    ),
    function() ragg::agg_tiff(
      file.path(output_dir, paste0(stem, ".tiff")), width = width_in,
      height = height_in, units = "in", res = 600, compression = "lzw",
      background = "white"
    ),
    function() ragg::agg_png(
      file.path(output_dir, paste0(stem, "_600dpi.png")), width = width_in,
      height = height_in, units = "in", res = 600, background = "white"
    ),
    function() ragg::agg_png(
      file.path(output_dir, paste0(stem, "_preview.png")), width = width_in,
      height = height_in, units = "in", res = 300, background = "white"
    )
  )
  for (open_device in devices) {
    open_device(); draw_fun(); grDevices::dev.off()
  }
  register_export(stem, width_mm, height_mm, output_dir, source_files)
}

v03 <- file.path(project_root, "05_results", "v0_3_20260722")
forward <- fread(file.path(
  project_root, "05_results", "tables", "mr_multiplicity_forward.csv"
))
reverse <- fread(file.path(
  project_root, "05_results", "tables", "reverse_mr_multiplicity.csv"
))
multiplicity <- fread(file.path(v03, "multiplicity_sensitivity_trait_results.csv"))
power <- fread(file.path(v03, "power_mde_trait_results.csv"))
architecture <- fread(file.path(v03, "forward_instrument_architecture.csv"))
hunt <- fread(file.path(v03, "hunt_same_snp_validation.csv"))
hunt_summary <- fread(file.path(v03, "hunt_same_snp_validation_summary.csv"))
hunt_nominal <- fread(file.path(v03, "hunt_nominal_trait_audit.csv"))
strict_results <- fread(file.path(v03, "source_study_wide_mr_primary_results.csv"))
strict_summary <- fread(file.path(v03, "source_study_wide_sensitivity_summary.csv"))
mechanistic <- fread(file.path(v03, "mechanistic_screening_family_summary.csv"))

# Figure 1 ---------------------------------------------------------------------
figure1_counts <- data.table(
  direction = c(
    rep("Forward", 6), rep("Cross-cohort exposure validation", 5),
    rep("Reverse", 5), rep("Known-overlap sensitivity", 3)
  ),
  item = c(
    "Swedish traits", "Eligible forward traits", "Estimable forward traits",
    "Forward nominal", "Forward FDR", "FinnGen cases and controls",
    "Exact-label traits", "Same-SNP coverage", "Direction concordant",
    "Same-SNP HUNT GWS", "Focal traits validated",
    "ED GWS candidates", "Independent ED instruments", "Swedish outcomes",
    "Reverse nominal", "Reverse FDR", "EUR sensitivity FDR",
    "AFR sensitivity FDR", "Cross-ancestry sensitivity FDR"
  ),
  value = c(
    1572, 230, 218, 7, 0, 2886 + 215272,
    97, 97, 76, 11, 0, 479, 24, 1572, 77, 0, 8, 0, 8
  ),
  evidence_level = c(
    rep("primary discovery", 6), rep("independent exposure cohort only", 5),
    rep("primary reverse screen", 5), rep("known FinnGen overlap", 3)
  )
)
figure1_source <- write_source(figure1_counts, "Figure_1_source_data.csv")

draw_box <- function(x, y, width, height, title, details,
                     fill = palette[["neutral_pale"]]) {
  grid::grid.roundrect(
    x = grid::unit(x, "npc"), y = grid::unit(y, "npc"),
    width = grid::unit(width, "npc"), height = grid::unit(height, "npc"),
    r = grid::unit(1.7, "mm"),
    gp = grid::gpar(fill = fill, col = palette[["neutral_dark"]], lwd = 1.2)
  )
  grid::grid.text(
    title, x = x, y = y + height * 0.20,
    gp = grid::gpar(fontfamily = font_family, fontsize = 8.2,
                    fontface = "bold")
  )
  grid::grid.text(
    details, x = x, y = y - height * 0.15,
    gp = grid::gpar(fontfamily = font_family, fontsize = 6.8,
                    lineheight = 1.12)
  )
}

draw_arrow <- function(x0, y0, x1, y1, lty = 1L) {
  grid::grid.lines(
    x = grid::unit(c(x0, x1), "npc"),
    y = grid::unit(c(y0, y1), "npc"),
    arrow = grid::arrow(type = "closed", length = grid::unit(2.3, "mm")),
    gp = grid::gpar(col = palette[["neutral_dark"]], lwd = 1.2, lty = lty)
  )
}

draw_figure_1 <- function() {
  grid::grid.newpage()
  grid::grid.text(
    "a", x = 0.018, y = 0.975, just = c("left", "top"),
    gp = grid::gpar(fontfamily = font_family, fontsize = 10, fontface = "bold")
  )
  grid::grid.text(
    "Forward: gut microbial traits to erectile dysfunction",
    x = 0.055, y = 0.968, just = c("left", "top"),
    gp = grid::gpar(fontfamily = font_family, fontsize = 9.3, fontface = "bold")
  )
  draw_box(0.14, 0.79, 0.22, 0.15, "Swedish shotgun GWAS",
           "1 572 microbial traits\nN = 16 017; European")
  draw_box(0.39, 0.79, 0.18, 0.15, "Primary instruments",
           "P < 5×10⁻⁸; F > 10\n230 eligible traits")
  draw_box(0.62, 0.79, 0.19, 0.15, "FinnGen R12 ED",
           "2 886 cases\n215 272 controls")
  draw_box(0.86, 0.79, 0.19, 0.15, "Forward result",
           "218 estimable\n7 nominal; 0 FDR")
  draw_arrow(0.25, 0.79, 0.30, 0.79)
  draw_arrow(0.48, 0.79, 0.525, 0.79)
  draw_arrow(0.715, 0.79, 0.765, 0.79)

  draw_box(0.16, 0.53, 0.27, 0.15, "Exact-label HUNT coverage",
           "97/230 matched\n97/97 same SNPs retrieved", "white")
  draw_box(0.50, 0.53, 0.30, 0.15,
           "Cross-cohort exposure validation",
           "76/97 directions concordant\n95% CI 68.8%–86.1%; scales differ", "white")
  draw_box(0.84, 0.53, 0.27, 0.15, "Exploratory HUNT sensitivity",
           "Fimisoma/UBA644: 0 GWS IVs\nlegacy P<1×10⁻⁵ (23/20); 0 validated",
           "white")
  draw_arrow(0.14, 0.715, 0.16, 0.605, lty = 2L)
  draw_arrow(0.295, 0.53, 0.35, 0.53, lty = 2L)
  draw_arrow(0.65, 0.53, 0.705, 0.53, lty = 2L)

  grid::grid.lines(
    x = grid::unit(c(0.03, 0.97), "npc"),
    y = grid::unit(c(0.365, 0.365), "npc"),
    gp = grid::gpar(col = palette[["neutral_mid"]], lwd = 1.0)
  )
  grid::grid.text(
    "b", x = 0.018, y = 0.335, just = c("left", "top"),
    gp = grid::gpar(fontfamily = font_family, fontsize = 10, fontface = "bold")
  )
  grid::grid.text(
    "Reverse: erectile dysfunction to gut microbial traits",
    x = 0.055, y = 0.328, just = c("left", "top"),
    gp = grid::gpar(fontfamily = font_family, fontsize = 9.3, fontface = "bold")
  )
  draw_box(0.14, 0.19, 0.22, 0.14, "2025 European ED GWAS",
           "136 867 cases\n776 327 controls")
  draw_box(0.39, 0.19, 0.18, 0.14, "ED instruments",
           "479 GWS variants\n24 independent IVs")
  draw_box(0.62, 0.19, 0.19, 0.14, "Swedish outcomes",
           "1 572 microbial traits\n15–17 IVs per trait")
  draw_box(0.86, 0.19, 0.19, 0.14, "Reverse result",
           "1 572 estimable\n77 nominal; 0 FDR")
  draw_arrow(0.25, 0.19, 0.30, 0.19)
  draw_arrow(0.48, 0.19, 0.525, 0.19)
  draw_arrow(0.715, 0.19, 0.765, 0.19)
  grid::grid.text(
    "Known-overlap forward sensitivity: EUR 8 FDR; AFR 0; cross-ancestry 8. Includes FinnGen; not independent outcome replication.",
    x = 0.50, y = 0.085,
    gp = grid::gpar(fontfamily = font_family, fontsize = 6.5,
                    col = palette[["neutral_mid"]])
  )
  grid::grid.text(
    "Eligibility and multiplicity rules were finalized before association screening.",
    x = 0.50, y = 0.040,
    gp = grid::gpar(fontfamily = font_family, fontsize = 7.0,
                    fontface = "italic")
  )
  grid::grid.lines(
    x = grid::unit(c(0.06, 0.11), "npc"), y = grid::unit(c(0.012, 0.012), "npc"),
    gp = grid::gpar(lwd = 1.2, lty = 1)
  )
  grid::grid.text("primary discovery", x = 0.12, y = 0.012, just = "left",
                  gp = grid::gpar(fontfamily = font_family, fontsize = 5.9))
  grid::grid.lines(
    x = grid::unit(c(0.31, 0.36), "npc"), y = grid::unit(c(0.012, 0.012), "npc"),
    gp = grid::gpar(lwd = 1.2, lty = 2)
  )
  grid::grid.text("independent exposure cohort", x = 0.37, y = 0.012,
                  just = "left",
                  gp = grid::gpar(fontfamily = font_family, fontsize = 5.9))
  grid::grid.lines(
    x = grid::unit(c(0.63, 0.68), "npc"), y = grid::unit(c(0.012, 0.012), "npc"),
    gp = grid::gpar(lwd = 1.2, lty = 3)
  )
  grid::grid.text("known-overlap sensitivity", x = 0.69, y = 0.012,
                  just = "left",
                  gp = grid::gpar(fontfamily = font_family, fontsize = 5.9))
}

save_grid(
  draw_figure_1, "IJIR_Figure_1_Study_Design_v0_3", 183, 135,
  source_files = figure1_source
)

# Figure 2 ---------------------------------------------------------------------
rank_data <- rbindlist(list(
  data.table(direction = "Forward", p = fifelse(is.finite(forward$p), forward$p, 1),
             denominator = 230L),
  data.table(direction = "Reverse", p = fifelse(is.finite(reverse$p), reverse$p, 1),
             denominator = 1572L)
))
rank_data <- rank_data[, .(
  rank = seq_len(.N), observed_p = sort(p), denominator = denominator[[1L]]
), by = direction]
rank_data[, bh_p := 0.05 * rank / denominator]
rank_data[, global_bonferroni := 0.05 / (230 + 1572)]
figure2_source <- write_source(rank_data, "Figure_2_source_data.csv")
curve_data <- melt(
  rank_data,
  id.vars = c("direction", "rank", "denominator", "global_bonferroni"),
  measure.vars = c("observed_p", "bh_p"),
  variable.name = "curve", value.name = "p"
)
curve_data[, curve := factor(
  curve, levels = c("observed_p", "bh_p"),
  labels = c("Observed P", "BH 5% boundary")
)]
curve_data[, panel := factor(
  direction, levels = c("Forward", "Reverse"),
  labels = c(
    "a  Gut microbial traits → ED   (BH denominator = 230)",
    "b  ED → gut microbial traits   (BH denominator = 1 572)"
  )
)]
y_max <- max(5.2, -log10(curve_data$p), na.rm = TRUE) + 0.15
figure2 <- ggplot(curve_data, aes(rank, -log10(p), colour = curve,
                                  linetype = curve)) +
  geom_line(linewidth = 0.48) +
  geom_hline(yintercept = -log10(0.05 / 1802), linewidth = 0.40,
             linetype = "dotdash", colour = palette[["neutral_dark"]]) +
  geom_hline(yintercept = -log10(0.05), linewidth = 0.40,
             linetype = "dotted", colour = palette[["neutral_mid"]]) +
  facet_wrap(~panel, scales = "free_x", nrow = 1) +
  scale_colour_manual(values = c(
    "Observed P" = palette[["neutral_dark"]],
    "BH 5% boundary" = palette[["blue"]]
  )) +
  scale_linetype_manual(values = c("Observed P" = "solid",
                                   "BH 5% boundary" = "dashed")) +
  coord_cartesian(ylim = c(0, y_max), expand = FALSE) +
  labs(
    x = "Ranked tests", y = expression(-log[10](italic(P))),
    colour = NULL, linetype = NULL,
    caption = paste0(
      "Global Bonferroni = 0.05/1 802; nominal P = 0.05. ",
      "Forward: 12 non-estimable tests retained at P=1; no association passed FDR."
    )
  ) +
  theme_ijir() +
  theme(legend.position = "bottom", panel.spacing = grid::unit(7, "mm"),
        plot.caption = element_text(margin = margin(t = 4)))
save_gg(
  figure2, "IJIR_Figure_2_Multiplicity_v0_3", 183, 88,
  source_files = figure2_source
)

# Figure 3 ---------------------------------------------------------------------
nominal <- forward[analysis_status == "estimated" & p < 0.05]
nominal[, short_trait := fcase(
  grepl("Fimisoma avicola", trait), "Fimisoma avicola",
  grepl("UBA644", trait), "UBA644 sp900547165",
  grepl("Peptococcaceae", trait), "Peptococcaceae",
  grepl("Peptococcales", trait), "Peptococcales",
  grepl("Peptococcia", trait), "Peptococcia",
  grepl("Bacteroidaceae", trait), "Bacteroidaceae",
  grepl("CAG-302", trait), "CAG-302 sp934162325",
  default = trait
)]
setorder(nominal, p, source_id)
nominal[, y := .N:1L]
nominal[, nested_pepto := grepl("Peptococc", short_trait)]
nominal[, estimate_label := sprintf(
  "%.3f (%.3f–%.3f)", or, or_ci_lower, or_ci_upper
)]
nominal[, p_label := ifelse(p < 0.001, format(p, scientific = TRUE, digits = 2),
                            sprintf("%.3f", p))]
nominal[, q_label := sprintf("%.3f", q)]
figure3a_source <- write_source(nominal, "Figure_3a_source_data.csv")

pepto_range <- range(nominal[nested_pepto == TRUE, y])
p3a_forest <- ggplot(nominal, aes(y = y)) +
  annotate(
    "rect", xmin = 0.35, xmax = 6.8,
    ymin = pepto_range[[1L]] - 0.45, ymax = pepto_range[[2L]] + 0.45,
    fill = palette[["neutral_pale"]], colour = NA
  ) +
  geom_segment(aes(x = or_ci_lower, xend = or_ci_upper, yend = y),
               linewidth = 0.45, colour = palette[["neutral_dark"]]) +
  geom_point(aes(x = or, shape = nested_pepto), size = 2.0,
             stroke = 0.45, fill = "white", colour = palette[["blue"]]) +
  geom_vline(xintercept = 1, linetype = "dashed", linewidth = 0.40,
             colour = palette[["neutral_mid"]]) +
  scale_x_log10(limits = c(0.35, 6.8), breaks = c(0.5, 1, 2, 4),
                labels = scales::label_number(accuracy = 0.1)) +
  scale_y_continuous(breaks = nominal$y, labels = nominal$short_trait,
                     expand = expansion(mult = c(0.08, 0.13))) +
  scale_shape_manual(values = c(`FALSE` = 21, `TRUE` = 23)) +
  labs(
    tag = "a", title = "Nominal Swedish forward estimates",
    subtitle = "All are single-SNP Wald ratios; none survived FDR",
    x = "Odds ratio for erectile dysfunction (log scale)", y = NULL
  ) +
  theme_ijir() +
  theme(legend.position = "none", plot.margin = margin(4, 2, 2, 2))

table_long <- rbindlist(list(
  nominal[, .(y, column = "OR (95% CI)", label = estimate_label, x = 1)],
  nominal[, .(y, column = "P", label = p_label, x = 2)],
  nominal[, .(y, column = "q", label = q_label, x = 3)]
))
p3a_table <- ggplot(table_long, aes(x, y, label = label)) +
  annotate(
    "rect", xmin = 0.5, xmax = 3.5,
    ymin = pepto_range[[1L]] - 0.45, ymax = pepto_range[[2L]] + 0.45,
    fill = palette[["neutral_pale"]], colour = NA
  ) +
  geom_text(size = 2.2, family = font_family) +
  annotate("text", x = 1:3, y = max(nominal$y) + 0.80,
           label = c("OR (95% CI)", "P", "q"), fontface = "bold",
           size = 2.25, family = font_family) +
  annotate("text", x = 2, y = min(pepto_range) - 0.28,
           label = "nested, identical estimates", size = 2.05,
           colour = palette[["neutral_mid"]], family = font_family) +
  scale_x_continuous(limits = c(0.5, 3.5)) +
  scale_y_continuous(limits = c(0.2, max(nominal$y) + 1.15)) +
  theme_void(base_family = font_family) +
  theme(plot.margin = margin(4, 2, 2, 0))
p3a <- p3a_forest + p3a_table + plot_layout(widths = c(1.45, 1.0))

focal_ids <- c("GCST90670781", "GCST90670586")
hunt_two <- hunt[discovery_source_id %in% focal_ids]
hunt_two[, short_trait := fifelse(
  grepl("Fimisoma", discovery_trait), "Fimisoma avicola",
  "UBA644 sp900547165"
)]
hunt_two[, swedish_z := discovery_beta / discovery_se]
hunt_two[, y := fifelse(short_trait == "Fimisoma avicola", 2L, 1L)]
figure3b_source <- write_source(hunt_two, "Figure_3b_source_data.csv")
hunt_long <- rbindlist(list(
  hunt_two[, .(short_trait, y, cohort = "Swedish", signed_z = swedish_z,
               p = discovery_p, F = discovery_F)],
  hunt_two[, .(short_trait, y, cohort = "HUNT", signed_z = hunt_signed_z_aligned,
               p = hunt_p, F = hunt_F_same_snp)]
))
p3b <- ggplot() +
  geom_segment(
    data = hunt_two,
    aes(x = swedish_z, xend = hunt_signed_z_aligned, y = y, yend = y),
    linewidth = 0.45, colour = palette[["neutral_light"]]
  ) +
  geom_vline(xintercept = 0, linewidth = 0.40, linetype = "dashed",
             colour = palette[["neutral_mid"]]) +
  geom_point(
    data = hunt_long, aes(signed_z, y, colour = cohort, shape = cohort),
    size = 2.3, stroke = 0.45
  ) +
  geom_text(
    data = hunt_long[cohort == "HUNT"],
    aes(signed_z, y, label = paste0("  P=", sprintf("%.3f", p))),
    hjust = 0, size = 2.0, family = font_family,
    colour = palette[["neutral_dark"]]
  ) +
  scale_y_continuous(breaks = hunt_two$y, labels = hunt_two$short_trait,
                     limits = c(0.45, 2.55)) +
  scale_x_continuous(limits = c(-6.8, 2.2), breaks = c(-6, -4, -2, 0, 2)) +
  scale_colour_manual(values = c("Swedish" = palette[["blue"]],
                                 "HUNT" = palette[["orange"]])) +
  scale_shape_manual(values = c("Swedish" = 16, "HUNT" = 17)) +
  labs(
    tag = "b", title = "Same-SNP HUNT sensitivity",
    subtitle = "Swedish lead SNP, exact label and allele alignment",
    x = "Signed SNP–exposure Z", y = NULL, colour = NULL, shape = NULL,
    caption = paste0(
      "HUNT F=0.002 and 0.180; 0/2 validated.\n",
      "Legacy HUNT-selected IVs: P<1×10⁻⁵ (23/20 SNPs).\n",
      "Exposure scales differ;\nraw beta and MR OR are not directly comparable."
    )
  ) +
  theme_ijir(6.6) +
  theme(legend.position = "top", legend.justification = "left",
        plot.caption = element_text(size = 5.5),
        plot.margin = margin(4, 3, 2, 2))

architecture_estimable <- architecture[nsnp > 0]
architecture_source <- write_source(
  architecture, "Figure_3c_instrument_architecture_source_data.csv"
)
power_source <- write_source(power, "Figure_3c_power_source_data.csv")
p3c_bar <- ggplot(architecture_estimable, aes(factor(nsnp), trait_count)) +
  geom_col(width = 0.66, fill = palette[["blue"]], colour = "black",
           linewidth = 0.40) +
  geom_text(aes(label = trait_count), vjust = -0.35, size = 2.1,
            family = font_family) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.14))) +
  labs(tag = "c", title = "Instrument architecture", x = "IVs per trait",
       y = "Estimable traits", subtitle = "194/218 (89%) used one SNP") +
  theme_ijir(6.4) +
  theme(plot.margin = margin(4, 2, 2, 2))

power_plot <- copy(power)
power_plot[, alpha_display := factor(
  alpha_label,
  levels = c("nominal_0.05", "forward_bonferroni_0.05_over_230",
             "global_bonferroni_0.05_over_1802"),
  labels = c("Nominal", "Forward\nBonf.", "Global\nBonf.")
)]
medians <- power_plot[, .(median_mde = median(mde_or_higher)), by = alpha_display]
p3c_power <- ggplot(power_plot, aes(alpha_display, mde_or_higher)) +
  geom_boxplot(width = 0.63, outlier.shape = NA, fill = palette[["neutral_pale"]],
               colour = palette[["neutral_dark"]], linewidth = 0.40) +
  geom_jitter(width = 0.16, height = 0, size = 0.32, alpha = 0.24,
              colour = palette[["teal"]]) +
  geom_text(data = medians, aes(alpha_display, median_mde,
                                label = sprintf("%.2f", median_mde)),
            nudge_y = 0.14, size = 2.0, fontface = "bold",
            family = font_family) +
  coord_cartesian(ylim = c(1.45, 3.70)) +
  labs(title = "80% power detectability", x = NULL,
       y = "Minimum detectable OR", subtitle = "Median shown; 218 traits") +
  theme_ijir(6.4) +
  theme(plot.margin = margin(4, 2, 2, 2))
p3c <- p3c_bar + p3c_power + plot_layout(widths = c(0.82, 1.18))

figure3 <- p3a / (p3b + p3c + plot_layout(widths = c(1.00, 1.22))) +
  plot_layout(heights = c(1.28, 1.00))
save_gg(
  figure3, "IJIR_Figure_3_Forward_Evidence_Profile_v0_3", 183, 156,
  source_files = c(
    figure3a_source, figure3b_source, architecture_source, power_source
  )
)

# Supplementary Figure S1 ------------------------------------------------------
power_nominal <- power[alpha_label == "nominal_0.05"]
power_nominal[, phenotype_display := fcase(
  phenotype == "presence", "Presence liability",
  grepl("diversity", phenotype), "Diversity (RIN)",
  default = "Abundance (RIN)"
)]
f_long <- melt(
  power_nominal,
  id.vars = c("source_id", "nsnp"),
  measure.vars = c("min_F", "median_F"),
  variable.name = "F_metric", value.name = "F_value"
)
f_long[, F_metric := factor(F_metric, levels = c("min_F", "median_F"),
                            labels = c("Minimum F", "Median F"))]
s1_source1 <- write_source(architecture, "Supplementary_Figure_S1a_source_data.csv")
s1_source2 <- write_source(f_long, "Supplementary_Figure_S1b_source_data.csv")
s1_source3 <- write_source(power_nominal, "Supplementary_Figure_S1c_source_data.csv")

s1a <- ggplot(architecture, aes(factor(nsnp), trait_count)) +
  geom_col(width = 0.68, fill = palette[["blue"]], colour = "black",
           linewidth = 0.40) +
  geom_text(aes(label = trait_count), vjust = -0.35, size = 2.1,
            family = font_family) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(tag = "a", title = "Forward IV-count distribution", x = "IVs per trait",
       y = "Traits", subtitle = "12 non-estimable; 218 estimable") +
  theme_ijir()
s1b <- ggplot(f_long, aes(F_metric, F_value, fill = F_metric)) +
  geom_boxplot(width = 0.58, outlier.shape = NA, linewidth = 0.40) +
  geom_jitter(width = 0.12, size = 0.35, alpha = 0.25) +
  geom_hline(yintercept = 10, linetype = "dashed", linewidth = 0.40,
             colour = palette[["orange"]]) +
  coord_cartesian(ylim = c(8, quantile(f_long$F_value, 0.98))) +
  scale_fill_manual(values = c("Minimum F" = palette[["blue_light"]],
                               "Median F" = palette[["neutral_light"]])) +
  labs(tag = "b", title = "Instrument strength", x = NULL, y = "F statistic",
       subtitle = "Dashed line: F=10") +
  theme_ijir() + theme(legend.position = "none")
s1c <- ggplot(power_nominal, aes(phenotype_display, r2, fill = phenotype_display)) +
  geom_boxplot(width = 0.62, outlier.shape = NA, linewidth = 0.40) +
  geom_jitter(width = 0.14, size = 0.35, alpha = 0.25) +
  scale_y_log10(labels = scales::label_number(accuracy = 0.0001)) +
  scale_fill_manual(values = c(
    "Presence liability" = palette[["blue_light"]],
    "Abundance (RIN)" = palette[["teal"]],
    "Diversity (RIN)" = palette[["neutral_light"]]
  )) +
  labs(tag = "c", title = "Approximate exposure variance explained",
       x = NULL, y = expression(R^2),
       subtitle = "Forward-trait scale only; see assumptions in Supplementary Table S5") +
  theme_ijir() +
  theme(legend.position = "none", axis.text.x = element_text(angle = 20, hjust = 1))
supp_s1 <- s1a + s1b + s1c + plot_layout(widths = c(0.85, 0.95, 1.20))
save_gg(
  supp_s1, "IJIR_Supplementary_Figure_S1_Instrument_Architecture_v0_3",
  183, 96, supplement_dir, c(s1_source1, s1_source2, s1_source3)
)

# Supplementary Figure S2 ------------------------------------------------------
qq <- fread(file.path(v03, "qq_plot_input.csv"))
s2_source1 <- write_source(qq, "Supplementary_Figure_S2ab_source_data.csv")
qq[, panel := factor(
  direction, levels = c("forward", "reverse"),
  labels = c("Forward (218 estimable)", "Reverse (1 572 estimable)")
)]
qq_plot <- function(panel_name, tag) {
  ggplot(qq[panel == panel_name], aes(expected_minus_log10_p,
                                     observed_minus_log10_p)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                linewidth = 0.40, colour = palette[["neutral_mid"]]) +
    geom_point(size = 0.58, alpha = 0.62, colour = palette[["blue"]]) +
    coord_equal() +
    labs(tag = tag, title = as.character(panel_name),
         x = expression(Expected~~-log[10](italic(P))),
         y = expression(Observed~~-log[10](italic(P)))) +
    theme_ijir()
}
s2a <- qq_plot(levels(qq$panel)[[1L]], "a")
s2b <- qq_plot(levels(qq$panel)[[2L]], "b")
estimable_p <- sort(multiplicity[is.finite(p), p])
sens_curve <- data.table(
  rank = seq_along(estimable_p), observed_p = estimable_p,
  primary_BH = 0.05 * seq_along(estimable_p) / 230,
  estimable_only_BH = 0.05 * seq_along(estimable_p) / length(estimable_p)
)
s2_source2 <- write_source(sens_curve, "Supplementary_Figure_S2c_source_data.csv")
sens_long <- melt(
  sens_curve, id.vars = "rank",
  measure.vars = c("observed_p", "primary_BH", "estimable_only_BH"),
  variable.name = "curve", value.name = "p"
)
sens_long[, curve := factor(
  curve, levels = c("observed_p", "primary_BH", "estimable_only_BH"),
  labels = c("Observed", "Predefined family n=230", "Estimable only n=218")
)]
s2c <- ggplot(sens_long, aes(rank, -log10(p), colour = curve,
                             linetype = curve)) +
  geom_line(linewidth = 0.45) +
  scale_colour_manual(values = c(
    "Observed" = palette[["neutral_dark"]],
    "Predefined family n=230" = palette[["blue"]],
    "Estimable only n=218" = palette[["orange"]]
  )) +
  scale_linetype_manual(values = c("Observed" = "solid",
                                   "Predefined family n=230" = "dashed",
                                   "Estimable only n=218" = "dotted")) +
  labs(tag = "c", title = "Forward BH sensitivity", x = "Ranked estimable tests",
       y = expression(-log[10](italic(P))), colour = NULL, linetype = NULL,
       subtitle = "0 FDR signals in all corrections\nUnique clusters n=225; minimum q=0.893–0.961") +
  theme_ijir()
supp_s2 <- s2a + s2b + s2c +
  plot_layout(widths = c(0.88, 0.88, 1.24), guides = "collect") +
  plot_annotation(caption = paste0(
    "QQ plots are descriptive because microbial traits are correlated; no genomic-inflation estimate is interpreted as if tests were independent."
  )) & theme(legend.position = "bottom",
             plot.caption = element_text(size = 5.8, hjust = 0))
save_gg(
  supp_s2, "IJIR_Supplementary_Figure_S2_Pvalue_Calibration_v0_3",
  183, 110, supplement_dir, c(s2_source1, s2_source2)
)

# Supplementary Figure S3 ------------------------------------------------------
hunt[, discovery_phenotype := fcase(
  grepl("presence", discovery_trait, ignore.case = TRUE), "Swedish presence",
  grepl("diversity", discovery_trait, ignore.case = TRUE), "Swedish diversity",
  default = "Swedish abundance"
)]
hunt[, swedish_signed_z := discovery_beta / discovery_se]
s3_source <- write_source(hunt, "Supplementary_Figure_S3_source_data.csv")
s3a <- ggplot(hunt, aes(swedish_signed_z, hunt_signed_z_aligned,
                        colour = discovery_phenotype,
                        shape = direction_concordant)) +
  annotate("rect", xmin = -Inf, xmax = 0, ymin = -Inf, ymax = 0,
           fill = palette[["neutral_pale"]], colour = NA) +
  annotate("rect", xmin = 0, xmax = Inf, ymin = 0, ymax = Inf,
           fill = palette[["neutral_pale"]], colour = NA) +
  geom_hline(yintercept = 0, linewidth = 0.40, colour = "black") +
  geom_vline(xintercept = 0, linewidth = 0.40, colour = "black") +
  geom_point(size = 1.65, stroke = 0.40, alpha = 0.82) +
  scale_colour_manual(values = c(
    "Swedish presence" = palette[["blue"]],
    "Swedish abundance" = palette[["teal"]],
    "Swedish diversity" = palette[["orange"]]
  )) +
  scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 1),
                     labels = c(`TRUE` = "Direction concordant",
                                `FALSE` = "Direction discordant")) +
  labs(tag = "a", title = "Exact-label same-SNP exposure associations",
       x = "Swedish signed Z", y = "HUNT signed Z",
       colour = "Swedish phenotype", shape = NULL,
       subtitle = "97/97 exact-label Swedish lead SNPs found; no fuzzy matching") +
  theme_ijir() + theme(legend.position = "bottom")
concordance <- data.table(
  estimate = hunt_summary$direction_concordance_proportion,
  lower = hunt_summary$concordance_exact_95ci_lower,
  upper = hunt_summary$concordance_exact_95ci_upper
)
s3b <- ggplot(concordance, aes(estimate, 1)) +
  geom_vline(xintercept = 0.5, linetype = "dashed", linewidth = 0.40,
             colour = palette[["neutral_mid"]]) +
  geom_segment(aes(x = lower, xend = upper, yend = 1), linewidth = 0.55,
               colour = palette[["neutral_dark"]]) +
  geom_point(size = 3.0, shape = 21, fill = palette[["blue"]],
             colour = "black", stroke = 0.45) +
  annotate("text", x = concordance$estimate, y = 1.10,
           label = sprintf("76/97 = 78.4%%\n95%% CI 68.8%%–86.1%%"),
           size = 2.4, family = font_family, fontface = "bold") +
  scale_x_continuous(limits = c(0.4, 1), labels = scales::label_percent(),
                     breaks = c(0.5, 0.6, 0.7, 0.8, 0.9, 1)) +
  scale_y_continuous(NULL, breaks = NULL, limits = c(0.82, 1.20)) +
  labs(tag = "b", title = "Direction concordance",
       x = "Concordant proportion",
       subtitle = "Descriptive binomial interval; trait correlation not modelled") +
  theme_ijir()
supp_s3 <- s3a + s3b +
  plot_layout(widths = c(1.65, 1.0), guides = "collect") +
  plot_annotation(caption = paste0(
    "Signed Z supports a direction-only comparison. Swedish presence and HUNT normalized abundance scales preclude direct comparison of raw beta or MR OR magnitude."
  )) & theme(legend.position = "bottom",
             plot.caption = element_text(size = 5.8, hjust = 0))
save_gg(
  supp_s3, "IJIR_Supplementary_Figure_S3_HUNT_Same_SNP_v0_3",
  183, 100, supplement_dir, s3_source
)

# Supplementary Figure S4 ------------------------------------------------------
s4_flow <- data.table(
  stage = factor(c("Source catalog", "Eligible at source threshold", "Estimable"),
                 levels = c("Source catalog", "Eligible at source threshold",
                            "Estimable")),
  count = c(strict_summary$source_catalog_traits,
            strict_summary$eligible_traits, strict_summary$estimable_traits)
)
strict_rank <- copy(strict_results)
strict_rank[, p_display := fifelse(is.finite(p), p, 1)]
setorder(strict_rank, p_display)
strict_rank[, rank := seq_len(.N)]
strict_rank[, bh_p := 0.05 * rank / .N]
s4_source1 <- write_source(s4_flow, "Supplementary_Figure_S4a_source_data.csv")
s4_source2 <- write_source(strict_rank, "Supplementary_Figure_S4b_source_data.csv")
s4a <- ggplot(s4_flow, aes(stage, count)) +
  geom_col(width = 0.66, fill = palette[["blue"]], colour = "black",
           linewidth = 0.40) +
  geom_text(aes(label = scales::label_number(big.mark = " ")(count)),
            vjust = -0.35, size = 2.2, family = font_family) +
  scale_y_log10(expand = expansion(mult = c(0, 0.14))) +
  labs(tag = "a", title = "Source-study-wide threshold eligibility",
       x = NULL, y = "Traits (log scale)",
       subtitle = "Thresholds: 1.7×10⁻⁸, 5.4×10⁻¹¹ or 4.3×10⁻¹⁰ by trait class") +
  theme_ijir() + theme(axis.text.x = element_text(angle = 18, hjust = 1))
s4_curve <- melt(
  strict_rank, id.vars = "rank", measure.vars = c("p_display", "bh_p"),
  variable.name = "curve", value.name = "p"
)
s4_curve[, curve := factor(curve, levels = c("p_display", "bh_p"),
                           labels = c("Observed", "BH 5% boundary"))]
s4b <- ggplot(s4_curve, aes(rank, -log10(p), colour = curve,
                            linetype = curve)) +
  geom_line(linewidth = 0.48) +
  geom_hline(yintercept = -log10(0.05), linewidth = 0.40,
             linetype = "dotted", colour = palette[["neutral_mid"]]) +
  scale_colour_manual(values = c("Observed" = palette[["neutral_dark"]],
                                 "BH 5% boundary" = palette[["blue"]])) +
  scale_linetype_manual(values = c("Observed" = "solid",
                                   "BH 5% boundary" = "dashed")) +
  labs(tag = "b", title = "Strict-threshold MR sensitivity",
       x = "Ranked eligible traits", y = expression(-log[10](italic(P))),
       colour = NULL, linetype = NULL,
       subtitle = "27 eligible; 23 estimable; minimum P=0.153; minimum q=1") +
  theme_ijir() + theme(legend.position = "bottom")
supp_s4 <- s4a + s4b + plot_layout(widths = c(0.9, 1.1))
save_gg(
  supp_s4, "IJIR_Supplementary_Figure_S4_Source_Threshold_v0_3",
  183, 88, supplement_dir, c(s4_source1, s4_source2)
)

# Supplementary Figure S5 ------------------------------------------------------
family_labels <- c(
  mechanistic_x_to_y = "Function → ED",
  cytokine_m_to_y = "Cytokine → ED",
  endothelial_m_to_y = "Endothelial protein → ED",
  cytokine_x_to_m = "Function → cytokine",
  endothelial_x_to_m = "Function → endothelial protein",
  cytokine_indirect = "Cytokine indirect effect",
  endothelial_indirect = "Endothelial indirect effect"
)
mechanistic[, family_display := family_labels[family]]
mechanistic[, family_display := factor(
  family_display, levels = rev(unname(family_labels))
)]
mechanistic_long <- melt(
  mechanistic,
  id.vars = c("family", "family_display", "minimum_q", "planned_tests"),
  measure.vars = c(
    "planned_tests", "estimable_tests", "nominal_p_lt_0_05",
    "fdr_significant_tests"
  ),
  variable.name = "metric", value.name = "count"
)
mechanistic_long[, metric := factor(
  metric,
  levels = c("planned_tests", "estimable_tests", "nominal_p_lt_0_05",
             "fdr_significant_tests"),
  labels = c("Planned", "Estimable", "Nominal P<0.05", "FDR q<0.05")
)]
mechanistic_long[, fraction_planned := count / planned_tests]
s5_source <- write_source(
  mechanistic, "Supplementary_Figure_S5_source_data.csv"
)
s5_tiles <- ggplot(mechanistic_long, aes(metric, family_display,
                                         fill = fraction_planned)) +
  geom_tile(colour = "white", linewidth = 0.45) +
  geom_text(aes(label = count), size = 2.35, family = font_family,
            fontface = "bold") +
  scale_fill_gradient(low = "white", high = palette[["neutral_mid"]],
                      limits = c(0, 1), labels = scales::label_percent()) +
  labs(tag = "a", title = "Prespecified bounded mechanistic screening",
       x = NULL, y = NULL, fill = "Fraction of\nplanned tests",
       subtitle = "Counts are shown within complete testing families") +
  theme_ijir() +
  theme(axis.line = element_blank(), axis.ticks = element_blank(),
        legend.position = "right")
s5_q <- ggplot(mechanistic, aes(1, family_display, label = sprintf("%.3f", minimum_q))) +
  geom_text(size = 2.35, family = font_family) +
  scale_x_continuous(limits = c(0.6, 1.4)) +
  scale_y_discrete(drop = FALSE) +
  labs(tag = "b", title = "Minimum q") +
  theme_void(base_family = font_family) +
  theme(plot.title = element_text(size = 7.8, face = "bold"),
        plot.tag = element_text(size = 9, face = "bold"))
supp_s5 <- s5_tiles + s5_q + plot_layout(widths = c(1.78, 0.58)) +
  plot_annotation(caption = paste0(
    "No family produced an FDR-significant result. The display summarizes evidence counts and does not imply biological pathway support."
  )) & theme(plot.caption = element_text(size = 5.8, hjust = 0))
save_gg(
  supp_s5, "IJIR_Supplementary_Figure_S5_Mechanistic_Evidence_Map_v0_3",
  183, 106, supplement_dir, s5_source
)

# Combined supplementary PDF and output manifest ------------------------------
combined_pdf <- file.path(package_root, "06_supplement",
                          "IJIR_Supplementary_Figures_v0_3.pdf")
grDevices::cairo_pdf(combined_pdf, width = 183 / 25.4, height = 112 / 25.4,
                     family = font_family, onefile = TRUE)
print(supp_s1); print(supp_s2); print(supp_s3); print(supp_s4); print(supp_s5)
grDevices::dev.off()

manifest <- rbindlist(export_records, use.names = TRUE, fill = TRUE)
manifest[, minimum_rule_pt := 1.0]
manifest[, text_font := font_family]
manifest[, backend := "R"]
manifest[, combined_supplementary_pdf := fifelse(
  grepl("Supplementary", figure), substring(combined_pdf, nchar(package_root) + 2L),
  NA_character_
)]
fwrite(manifest, file.path(qc_dir, "IJIR_Figure_Output_Manifest_v0_3.csv"))

cat(sprintf(
  paste0(
    "IJIR v0.3 figures complete: 3 main figures, 5 supplementary figures, ",
    "%d exported files plus combined supplementary PDF.\n"
  ), nrow(manifest)
))
