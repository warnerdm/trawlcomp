# Acoustic-survey tows (user, 2026-10-14).
# Michigan: every tow in the bloaterTS per-year files (L_2_Y_<year>_Acoustic_optrop.csv) and only those;
#   the USGS release (OP.csv and associated files) is never used for Michigan.
# Huron: the USGS release (OP.csv, doi:10.5066/F75M63X0 ver. 3.0), OP_TARGET.csv TARGET %in% c(209, 210),
#   with bloaterTS's filter (2004+, SAMPLE_TYPE 1, vessels 17/35/88).
library(tidyverse)
source("D:/pyprojects/trawlcomp/R/paths.R")

ACOUSTIC_TARGETS <- c(209, 210)

read_trawl <- function(f, ...) {
  read_csv(file.path(TRAWL_DIR, f), show_col_types = FALSE, guess_max = 1e6, ...)
}

# One row per tow: OP_ID, lake, YEAR, VESSEL, transect, time (hhmm, as logged), bottom_depth (mean of
# BEG_DEPTH and END_DEPTH, m), fishing_depth (FISHING_DEPTH, m), lat, lon (tow start, decimal degrees).
tow_fields <- function(d, lake) {
  num <- \(x) suppressWarnings(as.numeric(x))
  transmute(d, OP_ID = as.integer(OP_ID), lake = lake, YEAR = as.integer(YEAR), VESSEL = as.integer(VESSEL),
            transect = str_trim(as.character(TRANSECT)), time = as.integer(TIME),
            bottom_depth = rowMeans(cbind(num(BEG_DEPTH), num(END_DEPTH)), na.rm = TRUE),
            fishing_depth = num(FISHING_DEPTH),
            lat = num(BEG_LATITUDE_DD), lon = num(BEG_LONGITUDE_DD))
}

select_tows <- function() {
  mi <- list.files(TRAWL_DIR, pattern = "^L_2_Y_\\d{4}_Acoustic_optrop\\.csv$", full.names = TRUE) %>%
    map(\(f) read_csv(f, show_col_types = FALSE, col_types = cols(.default = "c"))) %>%
    list_rbind() %>%
    tow_fields("Michigan")

  acoustic_ops <- read_trawl("OP_TARGET.csv") %>%
    filter(TARGET %in% ACOUSTIC_TARGETS) %>%
    distinct(OP_ID) %>%
    pull(OP_ID)
  hu <- read_trawl("OP.csv", locale = locale(encoding = "latin1"), col_types = cols(.default = "c")) %>%
    filter(LAKE == "3" & as.integer(YEAR) >= 2004 & SAMPLE_TYPE == "1" & VESSEL %in% c("17", "35", "88") &
             as.integer(OP_ID) %in% acoustic_ops) %>%
    left_join(read_trawl("TR_OP.csv", col_types = cols(.default = "c")) %>% select(OP_ID, FISHING_DEPTH),
              by = "OP_ID") %>%
    tow_fields("Huron")

  tows <- bind_rows(mi, hu)
  stopifnot(!any(duplicated(tows$OP_ID)))
  tows
}
