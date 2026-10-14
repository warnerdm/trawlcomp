# trawlcomp status

## Current state (2026-10-14)
- Tow selection: `R/select_tows.R` `select_tows()`. Acoustic-survey tows = OP_TARGET TARGET 209/210 (user).
  - Michigan: bloaterTS per-year files, 2004-2024. 510 tows (2004-2018) pass the TARGET check; 16 file tows
    (8 in 2017, 8 in 2018) are not tagged 209/210 and are dropped. 175 tows from 2019-2024 have no TARGET
    (release ends 2018): kept, flagged target_checked = FALSE.
  - Huron: USGS release, 2004+, SAMPLE_TYPE 1, vessels 17/35/88: 493 tows (2004-2018, none in 2006).
  - Not used: 50 release Michigan tows tagged 209/210 that are not in the files (mostly vessel 17 with
    TR_DESIGN 30/33; 11 from vessel 41 in 2018).
- No trawl-design filter: TARGET defines the tows.

## Open questions
- Michigan 2019-2024 tows: keep (unchecked) or drop?

## Tasks
1. Show where the tows sit relative to each other (lake, year, depth, area, time of night) and how many
   could serve as pseudo-replicates.
2. Choose the replicate grouping (user decision).
3. Define the groups (species, species-size) and the within-tow n (whole catch vs length subsample).
4. Fit the beta-binomial / binomial GLMM; bootstrap check; report each tow's mean and SD with the
   binomial lower bound.
