# SE of the mean proportion vs number of tows, one figure per lake (needs analysis/03_fit_models.R output).
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/se_plots.R")))

tows <- read_csv(file.path(OUTPUT_DIR, "repeat_tow_stats.csv"), show_col_types = FALSE)
se <- se_vs_tows(tows)
write_csv(se, file.path(OUTPUT_DIR, "se_vs_tows.csv"))
for (lk in c("Michigan", "Huron")) {
  n_groups <- n_distinct(se$group[se$lake == lk])
  ggsave(file.path(OUTPUT_DIR, paste0("se_vs_tows_", tolower(lk), ".png")),
         plot_se_vs_tows(se, lk), width = 2.6 * n_groups + 1, height = 4, dpi = 150)
}
print(as.data.frame(filter(se, m %in% c(1, 4, 10, 25, 50)) %>% mutate(across(starts_with("se"), \(x) round(x, 3)))))
