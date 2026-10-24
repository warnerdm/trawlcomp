# Reproduce every trawlcomp result in order (see docs/REPRODUCE.md). Run from anywhere with R 4.4.0:
#   "C:\Program Files\R\R-4.4.0\bin\Rscript.exe" D:\pyprojects\trawlcomp\run_all.R
# Optional: Rscript run_all.R 08 09   (run only scripts whose number is listed)
# Each script runs in its own R process; LAKE is passed through the environment. Logs go to output/logs/.
root <- "D:/pyprojects/trawlcomp"
rscript <- file.path(R.home("bin"), "Rscript.exe")
dir.create(file.path(root, "output", "logs"), showWarnings = FALSE, recursive = TRUE)

steps <- list(
  list("01_tow_layout"),
  list("02_composition_plots"),
  list("03_fit_models"),                      # ~15 min; 04-06 read its output
  list("16_gam_plots"),                       # ~4 min; summaries and smooth plots of 03's models
  list("04_se_vs_tows"),
  list("05_effort"),
  list("06_subsample"),
  list("07_huron_evenness"),
  list("08_strata", "Michigan"), list("08_strata", "Huron"),
  list("09_stratum_stats", "Michigan"), list("09_stratum_stats", "Huron"),
  list("10_strata_figure", "Michigan"), list("10_strata_figure", "Huron"),   # 10 reads 09's output
  list("12_acoustic_fish_ha_years"),
  list("13_region_test", "Michigan"), list("13_region_test", "Huron"),
  list("14_region_depth_strata", "Huron"),
  list("15_region_depth_presentation"),
  list("17_two_gear_uncertainty"),            # Michigan 2021 (YEAR, FRAME env vars); reads 09's output
  list("18_two_gear_bootstrap"),              # ~1 min; Michigan 2021 bootstrap; compares with 17
  list("17_two_gear_uncertainty", "", c(FRAME = "region_layer_ps")),   # trawl post-strata
  list("18_two_gear_bootstrap", "", c(FRAME = "region_layer_ps"))
)
only <- commandArgs(trailingOnly = TRUE)
if (length(only)) steps <- Filter(\(s) substr(s[[1]], 1, 2) %in% only, steps)

# A step is list(script, lake = "", env = c(NAME = "value", ...)); env vars are set for that step only.
for (s in steps) {
  script <- s[[1]]; lake <- if (length(s) > 1) s[[2]] else ""
  env <- if (length(s) > 2) s[[3]] else character(0)
  Sys.setenv(LAKE = lake)
  if (lake == "") Sys.unsetenv("LAKE")
  Sys.unsetenv(c("FRAME", "YEAR", "B"))
  if (length(env)) do.call(Sys.setenv, as.list(env))
  tag <- paste0(if (nzchar(lake)) paste0("_", tolower(lake)), if (length(env)) paste0("_", paste(env, collapse = "_")))
  log <- file.path(root, "output", "logs", paste0(script, tag, ".log"))
  t0 <- Sys.time()
  status <- system2(rscript, shQuote(file.path(root, "analysis", paste0(script, ".R"))), stdout = log, stderr = log)
  cat(sprintf("%-28s %-16s %s (%.0f s)\n", script, paste0(lake, paste(env, collapse = " ")),
              if (status == 0) "ok" else paste("FAILED, see", log),
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  if (status != 0) stop("stopped at ", script)
}
