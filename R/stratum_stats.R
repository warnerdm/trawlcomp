# Mean proportion, SD and SE of each species' tow proportion within depth strata (design-based framework).
# Strata: Adams et al. (2006) clustering of Lake Michigan cells (strata.R), here k = 4 from tows with >= 10 fish
# and cells with >= 5 tows (user, 2026-10-15). The strata are defined once, by number, and used for both
# number and weight proportions.
# Per stratum and species:
#   mean_p     mean of the tow proportions (every tow equal, as Adams et al.)
#   ratio_p    catch-weighted proportion, sum(count) / sum(n)
#   sd_all     SD of the tow proportions over all tows (years pooled; includes between-year change)
#   sd_within  pooled within-year SD: deviations from each year's stratum mean, df = tows - years
#              (years with one tow add no df); the "repeat the tow here" SD within a survey
#   se_now     sd_within / sqrt(median tows per year): SE of a year's stratum mean at current effort
#   Ratio (catch-weighted) estimator, tows as the sampling unit (Cochran 1977, ratio estimator): residuals
#   e_i = count_i - R n_i; SE(R) for m tows = sd(e) / (nbar sqrt(m)), nbar = mean catch per tow. On one year's
#   m tows this is sqrt(sum n_i^2 (p_i - R)^2 / (m (m - 1) nbar^2)).
#   sd_ratio_within  pooled within-year sd(e) / nbar (R and its residuals per year; df = tows - years)
#   sd_ratio_all     sd(e) / nbar over all tows with the all-years R
#   se_ratio_now     sd_ratio_within / sqrt(median tows per year)
# Combined (W_h = stratum share of cells, each cell an equal share of the sample space):
#   p_st = sum W_h mean_p_h, se_st = sqrt(sum W_h^2 sd_within_h^2 / m_h) with m_h = median tows per year.
source("D:/pyprojects/trawlcomp/R/strata.R")

# Tow -> stratum for Lake Michigan (k strata), with descriptive names
michigan_strata <- function(tows, k = 4, cell_m = 20, min_fish = 10, min_tows = 5) {
  catch <- tow_catch(tows, "N") %>% mutate(n_fish = n)
  tc <- tow_cells(catch, cell_m = cell_m, min_fish = min_fish)
  cs <- main_block(cell_stats(tc, min_tows = min_tows))$cells
  st <- cutree(cluster_cells(cs), k = k)
  cell_st <- tibble(cell = cs$cell, stratum = st)
  tc %>%
    inner_join(cell_st, by = "cell") %>%
    mutate(.by = stratum, s_bloater = mean(bloater), s_bd = mean(bottom_depth), s_fd = mean(fishing_depth),
           cells = n_distinct(cell)) %>%
    select(OP_ID, cell, stratum, s_bloater, s_bd, s_fd, cells)
}

# Names for the 4 strata: deep = most bloater; surface offshore = deepest bottom of the rest; midwater
# nearshore = deepest fishing of the remaining two; the last = surface nearshore
name_strata <- function(ts) {
  s <- distinct(ts, stratum, s_bloater, s_bd, s_fd, cells)
  deep <- s$stratum[which.max(s$s_bloater)]
  r <- filter(s, stratum != deep)
  off <- r$stratum[which.max(r$s_bd)]
  r <- filter(r, stratum != off)
  mid <- r$stratum[which.max(r$s_fd)]
  near <- setdiff(r$stratum, mid)
  lv <- c("Surface nearshore", "Midwater nearshore", "Surface offshore", "Deep")
  key <- setNames(lv, c(near, mid, off, deep))
  mutate(ts, stratum_name = factor(key[as.character(stratum)], lv))
}

# Per stratum x group statistics for one measure
stratum_stats <- function(props, groups = STRATA_GROUPS) {
  props %>%
    pivot_longer(all_of(groups), names_to = "group", values_to = "count") %>%
    mutate(p = count / n) %>%
    group_by(stratum_name, group) %>%
    summarise(tows = n(), years = n_distinct(YEAR),
              tows_per_year = median(table(YEAR)),
              mean_p = mean(p), ratio_p = sum(count) / sum(n), sd_all = sd(p),
              ss_within = sum((p - ave(p, YEAR))^2), df_within = tows - years,
              nbar = mean(n),
              ss_ratio_within = sum((count - n * ave(count, YEAR, FUN = sum) / ave(n, YEAR, FUN = sum))^2),
              sd_ratio_all = sd(count - n * ratio_p) / nbar,
              cells = first(cells), .groups = "drop") %>%
    mutate(sd_within = sqrt(ss_within / df_within),
           se_now = sd_within / sqrt(tows_per_year),
           se_now_all = sd_all / sqrt(tows_per_year),
           sd_ratio_within = sqrt(ss_ratio_within / df_within) / nbar,
           se_ratio_now = sd_ratio_within / sqrt(tows_per_year)) %>%
    select(-ss_within, -ss_ratio_within)
}

# Combined (stratified) proportion and SE per group, W_h = share of cells
combined_stats <- function(ss) {
  ss %>%
    mutate(W = cells / sum(cells[!duplicated(stratum_name)]), .by = group) %>%
    summarise(.by = group, p_st = sum(W * mean_p),
              se_st = sqrt(sum(W^2 * sd_within^2 / tows_per_year)),
              se_st_all = sqrt(sum(W^2 * sd_all^2 / tows_per_year)))
}

# Diagonal hatch segments (both directions) clipped to a rectangle; c_grid shared by all cells so the hatching
# runs continuously across neighbouring cells of a stratum
hatch_cell <- function(x0, x1, y0, y1, spacing) {
  cs <- seq(-400, 400, by = spacing)
  up <- tibble(c = cs, xa = pmax(x0, y0 + c), xb = pmin(x1, y1 + c)) %>%
    filter(xa < xb) %>% transmute(x = xa, y = xa - c, xend = xb, yend = xb - c)
  dn <- tibble(c = cs, xa = pmax(x0, c - y1), xb = pmin(x1, c - y0)) %>%
    filter(xa < xb) %>% transmute(x = xa, y = c - xa, xend = xb, yend = c - xb)
  bind_rows(up, dn)
}

# Adams et al. (2006) Figure 4 style: strata in the water column (bottom depth x depth), crosshatching denser
# where composition is more variable (mean over species of the SD of tow proportions), stratum outlines,
# lakebed shaded. cells: cell, bd_bin, fd_bin, stratum_name; msd: stratum_name, mean_sd.
plot_strata_adams <- function(cells, msd, cell_m = 20, title = NULL) {
  d <- cells %>% left_join(msd, by = "stratum_name") %>%
    mutate(x0 = bd_bin * cell_m, x1 = x0 + cell_m, y0 = fd_bin * cell_m, y1 = y0 + cell_m)
  # spacing ~ 1 / SD^2 for contrast; none where spacing would exceed a cell (SD < ~0.16)
  hatch <- pmap(d, \(x0, x1, y0, y1, mean_sd, ...) {
    sp <- 0.5 / mean_sd^2
    if (sp > cell_m) NULL else hatch_cell(x0, x1, y0, y1, sp)
  }) %>% list_rbind()
  key <- paste(d$bd_bin, d$fd_bin)
  st_of <- setNames(as.character(d$stratum_name), key)
  edge <- function(dx, dy) as.character(st_of[paste(d$bd_bin + dx, d$fd_bin + dy)])
  edges <- bind_rows(
    d %>% mutate(nb = edge(-1, 0)) %>% filter(is.na(nb) | nb != stratum_name) %>% transmute(x = x0, y = y0, xend = x0, yend = y1),
    d %>% mutate(nb = edge(1, 0)) %>% filter(is.na(nb) | nb != stratum_name) %>% transmute(x = x1, y = y0, xend = x1, yend = y1),
    d %>% mutate(nb = edge(0, -1)) %>% filter(is.na(nb) | nb != stratum_name) %>% transmute(x = x0, y = y0, xend = x1, yend = y0),
    d %>% mutate(nb = edge(0, 1)) %>% filter(is.na(nb) | nb != stratum_name) %>% transmute(x = x0, y = y1, xend = x1, yend = y1))
  labs_df <- d %>% summarise(.by = c(stratum_name, mean_sd), x = mean((x0 + x1) / 2), y = mean((y0 + y1) / 2)) %>%
    mutate(label = paste0(stratum_name, "\nmean SD ", sprintf("%.2f", mean_sd)))
  xmax <- max(d$x1); ymax <- max(d$y1)
  bed <- tibble(x = c(0, ymax, xmax, xmax, 0), y = c(0, ymax, ymax, ymax, ymax))
  ggplot() +
    geom_segment(data = hatch, aes(x, y, xend = xend, yend = yend), linewidth = 0.25, colour = "grey25") +
    geom_polygon(data = tibble(x = c(0, ymax, 0), y = c(0, ymax, ymax)), aes(x, y), fill = "grey80") +
    geom_segment(data = edges, aes(x, y, xend = xend, yend = yend), linewidth = 0.9) +
    geom_abline(slope = 1, intercept = 0, colour = "grey40") +
    geom_label(data = labs_df, aes(x, y, label = label), size = 3, linewidth = 0, fill = alpha("white", 0.85),
               lineheight = 0.9) +
    scale_y_reverse(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) +
    coord_cartesian(xlim = c(0, xmax), ylim = c(ymax, 0)) +
    labs(x = "Bottom depth (m)", y = "Fishing depth (m)", title = title,
         caption = "Denser crosshatching = more variable catch composition (mean SD of tow proportions of alewife, smelt, bloater).\nGrey = below the lakebed. Outside the outlines: too few tows (< 5 tows with >= 10 fish per 20 m cell).") +
    theme_bw(base_size = 11) + theme(panel.grid = element_blank(), plot.caption = element_text(hjust = 0))
}
