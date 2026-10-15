# Adams et al. (2006) depth stratification for Lake Michigan tows, by numbers and by weight, 20 m cells.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/strata.R")))
library(patchwork)

CELL_M <- 20
MIN_FISH <- 10   # fish (by number) per tow; 0 = Adams et al. (all tows)
MIN_TOWS <- 5    # tows per cell; 2 = Adams et al.
OUT_TAG <- paste0(if (MIN_FISH > 0) paste0("_min", MIN_FISH, "fish") else "", if (MIN_TOWS != 2) paste0("_min", MIN_TOWS, "tows") else "")
tows <- drop_bad_coordinates(select_tows()) %>% filter(lake == "Michigan")
n_fish <- tow_catch(tows, "N") %>% select(OP_ID, n_fish = n)
options(width = 200)
all_summ <- list()
for (m in c("N", "WEIGHT")) {
  tc <- tow_cells(left_join(tow_catch(tows, m), n_fish, by = "OP_ID"), cell_m = CELL_M, min_fish = MIN_FISH)
  cs_all <- cell_stats(tc, min_tows = MIN_TOWS)
  blk <- main_block(cs_all)
  cs <- blk$cells
  tree <- cluster_cells(cs)
  cat("\n==", m, ":", nrow(tc), "tows;", nrow(cs_all), paste0("cells with >= ", MIN_TOWS, " tows;"), nrow(cs), "cells /", sum(cs$tows),
      "tows in the main block; excluded:", nrow(blk$excluded), "cells /", sum(blk$excluded$tows), "tows;",
      nrow(tc) - sum(cs_all$tows), "tows in cells with 1 tow\n")
  plots <- list()
  for (k in 2:7) {
    st <- cutree(tree, k = k)
    s <- stratum_summary(tc, cs, st, CELL_M) %>% mutate(measure = m, k = k, .before = 1)
    all_summ[[length(all_summ) + 1]] <- s
    cat("k =", k, "\n"); print(as.data.frame(mutate(s, across(where(is.double), \(x) round(x, 2)))))
    plots[[k - 1]] <- plot_strata(cs, st, CELL_M, paste(k, "strata"))
  }
  ggsave(file.path(OUTPUT_DIR, paste0("strata_michigan_", tolower(m), OUT_TAG, ".png")),
         wrap_plots(plots, ncol = 3) + plot_annotation(title = paste0("Lake Michigan depth strata (Adams et al. 2006 method), proportions by ",
                                                                        if (m == "N") "number" else "weight", if (MIN_FISH > 0) paste0(", tows with >= ", MIN_FISH, " fish") else "", paste0(", cells with >= ", MIN_TOWS, " tows"), "; labels = tows per cell")),
         width = 14, height = 8, dpi = 150)
  png(file.path(OUTPUT_DIR, paste0("strata_tree_michigan_", tolower(m), OUT_TAG, ".png")), width = 1400, height = 700, res = 130)
  plot(structure(tree, class = "hclust"), labels = paste0(cs$bd_bin * CELL_M, "/", cs$fd_bin * CELL_M), main = paste("Constrained complete-linkage tree,", m),
       xlab = "Cell (bottom depth / fishing depth, m, lower edges)", sub = "")
  dev.off()
}
write_csv(list_rbind(all_summ), file.path(OUTPUT_DIR, paste0("strata_michigan_summary", OUT_TAG, ".csv")))
