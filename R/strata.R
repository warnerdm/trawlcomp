# Depth strata for trawl tows following Adams et al. (2006, NAJFM 26:612-621), "depth stratification":
#  1. grid the water column by bottom depth x fishing depth (cell_m x cell_m cells);
#  2. describe each cell by the mean and SD (across its tows, years pooled) of each group's per-tow proportion;
#     cells with < 2 tows are left out;
#  3. neighbour-restricted complete-linkage clustering of the cells (Euclidean distance on the means and SDs);
#     only cells sharing an edge on the grid can join (adespatial::constr.hclust);
#  4. cut at 2-5 strata; Neyman allocation p_di = W_d s_di / sum_d W_d s_di, averaged over groups.
# W_d: the paper used each stratum's share of acoustic biomass. Without it, W_d here is the stratum's share of
# grid cells (each cell an equal share of the sample space, as the paper assumed for the grid).
source("D:/pyprojects/trawlcomp/R/tow_catch.R")
library(adespatial)

STRATA_GROUPS <- c("alewife", "smelt", "bloater")

# Per-tow proportions with grid cell indices
tow_cells <- function(catch, cell_m = 20, groups = STRATA_GROUPS) {
  catch %>%
    filter(!is.na(n) & n > 0 & !is.na(fishing_depth) & !is.na(bottom_depth)) %>%
    mutate(across(all_of(groups), \(x) x / n),
           bd_bin = floor(bottom_depth / cell_m), fd_bin = floor(fishing_depth / cell_m),
           cell = paste(bd_bin, fd_bin, sep = "_"))
}

# One row per cell with >= min_tows tows: tows, mean_<group>, sd_<group>
cell_stats <- function(tc, groups = STRATA_GROUPS, min_tows = 2) {
  tc %>%
    summarise(.by = c(cell, bd_bin, fd_bin), tows = n(),
              across(all_of(groups), list(mean = mean, sd = sd), .names = "{.fn}_{.col}")) %>%
    filter(tows >= min_tows) %>%
    arrange(bd_bin, fd_bin)
}

# Edges between cells that share a side on the grid (rook neighbours)
cell_links <- function(cs) {
  idx <- seq_len(nrow(cs))
  e <- expand_grid(i = idx, j = idx) %>%
    filter(i < j, abs(cs$bd_bin[i] - cs$bd_bin[j]) + abs(cs$fd_bin[i] - cs$fd_bin[j]) == 1)
  as.matrix(e)
}

# Connected components of the neighbour graph (cells in different components can never join)
components <- function(n, links) {
  comp <- seq_len(n)
  repeat {
    changed <- FALSE
    for (r in seq_len(nrow(links))) {
      a <- links[r, 1]; b <- links[r, 2]
      m <- min(comp[a], comp[b])
      if (comp[a] != m || comp[b] != m) { comp[comp == comp[a] | comp == comp[b]] <- m; changed <- TRUE }
    }
    if (!changed) break
  }
  as.integer(factor(comp))
}

# Keep the largest connected block of cells; cells that touch none of it can never join a stratum (the
# paper likewise left sparse parts of the water column out). Returns the kept cells and the excluded ones.
main_block <- function(cs) {
  comp <- components(nrow(cs), cell_links(cs))
  big <- as.integer(names(which.max(table(comp))))
  list(cells = cs[comp == big, ], excluded = cs[comp != big, ])
}

# Neighbour-restricted complete-linkage clustering of the cells (one connected block)
cluster_cells <- function(cs, groups = STRATA_GROUPS) {
  feat <- as.matrix(cs[c(paste0("mean_", groups), paste0("sd_", groups))])
  links <- cell_links(cs)
  stopifnot(max(components(nrow(cs), links)) == 1)
  constr.hclust(dist(feat), method = "complete", links = links, coords = as.matrix(cs[c("bd_bin", "fd_bin")]))
}

# Map of the cells coloured by stratum (bottom depth across, fishing depth down), tows per cell as labels
plot_strata <- function(cs, stratum, cell_m, title) {
  d <- mutate(cs, stratum = factor(stratum), x = (bd_bin + 0.5) * cell_m, y = (fd_bin + 0.5) * cell_m)
  ggplot(d, aes(x, y)) +
    geom_tile(aes(fill = stratum), width = cell_m, height = cell_m, colour = "white") +
    geom_text(aes(label = tows), size = 2.8) +
    scale_y_reverse() +
    scale_fill_brewer(palette = "Set2") +
    labs(x = "Bottom depth (m)", y = "Fishing depth (m)", fill = "Stratum", title = title) +
    coord_cartesian(expand = FALSE) +
    theme_bw(base_size = 10)
}

# Stratum summary (like Adams Table 4): tows, cells, mean (SD) proportion over the stratum's tows, and
# proportional and Neyman allocation (W_d = share of cells)
stratum_summary <- function(tc, cs, stratum, cell_m, groups = STRATA_GROUPS) {
  cell_stratum <- tibble(cell = cs$cell, stratum = stratum)
  s <- tc %>%
    inner_join(cell_stratum, by = "cell") %>%
    summarise(.by = stratum, tows = n(), cells = n_distinct(cell),
              bottom_m = paste(min(bd_bin) * cell_m, (max(bd_bin) + 1) * cell_m, sep = "-"),
              fishing_m = paste(min(fd_bin) * cell_m, (max(fd_bin) + 1) * cell_m, sep = "-"),
              across(all_of(groups), list(mean = mean, sd = sd), .names = "{.fn}_{.col}")) %>%
    arrange(stratum) %>%
    mutate(W = cells / sum(cells), proportional = W)
  ney <- map(groups, \(g) { ws <- s$W * s[[paste0("sd_", g)]]; ws / sum(ws) })
  s$optimal <- Reduce(`+`, ney) / length(groups)
  s
}
