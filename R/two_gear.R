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

# --- Survey regions x depth layer (user, 2026-10-24: layers split at 40 m) ---
LAYER_SPLIT_M <- 40
layer_of <- function(depth) if_else(depth < LAYER_SPLIT_M, paste0("< ", LAYER_SPLIT_M, " m"), paste0(">= ", LAYER_SPLIT_M, " m"))

# Acoustic density per transect x layer (fish/ha of lake surface): per interval, sum of fish_ha over the 10 m layers
# in the depth layer (0 where the water is shallower); transect mean over its intervals. Wide by layer.
acoustic_transect_layers <- function(year) {
  read_intlay(year) %>%
    mutate(layer = layer_of(layer_mid)) %>%
    summarise(.by = c(region, regarea, Region_name, Interval, layer), fish_ha = sum(fish_ha)) %>%
    complete(nesting(region, regarea, Region_name, Interval), layer, fill = list(fish_ha = 0)) %>%
    summarise(.by = c(region, regarea, Region_name, layer), fish_ha = mean(fish_ha))
}

# Trawl proportion per region x layer for the year (tows by fishing depth). Where a region x layer has no tows
# that year, the year's lake-wide layer proportion is used (p_source "lake layer", as EchoNet2Fish's lake-wide
# hypolimnion slice). SE = pooled within-year SD (all years) of the region x layer (lake layer if < 10 tows over
# all years) / sqrt(tows used).
trawl_region_layers <- function(props, year, groups) {
  long <- props %>% mutate(layer = layer_of(fishing_depth)) %>%
    pivot_longer(all_of(groups), names_to = "group", values_to = "count") %>% mutate(p = count / n)
  sdw <- function(d) sqrt(sum((d$p - ave(d$p, d$YEAR))^2) / max(1, nrow(d) - n_distinct(d$YEAR)))
  sd_rl <- long %>% group_by(region, layer, group) %>% summarise(tows_all = n(), sd_rl = sdw(pick(everything())), .groups = "drop")
  sd_l <- long %>% group_by(layer, group) %>% summarise(sd_l = sdw(pick(everything())), .groups = "drop")
  yr <- filter(long, YEAR == year)
  lake <- yr %>% summarise(.by = c(layer, group), tows_lake = n(), p_lake = mean(p))
  regs <- unique(props$region)
  expand_grid(region = regs, layer = unique(long$layer), group = groups) %>%
    left_join(yr %>% summarise(.by = c(region, layer, group), tows = n(), p_rl = mean(p)), by = c("region", "layer", "group")) %>%
    left_join(lake, by = c("layer", "group")) %>%
    left_join(sd_rl, by = c("region", "layer", "group")) %>% left_join(sd_l, by = c("layer", "group")) %>%
    mutate(p_source = if_else(is.na(tows), "lake layer", "region layer"),
           p = coalesce(p_rl, p_lake), tows_used = coalesce(tows, tows_lake),
           sd = if_else(!is.na(tows_all) & tows_all >= 10 & p_source == "region layer", sd_rl, sd_l),
           se_p = sd / sqrt(tows_used)) %>%
    select(region, layer, group, p_source, tows = tows_used, p, sd, se_p)
}

# Species density per region = sum over layers of rho_layer x p_layer. Acoustic variance from the transects with the
# proportions fixed (keeps the covariance between a transect's layers); trawl variance sum over layers of
# rho^2 Var(p); product terms Var(rho) Var(p) per layer.
combine_region_layers <- function(at, tr) {
  at_tr <- at %>% inner_join(tr, by = c("region", "layer"), relationship = "many-to-many")
  ac <- at_tr %>% summarise(.by = c(region, regarea, group, Region_name), d_t = sum(fish_ha * p)) %>%
    summarise(.by = c(region, regarea, group), transects = n(), D = mean(d_t), var_ac = var(d_t) / n())
  lay <- at %>% summarise(.by = c(region, layer), rho = mean(fish_ha), var_rho = var(fish_ha) / n()) %>%
    inner_join(tr, by = c("region", "layer")) %>%
    summarise(.by = c(region, group), var_tr = sum(rho^2 * se_p^2), var_x = sum(var_rho * se_p^2),
              lake_layer_used = paste(layer[p_source == "lake layer"], collapse = "; "))
  ac %>% inner_join(lay, by = c("region", "group")) %>%
    mutate(se_D = sqrt(var_ac + var_tr + var_x), cv_D = se_D / D,
           share_acoustic = var_ac / se_D^2, share_trawl = var_tr / se_D^2, share_product = var_x / se_D^2)
}

# --- Method 2: bootstrap (user, 2026-10-24) ---
# Each replicate resamples, with replacement, the transects within each region (acoustic) and the year's tows
# within each region x layer (trawl; a region x layer without tows that year resamples the year's lake-wide tows
# of that layer, as in method 1), recomputes D = sum over layers rho_layer x p_layer per region and the area-
# weighted lake total. mode "both", "acoustic" (tows fixed) or "trawl" (transects fixed) splits the variance.
# Note: a region x layer with one tow has no bootstrap variance (method 1 borrows an all-years SD instead).
bootstrap_region_layer <- function(at, props_year, groups, B = 2000, mode = "both", seed = 1, pools = NULL) {
  set.seed(seed)
  tw <- props_year %>% mutate(layer = layer_of(fishing_depth)) %>%
    mutate(across(all_of(groups), \(x) x / n))
  regions <- unique(at$region); layers <- unique(at$layer)
  area <- distinct(at, region, regarea)
  # tow pool per region x layer (fallback: lake-wide pool for the layer), unless given (trawl post-strata)
  if (is.null(pools)) {
    pools <- list()
    for (r in regions) for (l in layers) {
      d <- filter(tw, region == r, layer == l)
      if (nrow(d) == 0) d <- filter(tw, layer == l)
      pools[[paste(r, l)]] <- as.matrix(d[groups])
    }
  }
  acw <- at %>% pivot_wider(names_from = layer, values_from = fish_ha, values_fill = 0)
  out <- vector("list", B)
  for (b in seq_len(B)) {
    rows <- list()
    for (r in regions) {
      a <- filter(acw, region == r)
      ia <- if (mode == "trawl") seq_len(nrow(a)) else sample.int(nrow(a), replace = TRUE)
      rho <- colMeans(as.matrix(a[ia, layers, drop = FALSE]))
      D <- setNames(numeric(length(groups)), groups)
      for (l in layers) {
        pm <- pools[[paste(r, l)]]
        it <- if (mode == "acoustic") seq_len(nrow(pm)) else sample.int(nrow(pm), replace = TRUE)
        D <- D + rho[[l]] * colMeans(pm[it, , drop = FALSE])
      }
      rows[[r]] <- tibble(b = b, region = r, group = groups, D = D)
    }
    out[[b]] <- bind_rows(rows)
  }
  bind_rows(out) %>% left_join(area, by = "region")
}

summarise_boot <- function(bt) {
  reg <- bt %>% summarise(.by = c(region, group), D_mean = mean(D), se_D = sd(D),
                          lo = quantile(D, 0.025), hi = quantile(D, 0.975))
  tot <- bt %>% summarise(.by = c(b, group), N = sum(regarea * D)) %>%
    summarise(.by = group, N_mean = mean(N), se_N = sd(N), lo = quantile(N, 0.025), hi = quantile(N, 0.975))
  list(region = reg, total = tot)
}

# --- Trawl post-strata (user, 2026-10-24: trawl only; the acoustic regions are kept) ---
# Upper layer (< 40 m): the year's tows in the region's half of the lake, north (nn, no) or south (sn, so, wn; wn's
# composition is closer to the south). Lower layer (>= 40 m): lake-wide tows of ALL years pooled (0-8 deep tows a
# year; deep composition ~98% bloater with no significant year or region effect).
TRAWL_HALF <- c(nn = "north", no = "north", sn = "south", so = "south", wn = "south")

ps_long <- function(props, groups) {
  props %>% mutate(layer = layer_of(fishing_depth), half = TRAWL_HALF[region]) %>%
    pivot_longer(all_of(groups), names_to = "group", values_to = "count") %>% mutate(p = count / n)
}

# Method 1 proportions per region x layer under the post-strata. Upper: the year's mean in the half, SE = the half's
# pooled within-year SD (all years) / sqrt(year's tows). Lower: all-years lake-wide mean, SE = SD / sqrt(all tows).
trawl_post_strata <- function(props, year, groups, regions) {
  long <- ps_long(props, groups)
  up <- filter(long, layer == layer_of(0))
  sd_up <- up %>% summarise(.by = c(half, group), sd = sqrt(sum((p - ave(p, YEAR))^2) / (n() - n_distinct(YEAR))))
  p_up <- up %>% filter(YEAR == year) %>% summarise(.by = c(half, group), tows = n(), p = mean(p)) %>%
    left_join(sd_up, by = c("half", "group")) %>% mutate(se_p = sd / sqrt(tows), p_source = paste(half, "half,", year))
  p_lo <- long %>% filter(layer == layer_of(100)) %>%
    summarise(.by = group, tows = n(), sd = sd(p), p = mean(p)) %>%
    mutate(se_p = sd / sqrt(tows), p_source = "lake-wide, all years")
  bind_rows(
    tibble(region = regions, half = unname(TRAWL_HALF[regions])) %>%
      left_join(p_up, by = "half", relationship = "many-to-many") %>% mutate(layer = layer_of(0)),
    expand_grid(region = regions, p_lo) %>% mutate(layer = layer_of(100))) %>%
    select(region, layer, group, p_source, tows, p, sd, se_p)
}

# Bootstrap pools under the post-strata (matrices of tow proportions keyed "region layer")
post_strata_pools <- function(props, year, groups, regions) {
  tw <- props %>% mutate(layer = layer_of(fishing_depth), half = TRAWL_HALF[region]) %>%
    mutate(across(all_of(groups), \(x) x / n))
  lo <- as.matrix(filter(tw, layer == layer_of(100))[groups])
  pools <- list()
  for (r in regions) {
    pools[[paste(r, layer_of(0))]] <- as.matrix(filter(tw, YEAR == year, layer == layer_of(0), half == TRAWL_HALF[[r]])[groups])
    pools[[paste(r, layer_of(100))]] <- lo
  }
  pools
}
