# STATUS task 4: binomial GAMs with a tow random effect, per lake and group; repeat-tow mean and SD per tow.
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/fit_models.R")))

catch <- tow_catch(drop_bad_coordinates(select_tows()))
fits <- c(fit_lake(catch, "Michigan"), fit_lake(catch, "Huron"))

summ <- map(fits, "summary") %>% list_rbind()
tows <- map(fits, "tows") %>% list_rbind()
saveRDS(map(fits, "model"), file.path(OUTPUT_DIR, "models.rds"))
write_csv(summ, file.path(OUTPUT_DIR, "model_summary.csv"))
write_csv(tows, file.path(OUTPUT_DIR, "repeat_tow_stats.csv"))

options(width = 200)
print(as.data.frame(mutate(summ, across(where(is.numeric), \(x) signif(x, 3)))))
cat("\nPer-tow repeat SDs (medians over tows) and ratio to the binomial SD:\n")
print(as.data.frame(tows %>% summarise(.by = c(lake, layer, group),
  mean_p = median(mean_p), sd_patch = median(sd_patch), sd_obs = median(sd_obs), sd_binom = median(sd_binom),
  obs_over_binom = median(sd_obs / pmax(sd_binom, 1e-9))) %>% mutate(across(where(is.numeric), \(x) signif(x, 3)))))

cat("
Coverage of the observed proportions by each tow's 90% repeat-tow interval (expected ~0.90):
")
print(as.data.frame(tows %>% summarise(.by = c(lake, layer, group), coverage = round(mean(observed_p >= q05_obs & observed_p <= q95_obs), 3))))
