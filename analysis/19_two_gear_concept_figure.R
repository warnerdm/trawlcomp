# Concept figure for the two-gear uncertainty (method 1): the spread of acoustic density (rho), of the trawl
# proportion (p), and of their product, species density D = rho x p, for a main and a minor species.
# Illustrative values (not survey estimates): rho 1,000 fish/ha with CV 20%; main species p = 0.50, CV 15%;
# minor species p = 0.10, CV 60%. Simulated independent draws (lognormal rho; beta p); CV_D^2 ~ CV_rho^2 + CV_p^2.
suppressWarnings(suppressMessages(library(tidyverse)))
source("D:/pyprojects/trawlcomp/R/paths.R")
set.seed(1)
n <- 1e5
rlnorm_cv <- function(n, mean, cv) { s <- sqrt(log(1 + cv^2)); rlnorm(n, log(mean) - s^2 / 2, s) }
rbeta_cv <- function(n, mean, cv) { v <- (cv * mean)^2; k <- mean * (1 - mean) / v - 1; rbeta(n, mean * k, (1 - mean) * k) }

rho <- rlnorm_cv(n, 1000, 0.20)
cases <- tribble(~species, ~p_mean, ~p_cv,
                 "Main species (e.g. alewife)", 0.50, 0.15,
                 "Minor species (e.g. smelt)",  0.10, 0.60)
sims <- pmap(cases, \(species, p_mean, p_cv) {
  p <- rbeta_cv(n, p_mean, p_cv)
  tibble(species = species,
         `Acoustic density (fish/ha)` = rho, `Trawl proportion` = p, `Species density (fish/ha)` = rho * p)
}) %>% list_rbind() %>%
  pivot_longer(-species, names_to = "quantity", values_to = "value") %>%
  mutate(quantity = factor(quantity, c("Acoustic density (fish/ha)", "Trawl proportion", "Species density (fish/ha)")),
         species = factor(species, cases$species))
lab <- sims %>% summarise(.by = c(species, quantity), m = mean(value), s = sd(value), hi = quantile(value, 0.995)) %>%
  mutate(cv = s / m, text = paste0("mean ", signif(m, 3), "\nCV ", round(100 * cv), "%"))
eq <- lab %>% filter(quantity != "Trawl proportion") %>% select(species, quantity, cv) %>%
  pivot_wider(names_from = quantity, values_from = cv) %>%
  left_join(filter(lab, quantity == "Trawl proportion") %>% select(species, cv_p = cv), by = "species") %>%
  mutate(text = sprintf("sqrt(%.2f^2 + %.2f^2) = %.2f", `Acoustic density (fish/ha)`, cv_p, sqrt(`Acoustic density (fish/ha)`^2 + cv_p^2)),
         quantity = factor("Species density (fish/ha)", levels(sims$quantity)))

p <- ggplot(sims, aes(value)) +
  geom_density(fill = "grey80", colour = "grey30", adjust = 1.5) +
  geom_vline(data = lab, aes(xintercept = m), colour = "firebrick") +
  geom_rect(data = lab, aes(xmin = m - s, xmax = m + s, ymin = -Inf, ymax = Inf), inherit.aes = FALSE,
            fill = "firebrick", alpha = 0.12) +
  geom_text(data = lab, aes(x = Inf, y = Inf, label = text), hjust = 1.1, vjust = 1.3, size = 3.3, inherit.aes = FALSE) +
  geom_text(data = eq, aes(x = Inf, y = Inf, label = paste0("CV from the two gears:\n", text)), hjust = 1.05, vjust = 3.6,
            size = 3, colour = "firebrick", inherit.aes = FALSE) +
  facet_wrap(species ~ quantity, ncol = 3, scales = "free", labeller = labeller(.multi_line = FALSE)) +
  labs(x = NULL, y = "Probability density",
       title = "Species density = acoustic density x trawl proportion: how the two spreads combine",
       subtitle = "Illustrative values. Red line = mean, shaded = +-1 SD. Acoustic spread is the same in both rows; the trawl spread differs.") +
  theme_bw(base_size = 11) +
  theme(strip.background = element_rect(fill = "grey92"), axis.text.y = element_blank(), axis.ticks.y = element_blank())
ggsave(file.path(OUTPUT_DIR, "two_gear_concept.png"), p, width = 12, height = 6.5, dpi = 150)
print(as.data.frame(mutate(lab, across(where(is.double), \(x) signif(x, 3)))))
