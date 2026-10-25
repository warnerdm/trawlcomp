# trawlcomp status

Last updated 2026-10-24. Reproduce everything with `run_all.R` (about 10 minutes); the step-by-step guide is
`docs/REPRODUCE.md`. Numbers below are from that run unless marked as history.

## Question
If a midwater tow were repeated at the same place and time, what would be the mean proportion of each species
group and its SD, and how does the uncertainty of a mean proportion fall with the number of tows? General
question about acoustic-trawl surveys (e.g. saildrones do the acoustics, a ship only trawls: is more trawling
worth it?), not apportioning (user). Selectivity is out of scope.

## Data and data rules (all applied in code; R/select_tows.R, R/tow_catch.R)
- Michigan: tows, catch and lengths ONLY from bloaterTS `L_2_Y_<year>_Acoustic_*` files, 2004-2024 (no 2020);
  701 tows. Huron: USGS release (OP, OP_TARGET TARGET 209/210, TR_OP, TR_CATCH), 2004+, SAMPLE_TYPE 1, vessels
  17/35/88; 493 tows (2004-2018, none in 2006). Huron 2019-2024 (user, 2026-10-24): bloaterTS
  OP_TR.OP_OP_target_huron.csv + TR_catch_Huron.csv, same filter (vessel 37 did no Huron survey midwater tows,
  user): 257 tows. All tows are night tows of the lakewide acoustic surveys.
- Bad coordinates dropped: 12 Huron tows (89398-89404 not decimal degrees; 76630, 78281, 83500 missing; 57431
  off the lake; 124850, 2023 SD_Comp05, lon -43.56). Leaves Michigan 701, Huron 738.
- Bottom depth = mean of BEG_DEPTH and END_DEPTH; a depth of 0 = not recorded (all 11 2019 vessel 17 END_DEPTH);
  2008 Michigan vessel 17 bottom depths are in feet (x 0.3048); 77542 and 104167 bottom depth NA (as bloaterTS).
- Groups: alewife (106), smelt (109), bloater (204); Huron also "other" (all other species). Michigan has no
  other group (its catch files hold only a few species). N (or WEIGHT) summed over life stages; species absent
  from a tow count as 0.
- Alewife in tows with fishing depth > 40 m are contamination and set to 0 (both lakes): 992 Michigan fish in
  42 tows; 7 Michigan tows then have no fish (58104, 279 alewife at 60.4 m, is odd; not acted on).
- Weight: a tow with a missing (or 0 with fish counted) weight for any group it caught drops out of weight
  proportions (38 Michigan tows; a few Huron tows with missing "other" weight).
- Tows with fish in the groups: Michigan 651, Huron 725.

## Results (current)
### 1. Tow-level model (analyses 02-06; all tows with >= 1 fish)
- Binomial GAM per lake and group: s(fishing_depth) + s(bottom_depth) + s(lon, lat) + year RE + tow RE with a
  separate SD per layer (fishing depth < 35 m / >= 35 m). Tow SD (logit) shallow / deep: MI alewife 3.20 / 2.24,
  smelt 2.87 / 2.11, bloater 2.89 / 2.64; HU smelt 2.12 / 1.74, bloater 2.22 / 1.72, other 2.06 / 1.86. Year SD
  0.5-2.1.
- A single tow's proportion has SD ~0.2-0.35, 3-6x the binomial SD; effective n per tow ~ n / 16-35, with a
  ceiling of ~1/rho (~2-3 fish). Precision comes from the number of tows, not fish per tow.
- Model summaries and smooth plots: analysis 16 (output/model_summaries.txt, gam_smooths_<lake>_<group>.png);
  output/models.rds is a named list (e.g. models$Huron_bloater) for interactive summary()/plot() (REPRODUCE.md s. 7).
- Subsampling check: real within-year SD / model SD (RMS over years) 1.05-1.47: the model is modestly optimistic.
- Fishing depth is the main gradient in both lakes; location matters too (s(lon, lat) significant everywhere).

### 2. Stratum framework (analyses 08-10, 13; tows with >= 5 fish)
- Strata from Adams et al. (2006, NAJFM 26:612-621) depth stratification: 20 m cells of bottom depth x fishing
  depth, cells with >= 5 tows, mean + SD of per-tow proportions, neighbour-restricted complete linkage
  (adespatial::constr.hclust), 5 strata per lake (stratum_stats.R LAKE_STRATA). Proportions by number and weight
  give nearly the same strata; the strata are defined by number and used for both.
- Michigan (524 tows): surface nearshore 308 (15/yr), midwater nearshore 54 (2/yr), surface mid-lake 87 (5/yr),
  surface offshore 20 (1/yr), deep 55 (3/yr). By number, mean / SE at current effort (all-years SD):
  nearshore alewife 0.74 / 0.09; midwater alewife 0.47, smelt 0.31, bloater 0.22, SEs 0.25-0.29; deep bloater
  0.98 / 0.05.
- Huron 2004-2024 (667 tows in strata; re-clustered with the 2019-2024 tows), strata named by range: fishing
  0-40 m over 0-40 m bottom (162; smelt 0.80), 0-40 m over 40-140 m (309; smelt 0.57, bloater 0.27, other 0.12),
  20-40 m over 80-140 m (33; smelt 0.77), 40-60 m over 40-120 m (89; bloater 0.70, SD 0.35), 60-100 m over
  80-140 m (74; bloater 0.86, SD 0.21). (2004-2018 version had one deep stratum 40-80 m, bloater 0.74, and a
  7-tow surface cell over 120-140 m.) Region x depth and region tests were rerun; figures in STATUS below this
  line for Huron predate the 2019-2024 data unless stated.
- One Michigan deep tow estimates the bloater share as precisely as ~20 Michigan surface-nearshore tows estimate
  the alewife share (~40 on a CV basis); ~14 Huron deep tows.
- Small groups have small absolute SEs but large CVs (e.g. Huron other: SE 0.06, CV ~48%).
- Mean of tow proportions (every tow equal; used for all SDs) vs catch-weighted ratio estimator (also reported,
  with its tow-based SE): they differ where composition depends on catch size (MI surface nearshore alewife
  0.72 vs 0.85).
- Year: significant within the nearshore strata (10-44% of variance; smelt -> bloater trend), none in deep.
  Pooling years is fine for SDs (5-10% larger), not for nearshore means.
- Region (transect prefix; Michigan nne/nnw/nnlu pooled into nn): Michigan midwater nearshore has a strong
  north-south split (smelt nn 0.59 vs sn 0.01; region 37-58% of variance); small or none elsewhere. Huron:
  region 20-32% of variance in several strata, including deep bloater/smelt/other.
- Huron region x depth strata (2026-10-24; analysis 14; regions gb Georgian Bay, me main east, mw main west,
  nc North Channel, sb southern basin; sg, 2 tows, pooled into mw): smelt dominates gb and nc (0.80-0.96 in the
  shallow strata), bloater is highest in me and sb (shallow over 40-120 m: 0.45-0.49 vs nc 0.00, gb 0.10); deep
  bloater 0.78-0.84 in me/mw/sb vs 0.57 gb (nc 3 tows, mostly smelt). Splitting a depth stratum by region at the
  same total tows cuts the variance of bloater and smelt by 15-27% (variance ratio 0.73-0.84; SE -8 to -15%);
  little for alewife and other. Each region x stratum cell gets only ~1-3 tows a year.

### 2b. Presentation framework: regions with depth classes (analysis 15; user, 2026-10-24)
- Goal: explain what is observed. Survey regions as the frame (they already carry geography and, in Michigan,
  nearshore/offshore); fishing depth 0-20/20-40/40-60/60+ m x bottom depth 0-40/40-80/80-120/120+ m within each
  region; tows with >= 5 fish; by number. Map, stacked-bar composition figure, table (tows, tows/yr, mean, SD,
  SE), and the share of tow-to-tow variance explained (R^2 of linear models on tow proportions).
- Michigan (555 tows): depth explains alewife 31%, bloater 50%, smelt 6%; region alewife 1%, bloater 8%, smelt
  15%; region x depth 27-58%; unexplained 42-73%. Huron (440): depth smelt 33%, bloater 41%; region 23-26%;
  region x depth 50-62%; alewife and other mostly unexplained (78-86%). Huron sg (2 tows, Saginaw Bay mouth,
  15 Sep 2018) pooled into mw (user, 2026-10-24); 5 Huron regions. With 2019-2024 (686 tows): depth smelt 35%,
  bloater 44%; region 22%; region x depth 51-61%; alewife and other 82-86% unexplained.

### 3. Acoustic (analysis 12; EchoNet2Fish intlaymeans_nph, 2004-2024)
- Interval x 10 m layer fish_ha placed in the Michigan strata cells; NA/Inf = 0 (user; as EchoNet2Fish's own
  species columns). Zero density is normal in Lake Michigan (user). Pooled mean fish/ha: surface nearshore 377,
  midwater 68, mid-lake 355, offshore 433, deep 18.5. All water below 40 m is ~0-1 fish/ha in 2004-2010 in these
  files (inside and outside the deep stratum). Paused (user).

### 4. Two-gear uncertainty (analysis 17; method 1, analytic; 2026-10-24) -- FIRST ATTEMPT, FROZEN
- (user, 2026-10-24) Continued as its own project, D:\pyprojects\cv_compare_acmt, with its own data (incl. the 25
  Michigan 2021 TARGET 119 survey-time tows and more acoustic data). trawlcomp keeps this version (L_2_Y tows only)
  as the first attempt; steps 17-20 here are not developed further.
- Species density D = rho x p; Var(D) = p^2 Var(rho) + rho^2 Var(p) + Var(rho) Var(p) (Goodman 1960); gears
  independent because sigma is in-situ TS (user). Default frame: the survey regions nn/no/sn/so/wn (user; as
  EchoNet2Fish; FRAME=strata gives the depth-strata version). rho = EchoNet2Fish water-column fish/ha (interval =
  sum of layers), transects as units; p = that year's tows (>= 5 fish, all fishing depths) in the region, SE from
  the region's pooled within-year SD. Lake total = sum(regarea x D). Default year 2021 (most tows; user).
- 2021 lake totals: bloater CV 29% (87% acoustic), alewife CV 33% (59% trawl), smelt CV 72% (83% trawl).
  By region: so bloater 0.92 of the catch, CV 40% (90% acoustic); nn all species trawl-dominated (81-94%; acoustic
  CV only 13%, 7 transects). no, so, wn have 2-3 transects in 2021, so their acoustic SEs are rough.
- Region x depth layer (DEFAULT; user, 2026-10-24: layers split at 40 m, "what I do already"): per region,
  D = sum over layers of rho_layer x p_layer; rho_layer = per interval sum of the 10 m layers' fish_ha in the layer
  (0 where shallower), transects as units (acoustic variance from transect-level species density, keeping the
  layers' covariance); p_layer from that year's tows by fishing depth; a region x layer with no tows that year
  uses the year's lake-wide layer proportion (2021: no >= 40 m; flagged p_source), as EchoNet2Fish's lake-wide
  hypolimnion slice. 2021 lake totals: bloater CV 30% (84% acoustic), alewife CV 32% (60% trawl), smelt CV 85%
  (85% trawl). Fish below 40 m are a few % of the water-column density in every region. Several region x layer
  cells have 1-3 tows; no/so/wn have 2-3 transects.
- Method 2, bootstrap (analysis 18; 2021, 2,000 replicates): transects resampled within region, that year's
  tows within region x layer. Lake totals agree with method 1 (alewife 2.58e9, smelt 4.4e8, bloater 4.84e9) but
  CVs are smaller: alewife 21% (method 1 32%), smelt 32% (85%), bloater 24% (30%). Reasons: the bootstrap uses
  only that year's tows, so region x layers with 1-3 similar tows have little or no trawl variance (method 1
  borrows the all-years within-year SD), and bootstrap SEs from 2-3 transects are biased low. Shares: bloater
  91% acoustic; alewife about half and half; smelt 89% trawl. Method 1 is the more conservative of the two.
- Trawl post-strata (FRAME=region_layer_ps; user: trawl only, acoustic regions kept): upper layer by north (nn, no)
  / south (sn, so, wn) half (>= 5 tows every year), lower layer lake-wide all years pooled (68 tows). 2021 lake
  totals: alewife 3.35e9 (CV 22% method 1 / 20% bootstrap), smelt 0.67e9 (35% / 29%), bloater 3.86e9 (25% /
  22%): the methods now agree. Totals shift vs region x layer (so's 4 upper tows, bloater 0.86, vs the south
  half's 0.55): bias-variance trade-off. Details in docs/TWO_GEAR_METHODS.md.
- Lake-wide mean density (fish/ha, = total / summed region area) added to the lake-total CSVs. 2021, method 1 /
  bootstrap: region x layer alewife 528 (CV 32% / 21%), smelt 91 (85% / 32%), bloater 995 (30% / 24%); post-strata
  alewife 686-693 (22% / 20%), smelt 138 (35% / 29%), bloater 791 (25% / 22%). Bloater = all sizes, by number.

## Open / possible next steps
- mixedtows reads trawlcomp's mixed_tows() live: with 2019-2024 it now gives 63 Huron mixed tows (41 + 22 from
  2019-2024). DECIDED (user, 2026-10-24): mixedtows includes 2019-2024; its next run picks them up.
- 58104 fishing depth (279 alewife only at 60.4 m).
- Size groups (species x length cut) in the stratum framework (theory supports it; needs length data and cuts).

## History (superseded; kept for the record)
- 2026-10-14: single 35 m layer split for effort/SE curves (analysis 05 still uses it); model tow SD first
  lake-wide, then by layer; a median-over-years subsampling summary wrongly suggested the model overstated deep
  Michigan variability (corrected to RMS).
- 2026-10-15: Adams strata tried with no catch minimum, >= 10 fish, >= 10 fish with 3- or 5-tow cells, >= 1 fish
  with 5-tow cells; small catches and 2-3 tow cells made the clustering peel off single noisy cells. Settled on
  >= 5 fish, >= 5 tows (Michigan first 4 strata from >= 10 fish, then 5 strata from >= 5 fish). Outputs of the
  superseded runs deleted 2026-10-24.
- 2026-10-15: 2019 vessel 17 zero END_DEPTH found by comparing with pydt4's acoustic bottom (77 tows; median
  difference 0.3 m); no further bottom checking (user).

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

