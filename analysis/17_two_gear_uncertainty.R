# Method 1: combined acoustic (EchoNet2Fish fish_ha) + trawl (proportion) uncertainty of species density per
# Michigan stratum for one year (YEAR env var, default 2021). Needs 09_stratum_stats output.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/two_gear.R")))
YEAR <- as.integer(Sys.getenv("YEAR", 2021))   # 2021: most Michigan tows (user)
LAKE <- "Michigan"
groups <- LAKE_STRATA[[LAKE]]$groups

tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == LAKE)
ts <- named_strata(tows, LAKE)
cells <- distinct(ts, cell, stratum_name)
ss <- read_csv(file.path(OUTPUT_DIR, "stratum_stats_michigan.csv"), show_col_types = FALSE) %>% filter(measure == "N")
props <- tow_catch(tows, "N") %>% filter(!is.na(n) & n > 0) %>% inner_join(ts, by = "OP_ID")

ac <- acoustic_by_stratum(YEAR, cells)
tr <- trawl_by_stratum(props, ss, YEAR, groups)
res <- combine_gears(ac, tr) %>% mutate(YEAR = YEAR, .before = 1) %>%
  mutate(stratum_name = factor(stratum_name, levels(ts$stratum_name)), group = factor(group, groups)) %>%
  arrange(stratum_name, group)
write_csv(res, file.path(OUTPUT_DIR, paste0("two_gear_michigan_", YEAR, ".csv")))

options(width = 220)
cat("Acoustic density by stratum,", YEAR, "(transects = sampling units):\n")
print(as.data.frame(mutate(ac, across(where(is.double), \(x) signif(x, 3)))))
cat("\nSpecies density, SE and CV; share of the variance from each gear:\n")
print(as.data.frame(res %>% transmute(stratum_name, group, tows, p = round(p, 3), cv_p = round(cv_p, 2),
  cv_rho = round(cv_rho, 2), D = round(D, 1), se_D = round(se_D, 1), cv_D = round(cv_D, 2),
  acoustic = round(share_acoustic, 2), trawl = round(share_trawl, 2), product = round(share_product, 2))))

d <- res %>% filter(D > 0) %>%
  select(stratum_name, group, cv_D, share_acoustic, share_trawl, share_product) %>%
  pivot_longer(starts_with("share"), names_to = "source", values_to = "share") %>%
  mutate(source = factor(str_remove(source, "share_"), c("acoustic", "trawl", "product")))
p <- ggplot(d, aes(group, share, fill = source)) +
  geom_col(width = 0.7) +
  geom_text(data = distinct(d, stratum_name, group, cv_D), aes(group, 1.04, label = paste0("CV ", round(100 * cv_D), "%")),
            inherit.aes = FALSE, size = 3) +
  facet_wrap(~stratum_name, nrow = 1, labeller = label_wrap_gen(20)) +
  scale_fill_manual(values = c(acoustic = "steelblue", trawl = "darkorange", product = "grey70"), name = "Source") +
  scale_y_continuous(limits = c(0, 1.08), breaks = c(0, 0.5, 1)) +
  labs(x = NULL, y = "Share of the variance of species density",
       title = paste0("Lake Michigan ", YEAR, ": where the uncertainty in species density comes from"),
       subtitle = "Density = acoustic fish/ha x trawl proportion; label = CV of the species density") +
  theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92"), legend.position = "bottom")
ggsave(file.path(OUTPUT_DIR, paste0("two_gear_michigan_", YEAR, ".png")), p, width = 13, height = 4.6, dpi = 150)
