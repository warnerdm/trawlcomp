# Presentation framework (both lakes): map of tows by region; composition by fishing depth x bottom depth within
# each region; table of tows, mean, SD, SE; variance breakdown (region, depth, both). By number.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/region_depth.R")))
options(width = 220)

for (lake in c("Michigan", "Huron")) {
  lk <- tolower(lake)
  groups <- LAKE_STRATA[[lake]]$groups
  tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == !!lake)
  props <- region_depth_props(tows, lake)
  tab <- region_depth_table(props, groups)
  vb <- variance_breakdown(props, groups)
  write_csv(tab, file.path(OUTPUT_DIR, paste0("region_depth_table_", lk, ".csv")))
  write_csv(vb, file.path(OUTPUT_DIR, paste0("region_depth_variance_", lk, ".csv")))

  ggsave(file.path(OUTPUT_DIR, paste0("region_map_", lk, ".png")), plot_region_map(props, lake),
         width = 7, height = 7, dpi = 150)
  nreg <- n_distinct(props$region)
  ggsave(file.path(OUTPUT_DIR, paste0("region_depth_composition_", lk, ".png")),
         plot_region_depth(tab, lake, groups), width = 12, height = 1.6 * nreg + 1.6, dpi = 150)

  cat("\n==", lake, ":", nrow(props), "tows in", nreg, "regions\n")
  cat("Share of tow-to-tow variance explained (R^2):\n")
  print(as.data.frame(mutate(vb, across(where(is.double), \(x) round(x, 2)))))
}
