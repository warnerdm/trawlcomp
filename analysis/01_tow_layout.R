# Where the acoustic-survey tows sit relative to each other (tows per lake-year-transect, depth neighbours, night check).
suppressWarnings(suppressMessages(source("D:/pyprojects/trawlcomp/R/tow_layout.R")))
t <- select_tows(); print(count(t, lake))
cat("missing: transect", sum(is.na(t$transect) | t$transect == ""), " fishing_depth", sum(is.na(t$fishing_depth)),
    " time", sum(is.na(t$time)), "\n")
o <- off_night(t); cat("logged time 06:00-20:00:", nrow(o), "\n"); print(as.data.frame(o[, c("OP_ID", "lake", "YEAR", "time")]))
s <- transect_summary(t)
write_csv(s, file.path(OUTPUT_DIR, "transect_summary.csv"))
cat("\nlake-year-transects by number of tows (6 = 6+):\n"); print(table(s$lake, pmin(s$n_tows, 6)))
cat("\nfishing depth quantiles:\n"); print(tapply(t$fishing_depth, t$lake, quantile, na.rm = TRUE))
for (tol in c(Inf, 10, 5)) {
  nb <- neighbours(t, tol)
  cat("\nsame lake-year-transect, fishing depth within", tol, "m: tows with >=1 / >=2 others\n")
  print(summarise(nb, .by = lake, n = n(), ge1 = sum(n_neigh >= 1), ge2 = sum(n_neigh >= 2)))
}
