# Region x depth strata (LAKE env var, default Huron): mean, SD and SE per depth stratum x survey region, and the
# variance gain from splitting each depth stratum by region at the same total effort. Number and weight.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/stratum_stats.R")))
LAKE <- Sys.getenv("LAKE", "Huron")
lk <- tolower(LAKE)
cfg <- LAKE_STRATA[[LAKE]]
tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == LAKE)
ts <- named_strata(tows, LAKE)

out <- map(c("N", "WEIGHT"), \(m) {
  props <- tow_catch(tows, m) %>% filter(!is.na(n) & n > 0) %>% inner_join(ts, by = "OP_ID") %>%
    mutate(region = tow_region(transect))
  rd <- region_depth_stats(props, cfg$groups) %>% mutate(measure = m, .before = 1)
  ss <- stratum_stats(props, groups = cfg$groups)
  list(rd = rd, gain = region_split_gain(rd, ss) %>% mutate(measure = m, .before = 1))
})
rd <- map(out, "rd") %>% list_rbind()
gain <- map(out, "gain") %>% list_rbind()
write_csv(rd, file.path(OUTPUT_DIR, paste0("region_depth_stats_", lk, ".csv")))
write_csv(gain, file.path(OUTPUT_DIR, paste0("region_split_gain_", lk, ".csv")))

options(width = 250)
cat("Mean proportion (tows) by depth stratum x region, by number; * = fewer than 5 tows:\n")
print(as.data.frame(rd %>% filter(measure == "N") %>%
  mutate(cell = paste0(sprintf("%.2f", mean_p), " (", tows, ")", if_else(small, "*", ""))) %>%
  select(stratum_name, group, region, cell) %>% pivot_wider(names_from = region, values_from = cell)))
cat("\nGain from splitting by region (by number); variance_ratio < 1 = less variance at the same effort:\n")
print(as.data.frame(gain %>% filter(measure == "N") %>%
  transmute(stratum_name, group, regions, sd_pooled = round(sd_pooled, 3), sd_within_regions = round(sd_within_regions, 3),
            variance_ratio = round(variance_ratio, 2), se_pooled_now = round(se_pooled_now, 3), se_split_now = round(se_split_now, 3))))

# Plot: mean proportion by region within each depth stratum (number), point size = tows, +-1 SE at current effort
p <- ggplot(filter(rd, measure == "N", !small), aes(region, mean_p, colour = group)) +
  geom_pointrange(aes(ymin = pmax(0, mean_p - se_now), ymax = pmin(1, mean_p + se_now)),
                  position = position_dodge(width = 0.5), size = 0.3) +
  facet_wrap(~stratum_name, nrow = 1, labeller = label_wrap_gen(22)) +
  scale_colour_manual(values = c(alewife = "magenta", smelt = "gray", bloater = "black", other = "darkorange"), name = NULL) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(x = "Region", y = "Mean proportion (by number)",
       title = paste0("Lake ", LAKE, ": composition by survey region within the depth strata"),
       subtitle = "Bars = +-1 SE at the current median tows per year in that region and stratum; cells with < 5 tows omitted") +
  theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92"), legend.position = "bottom")
ggsave(file.path(OUTPUT_DIR, paste0("region_depth_", lk, ".png")), p, width = 15, height = 4.8, dpi = 150)
