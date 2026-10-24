# Mean proportion, SD and SE of each species' tow proportion within depth strata (design-based framework).
# Strata: Adams et al. (2006) clustering of Lake Michigan cells (strata.R), here k = 5 from tows with >= 5 fish
# and cells with >= 5 tows (user, 2026-10-15; earlier k = 4 with >= 10 fish). The strata are defined once, by number, and used for both
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

# Strata settings per lake (user, 2026-10-15): Michigan 5 strata, Huron 5 strata; both from tows with >= 5 fish
# and cells with >= 5 tows. Huron clusters on alewife, smelt, bloater and other.
MI_STRATA_K <- 5
MI_STRATA_MIN_FISH <- 5
MI_STRATA_MIN_TOWS <- 5
LAKE_STRATA <- list(
  Michigan = list(k = 5, min_fish = 5, min_tows = 5, groups = STRATA_GROUPS),
  Huron    = list(k = 5, min_fish = 5, min_tows = 5, groups = c(STRATA_GROUPS, "other"))
)

# Tow -> stratum for one lake's tows (k strata)
lake_strata <- function(tows, lake, cell_m = 20) {
  cfg <- LAKE_STRATA[[lake]]
  catch <- tow_catch(filter(tows, lake == !!lake), "N") %>% mutate(n_fish = n)
  tc <- tow_cells(catch, cell_m = cell_m, groups = cfg$groups, min_fish = cfg$min_fish)
  cs <- main_block(cell_stats(tc, groups = cfg$groups, min_tows = cfg$min_tows))$cells
  st <- cutree(cluster_cells(cs, groups = cfg$groups), k = cfg$k)
  cell_st <- tibble(cell = cs$cell, stratum = st)
  tc %>%
    inner_join(cell_st, by = "cell") %>%
    mutate(.by = stratum, s_bloater = mean(bloater), s_bd = mean(bottom_depth), s_fd = mean(fishing_depth),
           cells = n_distinct(cell)) %>%
    select(OP_ID, cell, stratum, s_bloater, s_bd, s_fd, cells)
}

michigan_strata <- function(tows, cell_m = 20) lake_strata(tows, "Michigan", cell_m)

# Names from each stratum's cell ranges, e.g. "Fishing 0-40 m, bottom 0-40 m" (used for Huron), ordered by
# fishing then bottom depth
range_names <- function(ts, cell_m = 20) {
  r <- ts %>% distinct(stratum, cell) %>%
    separate(cell, c("bd", "fd"), sep = "_", convert = TRUE) %>%
    summarise(.by = stratum, fd0 = min(fd) * cell_m, fd1 = (max(fd) + 1) * cell_m,
              bd0 = min(bd) * cell_m, bd1 = (max(bd) + 1) * cell_m) %>%
    arrange(fd0, fd1, bd0) %>%
    mutate(name = paste0("Fishing ", fd0, "-", fd1, " m, bottom ", bd0, "-", bd1, " m"))
  key <- setNames(r$name, r$stratum)
  mutate(ts, stratum_name = factor(key[as.character(stratum)], r$name))
}

# Named strata for a lake: Michigan descriptive names, others range names
named_strata <- function(tows, lake) {
  ts <- lake_strata(tows, lake)
  if (lake == "Michigan") name_strata(ts) else range_names(ts)
}

# Names: deep = most bloater; then, among the rest by mean bottom depth, the deepest = surface offshore and
# (k = 5) the next = surface mid-lake; of the last two, the deeper fishing = midwater nearshore, the other =
# surface nearshore
STRATUM_LEVELS <- c("Surface nearshore", "Midwater nearshore", "Surface mid-lake", "Surface offshore", "Deep")

name_strata <- function(ts) {
  s <- distinct(ts, stratum, s_bloater, s_bd, s_fd, cells)
  key <- c()
  deep <- s$stratum[which.max(s$s_bloater)]; key[as.character(deep)] <- "Deep"
  r <- filter(s, stratum != deep) %>% arrange(desc(s_bd))
  key[as.character(r$stratum[1])] <- "Surface offshore"
  r <- r[-1, ]
  if (nrow(r) == 3) { key[as.character(r$stratum[1])] <- "Surface mid-lake"; r <- r[-1, ] }
  stopifnot(nrow(r) == 2)
  r <- arrange(r, desc(s_fd))
  key[as.character(r$stratum[1])] <- "Midwater nearshore"
  key[as.character(r$stratum[2])] <- "Surface nearshore"
  lv <- intersect(STRATUM_LEVELS, key)
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
  edges <- strata_edges(d)
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
         caption = paste0("Denser crosshatching = more variable catch composition (mean SD of tow proportions over the species groups).\nGrey = below the lakebed. Outside the outlines: too few tows (< ", MI_STRATA_MIN_TOWS, " tows with >= ", MI_STRATA_MIN_FISH, " fish per 20 m cell).")) +
    theme_bw(base_size = 11) + theme(panel.grid = element_blank(), plot.caption = element_text(hjust = 0))
}

# Outline segments between cells of different strata (or no stratum). d: bd_bin, fd_bin, stratum_name, x0, x1, y0, y1
strata_edges <- function(d) {
  st_of <- setNames(as.character(d$stratum_name), paste(d$bd_bin, d$fd_bin))
  edge <- function(dx, dy) as.character(st_of[paste(d$bd_bin + dx, d$fd_bin + dy)])
  bind_rows(
    d %>% mutate(nb = edge(-1, 0)) %>% filter(is.na(nb) | nb != stratum_name) %>% transmute(x = x0, y = y0, xend = x0, yend = y1),
    d %>% mutate(nb = edge(1, 0)) %>% filter(is.na(nb) | nb != stratum_name) %>% transmute(x = x1, y = y0, xend = x1, yend = y1),
    d %>% mutate(nb = edge(0, -1)) %>% filter(is.na(nb) | nb != stratum_name) %>% transmute(x = x0, y = y0, xend = x1, yend = y0),
    d %>% mutate(nb = edge(0, 1)) %>% filter(is.na(nb) | nb != stratum_name) %>% transmute(x = x0, y = y1, xend = x1, yend = y1))
}

# Every tow with fish as a point (bottom depth x fishing depth, slight jitter), coloured by stratum or by why
# it was left out, with the stratum outlines. pts: bottom_depth, fishing_depth, status (factor).
plot_tows_strata <- function(pts, cells, cell_m = 20, title = NULL) {
  d <- cells %>% mutate(x0 = bd_bin * cell_m, x1 = x0 + cell_m, y0 = fd_bin * cell_m, y1 = y0 + cell_m)
  ymax <- max(d$y1, pts$fishing_depth, na.rm = TRUE)
  ymax <- ceiling(ymax / cell_m) * cell_m + 2   # room for tows at the last grid line
  xmax <- ceiling(max(pts$bottom_depth, na.rm = TRUE) / cell_m) * cell_m
  few <- paste("<", MI_STRATA_MIN_FISH, "fish"); thin <- paste("Cell <", MI_STRATA_MIN_TOWS, "tows")
  strata_lv <- setdiff(levels(pts$status), c(thin, few))
  cols <- c(setNames(c("#1b9e77", "#d95f02", "#66a61e", "#7570b3", "#e7298a", "#e6ab02", "#a6761d")[seq_along(strata_lv)],
                     strata_lv), setNames(c("grey20", "grey60"), c(thin, few)))
  shp <- c(setNames(rep(16, length(strata_lv)), strata_lv), setNames(c(4, 1), c(thin, few)))
  ggplot(pts, aes(bottom_depth, fishing_depth)) +
    geom_polygon(data = tibble(x = c(0, ymax, 0), y = c(0, ymax, ymax)), aes(x, y), fill = "grey88") +
    geom_vline(xintercept = seq(0, xmax, cell_m), colour = "grey92", linewidth = 0.3) +
    geom_hline(yintercept = seq(0, ymax, cell_m), colour = "grey92", linewidth = 0.3) +
    geom_jitter(aes(colour = status, shape = status), width = 1, height = 0.5, size = 1.4, alpha = 0.75) +
    geom_segment(data = strata_edges(d), aes(x, y, xend = xend, yend = yend), linewidth = 0.8) +
    scale_colour_manual(values = cols, name = NULL, drop = FALSE) +
    scale_shape_manual(values = shp, name = NULL, drop = FALSE) +
    scale_y_reverse(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0), breaks = seq(0, xmax, 40)) +
    coord_cartesian(xlim = c(0, xmax), ylim = c(ymax, 0)) +
    labs(x = "Bottom depth (m)", y = "Fishing depth (m)", title = title,
         caption = "Points jittered slightly (1 m across, 0.5 m down). Thin grid = 20 m cells; thick lines = strata. Grey = below the lakebed.") +
    theme_bw(base_size = 11) + theme(panel.grid = element_blank(), legend.position = "bottom",
                                     plot.caption = element_text(hjust = 0))
}

# Survey region from the transect name: its leading letters (Michigan nn, no, wn, so, sn as EchoNet2Fish).
# The later northern splits (nne, nnw from 2016; nnlu, 2 tows in 2011) are merged into nn so the regions are
# the same in all years (2026-10-24). Huron sg (Saginaw Bay mouth, 2 tows on one night in 2018) is pooled into mw
# (main basin west) (user, 2026-10-24).
tow_region <- function(transect) {
  r <- str_extract(tolower(transect), "^[a-z]+")
  case_when(r %in% c("nne", "nnw", "nnlu") ~ "nn", r == "sg" ~ "mw", TRUE ~ r)
}

# Region effect on tow proportions within each stratum x group: one-way ANOVA p; region share of variance
# (one-way random-effects variance component, unbalanced n0); SD of tow proportions pooled within regions vs
# over all tows; p for region after year (anova of p ~ year + region); region means.
region_effects <- function(props, groups) {
  props %>%
    pivot_longer(all_of(groups), names_to = "group", values_to = "count") %>%
    mutate(p = count / n) %>%
    group_by(stratum_name, group) %>%
    group_modify(\(d, k) {
      g <- n_distinct(d$region)
      if (sd(d$p) == 0 || g < 2) return(tibble(tows = nrow(d), regions = g))
      a <- anova(lm(p ~ factor(region), d))
      ni <- table(d$region); N <- sum(ni); n0 <- (N - sum(ni^2) / N) / (g - 1)
      msb <- a$`Mean Sq`[1]; msw <- a$`Mean Sq`[2]
      s2b <- max(0, (msb - msw) / n0)
      a2 <- anova(lm(p ~ factor(YEAR) + factor(region), d))
      means <- d %>% summarise(.by = region, m = mean(p), n = n()) %>% arrange(region)
      tibble(tows = N, regions = g, p_region = a$`Pr(>F)`[1], region_share = s2b / (s2b + msw),
             sd_all = sd(d$p), sd_within_region = sqrt(msw), p_region_after_year = a2$`Pr(>F)`[2],
             region_means = paste0(means$region, " ", sprintf("%.2f", means$m), " (", means$n, ")", collapse = ", "))
    }) %>%
    ungroup()
}

# Region x depth strata. Per depth stratum x region x group: tows, years with tows, tows per year (median over
# years with tows), mean proportion, SD over all tows, SE at that effort. small = fewer than min_tows tows.
region_depth_stats <- function(props, groups, min_tows = 5) {
  props %>%
    pivot_longer(all_of(groups), names_to = "group", values_to = "count") %>%
    mutate(p = count / n) %>%
    summarise(.by = c(stratum_name, region, group), tows = n(), years = n_distinct(YEAR),
              tows_per_year = median(table(YEAR)), mean_p = mean(p), sd_all = if (n() > 1) sd(p) else NA_real_) %>%
    mutate(se_now = sd_all / sqrt(tows_per_year), small = tows < min_tows) %>%
    arrange(stratum_name, group, region)
}

# Gain from splitting each depth stratum by region, at the same total number of tows (proportional allocation,
# W_r = region's share of the stratum's tows): variance ratio = sum_r W_r s_r^2 / s^2 (< 1 = splitting helps;
# Cochran 1977). Regions with < 2 tows contribute no SD and are left out of the sum (their weight dropped).
region_split_gain <- function(rd, ss) {
  rd %>%
    filter(!is.na(sd_all)) %>%
    mutate(.by = c(stratum_name, group), W = tows / sum(tows)) %>%
    summarise(.by = c(stratum_name, group), regions = n(), sd_within_regions = sqrt(sum(W * sd_all^2))) %>%
    left_join(select(ss, stratum_name, group, sd_pooled = sd_all, tows_per_year), by = c("stratum_name", "group")) %>%
    mutate(variance_ratio = sd_within_regions^2 / sd_pooled^2,
           se_pooled_now = sd_pooled / sqrt(tows_per_year), se_split_now = sd_within_regions / sqrt(tows_per_year))
}
