# Does composition differ by survey region within the depth strata? (LAKE env var; Michigan first)
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/stratum_stats.R")))
LAKE <- Sys.getenv("LAKE", "Michigan")
lk <- tolower(LAKE)
cfg <- LAKE_STRATA[[LAKE]]
tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == LAKE)
ts <- named_strata(tows, LAKE)

res <- map(c("N", "WEIGHT"), \(m) {
  props <- tow_catch(tows, m) %>%
    filter(!is.na(n) & n > 0) %>%
    inner_join(ts, by = "OP_ID") %>%
    mutate(region = tow_region(transect))
  region_effects(props, cfg$groups) %>% mutate(measure = m, .before = 1)
}) %>% list_rbind()
write_csv(res, file.path(OUTPUT_DIR, paste0("region_effects_", lk, ".csv")))

options(width = 250)
print(as.data.frame(res %>% filter(measure == "N") %>%
  transmute(stratum_name, group, tows, regions, p_region = signif(p_region, 2), p_after_year = signif(p_region_after_year, 2),
            region_share = round(region_share, 2), sd_all = round(sd_all, 3), sd_within_region = round(sd_within_region, 3),
            region_means)))
