# Reproducing trawlcomp

How to rebuild every trawlcomp result from the raw data, what each step does, and which settings matter.
Current results and decisions are in `STATUS.md`.

## 1. What you need

| Item | Where |
|---|---|
| R 4.4.0 (4.6.1 lacks packages) | `C:\Program Files\R\R-4.4.0\bin\Rscript.exe` |
| R packages | tidyverse, mgcv, adespatial, patchwork |
| Trawl data (read only) | `D:\pyprojects\bloaterTS\data\raw\trawl\` |
| EchoNet2Fish output (read only; step 12 only) | `D:\Acoustics\EchoNet2Fish_LM\MI<year>\` |
| This project | `D:\pyprojects\trawlcomp` |

All paths are set in `R/paths.R` (plus `EN2F_DIR` in `R/acoustic.R`). Nothing outside `output/` is written.

## 2. Run everything

```
"C:\Program Files\R\R-4.4.0\bin\Rscript.exe" D:\pyprojects\trawlcomp\run_all.R
```

About 10 minutes, 8 of them in step 03. Each step runs in its own R process; one line per step is printed
(`ok` or `FAILED`), and each step's console output goes to `output/logs/<step>[_<lake>].log`. To rerun only some
steps, list their numbers: `Rscript run_all.R 08 09 10`.

A single step can also be run by itself. Steps that take a lake read the `LAKE` environment variable
(default Michigan), e.g. in Git Bash: `LAKE=Huron Rscript analysis/09_stratum_stats.R`.

## 3. Data rules (applied automatically)

These are in `R/select_tows.R` (`select_tows()`, `drop_bad_coordinates()`) and `R/tow_catch.R` (`tow_catch()`).

1. **Tows.** Michigan: every tow in the bloaterTS files `L_2_Y_<year>_Acoustic_optrop.csv` (2004-2024, no
   2020), and only those. Huron: the USGS ScienceBase release (doi:10.5066/F75M63X0), `OP.csv` with
   `OP_TARGET.csv` TARGET 209 or 210, 2004 on, SAMPLE_TYPE 1, vessels 17, 35, 88.
2. **Coordinates.** Tows with missing start coordinates or coordinates outside the lake's box are dropped
   (11 Huron tows).
3. **Bottom depth** = mean of BEG_DEPTH and END_DEPTH, with a depth of 0 treated as not recorded. Michigan 2008
   vessel 17 bottom depths are in feet (x 0.3048). Michigan 77542 and 104167 have no usable bottom depth.
4. **Catch.** Michigan catch from `L_2_Y_<year>_Acoustic_tr_catch.csv` only; Huron from the release's
   `TR_CATCH.csv`. Counts (or weights) are summed over life stages. Groups: alewife (106), smelt (109), bloater
   (204), and for Huron "other" (every other species). Species absent from a tow count as 0.
5. **Alewife contamination.** Alewife in tows fishing deeper than 40 m are set to 0 (they are caught while the
   net passes through the upper water column).
6. **Weight.** A tow with a missing weight (or a weight of 0 with fish counted) for a group it caught is left
   out of weight-based proportions.
7. **Tows used.** A tow needs at least 1 fish in the groups for the tow-level model (steps 02-06) and at least
   5 fish for the stratum framework (steps 08-10, 13).

## 4. The steps

| Step | Script (analysis/) | Functions (R/) | What it does | Main outputs (output/) |
|---|---|---|---|---|
| 01 | `01_tow_layout.R` | `tow_layout.R` | Tows per lake-year-transect, fishing-depth neighbours, night-time check | `transect_summary.csv` |
| 02 | `02_composition_plots.R` | `composition_plots.R` | Proportion per tow vs fishing depth, bottom depth, lat, lon | `composition_<lake>.png` |
| 03 | `03_fit_models.R` | `fit_models.R` | Binomial GAM per lake and group with year and tow random effects (tow SD by layer, < 35 m / >= 35 m); simulated repeat-tow mean, SD and 90% interval per tow | `model_summary.csv`, `repeat_tow_stats.csv`, `models.rds` |
| 04 | `04_se_vs_tows.R` | `se_plots.R` | SE of a mean proportion vs number of repeat tows (from 03) | `se_vs_tows_<lake>.png`, `se_vs_tows.csv` |
| 05 | `05_effort.R` | `effort.R` | Current tows per year by layer, placed on the SE curves; 2x and 3x effort | `effort_<lake>.png`, `effort_by_year.csv`, `effort_se.csv` |
| 06 | `06_subsample.R` | `subsample.R` | Model-free check: real within-year SD vs model SD; subsampling curves for well-sampled deep years | `subsample_empirical_vs_model.csv`, `subsample_deep_<lake>.png` |
| 07 | `07_huron_evenness.R` | `evenness.R` | Huron species evenness per tow (mixed-tows work; see STATUS) | `huron_evenness.csv`, `huron_mixed_tows.csv` |
| 08 | `08_strata.R` (per lake) | `strata.R` | Adams et al. (2006) clustering of 20 m bottom x fishing depth cells, 2-7 strata, number and weight | `strata_<lake>_<n/weight>_min5fish_min5tows.png`, `strata_tree_*`, `strata_<lake>_summary_*.csv` |
| 09 | `09_stratum_stats.R` (per lake) | `stratum_stats.R` | The chosen strata (5 per lake): mean, SD (all years, within year), SE at current effort, ratio estimator and its SE, combined estimate; SE vs tows plot | `stratum_stats_<lake>.csv`, `stratum_combined_<lake>.csv`, `stratum_se_<lake>_<n/weight>.png` |
| 10 | `10_strata_figure.R` (per lake) | `stratum_stats.R` | Adams Figure 4 style plot (crosshatch = variability) and every tow plotted by stratum or reason left out | `strata_adams_style_<lake>_*.png`, `strata_tows_<lake>.png` |
| 11 | `11_acoustic_fish_ha.R` (optional, `YEAR`) | `acoustic.R` | One year of EchoNet2Fish fish/ha by stratum, with a cell map | `acoustic_fish_ha_*_<year>` |
| 12 | `12_acoustic_fish_ha_years.R` | `acoustic.R` | EchoNet2Fish fish/ha (NA/Inf = 0) by Michigan stratum, every year | `acoustic_fish_ha_strata_{by_year,pooled}.csv`, `.png` |
| 13 | `13_region_test.R` (per lake) | `stratum_stats.R` | Does composition differ by survey region (transect prefix) within the strata? | `region_effects_<lake>.csv` |

Dependencies: 04, 05 and 06 read 03's output; 10 reads 09's output. `run_all.R` runs them in order.

## 5. Key settings (change them where listed, then rerun the affected steps)

| Setting | Value | Where |
|---|---|---|
| Alewife contamination depth | 40 m | `R/tow_catch.R` `ALEWIFE_CONTAMINATION_DEPTH_M` |
| Layer split for the model's tow SD and for 05/06 | 35 m | `R/tow_catch.R` `LAYER_BREAK_M` |
| Strata per lake, minimum fish per tow, minimum tows per cell | 5, 5, 5 | `R/stratum_stats.R` `LAKE_STRATA` (steps 09, 10, 13) |
| Same minimums for the exploratory clustering (2-7 strata) | 5, 5 | `analysis/08_strata.R` `MIN_FISH`, `MIN_TOWS` (or env vars) |
| Cell size | 20 m | `CELL_M` in 08; `cell_m` arguments elsewhere |
| Species groups | alewife, smelt, bloater (+ other in Huron) | `R/tow_catch.R` `SPECIES_GROUPS`, `R/stratum_stats.R` `LAKE_STRATA` |
| Michigan region pooling | nne, nnw, nnlu -> nn | `R/stratum_stats.R` `tow_region()` |

## 6. Reading the results

- **Single-tow SD** (`sd_all`, `sd_within` in `stratum_stats_<lake>.csv`; `sd_obs` in `repeat_tow_stats.csv`):
  how much one tow's proportion varies around the mean of comparable tows.
- **SE for m tows** = single-tow SD / sqrt(m). `se_now_all` uses the current median tows per year.
- **Tow-equivalents**: one tow in stratum A is worth (SD_B / SD_A)^2 tows in stratum B.
- **Species density**: with an acoustic total D, the species density is D x p, with SE = D x SE(p) and
  CV = SE(p) / p; combined with the acoustic CV as sqrt(CV_acoustic^2 + CV_p^2).
- Field definitions of the stratum table are in the header of `R/stratum_stats.R`.
