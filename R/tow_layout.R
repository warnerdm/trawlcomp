# Where the acoustic-survey tows sit relative to each other: tows per lake-year-transect and the spread of
# their fishing depths, to judge how many tows could serve as pseudo-replicates (STATUS task 1).
# All tows are night tows of the lakewide acoustic surveys (user, 2026-10-14), so time is only checked.
source("D:/pyprojects/trawlcomp/R/select_tows.R")

# Logged time (hhmm) outside 20:00-06:00
off_night <- function(tows) filter(tows, !is.na(time) & time >= 600 & time < 2000)

# Tows per lake-year-transect, with the range of fishing and bottom depths
transect_summary <- function(tows) {
  tows %>%
    summarise(.by = c(lake, YEAR, transect),
              n_tows = n(),
              fd_min = min(fishing_depth, na.rm = TRUE), fd_max = max(fishing_depth, na.rm = TRUE),
              bd_min = min(bottom_depth, na.rm = TRUE), bd_max = max(bottom_depth, na.rm = TRUE)) %>%
    arrange(lake, YEAR, transect)
}

# For each tow, the number of OTHER tows in the same lake-year-transect whose fishing depth is within
# depth_tol m (Inf = any depth)
neighbours <- function(tows, depth_tol = Inf) {
  tows %>%
    mutate(.by = c(lake, YEAR, transect),
           n_neigh = map_int(fishing_depth, \(fd) sum(abs(fishing_depth - fd) <= depth_tol, na.rm = TRUE) - 1L))
}
