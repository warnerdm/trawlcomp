# Acoustic-survey tows (user, 2026-10-14).
# Michigan: every tow in the bloaterTS per-year files (L_2_Y_<year>_Acoustic_optrop.csv) and only those;
#   the USGS release (OP.csv and associated files) is never used for Michigan.
# Huron: the USGS release (OP.csv, doi:10.5066/F75M63X0 ver. 3.0), OP_TARGET.csv TARGET %in% c(209, 210),
#   with bloaterTS's filter (2004+, SAMPLE_TYPE 1, vessels 17/35/88).
library(tidyverse)
source("D:/pyprojects/trawlcomp/R/paths.R")

ACOUSTIC_TARGETS <- c(209, 210)
MI_BAD_BOTTOM_DEPTH <- c(77542, 104167)

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
    tow_fields("Michigan") %>%
    # As bloaterTS (manuscript Rmd, R/bloater-cut-length.R): 2008 Steelhead (vessel 17) bottom depths are in
    # feet (checked against pydt4 bottom detection for 78103, 78105, 78110; fishing depths are metres);
    # 77542 (284 m at both ends) and 104167 (30.4 vs 333 m) have implausible bottom depths
    mutate(bottom_depth = if_else(YEAR == 2008 & VESSEL == 17, bottom_depth * 0.3048, bottom_depth),
           bottom_depth = if_else(OP_ID %in% MI_BAD_BOTTOM_DEPTH, NA_real_, bottom_depth))

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

# Lake bounding boxes (decimal degrees) for the coordinate check
LAKE_BOX <- tribble(
  ~lake,      ~lat_min, ~lat_max, ~lon_min, ~lon_max,
  "Michigan",     41.5,     46.2,    -88.1,    -84.7,
  "Huron",        43.0,     46.4,    -84.8,    -79.6
)

# Tows with missing start coordinates or coordinates outside their lake's box. Dropped for now (user,
# 2026-10-14); the bloaterTS tow lists hold the fixes for some of them.
bad_coordinates <- function(tows) {
  tows %>%
    left_join(LAKE_BOX, by = "lake") %>%
    filter(is.na(lat) | is.na(lon) | lat < lat_min | lat > lat_max | lon < lon_min | lon > lon_max) %>%
    select(all_of(names(tows)))
}

drop_bad_coordinates <- function(tows) anti_join(tows, bad_coordinates(tows), by = "OP_ID")
