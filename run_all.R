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
  list("03_fit_models"),                      # ~2 min; 04-06 read its output
  list("04_se_vs_tows"),
  list("05_effort"),
  list("06_subsample"),
  list("07_huron_evenness"),
  list("08_strata", "Michigan"), list("08_strata", "Huron"),
  list("09_stratum_stats", "Michigan"), list("09_stratum_stats", "Huron"),
  list("10_strata_figure", "Michigan"), list("10_strata_figure", "Huron"),   # 10 reads 09's output
  list("12_acoustic_fish_ha_years"),
  list("13_region_test", "Michigan"), list("13_region_test", "Huron")
)
only <- commandArgs(trailingOnly = TRUE)
if (length(only)) steps <- Filter(\(s) substr(s[[1]], 1, 2) %in% only, steps)

for (s in steps) {
  script <- s[[1]]; lake <- if (length(s) > 1) s[[2]] else ""
  Sys.setenv(LAKE = lake)
  if (lake == "") Sys.unsetenv("LAKE")
  log <- file.path(root, "output", "logs", paste0(script, if (nzchar(lake)) paste0("_", tolower(lake)), ".log"))
  t0 <- Sys.time()
  status <- system2(rscript, shQuote(file.path(root, "analysis", paste0(script, ".R"))), stdout = log, stderr = log)
  cat(sprintf("%-28s %-9s %s (%.0f s)\n", script, lake, if (status == 0) "ok" else paste("FAILED, see", log),
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  if (status != 0) stop("stopped at ", script)
}
