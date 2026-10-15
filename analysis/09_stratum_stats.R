# Mean, SD (all years / within year) and SE of species proportions in the Adams-style strata of one lake (LAKE env
# var, default Michigan; stratum_stats.R LAKE_STRATA settings), by number and by weight; SE vs number of tows.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/stratum_stats.R")))

LAKE <- Sys.getenv("LAKE", "Michigan")
lk <- tolower(LAKE)
cfg <- LAKE_STRATA[[LAKE]]
tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == LAKE)
ts <- named_strata(tows, LAKE)

stats <- map(c("N", "WEIGHT"), \(m) {
  props <- tow_catch(tows, m) %>%
    filter(!is.na(n) & n > 0) %>%
    inner_join(ts, by = "OP_ID")
  ss <- stratum_stats(props, groups = cfg$groups) %>% mutate(measure = m, .before = 1)
  list(stratum = ss, combined = combined_stats(ss) %>% mutate(measure = m, .before = 1))
})
ss <- map(stats, "stratum") %>% list_rbind()
cb <- map(stats, "combined") %>% list_rbind()
write_csv(ss, file.path(OUTPUT_DIR, paste0("stratum_stats_", lk, ".csv")))
write_csv(cb, file.path(OUTPUT_DIR, paste0("stratum_combined_", lk, ".csv")))

options(width = 220)
cat(LAKE, "tows per stratum (>=", cfg$min_fish, "fish, cells with >=", cfg$min_tows, "tows):
")
print(ts %>% count(stratum_name, cells))
print(as.data.frame(ss %>% select(measure, stratum_name, group, tows, tows_per_year, mean_p, sd_within, se_now,
                                  ratio_p, sd_ratio_within, se_ratio_now) %>%
                      mutate(across(where(is.double), \(x) round(x, 3)))))
cat("\nCombined over strata (W = share of cells):\n")
print(as.data.frame(mutate(cb, across(where(is.double), \(x) round(x, 3)))))

# SE vs tows per stratum from the all-years SD (within-year curves dropped: user, 2026-10-15, too busy);
# points = current median tows per year
lv <- cfg$groups  # species order
curves <- ss %>%
  cross_join(tibble(m = 1:40)) %>%
  transmute(measure, stratum_name, group = factor(group, lv), m, se = sd_all / sqrt(m))
now <- ss %>% mutate(group = factor(group, lv))
for (meas in c("N", "WEIGHT")) {
  p <- ggplot(filter(curves, measure == meas), aes(m, se, colour = group)) +
    geom_line(linewidth = 0.8) +
    # distinct shapes: where only two species occur (deep) their SDs are identical and the points coincide
    geom_point(data = filter(now, measure == meas), aes(tows_per_year, se_now_all, colour = group, shape = group,
                                                        size = group), inherit.aes = FALSE, stroke = 1.1) +
    scale_shape_manual(values = c(alewife = 16, smelt = 17, bloater = 1, other = 15), name = NULL) +
    scale_size_manual(values = c(alewife = 2.5, smelt = 2.5, bloater = 4, other = 2.5), name = NULL) +
    facet_wrap(~stratum_name, nrow = 1, labeller = label_wrap_gen(22)) +
    scale_colour_manual(values = c(alewife = "magenta", smelt = "gray", bloater = "black", other = "darkorange"), name = NULL) +
    labs(x = "Tows in the stratum (per year)", y = "SE of the mean proportion",
         title = paste0("Lake ", LAKE, " strata: SE of species proportions by ", if (meas == "N") "number" else "weight"),
         subtitle = "SD of tow proportions over all tows (years pooled); points = current median tows per year") +
    theme_bw(base_size = 11) +
    theme(strip.background = element_rect(fill = "grey92"), legend.position = "bottom")
  ggsave(file.path(OUTPUT_DIR, paste0("stratum_se_", lk, "_", tolower(meas), ".png")), p, width = 15, height = 4.6, dpi = 150)
}
