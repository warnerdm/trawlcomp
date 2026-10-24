# Combined acoustic + trawl uncertainty of species density, method 1 (analytic; user, 2026-10-24).
# Species density in stratum h: D_hs = rho_h * p_hs. rho from EchoNet2Fish fish_ha (in-situ TS, so the trawl enters
# only through p and the two gears are independent; user: in-situ TS is standard in the Great Lakes).
#   Var(D) = p^2 Var(rho) + rho^2 Var(p) + Var(rho) Var(p)   (exact for a product of independent estimates;
#   Goodman 1960). Reported as the shares of Var(D) from the acoustic term, the trawl term and their product.
source("D:/pyprojects/trawlcomp/R/acoustic.R")

# Acoustic density per stratum for one year: transect = sampling unit (Region_name, e.g. "nn1"). Each transect's
# mean fish_ha over its interval x layer cells in the stratum; rho = mean over transects; SE = SD / sqrt(n).
acoustic_by_stratum <- function(year, cells) {
  assign_strata(read_intlay(year), cells) %>%
    filter(stratum_name != "Outside strata") %>%
    summarise(.by = c(stratum_name, Region_name), cells = n(), fish_ha = mean(fish_ha)) %>%
    summarise(.by = stratum_name, transects = n(), acoustic_cells = sum(cells),
              rho = mean(fish_ha), se_rho = sd(fish_ha) / sqrt(n())) %>%
    mutate(cv_rho = se_rho / rho)
}

# Trawl proportion per stratum and group for one year: that year's mean of tow proportions; SE from the pooled
# within-year tow SD of all years (ss: stratum_stats output, measure N) / sqrt(that year's tows).
trawl_by_stratum <- function(props, ss, year, groups) {
  props %>%
    filter(YEAR == year) %>%
    pivot_longer(all_of(groups), names_to = "group", values_to = "count") %>%
    summarise(.by = c(stratum_name, group), tows = n(), p = mean(count / n)) %>%
    left_join(select(ss, stratum_name, group, sd_within), by = c("stratum_name", "group")) %>%
    mutate(se_p = sd_within / sqrt(tows), cv_p = se_p / p)
}

combine_gears <- function(ac, tr) {
  tr %>%
    inner_join(ac, by = "stratum_name") %>%
    mutate(D = rho * p,
           var_ac = p^2 * se_rho^2, var_tr = rho^2 * se_p^2, var_x = se_rho^2 * se_p^2,
           se_D = sqrt(var_ac + var_tr + var_x), cv_D = se_D / D,
           share_acoustic = var_ac / se_D^2, share_trawl = var_tr / se_D^2, share_product = var_x / se_D^2)
}

# --- Survey regions as the strata (user, 2026-10-24: sn/nn/no/wn/so, as EchoNet2Fish) ---
# Acoustic: an interval's water-column density = sum of its layers' fish_ha (EchoNet2Fish's interval totals equal
# the layer sums); transect mean over its intervals; region mean over transects, SE = SD / sqrt(transects).
# regarea (ha... as in the file) is kept for area-weighted lake totals.
acoustic_by_region <- function(year) {
  read_intlay(year) %>%
    summarise(.by = c(region, regarea, Region_name, Interval), fish_ha = sum(fish_ha)) %>%
    summarise(.by = c(region, regarea, Region_name), intervals = n(), fish_ha = mean(fish_ha)) %>%
    summarise(.by = c(region, regarea), transects = n(), intervals = sum(intervals),
              rho = mean(fish_ha), se_rho = sd(fish_ha) / sqrt(n())) %>%
    mutate(cv_rho = se_rho / rho)
}

# Trawl: that year's tows in the region (all fishing depths), mean of tow proportions; SE from the region's pooled
# within-year tow SD (all years) / sqrt(that year's tows). props needs region and YEAR.
trawl_by_region <- function(props, year, groups) {
  long <- props %>% pivot_longer(all_of(groups), names_to = "group", values_to = "count") %>% mutate(p = count / n)
  sdw <- long %>% summarise(.by = c(region, group), tows_all = n(), years_all = n_distinct(YEAR),
                            sd_within = sqrt(sum((p - ave(p, YEAR))^2) / (n() - n_distinct(YEAR))))
  long %>% filter(YEAR == year) %>%
    summarise(.by = c(region, group), tows = n(), p = mean(p)) %>%
    left_join(sdw, by = c("region", "group")) %>%
    mutate(se_p = sd_within / sqrt(tows), cv_p = se_p / p)
}

# Area-weighted lake total per group: N = sum(regarea * D), Var = sum(regarea^2 Var(D)) (regions independent)
lake_total <- function(res) {
  res %>% summarise(.by = group, N = sum(regarea * D), se_N = sqrt(sum(regarea^2 * se_D^2)),
                    var_ac = sum(regarea^2 * var_ac), var_tr = sum(regarea^2 * var_tr)) %>%
    mutate(cv_N = se_N / N, share_acoustic = var_ac / se_N^2, share_trawl = var_tr / se_N^2) %>%
    select(-var_ac, -var_tr)
}
