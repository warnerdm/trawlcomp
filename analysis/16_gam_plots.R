# Full summaries and smooth-term plots of the step-03 GAMs (reads output/models.rds; no refitting).
# One page per lake x group: s(fishing_depth), s(bottom_depth) (logit scale, +-2 SE bands, rug = tows) and the
# s(lon, lat) surface (heat map with contours; the lake outline from the maps package for orientation).
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
      width = 1800, height = 600, res = 130)
  par(mfrow = c(1, 3), mar = c(4.5, 4.5, 3, 1))
  plot(m, select = 1, shade = TRUE, seWithMean = TRUE, rug = TRUE, xlab = "Fishing depth (m)",
       ylab = "Effect (logit)", main = paste(labels[i], "- fishing depth"))
  abline(h = 0, lty = 3)
  plot(m, select = 2, shade = TRUE, seWithMean = TRUE, rug = TRUE, xlab = "Bottom depth (m)",
       ylab = "Effect (logit)", main = "Bottom depth")
  abline(h = 0, lty = 3)
  plot(m, select = 3, scheme = 2, too.far = 0.05, xlab = "Longitude", ylab = "Latitude",
       main = "Location: s(lon, lat), logit")
  lake_xy <- subset(shore, long > min(m$model$lon) - 1 & long < max(m$model$lon) + 1 &
                      lat > min(m$model$lat) - 1 & lat < max(m$model$lat) + 1)
  for (g in unique(lake_xy$group)) with(subset(lake_xy, group == g), lines(long, lat, col = "grey30", lwd = 0.7))
  points(m$model$lon, m$model$lat, pch = ".", col = "grey20")
  dev.off()
}
cat("Wrote", length(models), "plot pages and model_summaries.txt\n")
