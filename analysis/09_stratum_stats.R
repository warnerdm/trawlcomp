# Lake Michigan: mean, SD (all years / within year) and SE of species proportions in the 4 Adams-style strata,
# by number and by weight; SE vs number of tows per stratum.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/stratum_stats.R")))

tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == "Michigan")
ts <- name_strata(michigan_strata(tows))

stats <- map(c("N", "WEIGHT"), \(m) {
  props <- tow_catch(tows, m) %>%
    filter(!is.na(n) & n > 0) %>%
    inner_join(ts, by = "OP_ID")
  ss <- stratum_stats(props) %>% mutate(measure = m, .before = 1)
  list(stratum = ss, combined = combined_stats(ss) %>% mutate(measure = m, .before = 1))
})
ss <- map(stats, "stratum") %>% list_rbind()
cb <- map(stats, "combined") %>% list_rbind()
write_csv(ss, file.path(OUTPUT_DIR, "stratum_stats_michigan.csv"))
write_csv(cb, file.path(OUTPUT_DIR, "stratum_combined_michigan.csv"))

options(width = 220)
cat("Tows per stratum (>= 10 fish, cells with >= 5 tows):\n")
print(ts %>% count(stratum_name, cells))
print(as.data.frame(ss %>% select(measure, stratum_name, group, tows, years, tows_per_year, mean_p, ratio_p, sd_all,
                                  sd_within, se_now, se_now_all) %>%
                      mutate(across(where(is.double), \(x) round(x, 3)))))
cat("\nCombined over strata (W = share of cells):\n")
print(as.data.frame(mutate(cb, across(where(is.double), \(x) round(x, 3)))))

# SE vs tows per stratum: within-year SD (solid) and all-years SD (dashed); points = current tows per year
lv <- c("alewife", "smelt", "bloater")
curves <- ss %>%
  cross_join(tibble(m = 1:40)) %>%
  transmute(measure, stratum_name, group = factor(group, lv), m,
            `within year` = sd_within / sqrt(m), `all years` = sd_all / sqrt(m)) %>%
  pivot_longer(c(`within year`, `all years`), names_to = "sd_type", values_to = "se")
now <- ss %>% mutate(group = factor(group, lv))
for (meas in c("N", "WEIGHT")) {
  p <- ggplot(filter(curves, measure == meas), aes(m, se, colour = group, linetype = sd_type)) +
    geom_line(linewidth = 0.8) +
    geom_point(data = filter(now, measure == meas), aes(tows_per_year, se_now, colour = group),
               inherit.aes = FALSE, size = 2.5) +
    facet_wrap(~stratum_name, nrow = 1) +
    scale_colour_manual(values = c(alewife = "#1b9e77", smelt = "#d95f02", bloater = "#7570b3"), name = NULL) +
    scale_linetype_manual(values = c(`within year` = "solid", `all years` = "dashed"), name = "SD") +
    labs(x = "Tows in the stratum (per year)", y = "SE of the mean proportion",
         title = paste0("Lake Michigan strata: SE of species proportions by ", if (meas == "N") "number" else "weight"),
         subtitle = "Points = current median tows per year (within-year SD)") +
    theme_bw(base_size = 11) +
    theme(strip.background = element_rect(fill = "grey92"), legend.position = "bottom")
  ggsave(file.path(OUTPUT_DIR, paste0("stratum_se_michigan_", tolower(meas), ".png")), p, width = 13, height = 4.6, dpi = 150)
}
