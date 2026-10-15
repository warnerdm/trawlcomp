# EchoNet2Fish fish_ha (interval x 10 m layer, NA/Inf = 0) by trawl stratum, all Lake Michigan years.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/acoustic.R")))

tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == "Michigan")
cells <- name_strata(michigan_strata(tows)) %>% distinct(cell, stratum_name)
years <- list.files(EN2F_DIR, pattern = "^MI[0-9]{4}$") %>% str_sub(3) %>% as.integer()

il <- map(years, \(y) assign_strata(read_intlay(y), cells) %>% mutate(YEAR = y)) %>% list_rbind()

by_year <- il %>%
  summarise(.by = c(YEAR, stratum_name), rows = n(), zero = mean(fish_ha == 0),
            mean = mean(fish_ha), sd = sd(fish_ha), median = median(fish_ha)) %>%
  mutate(cv = sd / mean) %>%
  arrange(stratum_name, YEAR)
pooled <- il %>%
  summarise(.by = stratum_name, years = n_distinct(YEAR), rows = n(), zero = mean(fish_ha == 0),
            mean = mean(fish_ha), sd = sd(fish_ha), median = median(fish_ha), p90 = quantile(fish_ha, 0.9)) %>%
  mutate(cv = sd / mean) %>%
  arrange(stratum_name)
write_csv(by_year, file.path(OUTPUT_DIR, "acoustic_fish_ha_strata_by_year.csv"))
write_csv(pooled, file.path(OUTPUT_DIR, "acoustic_fish_ha_strata_pooled.csv"))

options(width = 200)
cat("Years:", paste(years, collapse = " "), "\n\nAll years pooled:\n")
print(as.data.frame(mutate(pooled, across(where(is.double), \(x) signif(x, 3)))))
cat("\nMean fish/ha by year and stratum:\n")
print(as.data.frame(by_year %>% select(YEAR, stratum_name, mean) %>% mutate(mean = round(mean)) %>%
                      pivot_wider(names_from = stratum_name, values_from = mean)))

p <- ggplot(filter(by_year, stratum_name != "Outside strata"), aes(YEAR, mean)) +
  geom_line() + geom_point() +
  facet_wrap(~stratum_name, nrow = 1, scales = "free_y") +
  labs(x = NULL, y = "Mean fish/ha (interval x 10 m layer)",
       title = "Lake Michigan: EchoNet2Fish mean fish/ha by trawl stratum and year",
       caption = "fish_ha NA/Inf = 0. Free y scales. No 2020 survey.") +
  theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92"), plot.caption = element_text(hjust = 0))
ggsave(file.path(OUTPUT_DIR, "acoustic_fish_ha_strata_by_year.png"), p, width = 15, height = 4.2, dpi = 150)
