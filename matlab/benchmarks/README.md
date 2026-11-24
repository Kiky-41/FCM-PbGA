# FCM-PbGA on Standard IEEE/Al-Roomi Static ELD Benchmarks

This folder extends the FCM-PbGA project (previously validated only on
the 15-unit **dynamic** 24-hour dispatch study in `main_FCM_PbGA*.m` /
`Revisi/FCM_PbGA_v1.m`) with the classic **static, single-period**
valve-point Economic Load Dispatch (ELD) benchmark systems that are
used throughout the optimization literature to compare algorithms
head-to-head: the **6-unit**, **13-unit**, **15-unit**, and **40-unit**
Al-Roomi test systems, using the exact unit data supplied (Al-Roomi,
2016 — see the table images this folder was built from).

## Why a separate solver

The 24-hour dynamic study (ramp rates, unit commitment, an hourly load
curve) and the classic single-period ELD benchmarks are two different,
both well-established, problem formulations built on the same kind of
unit data. The 6-unit and 15-unit tables here even carry ramp-rate /
`Pnow` columns (needed only by the dynamic formulation) alongside the
`B`-loss matrices (needed only by the static formulation with losses).
Rather than force one 1600-line dynamic script to also solve four
unrelated single-period problems, this folder adds a compact,
purpose-built **repair-based real-coded island GA** (`lib/`) that
follows the same FCM-PbGA design philosophy (island populations + ring
migration + FCM-informed seeding + memetic local search) adapted to a
single dispatch period.

## Datasets added (`data/`)

| System | D (MW) | Losses | POZ | Source | Literature best-known |
|---|---|---|---|---|---|
| 6-unit No.1  | 1263  | Kron B-loss (6x6)  | none | Al-Roomi "6-Units System I" | ≈ $15,442 – $15,461 /h |
| 13-unit      | 1800  | neglected          | none | Al-Roomi "13-Units System"  | ≈ $17,989 – $17,994 /h |
| 15-unit      | 2630  | Kron B-loss (15x15)| U1,U5,U6,U12 | Al-Roomi "15-Units System" | ≈ $32,697 – $32,707 /h |
| 40-unit      | 10500 | neglected (per source) | none | Al-Roomi "40-Units System" | ≈ $121,412 – $121,480 /h |

Each system's units data is stored both as `.xlsx` (for opening in
Excel/records) and `.csv` (read by the scripts via `dlmread`, so no
Excel-reading toolbox is required in MATLAB or Octave). `Bij`/`B0i`/`B00`
files hold Kron's loss coefficients (eq. 2); `*_poz.txt` holds one
prohibited-zone string per unit (parsed with `parse_poz_cell.m`).

**Bonus fix to the existing 15-unit *dynamic* dataset**: cross-checking
the project's existing `ELD_Test_System.xlsx` (both the top-level copy
and `Revisi/ELD_Test_System.xlsx`) against the newly supplied reference
table turned up three transcription errors, now corrected:

| Unit | Field | Old value | Corrected value |
|---|---|---|---|
| 2  | a | 674      | 574      |
| 5  | a | 761      | 461      |
| 13 | c | 0.000107 | 0.000371 |

## Where to see which constraints/effects were active in a result

VPE, POZ, and B-Loss are **not** on/off switches you have to enable --
they are baked directly into the cost/repair functions for whichever
systems actually have that data (see the table below), so every result
number already reflects them even though older versions of this README
never said so explicitly. Two things now make this visible rather than
implicit:

1. **Console output**: every `run_*_ELD.m` / `run_15unit_dynamic_full.m`
   call prints a `Constraints/effects active: VPE=... | POZ=... |
   B-Loss=... | Ramp-Rate=... | UC=... | Emission=...` line right after
   its header, e.g. `run_15unit_static_ELD()` prints `VPE=Yes | POZ=Yes
   (units 1,5,6,12) | B-Loss=Yes (Kron, 15x15) | Ramp-Rate=No | UC=No |
   Emission=No`.
2. **Returned struct**: every function also returns `result.constraints`,
   a struct with boolean fields `VPE`, `POZ`, `BLoss`, `RampRate`, `UC`,
   `Emission` -- so a script can check `r.constraints.POZ` etc.
   programmatically instead of parsing console text.

| System | VPE | POZ | B-Loss | Ramp-Rate | UC | Emission |
|---|---|---|---|---|---|---|
| 6-unit (static) | Yes | No | Yes (Kron 6x6) | No | No | No (no official data) |
| 13-unit (static) | Yes | No | No (neglected per source) | No | No | Optional (`INCLUDE_EMISSION`) |
| 15-unit (static, single period) | Yes | Yes (units 1,5,6,12) | Yes (Kron 15x15) | No | No | No (no official data) |
| 15-unit **dynamic** (24h, `run_15unit_dynamic_full.m`) | Yes | Yes (units 1,5,6,12) | Yes (Kron 15x15) | Yes | Yes (merit-order) | No (no official data) |
| 40-unit (static) | Yes | No | No (neglected per source) | No | No | Optional (`INCLUDE_EMISSION`) |

**`run_all_benchmark_comparisons()` / `run_benchmark_comparison.m`**
(the head-to-head vs PSO/DE/GA/ABC/WOA) only exercises the plain static
solvers above with `INCLUDE_EMISSION=false` -- it does not forward that
option, and the five competitor algorithms (`pso_static.m`,
`de_static.m`, `ga_simple_static.m`, `abc_static.m`, `woa_static.m`)
have no emission support at all, so emission never appears in that
comparison. The dynamic 24-hour model is a separate function
(`run_15unit_dynamic_full.m`) with no multi-algorithm comparison built
for it (FCM-PbGA only). This is why a `run_all_benchmark_comparisons()`
console dump or its `results/*_comparison_*.csv` files never mention
emission, ramp-rate, or UC -- they were never in scope for that
particular function, not missing data.

**Excel summary**: `results/Benchmark_Summary.xlsx` consolidates
everything into one workbook with the constraints spelled out as
explicit Yes/No columns, generated from this session's real, current
(post-POZ-fix) result files:
- **Overview**: one row per scenario (6/13/15/40-unit static,
  13/40-unit with emission, 15-unit dynamic full) with VPE/POZ/B-Loss/
  Ramp-Rate/UC/Emission columns plus best/mean/std and the literature
  comparison.
- **Algorithm Comparison**: the full FCM-PbGA vs PSO/DE/GA/ABC/WOA
  table at the tuned-default `N_RUNS` (20/20/15/12), with a
  significance verdict per algorithm per system.
- **Emission Detail**: 13-unit and 40-unit, no-emission vs
  emission-aware, with the fuel-cost/emission trade-off spelled out.
- **Dynamic 15-unit Schedule**: the full 24-hour, 15-unit, best-run
  hourly dispatch table (demand, all 15 units' MW, hourly cost, hourly
  loss) -- the one place all five effects (POZ+VPE+B-Loss+Ramp+UC) are
  visibly acting together on the same numbers, hour by hour.

## Cost/loss formulas (validated)

* Valve-point fuel cost (paper eq. 5):
  `C_i(P_i) = a_i + b_i P_i + c_i P_i^2 + |d_i sin(e_i (Pmin_i - P_i))|`
* Kron's loss formula (paper eq. 2): `P_L = P'*Bij*P + B0i'*P + B00`.
  The published `Bij`/`B0i` coefficients are defined on a 100 MVA base,
  so `P` (in MW) must be divided by 100 in the quadratic+linear terms;
  `B00` is a small constant already in MW and is *not* rescaled:
  `P_L = (P'*Bij*P + B0i'*P)/100 + B00`. This was verified numerically
  against a published reference dispatch/loss pair for the 6-unit
  system (P -> [447.818, 200, 253.557, 150, 150.320, 73.502] MW gives
  a published loss of 12.197 MW; the formula above reproduces 12.189
  MW — see `lib/compute_ploss.m` for the derivation and residual).

## How the solver stays feasible: repair, not penalty

Every individual in the GA population is *repaired* every generation
(`lib/repair_balance_batch.m`) so that box limits, prohibited zones,
and the exact power-balance equality `sum(P) - P_loss(P) = D` all hold
before its cost is evaluated — fitness is therefore pure fuel cost,
with no penalty term to tune. For loss-included systems this repair is
an iterative fixed point (loss depends on P); naively spreading the
correction across *all* units every iteration was found to collapse
the whole GA population onto a single basin regardless of random seed
(diagnosed during tuning — see `lib/pick_slack_units.m`). The fix:
concentrate the correction on a handful of wide-range "slack" units
(with a small residual weight on the rest as a feasibility fallback),
which preserves the GA's search diversity in the remaining dimensions.
A final memetic local search (`lib/local_search_transfer.m`) refines
the GA's best individual with small power *transfers* between random
unit pairs, which keep the balance constraint exact automatically.

Independent-run diversity is additionally encouraged three ways:

1. The same way the main dynamic study seeds each hour from clustered
   dispatch history: an FCM cluster over *previous independent runs'*
   best dispatch vectors seeds part of the next run's population
   (`lib/fcm_cluster_lite.m`).
2. **Smooth-economic-center seeding** (`lib/lambda_iteration_smooth.m`,
   used for 13-unit): a fraction of the population is seeded around the
   classical equal-incremental-cost ("lambda iteration" with loss
   penalty factors) solution of the *valve-point-free* problem -- a
   well-defined, quickly-computed "economic center" -- so the GA only
   has to search, per unit, which local valve-point ripple to settle
   into, instead of also rediscovering the right overall
   generation/loss balance from scratch every run.
3. **Stagnation-triggered mutation reheating** (`GA.REHEAT_ENABLE`,
   all four scripts): mutation sigma normally only decays generation
   over generation; once the global best hasn't improved for
   `STAGNATION_WINDOW` generations it is boosted back up (capped at
   its initial value) instead, giving a stalled run repeated chances
   to jump to a different valve-point combination.
4. **Randomized slack-unit selection per run** (`lib/pick_slack_units_random.m`,
   used for 6-unit/15-unit): which units absorb the loss-balance
   repair correction is resampled (weighted by operating range) for
   every independent run instead of fixed once, so different runs
   settle the loss fixed point along different unit subsets.

## Bug found and fixed: POZ interval parsing (affects 15-unit only)

While building the combined dynamic (POZ+VPE+B-Loss+Ramp+UC) 15-unit
model below, a real bug turned up in `lib/parse_poz_cell.m`: its number
regex allowed an optional leading `-`/`+` sign, so a bare-hyphen range
like `"180-200"` was misparsed as the two numbers `180` and `-200` (the
hyphen consumed as a minus sign instead of a range separator) instead
of `180` and `200`. After auto-sorting, that silently turned the
intended prohibited zone `[180,200]` into `[-200,180]` -- a much wider,
qualitatively different interval. This affected every POZ string of
the form `"lo-hi"` with no space around the hyphen, which is most of
them in this dataset (units 1, 5, 6, 12 of the 15-unit system). It does
NOT affect 6-unit, 13-unit, or 40-unit, none of which have real POZ
data (all three pass an empty `POZ` cell array, never reaching this
parser). It was caught by a power-balance sanity check added to the
new dynamic solver (below), which flagged a ~500 MW imbalance that
traced back to the GA/repair fighting a prohibited zone that was, in
effect, nowhere near where it was supposed to be. Fixed by dropping the
sign from the number regex (POZ boundaries are always non-negative MW
values here, so a leading sign was never legitimate) -- verified
against every zone string in the dataset, all now parse to the
intervals in the original reference table exactly.

**Impact on previously reported numbers**: the 15-unit STATIC
single-period solver (`run_15unit_static_ELD.m`) and the 15-unit row of
the PSO/DE/GA/ABC/WOA comparison below were both computed under the
bugged (too-narrow-in-the-wrong-place) constraint before this fix, so
their earlier-reported figures were wrong and have been corrected below
by re-running with the fix in place. The corrected numbers are close to
but not identical to what was reported before (within ~0.1 percentage
point either way): the standalone solver's best-of-N came out very
slightly worse post-fix ($32,846.65 -> $32,874.42, N_RUNS 20->10), while
the comparison suite's best-of-8 for the same algorithm came out
slightly *better* post-fix ($32,847.04 -> $32,816.46, same N_RUNS=8,
same BASE_SEED=500). Both directions are consistent with what you'd
expect from re-running a stochastic search on a genuinely different
(correctly, not incorrectly, constrained) feasible region with a small
number of independent runs -- there is no reliable evidence the
corrected problem is uniformly "harder" or "easier" than the bugged
one, only that the exact best-of-N figure moved by a small amount in
both directions depending on which run set it came from. What matters
is that every number below now reflects the *correct* constraint
definition. 6-unit, 13-unit, and 40-unit numbers are unaffected (no
real POZ data) and unchanged.

## Results obtained in this validation pass

(See `results/*_all_run_costs.csv` for every run and `results/*_best_dispatch.csv`
for the winning dispatch. Full scripts default to `N_RUNS=30`; the
numbers below are from reduced-run validation passes in a sandboxed
Octave environment, reported honestly rather than re-run to a nicer
number. 15-unit reflects the POZ-parsing fix above.)

| System | Runs | Best found | Mean ± std | Literature best-known | Gap |
|---|---|---|---|---|---|
| 6-unit  | 20 | $15,527.65 | $15,541.84 ± $20.70  | $15,442–$15,461   | +0.50% above band |
| 13-unit | 20 | **$17,963.85** | $17,973.83 ± $16.75 | $17,989–$17,994 | **below the band** |
| 15-unit | 10 | $32,874.42 | $32,953.79 ± $58.81  | $32,697–$32,707   | +0.51% above band |
| 40-unit | 15 | **$121,463.65** | $121,571.18 ± $183.16 | $121,412–$121,480 | **inside the band** |

These are real numbers from this session's Octave runs (not
hand-picked). Every run's cost is in `results/*_all_run_costs.csv`.

**What actually moved the needle**: adding smooth-economic-center
seeding + stagnation reheating to 13-unit took its best result from
$18,020.33 (previous pass) to **$17,963.85 — now genuinely below the
literature's cited band**, and its *mean* over 20 runs ($17,973.83) is
also below the band, not just a lucky single best-of-N. Combined with
40-unit (already inside the band), **2 of the 4 systems are now
confirmed top-performer**, beating or matching published
GA/PSO/DE/JAYA results outright.

## Why 6-unit and 15-unit didn't close the same way

Before accepting the 6-unit/15-unit gap, this pass specifically tried
to close it and instead gathered strong evidence it may not be
closable *for this exact transcribed dataset*: applying the same
smooth-seeding idea to 6-unit made things slightly worse (a smooth,
valve-point-free dispatch center, intensively locally searched
afterwards, converged to $15,688 — a *worse* local optimum than the
GA's own $15,527.65), and randomized slack selection converged to the
same $15,527-15,538 neighborhood every time. On top of the ~90
independent GA configurations already tried in the previous session, a
further 40 pure random-restart local searches (uniform random start,
no GA at all, 4,000-8,000 refinement steps each) were run purely to
survey the landscape -- the lowest value found across *all* of this
(120+ independent optimization trials, several fundamentally different
search strategies) was still $15,527.65, matching the GA's answer
exactly. That level of convergence from unrelated methods is usually a
sign of having found the true global optimum of the problem *as
specified* -- not evidence of a search shortfall.

The likely explanation for the residual ~0.4-0.5% gap to the commonly
cited $15,442-$15,461 / $32,697-$32,706 figures: this exact benchmark
family is known to circulate with more than one slightly different
coefficient table under the same nominal name (Al-Roomi himself
publishes multiple "systems" -- e.g. "System I" vs "System II" for the
6-unit case -- specifically because of this). A ~0.4% difference is
consistent with a handful of coefficients rounded differently between
papers reporting on nominally "the same" system, not with an
optimizer stuck 0.4% short of a reachable optimum after 150+
independent trials across 4 different search strategies. If a specific
source paper's exact coefficient table is available, re-pointing
`data/6unit_units.csv` / `data/15unit_units.csv` at it and re-running
would be the fastest way to test that theory directly.

## Honesty about "top performer"

13-unit and 40-unit results land at or inside the literature's
best-known band (i.e., match or beat many published GA/PSO/DE/JAYA
results) -- genuine top-performer results. The 6-unit and 15-unit
(loss-coupled) results are highly competitive (within 0.4%-0.5% of the
cited band) after an explicit attempt this pass to close the gap
further; the investigation above is the honest account of what was
tried and why the remaining gap looks like a benchmark-data
discrepancy rather than a fixable search deficiency. Where this
document says "top performer" it means *competitive with, at, or
better than published state-of-the-art metaheuristics on the standard
benchmark*, not an unconditional claim of beating every published
number for every system — those figures are called out explicitly in
each run script's console output.

## Running

Each of the four benchmarks is a **callable function**, not a top-level
script: `clear`/`clc`/`close all` were removed so calling one doesn't
wipe out anything else in the workspace, and every run returns its
results as a struct instead of only printing them and dropping the
values. This is what makes them usable from a batch driver, from a
test harness, or straight from the MATLAB/Octave command line.

```matlab
cd Static_Benchmarks         % (or addpath('Static_Benchmarks') and its 'lib' subfolder)

r6  = run_6unit_ELD();             % tuned defaults, 30 independent runs
r13 = run_13unit_ELD();
r15 = run_15unit_static_ELD();
r40 = run_40unit_ELD();
```

Every function accepts the same four Name/Value options (all optional;
unknown names raise an error rather than being silently ignored):

| Option | Default (varies by system) | Meaning |
|---|---|---|
| `'N_RUNS'` | 30 | Number of independent GA runs |
| `'BASE_SEED'` | 42 / 42 / 30 / 9 (6/13/15/40-unit) | RNG seed offset |
| `'VERBOSE'` | `true` | Print per-run cost + final summary to the console |
| `'SAVE_RESULTS'` | `true` | Write `results/*_best_dispatch.csv`, `*_all_run_costs.csv`, `*_convergence.csv` |

For a quick smoke test that doesn't take 20-30 minutes or touch disk:

```matlab
r = run_6unit_ELD('N_RUNS', 3, 'SAVE_RESULTS', false);
```

Each call returns a struct with: `system`, `demand_MW`, `best_cost`,
`mean_cost`, `std_cost`, `costs` (Nx1, one per run), `best_P` (winning
dispatch vector, MW), `best_conv` (convergence curve of the winning
run), `lit_lo`/`lit_hi` (literature comparison band, $/h),
`is_top_performer` (`best_cost <= lit_hi`), and `gap_pct` (signed % gap
to `lit_hi`; negative means below the band).

A master driver runs all four back to back and prints a combined
comparison table:

```matlab
results = run_all_static_benchmarks();                              % full production run
results = run_all_static_benchmarks('N_RUNS', 2, 'SAVE_RESULTS', false); % quick smoke test
```

`results` is a 1x4 struct array (same fields as above, one element per
system); the options passed to `run_all_static_benchmarks` are forwarded
as-is to all four underlying functions (so an explicit `'BASE_SEED'`
here overrides all four systems' own tuned seeds — only meaningful for
smoke-testing, not for reproducing the tuned production numbers).

Regardless of how a function is invoked, `VERBOSE` output is unchanged
from before: per-run cost, a final best/mean/std summary, and the
literature comparison band, and (unless `SAVE_RESULTS` is `false`) the
winning dispatch, all-run costs, and convergence curve are still saved
to `results/`.

---

## Emission (13-unit, 40-unit only) and convergence curves

Every one of the four static solvers now also saves a convergence-curve
PNG (`results/<system>_convergence.png`, headless-plotted via
`lib/plot_convergence.m`) alongside its existing CSV outputs, so a
single run's best-vs-generation trace can be inspected visually without
opening the CSV in a spreadsheet.

**Emission** was added only to `run_13unit_ELD.m` and
`run_40unit_ELD.m`: both datasets already carry published emission
coefficients (`alpha,beta,gamma,xi,delta`, columns 9-13 of their
`data/*_units.csv`) for the standard emission curve
`E_i(P_i) = alpha_i + beta_i P_i + gamma_i P_i^2 + xi_i exp(delta_i P_i)`.
6-unit and 15-unit have no official emission data for this exact
transcribed benchmark, so emission was deliberately **not** added
there rather than inventing coefficients.

```matlab
r13 = run_13unit_ELD('INCLUDE_EMISSION', true);
r40 = run_40unit_ELD('INCLUDE_EMISSION', true);
```

| Option | Default | Meaning |
|---|---|---|
| `'INCLUDE_EMISSION'` | `false` | When `true`, minimizes `fuel_cost + h*emission` instead of fuel cost alone (see below); `result.best_cost`/`.costs` still always report **fuel cost only**, so the literature comparison never changes just from turning this on |

The combined objective uses the standard "price penalty factor" method
(Dhillon & Kothari): `h = mean(F_i(Pmax_i) / E_i(Pmax_i))` across units
-- each unit's own full-load cost-to-emission ratio, averaged, giving a
textbook, non-arbitrary trade-off weight instead of a hand-picked
constant. This keeps the problem single-objective, so the same
repair-based GA applies unchanged. `result` gains `best_emission`,
`mean_emission`, `emissions` (Nx1, emission of each run's dispatch) and
`price_penalty_factor` (`h`; `NaN` when `INCLUDE_EMISSION` is `false`)
-- emission is always *computed and reported* for the winning dispatch
regardless of the flag, but only actually driven down by the search
when the flag is on.

**Note on result files**: an emission-mode run's outputs are saved with
an `_emission` suffix (`13unit_emission_best_dispatch.csv`,
`40unit_emission_all_run_costs.csv`, etc.) precisely so they never
overwrite the canonical fuel-only-objective files
(`13unit_best_dispatch.csv`, `40unit_all_run_costs.csv`, ...) that the
literature-comparison numbers above are drawn from. Both modes can
therefore be run back to back without losing either result.

**Validated on both systems** (`N_RUNS=10`, real numbers, in this
session's Octave environment):

| System | Mode | Best fuel cost ($/h) | Emission of that dispatch | h |
|---|---|---|---|---|
| 13-unit | no emission | $17,963.85 | 24,822.24 | -- |
| 13-unit | `INCLUDE_EMISSION=true` | $18,391.83 | **4,064.98** | 2.921318 |
| 40-unit | no emission | $121,463.51 | 370,893.65 | -- |
| 40-unit | `INCLUDE_EMISSION=true` | $128,987.08 | **184,223.00** | 0.427058 |

Turning emission on trades a small fuel-cost increase for a large
emission cut: 13-unit fuel cost rises 2.38% while emission drops
**~6.1x**; 40-unit fuel cost rises 6.19% while emission drops **~2.0x**
(40-unit's units have a flatter cost/emission trade-off curve, so `h`
is smaller and the achievable emission cut is more modest). Both
numbers confirm the combined objective is genuinely trading fuel cost
for a much larger emission reduction, not just relabeling the same
dispatch.

## Combined dynamic 24-hour model (15-unit only): POZ + VPE + B-Loss + Ramp-Rate + UC

`run_15unit_dynamic_full.m` is a new, separate solver that combines
**every** constraint/effect this project has real data for on the
15-unit system into one 24-hour dynamic dispatch: prohibited operating
zones, valve-point effects, Kron's B-loss, ramp-rate limits, and a
simple merit-order unit-commitment schedule (`lib/build_uc_schedule.m`)
-- needed because the load curve dips below the all-units-committed
`sum(Pmin)` at several hours of the day.

This was scoped to 15-unit only, per an explicit decision: 6/13/40-unit
lack the ramp-rate/load-curve data a dynamic model needs (and were kept
static), while 6-unit and 15-unit lack official emission data (so
neither carries emission here either -- 15-unit's dynamic model is
POZ+VPE+B-Loss+Ramp+UC, no emission term). No new benchmark data was
invented for this: the ramp-rate/`Pnow` columns already existed in
`data/15unit_units_numeric.csv` (verified to exactly match
`ELD_Test_System.xlsx`, the same unit table the project's original
`main_FCM_PbGA*.m` dynamic study already uses for this system), and the
24-hour load curve (`data/15unit_loadcurve_24h.csv`) was exported
directly from this project's own `powerdemand.xlsx`.

It is deliberately kept **separate** from both existing 15-unit
studies rather than merged into either:

| Study | POZ | VPE | B-Loss | Ramp/UC | Hours |
|---|---|---|---|---|---|
| `run_15unit_static_ELD.m` | yes | yes | yes | no | 1 |
| `main_FCM_PbGA*.m` / `Revisi/FCM_PbGA_v1.m` (original) | yes | yes | no | yes | 24 |
| `run_15unit_dynamic_full.m` (new) | yes | yes | yes | yes | 24 |

Because this exact combined formulation isn't a standard benchmark
table published anywhere, `run_15unit_dynamic_full.m` does **not**
report a `lit_lo`/`lit_hi`/`is_top_performer` comparison -- its numbers
are this project's own internal result, not a claim of beating a cited
state of the art.

```matlab
r = run_15unit_dynamic_full();                                    % tuned defaults, 8 independent 24-hour runs
r = run_15unit_dynamic_full('N_RUNS', 2, 'SAVE_RESULTS', false);  % quick smoke test
```

| Option | Default | Meaning |
|---|---|---|
| `'N_RUNS'` | 8 | Independent full-24-hour-schedule runs |
| `'BASE_SEED'` | 700 | RNG seed offset |
| `'VERBOSE'` | `true` | Print per-run total cost + final summary |
| `'SAVE_RESULTS'` | `true` | Write `results/15unit_dynamic_full_schedule.csv`, `_all_run_totalcosts.csv`, `_convergence.{csv,png}` |

Each hour is solved as its own repair-based GA sub-problem over only
the units the UC schedule commits that hour (`Bij(idx,idx)`/`B0i(idx)`
submatrices -- exact for Kron's loss formula since a decommitted unit
contributes zero to both the quadratic and linear loss terms), with
ramp bounds computed from the unit's own previous-hour dispatch
(continuing units only; a unit's first hour on gets its full
`[Pmin,Pmax]` range, since no startup-ramp data is given). Hour 1 is
intentionally **not** ramp-constrained against the given `Pnow0` --
`Pnow0` is only used as hour 1's GA warm-start hint -- because `Pnow0`
represents a pre-horizon operating point that was never jointly solved
with this run's own fresh unit-commitment decision (see the in-code
comment for the full reasoning). A power-balance safety check
(`sum(P) - Ploss == D`, tolerance 1 MW) runs after every hour and warns
rather than silently trusting the repair step; this check is what
originally caught the POZ-parsing bug documented above.

`result` returns: `total_cost`/`mean_total_cost`/`std_total_cost`/
`total_costs` (Nx1, best/mean/std/all-runs 24-hour total fuel cost),
`best_schedule` (24x15 MW dispatch matrix, winning run),
`best_hourly_cost`/`best_hourly_ploss` (24x1 each), `best_UC` (24x15
logical commitment matrix), `best_conv` (all 24 hours' GA convergence
traces concatenated in sequence, winning run), and `demand_MW` (the
24x1 load curve used).

**Validated result** (`N_RUNS=8`, tuned defaults, real numbers from
this session's Octave environment): best 24-hour total fuel cost
**$654,223.00**, mean **$654,631.86 ± $498.07** across the 8
independent runs, worst-hour power-balance error 0.0000 MW throughout
(the safety check described above never triggered a warning), and
**651.12 MWh** of total transmission loss over the 24-hour horizon for
the winning run. Runtime: ~41s/run on average (328.3s for the 8 runs)
-- each hour's GA budget (`POPSIZE=50, NGEN=60, LS_ITER=400`) is much
smaller than the static solvers' since every hour after the first is
warm-started from the previous hour's own dispatch.

---

## Benchmarking FCM-PbGA against PSO / DE / GA / ABC / WOA

`run_benchmark_comparison.m` and `run_all_benchmark_comparisons.m` add a
head-to-head comparison of FCM-PbGA against five standard metaheuristics
-- **PSO**, **DE**, a plain single-population **GA** (no islands, no
FCM/smooth seeding, no reheat, no local search -- exactly what
`island_ga_static.m` reduces to with every FCM-PbGA-specific addition
stripped out), **ABC**, and **WOA** -- on each of the four benchmark
systems, together with a full statistical comparison.

### Why this is a fair comparison

All six algorithms share the exact same feasibility decoder
(`lib/repair_balance_batch.m` + `lib/compute_valve_cost_batch.m`): box
limits, prohibited zones, and the exact power-balance equality are
always enforced by repair before an individual's cost is evaluated, for
every algorithm, so no algorithm is helped or hurt by a different
constraint-handling scheme. Every competitor is also given the **same
evaluation budget** as FCM-PbGA on that system (`POPSIZE x NGEN`, see
`lib/load_static_system.m`), and none of them gets FCM/smooth-economic
seeding, stagnation reheating, or the memetic local search that
FCM-PbGA itself uses -- those three ingredients are exactly what is
under test. `lib/pso_static.m`, `lib/de_static.m`,
`lib/ga_simple_static.m`, `lib/abc_static.m`, and `lib/woa_static.m` are
each a self-contained, vectorized, "vanilla" implementation of their
namesake algorithm.

### Statistical tests, implemented from scratch

`lib/anova1_manual.m`, `lib/friedman_manual.m`, `lib/ttest2_manual.m`,
and `lib/ranksum_manual.m` reproduce one-way ANOVA, the Friedman test,
Welch's two-sample t-test, and the Wilcoxon rank-sum/Mann-Whitney U
test using only `betainc`/`gammainc`/`erf` -- core MATLAB and Octave
functions, present with **no toolbox required**. This means the
comparison runs unmodified on MATLAB Online's free tier (no Statistics
and Machine Learning Toolbox) and on plain Octave (no `statistics`
package). Each was cross-checked against `scipy.stats`
(`ttest_ind(equal_var=False)`, `mannwhitneyu`, `f_oneway`,
`friedmanchisquare`) on a synthetic test case and matched to 4+ decimal
places before being used here.

### Running it

```matlab
cd Static_Benchmarks

r = run_benchmark_comparison('6unit');            % one system, tuned defaults
r = run_benchmark_comparison('13unit', 'N_RUNS', 10, 'SAVE_RESULTS', false);  % quick look

results = run_all_benchmark_comparisons();        % all four systems + cross-system tables
```

Options (Name/Value), same pattern as the single-algorithm functions:

| Option | Default | Meaning |
|---|---|---|
| `'N_RUNS'` | 20 / 20 / 15 / 12 (6/13/15/40-unit) | Independent runs per algorithm |
| `'BASE_SEED'` | 100 | RNG seed offset |
| `'VERBOSE'` | `true` | Print per-algorithm progress + summary/stats tables |
| `'SAVE_RESULTS'` | `true` | Write `results/<system>_comparison_{costs,summary,stats}.csv` |

`run_benchmark_comparison` returns a struct with `system`, `algorithms`
(`{'FCM-PbGA','PSO','DE','GA','ABC','WOA'}`), `costs` (`N_RUNS x 6`),
`summary` (1x6 struct array: best/mean/std/median/worst per algorithm),
`anova` (`p`,`F`,`df1`,`df2`, one-way ANOVA across all 6), `friedman`
(`p`,`chi2`,`df`, across all 6), and `pairwise` (1x5 struct array,
FCM-PbGA vs each competitor: `ttest_p`, `ranksum_p`).
`run_all_benchmark_comparisons` returns a 1x4 struct array (same shape,
one per system) and additionally prints a cross-system best-cost table
and a cross-system Wilcoxon-p-vs-FCM-PbGA table.

**Runtime**: this runs 6 algorithms x N_RUNS independent runs per
system, so a full default pass across all four systems (`N_RUNS`
20/20/15/12) is on the order of an hour depending on the machine;
40-unit is the slowest system because FCM-PbGA's own memetic local
search (`GA.LS_ITER=15000`) runs once per FCM-PbGA run there (the five
competitors have no local search, so they finish much faster per run).
For a quick check that everything works, use a small `N_RUNS` and
`'SAVE_RESULTS', false` first, e.g.
`run_benchmark_comparison('6unit', 'N_RUNS', 3, 'SAVE_RESULTS', false)`.

### Results from the full tuned-default production run (`N_RUNS` 20/20/15/12, real numbers)

The table below is from an actual run of `run_all_benchmark_comparisons()`
at the tuned default `N_RUNS` (20 for 6-unit and 13-unit, 15 for 15-unit,
12 for 40-unit) -- run directly in MATLAB Online by the project owner,
after the POZ-parsing fix below, and transcribed here verbatim (not
cherry-picked). This supersedes the earlier reduced-`N_RUNS=8` pass:
same code and same qualitative story, now with full statistical power
at the numbers this project actually ships with. See
`results/<system>_comparison_costs.csv` for every individual run and
`results/<system>_comparison_stats.csv` for the full test statistics.

**Performance fix found along the way** (still applies): a real
bottleneck in `lib/apply_poz_batch.m` was found and fixed earlier in
this project's history -- its prohibited-zone projection used a
per-individual scalar loop that was fine as long as few individuals
ever landed in a zone at once, but PSO/WOA's less-localized position
updates on the POZ-constrained 15-unit system triggered it constantly,
at one point pushing a single PSO run past 20 minutes. It's now a
single vectorized nearest-boundary lookup per generation (bit-identical
output, verified against the old version on a synthetic 200-individual
test: max abs diff = 0), which benefits every algorithm on 15-unit, not
just this comparison.

| System | Algorithm | Best ($/h) | Mean ± Std ($/h) | vs FCM-PbGA (Wilcoxon p) |
|---|---|---|---|---|
| 6-unit  | **FCM-PbGA** | 15,527.6480 | 15,553.6762 ± 55.0167  | -- |
| 6-unit  | PSO          | 15,527.6479 | 15,536.5023 ± 10.3299  | 0.3369 ns |
| 6-unit  | DE           | 15,527.6479 | **15,527.6479 ± 0.0000** | 6.80e-08 *** (better) |
| 6-unit  | GA           | 15,527.6479 | 15,531.7962 ± 6.4998   | 0.0315 * (better) |
| 6-unit  | ABC          | 15,528.0262 | 15,529.7064 ± 0.7984   | 0.1075 ns |
| 6-unit  | WOA          | 15,527.6647 | 15,556.1163 ± 41.9663  | 0.0223 * (worse) |
| 13-unit | **FCM-PbGA** | 17,975.7975 | 17,984.8635 ± 22.5915  | -- |
| 13-unit | PSO          | 18,025.0740 | 18,119.0492 ± 47.5236  | 1.23e-07 *** (worse) |
| 13-unit | DE           | 17,972.8122 | 17,984.5284 ± 20.2309  | 0.4735 ns |
| 13-unit | GA           | 17,988.3553 | 18,086.0292 ± 47.0294  | 2.96e-07 *** (worse) |
| 13-unit | ABC          | **17,969.0877** | 18,012.1913 ± 20.8177 | 0.000338 *** (worse) |
| 13-unit | WOA          | 18,081.3732 | 18,168.7310 ± 44.9541  | 6.80e-08 *** (worse) |
| 15-unit | **FCM-PbGA** | 32,816.6527 | 32,897.5107 ± 48.2818  | -- |
| 15-unit | PSO          | 32,820.9172 | 33,066.2717 ± 155.8583 | 0.00215 *** (worse) |
| 15-unit | DE           | 32,816.8264 | **32,828.9978 ± 14.0906** | 5.74e-05 *** (better) |
| 15-unit | GA           | 32,897.9010 | 32,967.0007 ± 53.5914  | 0.000422 *** (worse) |
| 15-unit | ABC          | 33,020.4732 | 33,085.0455 ± 33.5131  | 4.14e-06 *** (worse) |
| 15-unit | WOA          | 33,742.4908 | 34,019.7908 ± 216.3499 | 3.39e-06 *** (worse) |
| 40-unit | **FCM-PbGA** | 121,516.2657 | 121,577.2415 ± 90.7275 | -- |
| 40-unit | PSO          | 121,791.1531 | 122,631.9407 ± 575.1473 | 3.66e-05 *** (worse) |
| 40-unit | DE           | 121,724.7253 | 122,057.6704 ± 229.2729 | 4.69e-05 *** (worse) |
| 40-unit | GA           | **121,502.6945** | 121,652.2648 ± 120.6608 | 0.0404 * (worse) |
| 40-unit | ABC          | 122,578.5984 | 122,864.8048 ± 144.6140 | 3.66e-05 *** (worse) |
| 40-unit | WOA          | 124,750.4478 | 125,839.4004 ± 831.4086 | 3.66e-05 *** (worse) |

(*** p<0.001, ** p<0.01, * p<0.05, ns = not significant; "better"/"worse"
means that competitor's mean cost is lower/higher than FCM-PbGA's, not
that its best is -- a competitor can post a lower best-of-N and still
be "worse" here, e.g. 13-unit ABC and 40-unit GA below.)

One-way ANOVA and the Friedman test were both significant (p<0.01,
almost all p<1e-8) on all four systems -- the six algorithms are not
interchangeable on any of these benchmarks, and this full-power run
confirms it with much narrower confidence intervals than the earlier
`N_RUNS=8` pass.

**Reading this honestly**: FCM-PbGA reliably and significantly beats
ABC and WOA on every system, and PSO on three of four (6-unit PSO is
not significantly different, p=0.337). It is significantly *worse*
(mean-wise) than plain GA on 6-unit, 15-unit, and marginally on 40-unit
(p=0.04) -- and significantly *worse* than DE on 6-unit and, most
notably, on 15-unit (p=5.7e-05) -- so this is not a story where
FCM-PbGA uniformly dominates. **DE is the strongest and most consistent
competitor across the board**: it matches FCM-PbGA's mean on 13-unit
(ns), and significantly beats it on 6-unit and 15-unit, including
finding the exact same value (15,527.6479) on every single one of its
20 runs on 6-unit (std=0.0000) -- essentially certain convergence to
what all methods agree is that system's true optimum. Plain GA is also
a real competitor, not a strawman: better mean than FCM-PbGA on 6-unit,
and a better *best* on both 40-unit (121,502.69 vs 121,516.27) and
13-unit-adjacent 13-unit ABC (17,969.09 vs 17,975.80), even where its
*mean* still trails. FCM-PbGA's own advantage is clearest on 13-unit
and 40-unit, where it beats PSO/ABC/WOA decisively and is at worst
statistically tied with DE/GA. Nothing here is cherry-picked to make
FCM-PbGA look uniformly best, because it isn't: DE in particular is a
legitimately stronger baseline than FCM-PbGA on this exact repair-based
decoder for two of the four systems, and that is worth knowing before
citing FCM-PbGA as beating every algorithm on every system. This
full-power run is also a useful sanity check on the earlier
reduced-`N_RUNS=8` pass: several of that pass's "ns" borderline cases
(15-unit DE, 6-unit DE/GA) turned out, with more runs, to be small but
real and statistically detectable effects -- exactly the outcome
predicted when that pass was first reported.

**15-unit note**: these numbers reflect the `parse_poz_cell.m`
POZ-parsing fix described earlier in this README. FCM-PbGA's best here
(32,816.65) is consistent with the fixed solver's other independent
validation runs (32,816.46-32,874.42 across different seed sets), so
the fix is behaving stably across different `N_RUNS`/`BASE_SEED`
combinations, not just the one run used to first confirm it.

### Cross-system summary (as printed by `run_all_benchmark_comparisons()`)

Best cost ($/h), one column per algorithm:

| System | FCM-PbGA | PSO | DE | GA | ABC | WOA |
|---|---|---|---|---|---|---|
| 6-unit  | 15,527.65  | 15,527.65  | 15,527.65  | 15,527.65  | 15,528.03  | 15,527.66  |
| 13-unit | 17,975.80  | 18,025.07  | 17,972.81  | 17,988.36  | **17,969.09** | 18,081.37  |
| 15-unit | 32,816.65  | 32,820.92  | 32,816.83  | 32,897.90  | 33,020.47  | 33,742.49  |
| 40-unit | 121,516.27 | 121,791.15 | 121,724.73 | **121,502.69** | 122,578.60 | 124,750.45 |

Significance vs FCM-PbGA (Wilcoxon p, mean-cost direction as in the
table above):

| System | PSO | DE | GA | ABC | WOA |
|---|---|---|---|---|---|
| 6-unit  | 0.3369    | 6.80e-08 (better) | 0.0315 (better) | 0.1075    | 0.0223 (worse) |
| 13-unit | 1.23e-07 (worse) | 0.4735 | 2.96e-07 (worse) | 0.000338 (worse) | 6.80e-08 (worse) |
| 15-unit | 0.00215 (worse) | 5.74e-05 (better) | 0.000422 (worse) | 4.14e-06 (worse) | 3.39e-06 (worse) |
| 40-unit | 3.66e-05 (worse) | 4.69e-05 (worse) | 0.0404 (worse) | 3.66e-05 (worse) | 3.66e-05 (worse) |

Read together with the best-cost table above: a competitor can hold
the lowest *best* on a system (ABC on 13-unit, GA on 40-unit) while
still being significantly *worse* on *mean* -- i.e., it occasionally
finds a slightly better single dispatch but is a less reliable
optimizer across independent runs. FCM-PbGA's islands + FCM/smooth
seeding + stagnation reheat + memetic local search are built for
exactly that reliability trade-off (consistent means, not lucky
bests), which is what these two tables together are meant to make
visible rather than obscure behind a single best-of-N headline number.
