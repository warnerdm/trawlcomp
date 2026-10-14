# Model-free check of the SE curves by subsampling tows within lake-year-layers
# (needs analysis/03_fit_models.R output).
suppressWarnings(suppressMessages({
  source("D:/pyprojects/trawlcomp/R/tow_catch.R")
  source("D:/pyprojects/trawlcomp/R/subsample.R")
}))

catch <- tow_catch(drop_bad_coordinates(select_tows()))
tow_stats <- read_csv(file.path(OUTPUT_DIR, "repeat_tow_stats.csv"), show_col_types = FALSE)
props <- year_layer_props(catch)

# 1. All lake-year-layers with >= 5 tows: empirical SD of tow proportions vs the model's single-tow SD
cmp <- empirical_vs_model(props, tow_stats)
write_csv(cmp, file.path(OUTPUT_DIR, "subsample_empirical_vs_model.csv"))
options(width = 200)
# RMS over years (the SE of a mean depends on the average variance; medians of SDs hide the years where
# deep tows are mixed and overweight the years where they are all one species)
cat("Empirical vs model single-tow SD, RMS over lake-years with >= 5 tows in the layer:
")
print(as.data.frame(cmp %>% summarise(.by = c(lake, layer, group), years = n(),
  rms_emp = round(sqrt(mean(sd_emp^2)), 3), rms_model = round(sqrt(mean(sd_model^2)), 3)) %>%
  mutate(ratio = round(rms_emp / rms_model, 2)) %>% arrange(lake, layer, group)))

# 2. Subsampling curves for the deep layers with the most tows, against the model curve for that layer
picks <- tribble(~lake, ~YEAR, "Huron", 2013, "Huron", 2016, "Huron", 2017, "Michigan", 2005, "Michigan", 2022)
deep <- paste0(">= ", LAYER_BREAK_M, " m")
sub <- pmap(picks, \(lake, YEAR) {
  d <- filter(props, lake == !!lake & YEAR == !!YEAR & layer == deep)
  grp <- if (lake == "Huron") c("alewife", "smelt", "bloater", "other") else c("alewife", "smelt", "bloater")
  subsample_se(as.matrix(d[grp])) %>% mutate(lake = lake, YEAR = YEAR, M = nrow(d))
}) %>% list_rbind()
model_curve <- se_by_layer(tow_stats, catch) %>% filter(layer == deep)
write_csv(sub, file.path(OUTPUT_DIR, "subsample_deep.csv"))

for (lk in c("Michigan", "Huron")) {
  lv <- c("alewife", "smelt", "bloater", "other")
  s <- filter(sub, lake == lk) %>% mutate(group = factor(group, lv), year = factor(YEAR))
  mc <- filter(model_curve, lake == lk & m <= max(s$k)) %>% mutate(group = factor(group, lv))
  p <- ggplot(s, aes(k, se_k)) +
    geom_line(data = mc, aes(m, se), colour = "black", linewidth = 1, linetype = "dashed") +
    geom_line(aes(colour = year), linewidth = 0.8) + geom_point(aes(colour = year), size = 1.2) +
    facet_wrap(~group, nrow = 1) +
    labs(x = "Tows subsampled (k)", y = "SE of the mean proportion", colour = "Year",
         title = paste0("Lake ", lk, ", fishing depth >= ", LAYER_BREAK_M, " m: subsampled years vs model curve"),
         subtitle = "Coloured = subsampling within a year (finite-population corrected); dashed = model curve for the layer") +
    theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92"), legend.position = "bottom")
  ggsave(file.path(OUTPUT_DIR, paste0("subsample_deep_", tolower(lk), ".png")), p,
         width = 2.8 * n_distinct(s$group) + 1, height = 4.4, dpi = 150)
}
cat("\nDeep-layer tows in the subsampled years:\n")
print(distinct(sub, lake, YEAR, M))
