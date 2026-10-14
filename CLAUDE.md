# trawlcomp

Variability of species and species-size-group proportions in midwater trawl catches (Lake Michigan and
Lake Huron acoustic-survey tows). The question: if a midwater tow were repeated at the same place and
time, what would be the mean proportion of a group and its SD? Selectivity is out of scope for now.

**Read `STATUS.md` first.** It holds current status, decisions and the task list.

## Data (read only; never copy, edit, move or delete)
- Trawl data: `D:\pyprojects\bloaterTS\data\raw\trawl\` (master copy, owned by bloaterTS).
  `TR_OP.csv`/`OP.csv` (operations), `TR_CATCH.csv` (catch), `TR_LF.csv` (length frequency),
  per-year `L_2_Y_<year>_Acoustic_{optrop,tr_catch,tr_lf}.csv`; provenance in `sources.csv` there.
- Tow lists: `D:\pyprojects\bloaterTS\data\raw\LM_tow_list_2005_2024.csv`, `LH_tow_list_2004_2018.csv`.
- Lake sources (user, 2026-10-14): Michigan tows, catch and lengths come ONLY from the `L_2_Y_<year>_Acoustic_*`
  files (never OP.csv and the associated release files). Huron comes from the release, TARGET 209/210 in OP_TARGET.csv.
- Paths are set once in `R/paths.R`. Never hard-code them elsewhere.

## Environment
- R 4.4.0: `C:\Program Files\R\R-4.4.0\bin\Rscript.exe` (4.6.1 lacks packages).
- Code lives in `R/` (functions); `analysis/` holds scripts/Rmd that only call them; results go to `output/`.

## Method so far (from the 2026-10-14 discussion)
- The tow is the sampling unit, not the fish: fish in one tow are a cluster. The binomial SD
  sqrt(p(1-p)/n) is a LOWER bound.
- Model: beta-binomial (one group) / Dirichlet-multinomial (several groups). Var(p_hat) =
  mu(1-mu)/n * [1 + (n-1)rho]; effective n = n / [1 + (n-1)rho]. Equivalent: binomial GLMM with a tow
  random effect; a simulated new tow gives the "repeat this tow" distribution. Check with a two-stage
  bootstrap (tows, then fish within tows).
- No true replicates: rho is estimated from a group of pseudo-replicate tows (same lake/year/depth layer/
  night period, as tight as the data allow). Real differences among them inflate rho, so the result is an
  UPPER bound. Report it bracketed by the binomial lower bound.
- If groups come from a length subsample, the subsample n is the within-tow n (third sampling stage).
- References: Pennington & Volstad 1994; Pennington, Burmeister & Hjellvik 2002.

## Working rules
- The user is the fisheries/bloater-biology expert. Take stats decisions one step at a time; ask before
  changing a settled choice.
- At session end, update `STATUS.md`, commit and `git push`.
