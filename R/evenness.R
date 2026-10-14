# Species evenness per tow, to find tows whose catch was mixed (user, 2026-10-14). Huron first.
# Pielou's J = H' / ln(S) with H' = -sum(p ln p) and S FIXED at the number of species in the set (not the number
# caught), so J measures mixing across the whole set and is comparable between tows. Shares by number and by
# weight (WEIGHT summed over life stages). Alewife contamination rule as tow_catch (fishing depth > 40 m -> 0).
source("D:/pyprojects/trawlcomp/R/tow_catch.R")

EVENNESS_SPECIES_HURON <- c(`106` = "alewife", `109` = "smelt", `202` = "cisco", `204` = "bloater",
                            `504` = "emerald_shiner")

# Pielou's J of a vector of amounts, with S = length(x). NA when the total is 0 or any amount is NA.
pielou_j <- function(x) {
  tot <- sum(x)
  if (is.na(tot) || tot <= 0) return(NA_real_)
  p <- x[x > 0] / tot
  -sum(p * log(p)) / log(length(x))
}

# One row per tow: n_<species> and w_<species> (number, weight), n, w (set totals), J_n, J_w, the largest
# share (maxp_n, maxp_w) and its species (dom_n, dom_w), and n_other (catch outside the set, by number).
# w_missing: TRUE when a set species was caught but has no WEIGHT; J_w, maxp_w and dom_w are NA there.
tow_evenness <- function(tows, species = EVENNESS_SPECIES_HURON) {
  sp <- unname(species)
  catch <- read_catch() %>%
    semi_join(tows, by = c("OP_ID", "lake"))
  other <- catch %>%
    filter(!as.character(SPECIES) %in% names(species)) %>%
    summarise(.by = OP_ID, n_other = sum(N, na.rm = TRUE))
  set <- catch %>%
    filter(as.character(SPECIES) %in% names(species)) %>%
    mutate(species = species[as.character(SPECIES)],
           W = if_else(N > 0 & is.na(WEIGHT), NA_real_, coalesce(WEIGHT, 0))) %>%
    summarise(.by = c(OP_ID, species), n = sum(N), w = sum(W))
  long <- tows %>%
    select(OP_ID, fishing_depth) %>%
    cross_join(tibble(species = factor(sp, levels = sp))) %>%
    left_join(mutate(set, species = factor(species, levels = sp)), by = c("OP_ID", "species")) %>%
    mutate(n = coalesce(n, 0), w = if_else(n == 0, coalesce(w, 0), w),
           contaminated = species == "alewife" & coalesce(fishing_depth > ALEWIFE_CONTAMINATION_DEPTH_M, FALSE),
           n = if_else(contaminated, 0, n), w = if_else(contaminated, 0, w))
  stats <- long %>%
    arrange(OP_ID, species) %>%
    summarise(.by = OP_ID,
              J_n = pielou_j(n), J_w = pielou_j(w),
              maxp_n = if (sum(n) > 0) max(n) / sum(n) else NA_real_,
              maxp_w = if (!anyNA(w) && sum(w) > 0) max(w) / sum(w) else NA_real_,
              dom_n = if (sum(n) > 0) as.character(species[which.max(n)]) else NA_character_,
              dom_w = if (!anyNA(w) && sum(w) > 0) as.character(species[which.max(w)]) else NA_character_,
              w_missing = anyNA(w), n_tot = sum(n), w_tot = sum(w))
  wide <- long %>%
    select(OP_ID, species, n, w) %>%
    pivot_wider(names_from = species, values_from = c(n, w))
  tows %>%
    left_join(wide, by = "OP_ID") %>%
    left_join(stats, by = "OP_ID") %>%
    left_join(other, by = "OP_ID") %>%
    mutate(n_other = coalesce(n_other, 0))
}
