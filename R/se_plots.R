# Uncertainty of a mean proportion against the number of tows, from the repeat-tow SDs of the fitted models
# (output/repeat_tow_stats.csv). For tow i, SE_i(m) = sd_obs_i / sqrt(m): the SE of the mean of m repeat tows
# under that tow's conditions, each with that tow's catch size. Line = median over the lake's tows,
# band = 10th-90th percentile over tows.
library(tidyverse)
source("D:/pyprojects/trawlcomp/R/paths.R")

se_vs_tows <- function(tows, m = 1:50) {
  tows %>%
    cross_join(tibble(m = m)) %>%
    mutate(se = sd_obs / sqrt(m)) %>%
    summarise(.by = c(lake, group, m), se_med = median(se), se_lo = quantile(se, 0.1), se_hi = quantile(se, 0.9))
}

plot_se_vs_tows <- function(se, lake_name) {
  d <- filter(se, lake == lake_name) %>%
    mutate(group = factor(group, c("alewife", "smelt", "bloater", "other")))
  ggplot(d, aes(m, se_med)) +
    geom_ribbon(aes(ymin = se_lo, ymax = se_hi), fill = "steelblue", alpha = 0.2) +
    geom_line(colour = "steelblue4", linewidth = 0.9) +
    facet_wrap(~group, nrow = 1) +
    scale_x_continuous(breaks = c(1, 10, 20, 30, 40, 50)) +
    labs(x = "Number of tows", y = "SE of the mean proportion",
         title = paste0("Lake ", lake_name, ": uncertainty of the mean proportion vs number of tows"),
         subtitle = "Repeat tows under the same conditions; line = median over tows, band = 10th-90th percentile") +
    theme_bw(base_size = 11) +
    theme(strip.background = element_rect(fill = "grey92"))
}
