# Full summaries and smooth-term plots of the step-03 GAMs (reads output/models.rds; no refitting).
# One page per lake x group: s(fishing_depth), s(bottom_depth) (logit scale, +-2 SE bands, rug = tows) and the
# s(lon, lat) surface (heat map, red = low, white = high; blue contours labelled with the logit effect; lake
# outline from the maps package). The surface is blank far from tows.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/fit_models.R")))

models <- readRDS(file.path(OUTPUT_DIR, "models.rds"))
summ <- read_csv(file.path(OUTPUT_DIR, "model_summary.csv"), show_col_types = FALSE)
stopifnot(identical(names(models), paste(summ$lake, summ$group, sep = "_")))
labels <- paste(summ$lake, summ$group)
shore <- ggplot2::map_data("lakes")

sink(file.path(OUTPUT_DIR, "model_summaries.txt"))
for (i in seq_along(models)) {
  cat("\n\n==========", labels[i], "==========\n")
  print(summary(models[[i]]))
  cat("\nRandom-effect SDs (logit scale):\n")
  print(gam.vcomp(models[[i]], rescale = FALSE))
}
sink()

for (i in seq_along(models)) {
  m <- models[[i]]
  png(file.path(OUTPUT_DIR, paste0("gam_smooths_", tolower(summ$lake[i]), "_", summ$group[i], ".png")),
      width = 2000, height = 700, res = 130)
  par(mfrow = c(1, 3), mar = c(4.5, 4.5, 3, 1))
  plot(m, select = 1, shade = TRUE, seWithMean = TRUE, rug = TRUE, xlab = "Fishing depth (m)",
       ylab = "Effect (logit)", main = paste(labels[i], "- fishing depth"))
  abline(h = 0, lty = 3)
  plot(m, select = 2, shade = TRUE, seWithMean = TRUE, rug = TRUE, xlab = "Bottom depth (m)",
       ylab = "Effect (logit)", main = "Bottom depth")
  abline(h = 0, lty = 3)
  # map panel: whole lake (shoreline bounding box of the lake's tows + margin), map aspect (1 / cos(lat)),
  # full shoreline drawn and clipped by the plot region; the surface is blank where no tows are near (too.far)
  xl <- range(m$model$lon) + c(-0.4, 0.4); yl <- range(m$model$lat) + c(-0.3, 0.3)
  plot(m, select = 3, scheme = 2, too.far = 0.05, xlim = xl, ylim = yl, asp = 1 / cos(mean(yl) * pi / 180),
       xlab = "Longitude", ylab = "Latitude", main = "Location: s(lon, lat), logit")
  for (g in unique(shore$group)) with(shore[shore$group == g, ], lines(long, lat, col = "black", lwd = 1.3))
  points(m$model$lon, m$model$lat, pch = ".", col = "grey20")
  dev.off()
}
cat("Wrote", length(models), "plot pages and model_summaries.txt\n")
