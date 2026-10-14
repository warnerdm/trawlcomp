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
- Next: the user picks the "mixed" definition (index, number vs weight, cutoff, minimum catch).

## Tasks
2. Grouping: covariates rather than crossed cells (proposed, not yet confirmed): lake, fishing depth
   (probably two groups), bottom depth, lat, lon (bins or smooths), with a tow random effect.
3. Define the groups (species, species-size) and the within-tow n (whole catch vs length subsample).
4. Fit the beta-binomial / binomial GLMM; bootstrap check; report each tow's mean and SD with the
   binomial lower bound.
