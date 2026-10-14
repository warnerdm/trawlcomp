# trawlcomp status

## Current state (2026-10-14)
- Project created: folders, CLAUDE.md, git repo. No analysis yet.

## Tasks
1. User lists the tows of interest (op IDs).
2. Show where those tows sit relative to the other tows (lake, year, depth, area, time of night) and how
   many could serve as pseudo-replicates for each.
3. Choose the replicate grouping (user decision).
4. Define the groups (species, species-size) and the within-tow n (whole catch vs length subsample).
5. Fit the beta-binomial / binomial GLMM; bootstrap check; report each tow's mean and SD with the
   binomial lower bound.
