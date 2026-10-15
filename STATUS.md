# trawlcomp status

## Current state (2026-10-14)
- Tow selection: `R/select_tows.R` `select_tows()` (user, 2026-10-14).
  - Michigan: every tow in the bloaterTS files `L_2_Y_<year>_Acoustic_optrop.csv`, and only those; the USGS
    release (OP.csv and associated files) is never used for Michigan. 701 tows, 2004-2024 (no 2020).
  - Huron: USGS release, OP_TARGET TARGET 209/210, 2004+, SAMPLE_TYPE 1, vessels 17/35/88: 493 tows
    (2004-2018, none in 2006).
  - No trawl-design filter.
  - Bad coordinates dropped for now (user): `drop_bad_coordinates()` (missing, or outside the lake box).
    11 Huron tows: 57431 (2004, 42.05/-83.24, transect nc1), 76630, 78281, 83500 (missing), 89398-89404
    (Baird 2014, ~0.75/+1.39, not decimal degrees). Leaves Michigan 701, Huron 482.
  - All tows are night tows of the lakewide acoustic surveys (user). Logged TIME 06:00-20:00 in 24 tows:
    17 Huron 2004-2005/2012 at 18:35-20:00 (dusk); Michigan 57437 (10:57), 83437 (07:24), 93081 (06:09),
    83434 (06:02), 81848-81850 (19:00-19:54). Not acted on.
- Task 1 done (`R/tow_layout.R`, `analysis/01_tow_layout.R`, output/transect_summary.csv): 1-4 tows per
  lake-year-transect (mostly 1-2), usually at different fishing depths. Tows with >= 1 other tow on the same
  lake-year-transect: any depth MI 495/701, HU 372/493; within 10 m MI 234, HU 123; within 5 m MI 135, HU 63.

- Groups (user): alewife (106), smelt (109), bloater (204), plus other in Huron only; N summed over life
  stages. Michigan has no other group (user): the L_2_Y catch files hold only a few species (the release has
  ~3% other for these tows), so Michigan proportions are of the three species. `R/tow_catch.R` `tow_catch()`.
  Totals (1,183 tows): MI 78,396 fish, 41 tows with none of the three; HU 110,421 (other 5,394), 11 zero-catch.
  Smooth covariate terms, no bins (user).

## Composition variability (Michigan and Huron, 2026-10-14/15)
- Bottom depths: 2008 Michigan vessel 17 in feet (x 0.3048); 77542, 104167 NA (implausible), as bloaterTS
  (select_tows). Alewife in tows with fishing depth > 40 m are contamination and set to 0 (user; tow_catch
  ALEWIFE_CONTAMINATION_DEPTH_M): 992 fish in 42 Michigan tows (+1 Huron); 7 Michigan tows held only alewife and
  drop out (58086, 58104, 79137, 83153, 85929, 87181, 89419). 58104 (2005 v88, 60.4 m, 279 alewife only) is odd:
  check its fishing depth. tow_catch(measure = "N" | "WEIGHT"); weight missing for 38 Michigan tows.
- Composition plots (`R/composition_plots.R`, `analysis/02_composition_plots.R`): fishing depth is the main
  gradient (MI alewife -> bloater ~25-45 m; HU smelt -> bloater ~30-40 m); spatial patterns too.
- Models (`R/fit_models.R`, `analysis/03_fit_models.R`; output/model_summary.csv, repeat_tow_stats.csv): one
  binomial bam per lake and group: s(fishing_depth) + s(bottom_depth) + s(lon, lat) + year RE + tow RE with a
  separate SD per layer (< 35 m / >= 35 m; user). 651 Michigan, 469 Huron tows. Tow SD (logit) shallow / deep:
  MI alewife 3.20 / 2.24, smelt 2.89 / 2.11, bloater 2.89 / 2.64; HU smelt 2.12 / 1.74, bloater 2.22 / 1.72,
  other 2.06 / 1.86. Repeat-tow SD of a proportion ~0.2-0.35, 3-6x the binomial SD; 90% intervals cover
  0.90-0.99 (in-sample). Effective n per tow ~ n / k^2; ceiling ~1/rho (~2-3 fish).
- SE vs number of tows (`R/se_plots.R`, `analysis/04_se_vs_tows.R`): SE_i(m) = sd_obs_i / sqrt(m). Fish per tow
  left out (user: tows are what matter).
- Effort (`R/effort.R`, `analysis/05_effort.R`): tows with catch per year, median (range): MI < 35 m 26.5
  (17-47), >= 35 m 5 (1-10); HU 21 (12-44), 9.5 (3-14). SE at current effort, deep: MI bloater 0.087, smelt
  0.067; HU bloater 0.074, smelt 0.066. Deep layer is on the steep part of the curve. Context: user's question
  is general (saildrones collect acoustics, the ship only trawls: is more trawling worth it?), not apportioning.
- Subsampling check (`R/subsample.R`, `analysis/06_subsample.R`): real / model single-tow SD as RMS over years
  1.05-1.47 for all main groups and layers (model modestly optimistic; real layer SEs ~5-45% larger). Deep MI
  years are either all bloater (SD 0) or mixed (SD 0.4-0.55); a median over years misleads (earlier error).
- Adams et al. (2006, NAJFM 26:612-621) depth stratification, Michigan (`R/strata.R`, `analysis/08_strata.R`;
  output/strata_michigan_{n,weight}.png, strata_tree_michigan_*.png, strata_michigan_summary.csv): 20 m cells of
  bottom x fishing depth, >= 2 tows, mean + SD of proportions, neighbour-restricted complete linkage
  (adespatial::constr.hclust; main connected block). Number and weight nearly identical. k = 2: split at fishing
  depth 40 m: shallow (554 tows) alewife 0.66 (SD 0.41), smelt 0.20 (0.34), bloater 0.14 (0.30); deep (40-80 m
  over 40-140 m bottom, 91 tows) bloater 0.87 (0.31). k = 3-4 split the deep block (mixed smelt/bloater at
  40-60 m vs bloater core at 60-80 m, 0.95); k = 5-7 split the offshore surface (bottom > 180 m). W_d = share of
  cells (no acoustic biomass); Neyman ~78-80% of tows shallow.
  Restrictions (user, 2026-10-15; analysis/08_strata.R MIN_FISH, MIN_TOWS; outputs tagged _min10fish[_min5tows]):
  Adams used all tows with complete catch data and cells with >= 2 tows (no catch minimum found; user to reread).
  >= 10 fish per tow (by number) keeps 469 of 651 tows (deep 91 -> 45; the mixed deep 40-60 m cells were tiny
  catches, all-smelt or all-bloater). Adding >= 5 tows per cell: 445 tows in 19 cells. k = 4 resembles Adams'
  four strata: (1) surface 0-20 m over 0-160 m bottom (+ 20-40 m over 80-120 m) alewife 0.72 (SD 0.37), smelt
  0.16, bloater 0.12; (2) 20-40 m over 20-80 m bottom, mixed 0.45 / 0.34 / 0.22 (SDs 0.35-0.41); (3) deep 40-80 m
  over 60-120 m, bloater 0.99 (0.04); (4) surface over 160-200 m bottom, alewife 0.89. k = 5 splits the surface
  over 100-160 m bottom. With >= 3 tows per cell instead (user, 2026-10-15; script now MIN_TOWS = 3; outputs
  _min10fish_min3tows): 458 tows, 23 cells; single 3-tow cells peel off again (20-40 m over 120-140 and 140-160 m
  bottom; surface over 220-240 m) and the mixed midwater-nearshore stratum appears only at k = 7. Adams Table 4 (1994-95): 0.71/0.18/0.06; 0.40/0.20/0.38; offshore alewife 0.93; deep
  bloater 0.90.
- Stratum framework (user, 2026-10-15: not for survey design; a framework for mean, SD and SE of proportions
  across tows). `R/stratum_stats.R`, `analysis/09_stratum_stats.R`; output/stratum_stats_michigan.csv,
  stratum_combined_michigan.csv, stratum_se_michigan_{n,weight}.png. The 4 strata (>= 10 fish, >= 5 tows per
  cell, defined by number, used for both measures): surface nearshore 340 tows (15/yr), midwater nearshore 49
  (2/yr), surface offshore 17 (1/yr), deep 39 (2/yr). Mean of tow proportions, catch-weighted ratio, SD over all
  tows, pooled within-year SD, SE at current effort. By number, within-year SD / SE now: surface nearshore
  alewife 0.35 / 0.09, smelt 0.29 / 0.07, bloater 0.25 / 0.06; midwater nearshore 0.39 / 0.28, 0.36 / 0.26,
  0.27 / 0.19; surface offshore alewife 0.17 (df 5, unstable); deep bloater 0.04 / 0.03 (weight: 1.00, SD 0).
  Within-year SD only slightly below all-years SD. Combined with W = share of cells: alewife 0.54 (SE 0.067),
  bloater 0.31 (0.049), smelt 0.15 (0.056). Ratio and mean-of-proportions differ in surface nearshore (alewife
  0.85 vs 0.72): big catches are alewife.
  Ratio-estimator SE added (tows as units; pooled within-year residuals count - R n, / mean catch): by number at
  current effort, surface nearshore alewife 0.13 (vs 0.09 for the mean of proportions), smelt 0.13 (0.07),
  bloater 0.04 (0.06); midwater nearshore 0.18-0.22 (0.19-0.28); offshore and deep smaller than the mean's.
  Approximation: ratio variance is biased with 1-2 tows per year and heavy-tailed catches.
  Year effects (one-way ANOVA within stratum, by number): significant in surface nearshore (year 10-20% of
  variance; bloater +0.09 / decade, smelt -0.08) and midwater nearshore bloater (44%; +0.26 / decade, smelt
  -0.28); none in deep. Pooling years is fine for SDs (5-10% larger), not for nearshore means.
- Adams Figure 4 style plot (`plot_strata_adams()` in R/stratum_stats.R, `analysis/10_strata_figure.R`;
  output/strata_adams_style_michigan_{n,weight}.png): strata outlines in bottom depth x fishing depth,
  crosshatch spacing ~ 1 / (mean SD over species)^2 (none below ~0.16), lakebed shaded.

## Mixed-species tows (Huron first; user, 2026-10-14)
- Goal: use trawl catch to find tows whose acoustic data SHOULD be mixed species, then look for patterns in the
  acoustic data (tow regions as in bloaterTS; processing in pydt4, likely a separate project for the tow list,
  matching and review). Huron acoustic data is on disk for every year 2004-2018.
- Species set (user): 106 alewife, 109 smelt, 202 cisco, 204 bloater, 504 emerald shiner.
- First pass done: `R/evenness.R` `tow_evenness()`, `analysis/07_huron_evenness.R` -> output/huron_evenness.csv,
  huron_evenness_hist.png, huron_evenness_n_vs_w.png. Pielou's J with S fixed at 5, by number and by weight
  (WEIGHT summed over life stages), alewife contamination rule applied. Reference points: two species 50:50
  J = 0.43; 80:20 J = 0.31; three equal J = 0.68.
- Results (482 Huron tows, 470 with catch of the five): median J 0.10 (number) / 0.09 (weight); 90th
  percentile 0.43 / 0.42; r = 0.77. Smelt-dominated by number but bloater/cisco by weight in 43 tows.
  J >= 0.5 by both, n >= 10: 14 tows; J >= 0.4 by both: 41; J >= 0.3: 70. Other species 3% of fish.
  J_w NA for 3 tows (58517, 85739 bloater weight missing; 58561 one unweighed smelt).
- Mixed definition (user, 2026-10-14): J by number >= 0.4 and >= 30 fish of the five (evenness.R
  MIXED_J_MIN, MIXED_MIN_N; mixed_tows()). 41 Huron tows -> output/huron_mixed_tows.csv: 2005-2018 (no 2004,
  2006), 1-7 per year, vessel 88 38, vessel 35 3. 9 have J_w <= 0.3 (bloater or cisco by weight). Only 1 is in
  the bloaterTS Huron tow list, so 40 need tow matching from scratch.

## Tasks (composition variability)
- Done: tasks 1-4 (grouping by smooth covariates; groups alewife/smelt/bloater(/other); models; SE curves).
- Open: 58104 fishing depth; Adams strata with a stricter cell minimum; layer-specific results for Huron strata.
