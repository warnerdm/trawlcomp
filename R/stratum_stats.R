# Mean proportion, SD and SE of each species' tow proportion within depth strata (design-based framework).
# Strata: Adams et al. (2006) clustering of Lake Michigan cells (strata.R), here k = 4 from tows with >= 10 fish
# and cells with >= 5 tows (user, 2026-10-15). The strata are defined once, by number, and used for both
# number and weight proportions.
# Per stratum and species:
#   mean_p     mean of the tow proportions (every tow equal, as Adams et al.)
#   ratio_p    catch-weighted proportion, sum(count) / sum(n)
#   sd_all     SD of the tow proportions over all tows (years pooled; includes between-year change)
#   sd_within  pooled within-year SD: deviations from each year's stratum mean, df = tows - years
#              (years with one tow add no df); the "repeat the tow here" SD within a survey
#   se_now     sd_within / sqrt(median tows per year): SE of a year's stratum mean at current effort
# Combined (W_h = stratum share of cells, each cell an equal share of the sample space):
#   p_st = sum W_h mean_p_h, se_st = sqrt(sum W_h^2 sd_within_h^2 / m_h) with m_h = median tows per year.
source("D:/pyprojects/trawlcomp/R/strata.R")

# Tow -> stratum for Lake Michigan (k strata), with descriptive names
michigan_strata <- function(tows, k = 4, cell_m = 20, min_fish = 10, min_tows = 5) {
  catch <- tow_catch(tows, "N") %>% mutate(n_fish = n)
  tc <- tow_cells(catch, cell_m = cell_m, min_fish = min_fish)
  cs <- main_block(cell_stats(tc, min_tows = min_tows))$cells
  st <- cutree(cluster_cells(cs), k = k)
  cell_st <- tibble(cell = cs$cell, stratum = st)
  tc %>%
    inner_join(cell_st, by = "cell") %>%
    mutate(.by = stratum, s_bloater = mean(bloater), s_bd = mean(bottom_depth), s_fd = mean(fishing_depth),
           cells = n_distinct(cell)) %>%
    select(OP_ID, cell, stratum, s_bloater, s_bd, s_fd, cells)
}

# Names for the 4 strata: deep = most bloater; surface offshore = deepest bottom of the rest; midwater
# nearshore = deepest fishing of the remaining two; the last = surface nearshore
name_strata <- function(ts) {
  s <- distinct(ts, stratum, s_bloater, s_bd, s_fd, cells)
  deep <- s$stratum[which.max(s$s_bloater)]
  r <- filter(s, stratum != deep)
  off <- r$stratum[which.max(r$s_bd)]
  r <- filter(r, stratum != off)
  mid <- r$stratum[which.max(r$s_fd)]
  near <- setdiff(r$stratum, mid)
  lv <- c("Surface nearshore", "Midwater nearshore", "Surface offshore", "Deep")
  key <- setNames(lv, c(near, mid, off, deep))
  mutate(ts, stratum_name = factor(key[as.character(stratum)], lv))
}

# Per stratum x group statistics for one measure
stratum_stats <- function(props, groups = STRATA_GROUPS) {
  props %>%
    pivot_longer(all_of(groups), names_to = "group", values_to = "count") %>%
    mutate(p = count / n) %>%
    group_by(stratum_name, group) %>%
    summarise(tows = n(), years = n_distinct(YEAR),
              tows_per_year = median(table(YEAR)),
              mean_p = mean(p), ratio_p = sum(count) / sum(n), sd_all = sd(p),
              ss_within = sum((p - ave(p, YEAR))^2), df_within = tows - years,
              cells = first(cells), .groups = "drop") %>%
    mutate(sd_within = sqrt(ss_within / df_within),
           se_now = sd_within / sqrt(tows_per_year),
           se_now_all = sd_all / sqrt(tows_per_year)) %>%
    select(-ss_within)
}

# Combined (stratified) proportion and SE per group, W_h = share of cells
combined_stats <- function(ss) {
  ss %>%
    mutate(W = cells / sum(cells[!duplicated(stratum_name)]), .by = group) %>%
    summarise(.by = group, p_st = sum(W * mean_p),
              se_st = sqrt(sum(W^2 * sd_within^2 / tows_per_year)),
              se_st_all = sqrt(sum(W^2 * sd_all^2 / tows_per_year)))
}
