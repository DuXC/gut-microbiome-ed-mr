script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) stop("Run this builder with Rscript.")
script_path <- normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE)
script_dir <- dirname(script_path)
project_root <- normalizePath(file.path(script_dir, "../../.."), mustWork = TRUE)
output_dir <- file.path(script_dir, "../04_figures")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

draw_box <- function(x, y, width, height, title, details, fill = "#F2F2F2") {
  grid::grid.roundrect(
    x = grid::unit(x, "npc"), y = grid::unit(y, "npc"),
    width = grid::unit(width, "npc"), height = grid::unit(height, "npc"),
    r = grid::unit(0.015, "npc"),
    gp = grid::gpar(fill = fill, col = "#222222", lwd = 1)
  )
  grid::grid.text(title, x = x, y = y + height * 0.19,
                  gp = grid::gpar(fontfamily = "Helvetica", fontsize = 8.4, fontface = "bold"))
  grid::grid.text(details, x = x, y = y - height * 0.16,
                  gp = grid::gpar(fontfamily = "Helvetica", fontsize = 7.4, lineheight = 1.15))
}

draw_arrow <- function(x0, y0, x1, y1, dashed = FALSE) {
  grid::grid.lines(
    x = grid::unit(c(x0, x1), "npc"), y = grid::unit(c(y0, y1), "npc"),
    arrow = grid::arrow(type = "closed", length = grid::unit(0.09, "inches")),
    gp = grid::gpar(col = if (dashed) "#555555" else "#222222", lwd = 1,
                    lty = if (dashed) 2 else 1)
  )
}

draw_figure_1 <- function() {
  grid::grid.newpage()
  grid::grid.text("a", x = 0.02, y = 0.96, just = c("left", "top"),
                  gp = grid::gpar(fontfamily = "Helvetica", fontsize = 11, fontface = "bold"))
  grid::grid.text("Forward: gut microbiota to erectile dysfunction", x = 0.06, y = 0.955,
                  just = c("left", "top"), gp = grid::gpar(fontfamily = "Helvetica", fontsize = 10, fontface = "bold"))

  draw_box(0.15, 0.76, 0.22, 0.16, "Swedish shotgun GWAS", "1,572 microbial traits\nN = 16,017; European ancestry")
  draw_box(0.40, 0.76, 0.18, 0.16, "Primary instruments", "P < 5×10⁻⁸; F > 10\n230 eligible traits")
  draw_box(0.63, 0.76, 0.18, 0.16, "FinnGen R12 ED", "2,886 cases\n215,272 controls")
  draw_box(0.865, 0.76, 0.19, 0.16, "Forward result", "218 estimable\n7 nominal; 0 FDR")
  draw_arrow(0.26, 0.76, 0.31, 0.76)
  draw_arrow(0.49, 0.76, 0.54, 0.76)
  draw_arrow(0.72, 0.76, 0.77, 0.76)

  draw_box(0.195, 0.50, 0.27, 0.14, "Exact-label HUNT validation", "97/230 traits matched\n2 nominal candidates testable", fill = "white")
  draw_box(0.505, 0.50, 0.25, 0.14, "Independent exposure check", "P = 0.4273 and 0.1752\n0 validated", fill = "white")
  draw_box(0.815, 0.50, 0.27, 0.14, "2025 ED meta-analysis", "Known FinnGen overlap\nSensitivity evidence only", fill = "white")
  draw_arrow(0.15, 0.68, 0.195, 0.57, dashed = TRUE)
  draw_arrow(0.33, 0.50, 0.38, 0.50, dashed = TRUE)
  draw_arrow(0.63, 0.68, 0.78, 0.57, dashed = TRUE)

  grid::grid.lines(x = grid::unit(c(0.03, 0.97), "npc"), y = grid::unit(c(0.37, 0.37), "npc"),
                   gp = grid::gpar(col = "#B3B3B3", lwd = 0.8))
  grid::grid.text("b", x = 0.02, y = 0.32, just = c("left", "top"),
                  gp = grid::gpar(fontfamily = "Helvetica", fontsize = 11, fontface = "bold"))
  grid::grid.text("Reverse: erectile dysfunction to gut microbiota", x = 0.06, y = 0.315,
                  just = c("left", "top"), gp = grid::gpar(fontfamily = "Helvetica", fontsize = 10, fontface = "bold"))

  draw_box(0.15, 0.16, 0.22, 0.15, "2025 European ED GWAS", "136,867 cases\n776,327 controls")
  draw_box(0.40, 0.16, 0.18, 0.15, "ED instruments", "479 GWS variants\n24 independent IVs")
  draw_box(0.63, 0.16, 0.18, 0.15, "Swedish outcomes", "1,572 microbial traits\n15–17 IVs per trait")
  draw_box(0.865, 0.16, 0.19, 0.15, "Reverse result", "1,572 estimable\n77 nominal; 0 FDR")
  draw_arrow(0.26, 0.16, 0.31, 0.16)
  draw_arrow(0.49, 0.16, 0.54, 0.16)
  draw_arrow(0.72, 0.16, 0.77, 0.16)
  grid::grid.text("Genome-wide eligibility and multiplicity rules were frozen before association screening.",
                  x = 0.5, y = 0.025,
                  gp = grid::gpar(fontfamily = "Helvetica", fontsize = 7.5, fontface = "italic"))
}

export_grid_figure <- function(stem, draw_fun, width, height) {
  grDevices::cairo_pdf(file.path(output_dir, paste0(stem, ".pdf")), width = width, height = height, family = "Helvetica")
  draw_fun(); grDevices::dev.off()
  grDevices::svg(file.path(output_dir, paste0(stem, ".svg")), width = width, height = height, family = "Helvetica")
  draw_fun(); grDevices::dev.off()
  production_png <- file.path(output_dir, paste0(stem, "_600dpi.png"))
  grDevices::png(production_png, width = width, height = height,
                 units = "in", res = 600, type = "cairo", family = "Helvetica")
  draw_fun(); grDevices::dev.off()
  status <- system2("/usr/bin/sips", c("-s", "format", "tiff", production_png,
                                      "--out", file.path(output_dir, paste0(stem, ".tiff"))),
                    stdout = FALSE, stderr = FALSE)
  if (!identical(status, 0L)) warning("TIFF conversion failed for ", stem)
  grDevices::png(file.path(output_dir, paste0(stem, "_preview.png")), width = width, height = height,
                 units = "in", res = 300, type = "cairo", family = "Helvetica")
  draw_fun(); grDevices::dev.off()
}

draw_ranked_panel <- function(p_values, n_family, title, panel, nominal_count, min_q, nonestimable = 0L) {
  p_values[!is.finite(p_values)] <- 1
  observed <- sort(pmax(p_values, .Machine$double.xmin))
  ranks <- seq_len(n_family)
  bh <- 0.05 * ranks / n_family
  global <- 0.05 / (230 + 1572)
  ymax <- max(5.2, -log10(observed[1]) + 0.5)
  graphics::plot(ranks, -log10(observed), type = "l", lwd = 1.5, col = "#111111",
                 xlab = "Ranked primary tests", ylab = expression(-log[10](italic(P))),
                 ylim = c(0, ymax), xaxs = "i", yaxs = "i", bty = "l", family = "Helvetica")
  graphics::lines(ranks, -log10(bh), lwd = 1.1, lty = 2, col = "#666666")
  graphics::abline(h = -log10(global), lwd = 1, lty = 3, col = "#111111")
  graphics::abline(h = -log10(0.05), lwd = 0.8, lty = 4, col = "#B0B0B0")
  graphics::title(main = title, adj = 0, line = 1, cex.main = 1.05, font.main = 2, family = "Helvetica")
  graphics::mtext(panel, side = 3, at = par("usr")[1] - 0.10 * diff(par("usr")[1:2]), line = 1.2,
                  cex = 1.2, font = 2, family = "Helvetica")
  note <- sprintf("%d nominal; minimum q = %.3f", nominal_count, min_q)
  if (nonestimable > 0) note <- paste0(note, "\n", nonestimable, " non-estimable tests shown at P = 1")
  graphics::legend("topright", legend = note, bty = "o", bg = "white", box.col = "#B0B0B0",
                   text.col = "#222222", cex = 0.72)
}

draw_figure_2 <- function() {
  forward <- utils::read.csv(file.path(project_root, "05_results/tables/mr_multiplicity_forward.csv"), check.names = FALSE)
  reverse <- utils::read.csv(file.path(project_root, "05_results/tables/reverse_mr_multiplicity.csv"), check.names = FALSE)
  old <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old))
  graphics::layout(matrix(c(1, 2, 3, 3), nrow = 2, byrow = TRUE), heights = c(9, 1.2))
  graphics::par(mar = c(4.0, 4.3, 3.2, 1.0), mgp = c(2.3, 0.7, 0), tcl = -0.25, las = 1,
                cex.axis = 0.82, cex.lab = 0.9, family = "Helvetica")
  draw_ranked_panel(forward$p, 230, "Gut microbiota to ED", "a",
                    sum(forward$p < 0.05, na.rm = TRUE), min(forward$q, na.rm = TRUE), sum(is.na(forward$p)))
  draw_ranked_panel(reverse$p, 1572, "ED to gut microbiota", "b",
                    sum(reverse$p < 0.05, na.rm = TRUE), min(reverse$q, na.rm = TRUE), 0)
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  graphics::legend("center", legend = c("Observed P value", "BH 5% boundary", "Global Bonferroni", "Nominal P = 0.05"),
                   lty = c(1, 2, 3, 4), lwd = c(1.5, 1.1, 1, 0.8),
                   col = c("#111111", "#666666", "#111111", "#B0B0B0"),
                   horiz = TRUE, bty = "n", cex = 0.78)
}

export_base_figure <- function(stem, draw_fun, width, height) {
  grDevices::cairo_pdf(file.path(output_dir, paste0(stem, ".pdf")), width = width, height = height, family = "Helvetica")
  draw_fun(); grDevices::dev.off()
  grDevices::svg(file.path(output_dir, paste0(stem, ".svg")), width = width, height = height, family = "Helvetica")
  draw_fun(); grDevices::dev.off()
  production_png <- file.path(output_dir, paste0(stem, "_600dpi.png"))
  grDevices::png(production_png, width = width, height = height,
                 units = "in", res = 600, type = "cairo", family = "Helvetica")
  draw_fun(); grDevices::dev.off()
  status <- system2("/usr/bin/sips", c("-s", "format", "tiff", production_png,
                                      "--out", file.path(output_dir, paste0(stem, ".tiff"))),
                    stdout = FALSE, stderr = FALSE)
  if (!identical(status, 0L)) warning("TIFF conversion failed for ", stem)
  grDevices::png(file.path(output_dir, paste0(stem, "_preview.png")), width = width, height = height,
                 units = "in", res = 300, type = "cairo", family = "Helvetica")
  draw_fun(); grDevices::dev.off()
}

export_grid_figure("IJIR_Figure_1_Study_Design_v0_1", draw_figure_1, 7.2, 5.7)
export_base_figure("IJIR_Figure_2_Multiplicity_v0_1", draw_figure_2, 7.2, 3.4)
message("Figures written to ", normalizePath(output_dir))
