# Proportion of each species group per tow against the candidate covariates (fishing depth, bottom depth,
# lat, lon), one figure per lake. Points are tows (size = fish in the groups); the line is a binomial GAM
# smooth weighted by n, i.e. the catch-weighted mean proportion along that covariate alone.
source("D:/pyprojects/trawlcomp/R/tow_catch.R")
library(mgcv)

COVARIATES <- c(fishing_depth = "Fishing depth (m)", bottom_depth = "Bottom depth (m)",
                lat = "Latitude", lon = "Longitude")

composition_long <- function(catch) {
  catch %>%
    filter(n > 0) %>%
    pivot_longer(c(alewife, smelt, bloater, other), names_to = "group", values_to = "count") %>%
    filter(!is.na(count)) %>%
    mutate(p = count / n, group = factor(group, c("alewife", "smelt", "bloater", "other"))) %>%
    pivot_longer(all_of(names(COVARIATES)), names_to = "covariate", values_to = "x") %>%
    filter(!is.na(x)) %>%
    mutate(covariate = factor(COVARIATES[covariate], COVARIATES))
}

plot_composition <- function(long, lake_name) {
  d <- filter(long, lake == lake_name)
  ggplot(d, aes(x, p)) +
    geom_point(aes(size = n), alpha = 0.25, stroke = 0) +
    geom_smooth(aes(weight = n), method = "gam", formula = y ~ s(x, k = 6),
                method.args = list(family = binomial), colour = "firebrick", fill = "firebrick", alpha = 0.2) +
    facet_grid(group ~ covariate, scales = "free_x") +
    scale_size_area(max_size = 4, trans = "sqrt", name = "Fish in tow") +
    scale_y_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1)) +
    labs(x = NULL, y = "Proportion of tow catch",
         title = paste0("Lake ", lake_name, ": species proportions by tow (", n_distinct(d$OP_ID), " tows with catch)")) +
    theme_bw(base_size = 11) +
    theme(strip.background = element_rect(fill = "grey92"), legend.position = "bottom")
}
