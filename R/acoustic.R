# EchoNet2Fish Lake Michigan interval x layer output (intlaymeans_nph: numbers per ha), read only from
# D:/Acoustics/EchoNet2Fish_LM/MI<year>/. Layer depths are depth below the surface (user, 2026-10-15), the same
# axis as trawl fishing depth; depth_botmid is the interval's bottom depth (10 m bins).
# fish_ha NA or Inf (no usable single targets / no backscatter) are set to 0 (user, 2026-10-15).
source("D:/pyprojects/trawlcomp/R/stratum_stats.R")

EN2F_DIR <- "D:/Acoustics/EchoNet2Fish_LM"

read_intlay <- function(year) {
  f <- list.files(file.path(EN2F_DIR, paste0("MI", year)), pattern = "intlaymeans_nph.*[.]csv$", full.names = TRUE)
  stopifnot(length(f) == 1)
  read_csv(f, show_col_types = FALSE, guess_max = 1e5) %>%
    mutate(file = basename(f),
           fish_ha_raw = fish_ha,
           fish_ha = if_else(is.finite(fish_ha), fish_ha, 0),
           layer_mid = (Layer_depth_min + Layer_depth_max) / 2)
}

# Assign each interval x layer to the trawl strata by its 20 m cell (bottom depth x layer mid-depth).
# cells: cell (bd_bin_fd_bin), stratum_name. Rows in cells that are not in a stratum get "Outside strata".
assign_strata <- function(il, cells, cell_m = 20) {
  il %>%
    mutate(bd_bin = floor(depth_botmid / cell_m), fd_bin = floor(layer_mid / cell_m),
           cell = paste(bd_bin, fd_bin, sep = "_")) %>%
    left_join(distinct(cells, cell, stratum_name), by = "cell") %>%
    mutate(stratum_name = factor(coalesce(as.character(stratum_name), "Outside strata"),
                                 c(levels(cells$stratum_name), "Outside strata")))
}
