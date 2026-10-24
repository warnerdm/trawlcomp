# Worked example of method 1 for one region and species (env vars REGION, GROUP, YEAR; default sn, bloater, 2021),
# region x layer version: the four steps of the calculation drawn from the real data.
#  A acoustic density per transect and layer; B trawl tow proportions per layer; C each transect's species density
#  D_t with the proportions fixed; D the variance terms (acoustic, trawl, product) and the result.
suppressWarnings(suppressMessages({ source("D:/pyprojects/trawlcomp/R/two_gear.R"); library(patchwork) }))
REGION <- Sys.getenv("REGION", "sn"); GROUP <- Sys.getenv("GROUP", "bloater"); YEAR <- as.integer(Sys.getenv("YEAR", 2021))
LAKE <- "Michigan"
groups <- LAKE_STRATA[[LAKE]]$groups
tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == LAKE)
n_fish <- tow_catch(tows, "N") %>% select(OP_ID, n_fish = n)
props <- tow_catch(tows, "N") %>% left_join(n_fish, by = "OP_ID") %>%
  filter(!is.na(n) & n > 0 & n_fish >= LAKE_STRATA[[LAKE]]$min_fish) %>% mutate(region = tow_region(transect))

at <- acoustic_transect_layers(YEAR) %>% filter(region == REGION)
tr <- trawl_region_layers(props, YEAR, groups) %>% filter(region == REGION, group == GROUP)
lv <- c(layer_of(0), layer_of(100))
pl <- setNames(tr$p, tr$layer); sel <- setNames(tr$se_p, tr$layer); sdl <- setNames(tr$sd, tr$layer)
ntw <- setNames(tr$tows, tr$layer); src <- setNames(tr$p_source, tr$layer)

# A: acoustic transect values
A <- at %>% mutate(layer = factor(layer, lv))
rho <- A %>% summarise(.by = layer, rho = mean(fish_ha), se = sd(fish_ha) / sqrt(n()), n = n())
pA <- ggplot(A, aes(layer, fish_ha)) +
  geom_jitter(width = 0.08, height = 0, size = 2.2, colour = "steelblue", alpha = 0.8) +
  geom_pointrange(data = rho, aes(y = rho, ymin = rho - se, ymax = rho + se), colour = "black", size = 0.6,
                  position = position_nudge(x = 0.25)) +
  geom_text(data = rho, aes(y = rho, label = sprintf("rho = %.0f\nSE %.0f (n = %d)", rho, se, n)),
            position = position_nudge(x = 0.42), hjust = 0, size = 3.2) +
  scale_x_discrete(expand = expansion(add = c(0.5, 1.3))) +
  labs(x = "Depth layer", y = "Fish/ha (all species)",
       title = "A. Acoustics: each point is one transect", subtitle = "rho = mean of transects; SE = SD / sqrt(transects)") +
  theme_bw(base_size = 10)

# B: trawl tow proportions in the year
B <- props %>% filter(YEAR == !!YEAR, region == REGION) %>% mutate(layer = factor(layer_of(fishing_depth), lv), p = .data[[GROUP]] / n)
trB <- tibble(layer = factor(lv, lv), p = pl[lv], se = sel[lv], sd = sdl[lv], n = ntw[lv], src = src[lv])
pB <- ggplot(B, aes(layer, p)) +
  geom_jitter(width = 0.08, height = 0, size = 2.2, colour = "darkorange", alpha = 0.8) +
  geom_pointrange(data = trB, aes(y = p, ymin = pmax(0, p - se), ymax = pmin(1, p + se)), colour = "black", size = 0.6,
                  position = position_nudge(x = 0.25)) +
  geom_text(data = trB, aes(y = p, label = sprintf("p = %.2f\nSE = %.2f / sqrt(%d)\n= %.2f", p, sd, n, se)),
            position = position_nudge(x = 0.42), hjust = 0, size = 3.1) +
  scale_y_continuous(limits = c(0, 1.05)) +
  scale_x_discrete(expand = expansion(add = c(0.5, 1.3))) +
  labs(x = "Depth layer (tow fishing depth)", y = paste("Proportion", GROUP),
       title = "B. Trawl: each point is one tow", subtitle = "p = mean of the year's tows; SD borrowed from all years") +
  theme_bw(base_size = 10)

# C: transect species density with p fixed
C <- at %>% mutate(w = pl[layer]) %>% summarise(.by = Region_name, D_t = sum(fish_ha * w))
Dm <- mean(C$D_t); var_ac <- var(C$D_t) / nrow(C)
pC <- ggplot(C, aes(x = "transects", y = D_t)) +
  geom_jitter(width = 0.06, height = 0, size = 2.2, colour = "purple", alpha = 0.8) +
  geom_pointrange(aes(y = Dm, ymin = Dm - sqrt(var_ac), ymax = Dm + sqrt(var_ac)), data = tibble(), colour = "black",
                  size = 0.6, position = position_nudge(x = 0.2)) +
  annotate("text", x = 1.3, y = Dm, hjust = 0, size = 3.2,
           label = sprintf("D = %.0f\nacoustic SE %.0f", Dm, sqrt(var_ac))) +
  labs(x = NULL, y = paste(GROUP, "/ha"),
       title = "C. Species density per transect",
       subtitle = sprintf("D_t = rho_upper,t x %.2f + rho_lower,t x %.2f", pl[lv[1]], pl[lv[2]])) +
  theme_bw(base_size = 10)

# D: variance terms
rl <- setNames(rho$rho, as.character(rho$layer)); vr <- setNames(rho$se^2, as.character(rho$layer))
var_tr <- sum(rl[lv]^2 * sel[lv]^2); var_x <- sum(vr[lv] * sel[lv]^2)
tot <- var_ac + var_tr + var_x
vt <- tibble(term = factor(c("acoustic", "trawl", "product"), c("acoustic", "trawl", "product")),
             value = c(var_ac, var_tr, var_x),
             how = c("var(D_t) / transects", "sum over layers of\nrho^2 x SE(p)^2", "sum over layers of\nSE(rho)^2 x SE(p)^2"))
pD <- ggplot(vt, aes(term, value, fill = term)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf("%s\n%.0f (%.0f%%)", how, value, 100 * value / tot)), vjust = -0.15, size = 3) +
  scale_fill_manual(values = c(acoustic = "steelblue", trawl = "darkorange", product = "grey60"), guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.35))) +
  labs(x = NULL, y = "Variance of D", title = "D. Add the variances",
       subtitle = sprintf("Var = %.0f; SE = sqrt(Var) = %.0f; CV = %.0f / %.0f = %.0f%%", tot, sqrt(tot), sqrt(tot), Dm, 100 * sqrt(tot) / Dm)) +
  theme_bw(base_size = 10)

p <- (pA | pB) / (pC | pD) +
  plot_annotation(title = sprintf("Method 1 step by step: %s in region %s, %d (region x layer, split at 40 m)", GROUP, REGION, YEAR),
                  subtitle = "Species density D = rho_upper x p_upper + rho_lower x p_lower")
ggsave(file.path(OUTPUT_DIR, sprintf("two_gear_worked_%s_%s_%d.png", REGION, GROUP, YEAR)), p, width = 13, height = 9, dpi = 150)
cat(sprintf("D %.1f, var_ac %.0f, var_tr %.0f, var_x %.0f, SE %.1f, CV %.3f; trawl sources: %s\n", Dm, var_ac, var_tr, var_x,
            sqrt(tot), sqrt(tot) / Dm, paste(src, collapse = ", ")))
