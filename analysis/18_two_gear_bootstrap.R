# Method 2: bootstrap of transects and tows for species density by region x depth layer (< / >= 40 m), Lake
# Michigan, one year (YEAR env var, default 2021); compared with method 1 (step 17). B replicates (env var B).
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/two_gear.R")))
YEAR <- as.integer(Sys.getenv("YEAR", 2021))
B <- as.integer(Sys.getenv("B", 2000))
LAKE <- "Michigan"
groups <- LAKE_STRATA[[LAKE]]$groups
min_fish <- LAKE_STRATA[[LAKE]]$min_fish

tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == LAKE)
n_fish <- tow_catch(tows, "N") %>% select(OP_ID, n_fish = n)
props_year <- tow_catch(tows, "N") %>% left_join(n_fish, by = "OP_ID") %>%
  filter(!is.na(n) & n > 0 & n_fish >= min_fish & YEAR == !!YEAR) %>% mutate(region = tow_region(transect))
at <- acoustic_transect_layers(YEAR)

runs <- map(c("both", "acoustic", "trawl"), \(m) summarise_boot(bootstrap_region_layer(at, props_year, groups, B, m)))
names(runs) <- c("both", "acoustic", "trawl")
reg <- runs$both$region %>%
  left_join(select(runs$acoustic$region, region, group, se_ac = se_D), by = c("region", "group")) %>%
  left_join(select(runs$trawl$region, region, group, se_tr = se_D), by = c("region", "group")) %>%
  mutate(cv = se_D / D_mean, share_acoustic = se_ac^2 / (se_ac^2 + se_tr^2), share_trawl = se_tr^2 / (se_ac^2 + se_tr^2))
tot <- runs$both$total %>%
  left_join(select(runs$acoustic$total, group, se_ac = se_N), by = "group") %>%
  left_join(select(runs$trawl$total, group, se_tr = se_N), by = "group") %>%
  mutate(cv = se_N / N_mean, share_acoustic = se_ac^2 / (se_ac^2 + se_tr^2), share_trawl = se_tr^2 / (se_ac^2 + se_tr^2))

m1 <- file.path(OUTPUT_DIR, paste0("two_gear_michigan_", YEAR, "_region_layer_lake_total.csv"))
if (file.exists(m1)) tot <- tot %>% left_join(read_csv(m1, show_col_types = FALSE) %>%
                                                select(group, N_m1 = N, se_m1 = se_N, cv_m1 = cv_N), by = "group")
write_csv(reg, file.path(OUTPUT_DIR, paste0("two_gear_boot_michigan_", YEAR, "_regions.csv")))
write_csv(tot, file.path(OUTPUT_DIR, paste0("two_gear_boot_michigan_", YEAR, "_lake_total.csv")))

options(width = 220)
cat("Bootstrap,", B, "replicates. By region (fish/ha):\n")
print(as.data.frame(reg %>% transmute(region, group, D = round(D_mean, 1), se = round(se_D, 1), cv = round(cv, 2),
  lo = round(lo, 1), hi = round(hi, 1), acoustic = round(share_acoustic, 2), trawl = round(share_trawl, 2))))
cat("\nLake totals (fish), bootstrap vs method 1:\n")
print(as.data.frame(mutate(tot, across(where(is.double), \(x) signif(x, 3)))))
