# Current effort per lake-year and depth layer (< 35 m, >= 35 m) on the SE curves
# (needs analysis/03_fit_models.R output).
suppressWarnings(suppressMessages({
  source("D:/pyprojects/trawlcomp/R/tow_catch.R")
  source("D:/pyprojects/trawlcomp/R/effort.R")
}))

catch <- tow_catch(drop_bad_coordinates(select_tows()))
tow_stats <- read_csv(file.path(OUTPUT_DIR, "repeat_tow_stats.csv"), show_col_types = FALSE)

effort <- effort_by_year(catch)
se <- se_by_layer(tow_stats, catch)
pts <- effort_points(se, effort)
write_csv(effort, file.path(OUTPUT_DIR, "effort_by_year.csv"))
write_csv(pts, file.path(OUTPUT_DIR, "effort_se.csv"))

for (lk in c("Michigan", "Huron")) {
  n_groups <- n_distinct(se$group[se$lake == lk])
  ggsave(file.path(OUTPUT_DIR, paste0("effort_", tolower(lk), ".png")),
         plot_effort(se, pts, lk), width = 2.8 * n_groups + 1, height = 4.4, dpi = 150)
}

options(width = 200)
cat("Tows with catch per year, by layer:\n")
print(as.data.frame(effort %>% select(-tows) %>% pivot_wider(names_from = layer, values_from = tows_with_catch)))
cat("\nSE at current, 2x and 3x effort:\n")
print(as.data.frame(mutate(pts, across(starts_with("se"), \(x) round(x, 3)))))
