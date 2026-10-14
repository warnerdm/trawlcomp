# trawlcomp status

## Current state (2026-10-14)
- Tow selection: `R/select_tows.R` `select_tows()` (user, 2026-10-14).
  - Michigan: every tow in the bloaterTS files `L_2_Y_<year>_Acoustic_optrop.csv`, and only those; the USGS
    release (OP.csv and associated files) is never used for Michigan. 701 tows, 2004-2024 (no 2020).
  - Huron: USGS release, OP_TARGET TARGET 209/210, 2004+, SAMPLE_TYPE 1, vessels 17/35/88: 493 tows
    (2004-2018, none in 2006).
  - No trawl-design filter.

## Tasks
1. Show where the tows sit relative to each other (lake, year, depth, area, time of night) and how many
   could serve as pseudo-replicates.
2. Choose the replicate grouping (user decision).
3. Define the groups (species, species-size) and the within-tow n (whole catch vs length subsample).
4. Fit the beta-binomial / binomial GLMM; bootstrap check; report each tow's mean and SD with the
   binomial lower bound.
