# Acoustic-survey tows: OP_TARGET.csv TARGET %in% c(209, 210) (user, 2026-10-14).
# Michigan: the bloaterTS per-year files (L_2_Y_<year>_Acoustic_optrop.csv); Huron: the USGS release
# (OP.csv, doi:10.5066/F75M63X0 ver. 3.0) with bloaterTS's filter (2004+, SAMPLE_TYPE 1, vessels 17/35/88).
# The release ends in 2018, so Michigan 2019+ tows have no TARGET to check; they are kept and flagged
# (target_checked = FALSE).
library(tidyverse)
source("D:/pyprojects/trawlcomp/R/paths.R")

ACOUSTIC_TARGETS <- c(209, 210)

read_trawl <- function(f, ...) {
  read_csv(file.path(TRAWL_DIR, f), show_col_types = FALSE, guess_max = 1e6, ...)
}

select_tows <- function() {
  acoustic_ops <- read_trawl("OP_TARGET.csv") %>%
    filter(TARGET %in% ACOUSTIC_TARGETS) %>%
    distinct(OP_ID) %>%
    pull(OP_ID)
  release_years <- 1958:2018

  mi <- list.files(TRAWL_DIR, pattern = "^L_2_Y_\\d{4}_Acoustic_optrop\\.csv$", full.names = TRUE) %>%
    map(\(f) read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c"))) %>%
    list_rbind() %>%
    transmute(OP_ID = as.integer(OP_ID), YEAR = as.integer(YEAR), VESSEL = as.integer(VESSEL),
              lake = "Michigan") %>%
    mutate(target_checked = YEAR %in% release_years) %>%
    filter(!target_checked | OP_ID %in% acoustic_ops)

  hu <- read_trawl("OP.csv", locale = locale(encoding = "latin1")) %>%
    filter(LAKE == 3 & YEAR >= 2004 & SAMPLE_TYPE == 1 & VESSEL %in% c(17, 35, 88) &
             OP_ID %in% acoustic_ops) %>%
    transmute(OP_ID = as.integer(OP_ID), YEAR = as.integer(YEAR), VESSEL = as.integer(VESSEL),
              lake = "Huron", target_checked = TRUE)

  tows <- bind_rows(mi, hu)
  stopifnot(!any(duplicated(tows$OP_ID)))
  tows
}
