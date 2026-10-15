# EchoNet2Fish fish_ha (fish per ha, interval x 10 m layer) by trawl stratum. First pass: one year.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/acoustic.R")))
YEAR <- as.integer(Sys.getenv("YEAR", 2004))

tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == "Michigan")
cells <- name_strata(michigan_strata(tows)) %>% distinct(cell, stratum_name)

il <- assign_strata(read_intlay(YEAR), cells)
cat(YEAR, ":", nrow(il), "interval x layers in", n_distinct(paste(il$Region_name, il$Interval)), "intervals\n")
cat("fish_ha NA:", sum(is.na(il$fish_ha_raw)), " Inf:", sum(is.infinite(il$fish_ha_raw)),
    " finite:", sum(is.finite(il$fish_ha_raw)), " (NA/Inf set to 0)\n")
cat("  of the NA/Inf rows, Sv_mean present:", sum(!is.finite(il$fish_ha_raw) & !is.na(il$Sv_mean)), "\n")

s <- il %>%
  summarise(.by = stratum_name, cells_layers = n(), zero = sum(fish_ha == 0),
            mean = mean(fish_ha), sd = sd(fish_ha), median = median(fish_ha), p90 = quantile(fish_ha, 0.9),
            max = max(fish_ha)) %>%
  mutate(cv = sd / mean) %>%
  arrange(stratum_name)
options(width = 200)
print(as.data.frame(mutate(s, across(where(is.double), \(x) signif(x, 3)))))
write_csv(s, file.path(OUTPUT_DIR, paste0("acoustic_fish_ha_strata_", YEAR, ".csv")))

# Map: mean fish_ha per 20 m cell with the strata outlines; and the distribution per stratum
cm <- il %>% summarise(.by = c(bd_bin, fd_bin, stratum_name), n = n(), mean_fish_ha = mean(fish_ha))
d <- cells %>% separate(cell, c("bd_bin", "fd_bin"), sep = "_", convert = TRUE) %>%
  mutate(x0 = bd_bin * 20, x1 = x0 + 20, y0 = fd_bin * 20, y1 = y0 + 20)
p1 <- ggplot(cm, aes((bd_bin + 0.5) * 20, (fd_bin + 0.5) * 20)) +
  geom_tile(aes(fill = mean_fish_ha), width = 20, height = 20) +
  geom_text(aes(label = round(mean_fish_ha)), size = 2.6) +
  geom_segment(data = strata_edges(d), aes(x, y, xend = xend, yend = yend), linewidth = 0.9, inherit.aes = FALSE) +
  scale_fill_viridis_c(trans = "sqrt", name = "Mean fish/ha") +
  scale_y_reverse(expand = c(0, 0)) + scale_x_continuous(expand = c(0, 0)) +
  labs(x = "Bottom depth (m)", y = "Layer depth (m)",
       title = paste0("Lake Michigan ", YEAR, ": EchoNet2Fish mean fish/ha per 20 m cell, with the trawl strata"),
       caption = "Interval x 10 m layer values (NA/Inf = 0) averaged within 20 m bottom x 20 m depth cells.") +
  theme_bw(base_size = 11) + theme(panel.grid = element_blank(), plot.caption = element_text(hjust = 0))
ggsave(file.path(OUTPUT_DIR, paste0("acoustic_fish_ha_cells_", YEAR, ".png")), p1, width = 11, height = 6, dpi = 150)

p2 <- ggplot(il, aes(stratum_name, fish_ha + 1)) +
  geom_boxplot(outlier.size = 0.8, fill = "grey90") +
  stat_summary(fun = mean, geom = "point", shape = 4, size = 3, colour = "red") +
  scale_y_log10() +
  labs(x = NULL, y = "fish/ha + 1 (log scale)",
       title = paste0("Lake Michigan ", YEAR, ": EchoNet2Fish fish/ha per interval x layer, by trawl stratum"),
       caption = "Box = quartiles; red x = mean. NA/Inf set to 0.") +
  theme_bw(base_size = 11) + theme(plot.caption = element_text(hjust = 0))
ggsave(file.path(OUTPUT_DIR, paste0("acoustic_fish_ha_box_", YEAR, ".png")), p2, width = 9, height = 5, dpi = 150)
