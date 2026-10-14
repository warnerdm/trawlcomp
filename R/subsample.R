# Model-free check of the SE curves: subsample the tows of a lake-year-layer and see how much the estimate
# (mean of the tows' proportions, as in the SE curves) moves. Sampling k of the M tows without replacement;
# the SD across draws is scaled by 1 / sqrt((M - k) / (M - 1)) (finite population correction), giving the
# SE for k tows drawn from conditions like that year-layer's, comparable to the model's SE curve.
# The empirical SD includes the spread of areas and depths within the layer; the model curve does not.
source("D:/pyprojects/trawlcomp/R/effort.R")

subsample_se <- function(obs, k_max = NULL, n_draw = 2000, seed = 1) {
  set.seed(seed)
  M <- nrow(obs)
  ks <- seq_len(min(M - 1, if (is.null(k_max)) M - 1 else k_max))
  map(ks, \(k) {
    draws <- replicate(n_draw, colMeans(obs[sample.int(M, k), , drop = FALSE]))
    draws <- matrix(draws, nrow = ncol(obs))
    tibble(k = k, group = colnames(obs), sd_draw = apply(draws, 1, sd),
           se_k = sd_draw / sqrt((M - k) / (M - 1)))
  }) %>% list_rbind()
}

# Tow proportions per lake-year-layer (tows with catch), wide by group
year_layer_props <- function(catch) {
  catch %>%
    filter(n > 0 & !is.na(fishing_depth)) %>%
    add_layer() %>%
    mutate(across(c(alewife, smelt, bloater, other), \(x) x / n))
}

# Empirical SD of tow proportions in each lake-year-layer vs the model's median single-tow SD (sd_obs) for
# the same tows. ratio > 1: the model curve is optimistic for a whole layer.
empirical_vs_model <- function(props, tow_stats, min_tows = 5) {
  props %>%
    pivot_longer(c(alewife, smelt, bloater, other), names_to = "group", values_to = "p") %>%
    filter(!is.na(p)) %>%
    inner_join(select(tow_stats, OP_ID, group, sd_obs), by = c("OP_ID", "group")) %>%
    summarise(.by = c(lake, YEAR, layer, group), tows = n(), sd_emp = sd(p), sd_model = median(sd_obs)) %>%
    filter(tows >= min_tows) %>%
    mutate(ratio = sd_emp / sd_model)
}
