# Combined acoustic and trawl uncertainty of species density: methods

Code: `R/two_gear.R`; scripts `analysis/17_two_gear_uncertainty.R` (method 1) and `analysis/18_two_gear_bootstrap.R`
(method 2). Default: Lake Michigan, 2021, survey regions x two depth layers.

## Quantity estimated

- Species density in region r (fish per ha of lake surface):
  **D_rs = sum over layers l of rho_rl x p_rls**
  - rho_rl: acoustic fish density in layer l of region r (fish/ha).
  - p_rls: trawl proportion of species s in layer l of region r.
- Lake total: **N_s = sum over regions of A_r x D_rs**, with A_r the region area (`regarea` in the EchoNet2Fish file).
- Lake-wide mean density: **N_s / sum of A_r** (fish/ha); same CV as the total. Both are in the lake-total CSVs.
- Regions: nn, no, sn, so, wn (Michigan nne, nnw and nnlu pooled into nn). Layers: < 40 m and >= 40 m.
- Species: alewife, rainbow smelt, bloater (proportions by number).

## Data

- **Acoustic:** EchoNet2Fish `intlaymeans_nph` for the year: fish_ha per interval x 10 m layer (NA/Inf = 0),
  with sigma from in-situ TS. The trawl therefore affects only the proportions, and the acoustic and trawl
  estimates are independent.
- **Trawl:** that year's midwater tows in the region with >= 5 fish of the three species. A tow is in the upper
  layer if its fishing depth is < 40 m, otherwise the lower layer. Data rules as in `docs/REPRODUCE.md` section 3
  (including alewife in tows deeper than 40 m set to 0 as contamination).

## Acoustic density per region and layer

- For each interval, rho for a layer = the sum of fish_ha over the interval's 10 m layers within that depth layer.
  Where the water is shallower than 40 m, the lower layer is 0.
- Transect value = the mean of its intervals.
- rho_rl = the mean of the region's transect values. **The transect is the sampling unit.**

## Trawl proportion per region and layer

- p_rls = the mean of the year's tow proportions in the region x layer (every tow counts equally).
- If the region x layer has **no tows that year**, the year's lake-wide proportion for that layer is used, as in
  EchoNet2Fish's lake-wide hypolimnion slice. This is flagged as `p_source = "lake layer"`.

## Method 1: analytic (step 17)

**Acoustic variance**
- For each transect t, compute its whole-water-column species density with the proportions held fixed:
  D_t = rho_upper,t x p_upper + rho_lower,t x p_lower.
  - rho_upper,t: transect t's acoustic fish density (all species) above 40 m: for each of its intervals, the sum
    of the fish/ha of the 10 m layers between 0 and 40 m, averaged over the transect's intervals.
  - rho_lower,t: the same for 40 m and deeper (0 for intervals in water shallower than 40 m).
  - p_upper, p_lower: the region's trawl proportions of the species in each layer; the same for every transect
    in the region (they come from the region's tows, not from the transect).
  - D_t: fish of the species per ha along transect t.
- Var_ac(D_rs) = variance of D_t across the region's transects / number of transects.
- Combining the layers within each transect keeps the covariance between the layers: if transects with many
  fish above 40 m also tend to have many below, that shared variation is counted correctly.
- Holding the p's fixed and letting only rho vary between transects isolates the uncertainty that comes from
  the acoustic sampling.

*Worked example* (bloater in one region; p_upper = 0.30, p_lower = 0.95):

| Transect | rho_upper,t | rho_lower,t | D_t (bloater/ha) |
|---|---|---|---|
| 1 | 800 | 40 | 800 x 0.30 + 40 x 0.95 = 278 |
| 2 | 500 | 10 | 150 + 9.5 = 160 |
| 3 | 1,200 | 60 | 360 + 57 = 417 |

The region's bloater density is the mean of D_t (285 bloater/ha); its acoustic variance is the variance of the
three D_t values divided by 3 (SD 128.6, so Var_ac = 128.6^2 / 3 = 5,516; SE 74.3).

**Trawl variance**
- SE(p_rls) = SD_rls / sqrt(n), where n = the number of that year's tows used for p.
- **SD_rls is the pooled within-year SD from all years** (the "borrowed" SD):
  - For each year with tows in that region x layer, take each tow's deviation from that year's mean proportion.
  - Pool the squared deviations over all years: SD^2 = sum of squared deviations / (total tows - number of years).
  - This is how much one tow in that region x layer typically differs from the other tows of the same year,
    estimated from all 20 years instead of from the year's own 1-20 tows.
  - If the region x layer has fewer than 10 tows over all years, the lake-wide SD for that layer is used.
  - Reason: one year often has 1-3 tows in a region x layer. One tow gives no SD; two similar tows give an SD
    near 0, which reflects chance agreement, not a precisely known proportion.
- Var_tr(D_rs) = sum over layers of rho_rl^2 x SE(p_rls)^2. The layers are independent because they come from
  different tows.

**Combination**
- Var(D_rs) = Var_ac + Var_tr + sum over layers of Var(rho_rl) x SE(p_rls)^2. This is the exact variance of a
  product of independent estimates (Goodman 1960); the last term is the small product term.
- Var(N_s) = sum over regions of A_r^2 x Var(D_rs). Regions are sampled independently.
- Shares: Var_ac / Var, Var_tr / Var and product / Var show which gear drives the uncertainty.

## Method 2: bootstrap (step 18)

- Each of B = 2,000 replicates:
  - resamples the region's transects with replacement (acoustic), recomputing rho_rl;
  - resamples the year's tows within each region x layer with replacement (trawl), recomputing p_rls. A region x
    layer without tows that year resamples the year's lake-wide tows of that layer;
  - recomputes D_rs and N_s.
- SE = SD over replicates; 95% interval = 2.5th-97.5th percentiles.
- Acoustic and trawl shares: two more runs, one resampling only transects (tows fixed) and one resampling only
  tows (transects fixed); share = each run's variance / their sum.

## Trawl post-stratification (option `FRAME=region_layer_ps`; user, 2026-10-24)

- Purpose: avoid region x layer cells with 0-3 tows in a year. **Only the trawl side changes; the acoustic regions
  and layers are kept as above.**
- Upper layer (< 40 m): each region uses the year's mean proportion from its half of the lake:
  north = nn + no; south = sn + so + wn (wn's composition is closer to the south). Every year 2004-2024 has
  >= 5 tows in each half (median 11). SE = the half's pooled within-year SD (all years) / sqrt(the year's tows).
- Lower layer (>= 40 m): every region uses the lake-wide proportion from all years' deep tows pooled (68 tows;
  bloater 0.93, smelt 0.07). Deep tows number 0-8 a year, but deep composition shows no significant year or
  region effect. SE = SD / sqrt(68).
- Bootstrap: upper-layer tows resampled within the year's half; lower-layer tows from the all-years pool.
- Trade-off: much smaller and more stable trawl variance, at the cost of assuming one composition per half
  (upper) and one for the whole lake and all years (lower). Region-level differences inside a half are averaged.

**2021 lake totals (fish), region x layer vs post-strata:**

| | Region x layer: total, CV method 1 / bootstrap | Post-strata: total, CV method 1 / bootstrap |
|---|---|---|
| Alewife | 2.58e9, 32% / 21% | 3.35e9, 22% / 20% |
| Smelt | 0.45e9, 85% / 32% | 0.67e9, 35% / 29% |
| Bloater | 4.85e9, 30% / 24% | 3.86e9, 25% / 22% |

- With post-strata the two methods agree closely, because every trawl cell now has enough tows.
- The totals move (alewife up, bloater down) mainly because so's upper layer used its own 4 tows (bloater 0.86)
  in the region x layer version but the south half's 21 tows (bloater 0.55) here. Which is closer to the truth
  depends on whether so's few 2021 tows represent so; this is the bias side of the trade-off.

## Differences between the methods and when to use each

| | Method 1 (analytic) | Method 2 (bootstrap) |
|---|---|---|
| Trawl variability | Pooled within-year tow SD from all years | Only the year's own tows |
| Region x layer with 1-3 tows | Realistic SE (borrowed SD) | Little or no trawl variance |
| Regions with 2-3 transects | SE from 2-3 values (rough) | SE biased low (few distinct resamples) |
| Distribution | Mean and SE (assumes near-normal) | Full distribution, asymmetric intervals |
| 2021 lake-total CVs | alewife 32%, smelt 85%, bloater 30% | alewife 21%, smelt 32%, bloater 24% |

- Both methods give the same totals and the same ranking of the gears: acoustic dominates bloater, the trawl
  dominates smelt, and alewife is mixed.
- **Method 1 is the more conservative and, for this survey's small per-year samples, the more realistic.**
  The bootstrap is preferable when every region x layer has enough tows (roughly 5 or more) and transects.

## Suggested methods text

> For each survey region, species density was the sum over two depth layers (< 40 m and >= 40 m) of the
> region's acoustic fish density in the layer times the species' trawl proportion for the same region and
> layer. Acoustic density was the mean of transect values, each the mean of its intervals' summed layer
> densities, with transects as the sampling units. Each tow's proportion of a species was its catch of the
> species divided by its catch of the three species (by number); the trawl proportion for a region and layer
> was the mean of these tow proportions over the year's tows in that region whose fishing depth fell in the
> layer, each tow weighted equally (the year's lake-wide proportion for the layer where a region had no tows
> in it). Acoustic variance was estimated from the
> transect-to-transect variation of each transect's whole-water-column species density, with the proportions
> held fixed, which retains the covariance between layers. Trawl variance used the pooled within-year SD of
> tow proportions for the region and layer, estimated from all survey years (2004-2024), divided by the square
> root of the year's number of tows. The variance of each density was the sum of the acoustic and trawl terms
> and their product (Goodman 1960); lake totals were weighted by region area. A bootstrap (2,000 replicates,
> resampling transects within regions and tows within region-layers) gave the same totals and a similar
> partition of the variance.

Reference: Goodman, L. A. 1960. On the exact variance of products. Journal of the American Statistical
Association 55: 708-713.
