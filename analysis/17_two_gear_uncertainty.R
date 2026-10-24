# Method 1: combined acoustic (EchoNet2Fish fish_ha) + trawl (proportion) uncertainty of species density, Lake
# Michigan, one year (YEAR env var, default 2021: most tows, user). FRAME = "region" (default; survey regions
# sn/nn/no/wn/so as EchoNet2Fish, user) or "strata" (the depth strata; needs 09_stratum_stats output).
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/two_gear.R")))
YEAR <- as.integer(Sys.getenv("YEAR", 2021))
FRAME <- Sys.getenv("FRAME", "region")
LAKE <- "Michigan"
groups <- LAKE_STRATA[[LAKE]]$groups
min_fish <- LAKE_STRATA[[LAKE]]$min_fish

tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == LAKE)
n_fish <- tow_catch(tows, "N") %>% select(OP_ID, n_fish = n)
props <- tow_catch(tows, "N") %>% left_join(n_fish, by = "OP_ID") %>%
  filter(!is.na(n) & n > 0 & n_fish >= min_fish) %>% mutate(region = tow_region(transect))

if (FRAME == "region") {
  ac <- acoustic_by_region(YEAR)
  tr <- trawl_by_region(props, YEAR, groups)
  res <- tr %>% inner_join(ac, by = "region") %>%
    mutate(D = rho * p, var_ac = p^2 * se_rho^2, var_tr = rho^2 * se_p^2, var_x = se_rho^2 * se_p^2,
           se_D = sqrt(var_ac + var_tr + var_x), cv_D = se_D / D,
           share_acoustic = var_ac / se_D^2, share_trawl = var_tr / se_D^2, share_product = var_x / se_D^2,
           unit = region)
  tot <- lake_total(res) %>% mutate(YEAR = YEAR, .before = 1)
  write_csv(tot, file.path(OUTPUT_DIR, paste0("two_gear_michigan_", YEAR, "_lake_total.csv")))
} else {
  ts <- named_strata(tows, LAKE)
  cells <- distinct(ts, cell, stratum_name)
  ss <- read_csv(file.path(OUTPUT_DIR, "stratum_stats_michigan.csv"), show_col_types = FALSE) %>% filter(measure == "N")
  ac <- acoustic_by_stratum(YEAR, cells)
  tr <- trawl_by_stratum(inner_join(props, select(ts, OP_ID, stratum_name), by = "OP_ID"), ss, YEAR, groups)
  res <- combine_gears(ac, tr) %>% mutate(unit = as.character(stratum_name))
}
res <- res %>% mutate(YEAR = YEAR, group = factor(group, groups), .before = 1) %>% arrange(unit, group)
tag <- paste0(YEAR, if (FRAME == "region") "_regions" else "_strata")
write_csv(res, file.path(OUTPUT_DIR, paste0("two_gear_michigan_", tag, ".csv")))

options(width = 220)
cat("Acoustic density,", YEAR, FRAME, "(transects = sampling units):\n")
print(as.data.frame(mutate(ac, across(where(is.double), \(x) signif(x, 3)))))
cat("\nSpecies density (fish/ha), SE, CV; share of the variance from each gear:\n")
print(as.data.frame(res %>% transmute(unit, group, tows, p = round(p, 3), cv_p = round(cv_p, 2), cv_rho = round(cv_rho, 2),
  D = round(D, 1), se_D = round(se_D, 1), cv_D = round(cv_D, 2), acoustic = round(share_acoustic, 2),
  trawl = round(share_trawl, 2), product = round(share_product, 2))))
if (FRAME == "region") {
  cat("\nLake total (sum of region area x density; units of regarea x fish/ha):\n")
  print(as.data.frame(mutate(tot, across(where(is.double), \(x) signif(x, 3)))))
}

d <- res %>% filter(D > 0) %>%
  select(unit, group, cv_D, share_acoustic, share_trawl, share_product) %>%
  pivot_longer(starts_with("share"), names_to = "source", values_to = "share") %>%
  mutate(source = factor(str_remove(source, "share_"), c("acoustic", "trawl", "product")))
p <- ggplot(d, aes(group, share, fill = source)) +
  geom_col(width = 0.7) +
  geom_text(data = distinct(d, unit, group, cv_D), aes(group, 1.04, label = paste0("CV ", round(100 * cv_D), "%")),
            inherit.aes = FALSE, size = 3) +
  facet_wrap(~unit, nrow = 1, labeller = label_wrap_gen(20)) +
  scale_fill_manual(values = c(acoustic = "steelblue", trawl = "darkorange", product = "grey70"), name = "Source") +
  scale_y_continuous(limits = c(0, 1.08), breaks = c(0, 0.5, 1)) +
  labs(x = NULL, y = "Share of the variance of species density",
       title = paste0("Lake Michigan ", YEAR, ": where the uncertainty in species density comes from (",
                      if (FRAME == "region") "survey regions" else "depth strata", ")"),
       subtitle = "Density = acoustic fish/ha x trawl proportion; label = CV of the species density") +
  theme_bw(base_size = 11) + theme(strip.background = element_rect(fill = "grey92"), legend.position = "bottom")
ggsave(file.path(OUTPUT_DIR, paste0("two_gear_michigan_", tag, ".png")), p, width = 13, height = 4.6, dpi = 150)
