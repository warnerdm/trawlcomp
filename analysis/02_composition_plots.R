# Proportion of each species group per tow against fishing depth, bottom depth, lat and lon, by lake.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/composition_plots.R")))

catch <- tow_catch(drop_bad_coordinates(select_tows()))
long <- composition_long(catch)
for (lk in c("Michigan", "Huron")) {
  n_groups <- n_distinct(long$group[long$lake == lk])
  ggsave(file.path(OUTPUT_DIR, paste0("composition_", tolower(lk), ".png")),
         plot_composition(long, lk), width = 11, height = 2.4 * n_groups + 1.2, dpi = 150)
}
