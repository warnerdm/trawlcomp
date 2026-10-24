# Presentation framework: survey regions, with fishing-depth x bottom-depth classes within each region
# (user, 2026-10-24: explain what is observed; regions already carry geography and partly depth).
source("D:/pyprojects/trawlcomp/R/stratum_stats.R")

FD_BREAKS <- c(0, 20, 40, 60, Inf)        # fishing depth classes (m)
BD_BREAKS <- c(0, 40, 80, 120, Inf)       # bottom depth classes (m)
REGION_MIN_FISH <- 5                      # as the stratum framework

depth_class <- function(x, breaks) {
  lab <- paste0(head(breaks, -1), if_else(is.finite(tail(breaks, -1)), paste0("-", tail(breaks, -1)), "+"), " m")
  cut(x, breaks, labels = lab, right = FALSE)
}

# Tow proportions with region and depth classes (tows with >= min_fish fish of the groups, by number)
region_depth_props <- function(tows, lake, measure = "N", min_fish = REGION_MIN_FISH) {
  groups <- LAKE_STRATA[[lake]]$groups
  n_fish <- tow_catch(tows, "N") %>% select(OP_ID, n_fish = n)
  tow_catch(tows, measure) %>%
    left_join(n_fish, by = "OP_ID") %>%
    filter(!is.na(n) & n > 0 & n_fish >= min_fish & !is.na(fishing_depth) & !is.na(bottom_depth)) %>%
    mutate(region = tow_region(transect),
           fd_class = depth_class(fishing_depth, FD_BREAKS), bd_class = depth_class(bottom_depth, BD_BREAKS),
           across(all_of(groups), \(x) x / n))
}

# Per region x fishing class x bottom class x group: tows, years, tows per year, mean, SD, SE at current effort
region_depth_table <- function(props, groups) {
  props %>%
    pivot_longer(all_of(groups), names_to = "group", values_to = "p") %>%
    summarise(.by = c(region, bd_class, fd_class, group), tows = n(), years = n_distinct(YEAR),
              tows_per_year = median(table(YEAR)), mean_p = mean(p), sd = if (n() > 1) sd(p) else NA_real_) %>%
    mutate(se_now = sd / sqrt(tows_per_year)) %>%
    arrange(region, bd_class, fd_class, group)
}

# Share of the tow-to-tow variance in each group's proportion explained by region, by depth class
# (fishing x bottom), by both (additive) and with their interaction (R^2 of linear models on the tow proportions)
variance_breakdown <- function(props, groups) {
  map(groups, \(g) {
    d <- props %>% mutate(p = .data[[g]], depth = interaction(fd_class, bd_class, drop = TRUE))
    r2 <- \(f) summary(lm(f, d))$r.squared
    tibble(group = g, tows = nrow(d), region = r2(p ~ region), depth = r2(p ~ depth),
           region_plus_depth = r2(p ~ region + depth), region_x_depth = r2(p ~ region * depth))
  }) %>% list_rbind() %>%
    mutate(unexplained = 1 - region_x_depth)
}

SPECIES_COLOURS <- c(alewife = "magenta", smelt = "gray70", bloater = "black", other = "darkorange")

# Stacked bars of mean composition by fishing-depth class (rows), one panel per region x bottom-depth class;
# n = tows; cells with fewer than min_tows tows are marked * (fading would make bloater look like smelt).
plot_region_depth <- function(tab, lake, groups, min_tows = 5) {
  d <- tab %>% mutate(group = factor(group, rev(groups)), faded = tows < min_tows,
                      fd_class = factor(fd_class, rev(levels(fd_class))))
  lab <- d %>% distinct(region, bd_class, fd_class, tows, faded)
  ggplot(d, aes(mean_p, fd_class, fill = group)) +
    geom_col(width = 0.8) +
    geom_text(data = lab, aes(x = 1.02, y = fd_class, label = paste0(tows, if_else(faded, "*", ""))),
              inherit.aes = FALSE, hjust = 0, size = 2.8) +
    facet_grid(region ~ bd_class, labeller = labeller(bd_class = \(x) paste("Bottom", x))) +
    scale_fill_manual(values = SPECIES_COLOURS, breaks = groups, name = NULL) +
    scale_x_continuous(limits = c(0, 1.15), breaks = c(0, 0.5, 1)) +
    labs(x = "Mean proportion of the catch (by number)", y = "Fishing depth",
         title = paste0("Lake ", lake, ": catch composition by fishing depth and bottom depth within survey regions"),
         subtitle = paste0("Tows with >= ", REGION_MIN_FISH, " fish; numbers = tows; * = fewer than ", min_tows, " tows")) +
    theme_bw(base_size = 10) +
    theme(strip.background = element_rect(fill = "grey92"), legend.position = "bottom", panel.grid.minor = element_blank())
}

# Map of the tows coloured by region, with the lake outline (maps package "lakes")
plot_region_map <- function(props, lake) {
  shore <- ggplot2::map_data("lakes")
  xl <- range(props$lon) + c(-0.3, 0.3); yl <- range(props$lat) + c(-0.3, 0.3)
  ctr <- props %>% summarise(.by = region, lon = median(lon), lat = median(lat), n = n())
  ggplot() +
    geom_polygon(data = shore, aes(long, lat, group = group), fill = "aliceblue", colour = "grey50", linewidth = 0.3) +
    geom_point(data = props, aes(lon, lat, colour = region), size = 1.2, alpha = 0.7) +
    geom_label(data = ctr, aes(lon, lat, label = paste0(region, " (", n, ")")), size = 3, alpha = 0.8) +
    coord_quickmap(xlim = xl, ylim = yl) +
    labs(x = NULL, y = NULL, colour = "Region", title = paste0("Lake ", lake, ": tows by survey region"),
         subtitle = paste0("Tows with >= ", REGION_MIN_FISH, " fish; label = region (tows)")) +
    theme_bw(base_size = 10)
}
