# trawlcomp

Between-tow variability of species proportions in Great Lakes midwater trawl catches (Lake Michigan and Lake
Huron acoustic-survey tows, 2004-2024): the mean proportion of each species group, its SD across tows, and how
the uncertainty of a mean proportion falls with the number of tows, by depth stratum.

- Reproduce everything: `"C:\Program Files\R\R-4.4.0\bin\Rscript.exe" run_all.R` (about 10 minutes).
- Step-by-step guide, data rules and settings: [docs/REPRODUCE.md](docs/REPRODUCE.md).
- Current results and decisions: [STATUS.md](STATUS.md).

Layout: `R/` functions, `analysis/` numbered scripts that call them, `output/` results (not in git),
`run_all.R` runs the scripts in order.
