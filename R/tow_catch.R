# Catch per tow by species group. N is summed over life stages (user, 2026-10-14).
# Michigan catch from the L_2_Y_<year>_Acoustic_tr_catch.csv files only; Huron from the USGS release TR_CATCH.csv.
source("D:/pyprojects/trawlcomp/R/select_tows.R")

SPECIES_GROUPS <- c(`106` = "alewife", `109` = "smelt", `204` = "bloater")

# Alewife caught in tows fishing deeper than this are contamination (caught while the net passes through the
# upper water column; bottom tows at the same spots at night catch none) and are set to 0 (user, 2026-10-14).
ALEWIFE_CONTAMINATION_DEPTH_M <- 40

# Depth layers: fishing depth < 35 m (shallow) and >= 35 m (deep) (user, 2026-10-14)
LAYER_BREAK_M <- 35

add_layer <- function(d) {
  mutate(d, layer = factor(if_else(fishing_depth < LAYER_BREAK_M, paste0("< ", LAYER_BREAK_M, " m"),
                                   paste0(">= ", LAYER_BREAK_M, " m")),
                           paste0(c("< ", ">= "), LAYER_BREAK_M, " m")))
}


read_catch <- function() {
  mi <- list.files(TRAWL_DIR, pattern = "^L_2_Y_[0-9]{4}_Acoustic_tr_catch[.]csv$", full.names = TRUE) %>%
    map(\(f) read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c"))) %>%
    list_rbind() %>%
    mutate(lake = "Michigan")
  hu <- read_trawl("TR_CATCH.csv", col_types = cols(.default = "c")) %>%
    mutate(lake = "Huron")
  bind_rows(mi, hu) %>%
    transmute(OP_ID = as.integer(OP_ID), lake, SPECIES = as.integer(SPECIES), N = as.numeric(N),
              WEIGHT = as.numeric(WEIGHT))
}

# One row per tow in `tows`, with counts alewife, smelt, bloater, other and n (total). Tows with no catch
# rows get zeros. The catch is matched on OP_ID and lake, so each lake uses its own source.
# Michigan has no "other" group (user, 2026-10-14): the L_2_Y files hold only a few species, so other = NA
# and n = alewife + smelt + bloater there. alewife_removed: alewife set to 0 as contamination.
# measure = "N" (numbers) or "WEIGHT" (catch weight; a WEIGHT that is missing, or 0 with fish counted, makes
# that group's total NA, so the tow's n is NA and it drops out of weight-based proportions).
tow_catch <- function(tows, measure = c("N", "WEIGHT")) {
  measure <- match.arg(measure)
  counts <- read_catch() %>%
    semi_join(tows, by = c("OP_ID", "lake")) %>%
    mutate(group = coalesce(SPECIES_GROUPS[as.character(SPECIES)], "other"),
           WEIGHT = if_else(WEIGHT == 0 & N > 0, NA_real_, WEIGHT),
           value = .data[[measure]]) %>%
    summarise(.by = c(OP_ID, group), N = sum(value)) %>%
    pivot_wider(names_from = group, values_from = N, values_fill = 0)
  for (g in setdiff(c("alewife", "smelt", "bloater", "other"), names(counts))) counts[[g]] <- 0
  tows %>%
    left_join(counts, by = "OP_ID") %>%
    # no catch rows -> 0; NA from a missing weight is kept
    mutate(across(c(alewife, smelt, bloater, other), \(x) if_else(OP_ID %in% counts$OP_ID, x, 0)),
           contaminated = coalesce(fishing_depth > ALEWIFE_CONTAMINATION_DEPTH_M, FALSE),
           alewife_removed = if_else(contaminated, alewife, 0),
           alewife = if_else(contaminated, 0, alewife),
           other = if_else(lake == "Michigan", NA_real_, other),
           n = alewife + smelt + bloater + coalesce(other, 0)) %>%
    select(-contaminated)
}
