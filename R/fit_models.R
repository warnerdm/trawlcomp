# Between-tow variability of species proportions (STATUS task 4).
# One binomial GAM per lake and group (the group vs the rest of the tow's catch in the groups):
#   cbind(count, n - count) ~ s(fishing_depth) + s(bottom_depth) + s(lon, lat) + s(year, re) + s(tow, re)
# The tow random effect (logit scale) is the tow-to-tow variability left after the covariates and the year
# effect; with one row per tow it is a logit-normal (overdispersed) binomial. The year effect keeps
# between-year change out of the repeat-tow SD. The null model has only the year and tow effects.
# Separate binomials do not force the groups' proportions to sum to one; a multinomial is a later check.
source("D:/pyprojects/trawlcomp/R/tow_catch.R")
library(mgcv)

model_data <- function(catch) {
  catch %>%
    filter(n > 0 & !is.na(fishing_depth) & !is.na(bottom_depth) & !is.na(lat) & !is.na(lon)) %>%
    mutate(tow = factor(OP_ID), year = factor(YEAR))
}

lake_groups <- function(lake) if (lake == "Huron") c("alewife", "smelt", "bloater", "other") else c("alewife", "smelt", "bloater")

FULL_RHS <- "s(fishing_depth, k = 8) + s(bottom_depth, k = 8) + s(lon, lat, k = 30) + s(year, bs = 're') + s(tow, bs = 're')"
NULL_RHS <- "s(year, bs = 're') + s(tow, bs = 're')"

fit_group <- function(d, group, rhs) {
  d$y <- d[[group]]
  bam(as.formula(paste("cbind(y, n - y) ~", rhs)), family = binomial, data = d, method = "fREML", discrete = TRUE)
}

# Standard deviation of a random effect (logit scale) from gam.vcomp (bam with fREML)
re_sd <- function(m, term) {
  v <- gam.vcomp(m, rescale = FALSE)
  v <- if (is.list(v)) v$vc else v
  unname(v[term, "std.dev"])
}

# Per tow: mean proportion for a new tow with the same covariates in an average year (eta excludes the year
# and tow effects), and its SD across repeat tows. sd_patch: true proportion only (n -> infinity);
# sd_obs: observed proportion with this tow's n fish (patchiness + binomial sampling); q05_obs, q95_obs:
# its 90% interval (coverage check).
repeat_tow_stats <- function(m, d, group, sigma_tow, n_sim = 4000, seed = 1) {
  set.seed(seed)
  observed <- d[[group]] / d$n
  eta <- predict(m, d, type = "link", exclude = c("s(year)", "s(tow)"))
  u <- rnorm(n_sim, 0, sigma_tow)
  map2(eta, d$n, \(e, n) {
    p <- plogis(e + u)
    p_obs <- rbinom(n_sim, n, p) / n
    tibble(mean_p = mean(p), sd_patch = sd(p), sd_obs = sd(p_obs),
           sd_binom = sqrt(mean(p) * (1 - mean(p)) / n),
           q05_obs = quantile(p_obs, 0.05), q95_obs = quantile(p_obs, 0.95))
  }) %>%
    list_rbind() %>%
    mutate(OP_ID = d$OP_ID, lake = d$lake, group = group, n = d$n, observed_p = observed,
           .before = 1)
}

fit_lake <- function(catch, lake_name) {
  d <- model_data(filter(catch, lake == lake_name))
  map(lake_groups(lake_name), \(g) {
    full <- fit_group(d, g, FULL_RHS)
    null <- fit_group(d, g, NULL_RHS)
    s <- summary(full)
    sig <- re_sd(full, "s(tow)")
    list(
      summary = tibble(lake = lake_name, group = g, tows = nrow(d),
                       sd_tow_null = re_sd(null, "s(tow)"), sd_tow_full = sig,
                       sd_year_full = re_sd(full, "s(year)"),
                       p_fishing_depth = s$s.table["s(fishing_depth)", "p-value"],
                       p_bottom_depth = s$s.table["s(bottom_depth)", "p-value"],
                       p_lonlat = s$s.table["s(lon,lat)", "p-value"],
                       edf_fishing_depth = s$s.table["s(fishing_depth)", "edf"],
                       edf_bottom_depth = s$s.table["s(bottom_depth)", "edf"],
                       edf_lonlat = s$s.table["s(lon,lat)", "edf"]),
      tows = repeat_tow_stats(full, d, g, sig),
      model = full)
  })
}
