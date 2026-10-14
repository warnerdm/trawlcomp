# Current trawl effort per lake-year and depth layer, placed on the SE-vs-number-of-tows curves.
# Layers: fishing depth < 35 m (shallow) and >= 35 m (deep) (user, 2026-10-14). Only tows with fish in the
# groups (n > 0) carry composition information, so effort counts those.
source("D:/pyprojects/trawlcomp/R/se_plots.R")

LAYER_BREAK_M <- 35

add_layer <- function(d) {
  mutate(d, layer = factor(if_else(fishing_depth < LAYER_BREAK_M, paste0("< ", LAYER_BREAK_M, " m"),
                                   paste0(">= ", LAYER_BREAK_M, " m")),
                           paste0(c("< ", ">= "), LAYER_BREAK_M, " m")))
}

# Tows per lake-year-layer (all tows and tows with catch)
effort_by_year <- function(catch) {
  catch %>%
    filter(!is.na(fishing_depth)) %>%
    add_layer() %>%
    summarise(.by = c(lake, YEAR, layer), tows = n(), tows_with_catch = sum(n > 0)) %>%
    complete(nesting(lake, YEAR), layer, fill = list(tows = 0L, tows_with_catch = 0L)) %>%
    arrange(lake, YEAR, layer)
}

# SE curves per lake, group and layer: SE_i(m) = sd_obs_i / sqrt(m), median over the layer's tows
se_by_layer <- function(tow_stats, catch, m = 1:150) {
  tow_stats %>%
    left_join(select(catch, OP_ID, fishing_depth), by = "OP_ID") %>%
    add_layer() %>%
    cross_join(tibble(m = m)) %>%
    summarise(.by = c(lake, group, layer, m), se = median(sd_obs / sqrt(m)))
}

# Current effort (median tows with catch per year in the layer) and 2x, 3x, with the SE at each
effort_points <- function(se, effort) {
  eff <- effort %>%
    summarise(.by = c(lake, layer), current = median(tows_with_catch),
              min_year = min(tows_with_catch), max_year = max(tows_with_catch))
  se %>%
    inner_join(eff, by = c("lake", "layer")) %>%
    summarise(.by = c(lake, group, layer, current, min_year, max_year),
              se_current = approx(m, se, xout = 1 * first(current))$y,
              se_2x = approx(m, se, xout = 2 * first(current))$y,
              se_3x = approx(m, se, xout = 3 * first(current))$y)
}

plot_effort <- function(se, pts, lake_name) {
  lv <- c("alewife", "smelt", "bloater", "other")
  s <- filter(se, lake == lake_name) %>% mutate(group = factor(group, lv))
  p <- filter(pts, lake == lake_name) %>% mutate(group = factor(group, lv)) %>%
    pivot_longer(c(se_current, se_2x, se_3x), names_to = "effort", values_to = "se_at") %>%
    mutate(m_at = case_when(effort == "se_current" ~ current, effort == "se_2x" ~ 2 * current, TRUE ~ 3 * current),
           effort = factor(effort, c("se_current", "se_2x", "se_3x"), c("current", "2x", "3x")))
  ggplot(s, aes(m, se, colour = layer)) +
    geom_line(linewidth = 0.9) +
    geom_point(data = p, aes(m_at, se_at, shape = effort), size = 2.6) +
    facet_wrap(~group, nrow = 1) +
    scale_shape_manual(values = c(current = 16, `2x` = 1, `3x` = 2), name = "Tows per year") +
    scale_colour_manual(values = c("#d95f02", "#1b9e77"), name = "Fishing depth") +
    labs(x = "Number of tows (per year, per layer)", y = "SE of the mean proportion",
         title = paste0("Lake ", lake_name, ": current trawl effort on the SE curves"),
         subtitle = "Current = median tows with catch per year in the layer; curves = median over the layer's tows") +
    theme_bw(base_size = 11) +
    theme(strip.background = element_rect(fill = "grey92"), legend.position = "bottom")
}
