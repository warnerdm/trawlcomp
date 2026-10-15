# Adams et al. (2006) Figure 4 style plot of one lake's strata (LAKE env var, default Michigan), and the tows.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/stratum_stats.R")))

LAKE <- Sys.getenv("LAKE", "Michigan")
lk <- tolower(LAKE)
cfg <- LAKE_STRATA[[LAKE]]
tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == LAKE)
ts <- named_strata(tows, LAKE)
cells <- ts %>% distinct(cell, stratum_name) %>%
  separate(cell, c("bd_bin", "fd_bin"), sep = "_", convert = TRUE, remove = FALSE)
ss <- read_csv(file.path(OUTPUT_DIR, paste0("stratum_stats_", lk, ".csv")), show_col_types = FALSE)
for (meas in c("N", "WEIGHT")) {
  msd <- ss %>% filter(measure == meas) %>% summarise(.by = stratum_name, mean_sd = mean(sd_all))
  p <- plot_strata_adams(cells, msd, title = paste0("Lake ", LAKE, " depth strata, proportions by ",
                                                   if (meas == "N") "number" else "weight"))
  ggsave(file.path(OUTPUT_DIR, paste0("strata_adams_style_", lk, "_", tolower(meas), ".png")), p,
         width = 9, height = 5.2, dpi = 150)
}

# All tows with fish as points: in a stratum, or left out (too few fish; cell with too few such tows)
pts <- tow_catch(tows, "N") %>%
  filter(n > 0 & !is.na(bottom_depth) & !is.na(fishing_depth)) %>%
  left_join(select(ts, OP_ID, stratum_name), by = "OP_ID") %>%
  mutate(status = factor(case_when(!is.na(stratum_name) ~ as.character(stratum_name),
                                   n < cfg$min_fish ~ paste("<", cfg$min_fish, "fish"),
                                   TRUE ~ paste("Cell <", cfg$min_tows, "tows")),
                         c(levels(ts$stratum_name), paste("Cell <", cfg$min_tows, "tows"),
                           paste("<", cfg$min_fish, "fish"))))
print(count(pts, status))
p <- plot_tows_strata(pts, cells, title = paste0("Lake ", LAKE, " tows (", nrow(pts), " with fish) and the ", nlevels(ts$stratum_name), " strata"))
ggsave(file.path(OUTPUT_DIR, paste0("strata_tows_", lk, ".png")), p, width = 10, height = 6, dpi = 150)
