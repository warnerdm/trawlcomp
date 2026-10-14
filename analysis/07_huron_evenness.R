# Huron species evenness per tow (Pielou's J, S = 5: alewife, smelt, cisco, bloater, emerald shiner), by number and
# by weight, first pass toward a "mixed tow" definition (user, 2026-10-14).
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/evenness.R")))
t <- select_tows() %>% drop_bad_coordinates() %>% filter(lake == "Huron")
e <- tow_evenness(t)
write_csv(e, file.path(OUTPUT_DIR, "huron_evenness.csv"))

cat("Huron tows:", nrow(e), " none of the five:", sum(e$n_tot == 0),
    " weight missing for a caught species:", sum(e$w_missing), "\n")
cat("catch outside the five (by number):", sum(e$n_other), "of", sum(e$n_other) + sum(e$n_tot), "fish\n")
k <- filter(e, n_tot > 0)
cat("\nJ quantiles (tows with catch):\n")
print(rbind(J_n = quantile(k$J_n, c(0, .1, .25, .5, .75, .9, 1)),
            J_w = quantile(k$J_w, c(0, .1, .25, .5, .75, .9, 1), na.rm = TRUE)), digits = 2)
cat("\ncorrelation J_n vs J_w:", round(cor(k$J_n, k$J_w, use = "complete.obs"), 2), "\n")
cat("\ndominant species (largest share) by number (rows) and by weight (cols):\n")
print(table(k$dom_n, k$dom_w, useNA = "ifany"))

cat("\ntows at or above example J cutoffs, by minimum catch of the five (by number):\n")
cuts <- expand_grid(min_n = c(1, 10, 30), J = c(0.3, 0.4, 0.5, 0.6))
print(as.data.frame(cuts %>% rowwise() %>% mutate(
  n_tows = sum(k$n_tot >= min_n),
  J_n = sum(k$n_tot >= min_n & k$J_n >= J),
  J_w = sum(k$n_tot >= min_n & k$J_w >= J, na.rm = TRUE),
  both = sum(k$n_tot >= min_n & k$J_n >= J & k$J_w >= J, na.rm = TRUE))))

cat("\ntows with J_n >= 0.5 and J_w >= 0.5 (n >= 10) by year:\n")
print(table(filter(k, n_tot >= 10, J_n >= 0.5, J_w >= 0.5)$YEAR))

p <- k %>%
  select(OP_ID, J_n, J_w) %>%
  pivot_longer(c(J_n, J_w), names_to = "basis", values_to = "J") %>%
  mutate(basis = recode(basis, J_n = "by number", J_w = "by weight")) %>%
  ggplot(aes(J)) + geom_histogram(binwidth = 0.05, boundary = 0) + facet_wrap(~basis, ncol = 1) +
  labs(x = "Pielou's J (S = 5)", y = "tows", title = "Lake Huron tows: species evenness") + theme_bw()
ggsave(file.path(OUTPUT_DIR, "huron_evenness_hist.png"), p, width = 6, height = 5, dpi = 150)
q <- ggplot(k, aes(J_n, J_w, colour = dom_w)) + geom_abline(linetype = 2) + geom_point(alpha = 0.7) +
  coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
  labs(x = "J by number", y = "J by weight", colour = "dominant by weight") + theme_bw()
ggsave(file.path(OUTPUT_DIR, "huron_evenness_n_vs_w.png"), q, width = 6.5, height = 5, dpi = 150)
