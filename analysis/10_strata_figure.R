# Adams et al. (2006) Figure 4 style plot of the 4 Lake Michigan strata (number and weight).
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/stratum_stats.R")))

tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == "Michigan")
ts <- name_strata(michigan_strata(tows))
cells <- ts %>% distinct(cell, stratum_name) %>%
  separate(cell, c("bd_bin", "fd_bin"), sep = "_", convert = TRUE, remove = FALSE)
ss <- read_csv(file.path(OUTPUT_DIR, "stratum_stats_michigan.csv"), show_col_types = FALSE)
for (meas in c("N", "WEIGHT")) {
  msd <- ss %>% filter(measure == meas) %>% summarise(.by = stratum_name, mean_sd = mean(sd_all))
  p <- plot_strata_adams(cells, msd, title = paste0("Lake Michigan depth strata, proportions by ",
                                                   if (meas == "N") "number" else "weight"))
  ggsave(file.path(OUTPUT_DIR, paste0("strata_adams_style_michigan_", tolower(meas), ".png")), p,
         width = 9, height = 5.2, dpi = 150)
}

# All tows with fish as points: in a stratum, or left out (< 10 fish; cell with < 5 such tows)
pts <- tow_catch(tows, "N") %>%
  filter(n > 0 & !is.na(bottom_depth) & !is.na(fishing_depth)) %>%
  left_join(select(ts, OP_ID, stratum_name), by = "OP_ID") %>%
  mutate(status = factor(case_when(!is.na(stratum_name) ~ as.character(stratum_name),
                                   n < 10 ~ "< 10 fish", TRUE ~ "Cell < 5 tows"),
                         c(levels(ts$stratum_name), "Cell < 5 tows", "< 10 fish")))
print(count(pts, status))
p <- plot_tows_strata(pts, cells, title = paste0("Lake Michigan tows (", nrow(pts), " with fish) and the 4 strata"))
ggsave(file.path(OUTPUT_DIR, "strata_tows_michigan.png"), p, width = 10, height = 6, dpi = 150)
