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
  Totals (1,183 tows): MI 78,396 fish, 40 zero-catch tows; HU 110,421 (other 5,394), 11 zero-catch.
  Smooth covariate terms, no bins (user).

## Tasks
2. Grouping: covariates rather than crossed cells (proposed, not yet confirmed): lake, fishing depth
   (probably two groups), bottom depth, lat, lon (bins or smooths), with a tow random effect.
3. Define the groups (species, species-size) and the within-tow n (whole catch vs length subsample).
4. Fit the beta-binomial / binomial GLMM; bootstrap check; report each tow's mean and SD with the
   binomial lower bound.
