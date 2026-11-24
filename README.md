# FCM-PbGA

**Structural feasibility handling in non-convex economic dispatch: Integrating fuzzy C-means clustering with a diagnostically-redesigned genetic algorithm**

Ikhsan, Rifki Rahman Nur · Suhartono, Efri · Raharjo, Jangkung · Yustika, Lindiasari Martha · Wijaya, I Gede Putu Oka Indra  
*IJOCTA, 2026*  
[![DOI](https://img.shields.io/badge/DOI-10.36922%2FIJOCTA026400306-blue)](https://doi.org/10.36922/IJOCTA026400306)

Fuzzy C-Means Population-Based Genetic Algorithm for non-convex economic dispatch with VPE, POZ, ramp-rate and unit commitment.

## Abstract

Practical thermal economic dispatch (ED) problems with valve-point effects (VPE), prohibited operating zones (POZ), ramp-rate limits, and unit commitment (UC) decisions are non-smooth, non-convex, and fragmented, which defeats gradient-based solvers. This paper presents a feasibility-aware computational intelligence framework—the Fuzzy C-Means Population-Based Genetic Algorithm (FCM-PbGA)—that embeds commitment-consistent encoding, FCM-guided initialisation, ramp-feasible bounds, POZ-aware projection, and Lamarckian refinement in a single-population evolutionary architecture. The framework is evaluated on the IEEE 15-unit, 24-hour benchmark (30 trials). The initial island-based architecture (Stage 1) achieves $662,173 ± $2,151. Budget-matched re-runs and ablation isolate architecture from budget: fixed six-island partitioning proves counterproductive, and the matched GA outperforms Stage 1. Three redesigns follow: adaptive merging, reheating, POZaware crossover and fractional seeding close 49% of the gap; corrected operators close an additional 36%; and removing islands entirely (v4) reaches $655,073.62 ± $1,469—a statistical tie with the matched GA (p = 0.199, d = −0.34) under published conditions, and a significant lead (p = 5.2 × 10−6, d = −1.34) with correctly loaded POZ sets and strict repair. Zero power-balance, ramp-rate, POZ, and generation-limit violations are verified over 10,800 unit-hours. The study demonstrates a diagnose-then-redesign methodology for constrained engineering scheduling.


## Proposed method

FCM-PbGA combines a feasibility-preserving chromosome with an island-based genetic algorithm. Fuzzy C-Means clusters historical dispatch vectors and seeds the population near the cluster centre closest to the previous hour; ramp- and POZ-aware projection keeps every candidate feasible; BLX-$\alpha$ crossover and adaptive Gaussian mutation explore; ring migration shares elites; and a greedy Lamarckian search refines the final dispatch. The method is evaluated on the IEEE 15-unit, 24-hour benchmark with valve-point effects, prohibited operating zones, ramp limits and unit commitment.

### Objective and constraints

Only committed units contribute cost, and the valve-point term adds a sinusoidal ripple to the quadratic curve:

$$\min F(\mathbf{P},\mathbf{u})=\sum_{i=1}^{N}u_i\left(a_i+b_iP_i+c_iP_i^2+\left|d_i\sin\left(e_i\left(P_i^{\min}-P_i\right)\right)\right|\right).$$

The schedule must satisfy

$$\sum_iP_i=P_D+P_L,\qquad u_iP_i^{\min}\le P_i\le u_iP_i^{\max},\qquad \sum_iu_iP_i^{\max}\ge P_D,$$

$$P_i\notin\bigcup_{k=1}^{K_i}\left[P_{i,k}^{L},P_{i,k}^{U}\right],\qquad -R_i^{D}\le P_i^{t}-P_i^{t-1}\le R_i^{U}.$$

The first line balances power, forces offline units to zero, and requires enough committed capacity. The second line removes prohibited zones and limits the change between hours.

### Notation

| Symbol | Meaning | Unit |
|---|---|---|
| $N$ | number of units | – |
| $P_i^{t}$ | output of unit $i$ at period $t$ | MW |
| $u_i^{t}$ | commitment state, 1 online / 0 offline | – |
| $a_i,b_i,c_i$ | fuel-cost coefficients | – |
| $d_i,e_i$ | valve-point amplitude and frequency | – |
| $P_i^{\min},P_i^{\max}$ | generation limits | MW |
| $P_D^{t}$ | demand at period $t$ | MW |
| $R_i^{U},R_i^{D}$ | ramp-up and ramp-down limits | MW/h |
| $[P_{i,k}^{L},P_{i,k}^{U}]$ | $k$-th prohibited operating zone | MW |
| $L_i^{t},U_i^{t}$ | ramp-effective lower and upper bounds | MW |
| $\Omega_i^{t}$ | admissible set after ramp and POZ removal | MW |
| $u_{kj}$ | FCM membership of sample $j$ in cluster $k$ | – |
| $\mathbf{c}_k$ | FCM cluster centre | MW |
| $m$ | FCM fuzzification parameter | – |
| $\alpha$ | BLX expansion parameter | – |
| $\sigma_j$ | mutation standard deviation of gene $j$ | MW |
| $\gamma,\rho$ | initial mutation scale and decay rate | – |
| $\mathcal{P}_s$ | population of island $s$ | – |

### Ramp- and POZ-feasible region

Ramp limits make the bounds time-varying. An off-to-on transition starts from zero rather than from the minimum:

$$L_i^{t}=
\begin{cases}
0, & u_i^{t-1}=0,~u_i^{t}=1,\\
\max\left(P_i^{\min},P_i^{t-1}-R_i^{D}\right), & \text{otherwise},
\end{cases}
\qquad
U_i^{t}=
\begin{cases}
\min\left(P_i^{\max},R_i^{U}\right), & u_i^{t-1}=0,~u_i^{t}=1,\\
\min\left(P_i^{\max},P_i^{t-1}+R_i^{U}\right), & \text{otherwise}.
\end{cases}$$

Removing the prohibited zones leaves a union of disjoint intervals:

$$\Omega_i^{t}=\left[L_i^{t},U_i^{t}\right]\setminus\bigcup_{k=1}^{K_i}Z_{i,k}.$$

Every candidate is projected onto this set:

$$P_i\leftarrow\Pi_{\Omega_i^{t}}(P_i)=\arg\min_{y\in\Omega_i^{t}}|y-P_i|.$$

The projection moves an infeasible value to the nearest admissible point, so crossover and mutation cannot inject ramp or POZ violations into the population.

### FCM seeding

Fuzzy C-Means minimises the weighted distance to the cluster centres:

$$J_{\mathrm{FCM}}=\sum_{j=1}^{M}\sum_{k=1}^{C}u_{kj}^{m}\left\Vert\mathbf{x}_j-\mathbf{c}_k\right\Vert_2^2,\qquad \sum_{k=1}^{C}u_{kj}=1.$$

The centres and memberships are updated alternately:

$$\mathbf{c}_k=\frac{\sum_{j=1}^{M}u_{kj}^{m}\mathbf{x}_j}{\sum_{j=1}^{M}u_{kj}^{m}},\qquad
u_{kj}=\left(\sum_{l=1}^{C}\left(\frac{\left\Vert\mathbf{x}_j-\mathbf{c}_k\right\Vert_2}{\left\Vert\mathbf{x}_j-\mathbf{c}_l\right\Vert_2}\right)^{\frac{2}{m-1}}\right)^{-1}.$$

The membership equation gives a sample a high degree in a nearby cluster and a low degree in a distant one. The seed for period $t$ is the centre nearest to the previous dispatch:

$$k^{\ast}=\arg\min_k\left\Vert\mathbf{c}_k-\mathbf{P}^{t-1}\right\Vert_2,\qquad \mathbf{P}^{t}_{\text{seed}}=\mathbf{c}_{k^{\ast}}.$$

### Genetic operators

Parents are chosen by tournament:

$$\boldsymbol{\theta}^{\text{sel}}=\arg\min_{\boldsymbol{\theta}\in\mathcal{T}}F(\boldsymbol{\theta}),\qquad |\mathcal{T}|=\kappa.$$

An offspring gene is either copied from the first parent or sampled in the expanded parental interval:

$$\theta_j'\sim\mathcal{U}\left(\min(\theta_j^{(1)},\theta_j^{(2)})-\alpha\Delta_j,~\max(\theta_j^{(1)},\theta_j^{(2)})+\alpha\Delta_j\right),\qquad \Delta_j=\left|\theta_j^{(1)}-\theta_j^{(2)}\right|.$$

Mutation adds a Gaussian perturbation whose scale starts as a fraction of the unit range and decays over generations:

$$\theta_j\leftarrow\theta_j+\eta_j,\quad \eta_j\sim\mathcal{N}(0,\sigma_j^2),\qquad \sigma_j^{(0)}=\gamma\left(P_{i_j}^{\max}-P_{i_j}^{\min}\right),\qquad \sigma_j^{(g+1)}=\max\left(\rho\sigma_j^{(g)},\sigma_j^{\min}\right).$$

The decay turns broad exploration into fine exploitation. Ring migration moves the best members of island $s$ into the neighbouring island:

$$\mathcal{M}_s^{g}=\mathrm{Best}_{K_{\text{mig}}}\left(\mathcal{P}_s^{g}\right),\qquad \mathcal{P}_{s+1}^{g}\leftarrow\left(\mathcal{P}_{s+1}^{g}\setminus\mathrm{Worst}_{K_{\text{mig}}}\left(\mathcal{P}_{s+1}^{g}\right)\right)\cup\mathcal{M}_s^{g}.$$

### Lamarckian refinement and fitness

The local search perturbs one randomly chosen gene with $\sigma_{\text{ls}}=0.03\left(P_{i_j}^{\max}-P_{i_j}^{\min}\right)$ and accepts it only if the cost falls:

$$\boldsymbol{\theta}^{(\ell)}=\boldsymbol{\theta}'~\text{if}~F(\boldsymbol{\theta}')\lt F(\boldsymbol{\theta}^{(\ell-1)}),\quad \text{otherwise}~\boldsymbol{\theta}^{(\ell-1)}.$$

Residual infeasibility is penalised. The shortfall is

$$\delta^{t}=\max\left(0,P_D^{t}-\sum_iP_i^{t}\right),$$

and the final fitness is

$$J=F+\lambda(\delta^{t})^2+\sum_{i\in\mathcal{V}^{t}}\left(\beta_0+\beta_1\min\left\lbrace\left|P_i-P_{i,k}^{L}\right|,\left|P_i-P_{i,k}^{U}\right|\right\rbrace\right),$$

where $\mathcal{V}^{t}$ is the set of units still inside a prohibited zone. The quadratic term punishes unserved demand, and the linear term punishes residual POZ violations.

### Reported result

IEEE 15-unit, 24-hour benchmark, 30 trials: best cost USD 655,073.62 with standard deviation USD 1,469, using only the units needed at each hour.

## Contents

```
.gitignore
figures/
  fig1_convergence_best_run.png
  fig1b_convergence_mean.png
  fig2_fcm_allruns.png
  fig3_boxplot.png
  fig4_mean_std.png
  fig5_demand_vs_gen.png
  fig6_hourly_cost.png
  fig7_dispatch_stack.png
  fig8_surplus.png
matlab/
  FCM_PbGA.m
  benchmarks/
  convergence_curve.m
  revision/
python/
  FCM-GA (ED-UC-VPE-POZ) v3.0.ipynb
  FCM-GSA (ED-UC-VPE-POZ) v3.0.ipynb
  FCM-GWO (ED-UC-VPE-POZ) v2.0.ipynb
  FCM-PSO (ED-UC-VPE-POZ) v3.0.ipynb
  FCM-WOA (ED-UC-VPE-POZ) v2.0.ipynb
  Merit Order (ED-UC-VPE-POZ) v2.0.ipynb
results/
  Ablation_Study.xlsx
  Budget_Matched_Results.xlsx
  Budget_Matched_Statistical_Tests.xlsx
  Convergence_Curves.xlsx
  FCM_PbGA_Results.xlsx
  FCM_PbGA_v4_Results.xlsx
  Final_Comprehensive_Comparison.xlsx
  Sensitivity_Analysis.xlsx
  Statistical_Tests.xlsx
  V4_Comparison_Results.xlsx
  revision/
```

## Data

Input data is **not included**. Place files in `data/` (notebooks) or next to the `.m` script (MATLAB):

| File | Columns |
|---|---|
| `ELD_Test_System.xlsx` | Sheet1: `Unit`, `pmin`, `pmax`, `a`, `b`, `c`, `d`, `e`, `Pnow`, `rampup`, `rampdown`, `poz` |
| `powerdemand.xlsx` | Sheet1: `load` |


## Results

### IEEE 15-unit, 24 hours, 30 runs

| Method | Full | FCM_PbGA_v4 | GA_vanilla | PSO_vanilla | GWO_vanilla | WOA_vanilla | MeritOrder_vanilla | GA_matched | PSO_matched | GWO_matched | WOA_matched |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Mean cost (USD) | 662,173.34 | 655,073.62 | 663,692.91 | 676,324.83 | 666,045.56 | 674,320.01 | 688,819.61 | 655,518.39 | 672,791.16 | 660,576.00 | 668,373.34 |
| Std | 2,150.85 | 1,469.06 | 1,733.43 | 2,562.30 | 2,238.93 | 2,239.87 | 0.00 | 1,165.25 | 1,798.52 | 1,544.03 | 1,874.98 |
| Min | 657,914.50 | 650,837.80 | 659,747.58 | 673,125.42 | 662,072.66 | 669,046.26 | 688,819.61 | 653,461.35 | 667,779.74 | 657,060.42 | 664,103.91 |
| Max | 667,154.23 | 658,108.69 | 666,989.51 | 683,582.42 | 669,881.22 | 680,054.54 | 688,819.61 | 657,699.70 | 675,980.40 | 663,418.45 | 673,550.55 |

The tuned FCM-PbGA run is the cheapest of the eleven entries at 655,073.62 USD, 1.30% below vanilla GA and 0.07% below the size-matched GA. Every GA-family variant beats the merit-order schedule at 688,819.61 USD, while PSO and WOA trail both GA variants.

### Ablation over 30 runs

| Variant | Full | NoFCM | NoLS | NoIslands | NoMigration |
|---|---|---|---|---|---|
| Mean cost (USD) | 662,173.34 | 662,489.74 | 661,842.65 | 656,904.09 | 663,542.93 |
| Std | 2,150.85 | 1,356.36 | 1,627.67 | 1,432.79 | 1,633.09 |
| Min | 657,914.50 | 660,432.14 | 658,385.11 | 654,180.22 | 660,793.81 |
| Max | 667,154.23 | 665,373.39 | 665,665.84 | 659,503.24 | 666,676.58 |

Dropping islands gives 656,904.09 USD, 0.80% under the full method, so islands do not pay for themselves on this case. Dropping line search lowers the mean by 0.05%, dropping FCM raises it by 0.05%, and dropping migration raises it by 0.21%. All gaps sit inside or near one standard deviation of the full run.

### Omnibus tests, 30 runs

| Test | p-value |
|---|---|
| ANOVA | 6.43e-116 |
| Friedman | 1.80e-27 |

ANOVA returns p 6.43e-116 and Friedman p 1.80e-27, so the six variants do not share a mean or median at any conventional significance level.

### Paired tests against each baseline

| Baseline | Wilcoxon p | t-test p | Tukey mean difference (USD) | Tukey q | Significant |
|---|---|---|---|---|---|
| GA | 4.03e-03 | 3.83e-03 | 1,519.58 | 4.14 | no |
| PSO | 3.02e-11 | 5.27e-31 | 12,631.91 | 34.43 | yes |
| GWO | 1.87e-07 | 5.62e-09 | 10,279.27 | 28.02 | yes |
| WOA | 3.02e-11 | 3.10e-29 | 8,274.45 | 22.55 | yes |
| MeritOrder | 1.21e-12 | 5.90e-57 | 14,499.60 | 39.52 | yes |

Every baseline is separated from FCM-PbGA at the 5% level by Wilcoxon, with p from 4.0e-3 against GA down to 1.2e-12 against merit order. Tukey agrees except for the size-matched GA, where the 1,519.58 USD gap gives q 4.14 and no significance; the t-test still separates that pair at p 0.0038, so the GA margin is small and depends on the test used.

### All comparisons against FCM-PbGA_v4, 30 runs

| Method | Full | GA-vanilla | PSO-vanilla | GWO-vanilla | WOA-vanilla | MeritOrder-vanilla | GA-matched | PSO-matched | GWO-matched | WOA-matched |
|---|---|---|---|---|---|---|---|---|---|---|
| Mean difference (USD) | -7,099.72 | -8,619.29 | -21,251.21 | -10,971.94 | -19,246.39 | -33,745.99 | -444.77 | -17,717.54 | -5,502.38 | -13,299.71 |
| t-test p | 1.58e-21 | 1.50e-28 | 1.44e-43 | 2.80e-30 | 1.56e-43 | 2.12e-72 | 1.99e-01 | 5.39e-45 | 1.89e-20 | 1.80e-37 |
| Wilcoxon p | 3.34e-11 | 3.02e-11 | 3.02e-11 | 3.02e-11 | 3.02e-11 | 1.21e-12 | 3.55e-01 | 3.02e-11 | 4.98e-11 | 3.02e-11 |
| Cohen d | -3.85 | -5.36 | -10.18 | -5.79 | -10.16 | -32.49 | -0.34 | -10.79 | -3.65 | -7.90 |
| Effect | large | large | large | large | large | large | small | large | large | large |
| Rejected at 5% | yes | yes | yes | yes | yes | yes | no | yes | yes | yes |

Against the eight unmatched baselines the tuned variant wins by 7,099.72 to 33,745.99 USD, with every paired test significant and Cohen d from -3.85 to -32.49. The size-matched GA is the one exception: a 444.77 USD gap with t-test p 0.199, Wilcoxon p 0.355 and d -0.34, so that pair is a tie.

### Budget-matched rerun: Tukey and effect size

| Baseline | Tukey mean difference (USD) | Tukey q | Cohen d, standard run | Cohen d, budget matched | Tukey significant |
|---|---|---|---|---|---|
| GA | 6,654.95 | 22.96 | -0.78 | 3.85 | yes |
| PSO | 10,617.82 | 36.64 | -5.98 | -5.36 | yes |
| GWO | 1,597.33 | 5.51 | -1.76 | 0.85 | yes |
| WOA | 6,200.00 | 21.39 | -5.53 | -3.07 | yes |
| MeritOrder | 26,646.27 | 91.94 | -17.52 | -17.52 | yes |

When every method is given the same evaluation budget the picture changes. FCM-PbGA is separated from all five baselines by Tukey, with gaps from 1,597.33 USD (q 5.51) against GWO up to 26,646.27 USD (q 91.94) against merit order, so the earlier tie with GA does not survive the budget correction. The two effect-size columns come from files that subtract in opposite directions, so compare their magnitude, not their sign.

### Sensitivity, single seed per setting

| Parameter / Value | Islands 1 | Islands 2 | Islands 4 | Islands 6 | Islands 8 | PopSize 80 | PopSize 120 | PopSize 160 | PopSize 200 | PopSize 250 | Generations 100 | Generations 150 | Generations 200 | Generations 250 | Generations 300 | FCM_Clusters 2 | FCM_Clusters 3 | FCM_Clusters 4 | FCM_Clusters 5 | FCM_Clusters 6 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Cost (USD) | 659,126.20 | 658,217.16 | 661,285.42 | 661,531.94 | 665,590.24 | 671,353.63 | 667,768.56 | 663,768.75 | 661,531.94 | 660,661.54 | 663,218.70 | 661,808.49 | 662,903.48 | 663,327.51 | 661,531.94 | 662,674.03 | 661,635.26 | 662,061.94 | 661,531.94 | 662,802.00 |
| Cost relative to default run (%) | 100.138 | 100.000 | 100.466 | 100.504 | 101.120 | 101.618 | 101.076 | 100.470 | 100.132 | 100.000 | 100.255 | 100.042 | 100.207 | 100.271 | 100.000 | 100.173 | 100.016 | 100.080 | 100.000 | 100.192 |

Cost is flat in population size down to 200, then rises 1.62% at 80, and flat in cluster count with a shallow minimum at five clusters. Island count matters little between two and six, and the generation cap is flat from 150 upward. The configured default (250 population, 5 clusters) is at or near the minimum of every sweep.

### Result workbooks

| File | Content |
|---|---|
| [`results/Ablation_Study.xlsx`](results/Ablation_Study.xlsx) | raw output |
| [`results/Budget_Matched_Results.xlsx`](results/Budget_Matched_Results.xlsx) | raw output |
| [`results/Budget_Matched_Statistical_Tests.xlsx`](results/Budget_Matched_Statistical_Tests.xlsx) | raw output |
| [`results/Convergence_Curves.xlsx`](results/Convergence_Curves.xlsx) | raw output |
| [`results/FCM_PbGA_Results.xlsx`](results/FCM_PbGA_Results.xlsx) | raw output |
| [`results/FCM_PbGA_v4_Results.xlsx`](results/FCM_PbGA_v4_Results.xlsx) | raw output |
| [`results/Final_Comprehensive_Comparison.xlsx`](results/Final_Comprehensive_Comparison.xlsx) | raw output |
| [`results/Sensitivity_Analysis.xlsx`](results/Sensitivity_Analysis.xlsx) | raw output |
| [`results/Statistical_Tests.xlsx`](results/Statistical_Tests.xlsx) | raw output |
| [`results/V4_Comparison_Results.xlsx`](results/V4_Comparison_Results.xlsx) | raw output |
| [`results/revision/CEC2020_results.xlsx`](results/revision/CEC2020_results.xlsx) | raw output |
| [`results/revision/R1a_v4_FCM_ablation.xlsx`](results/revision/R1a_v4_FCM_ablation.xlsx) | raw output |
| [`results/revision/R1b_v4_constraint_audit.xlsx`](results/revision/R1b_v4_constraint_audit.xlsx) | raw output |
| [`results/revision/R1c_GArematch.xlsx`](results/revision/R1c_GArematch.xlsx) | raw output |
| [`results/revision/R1d_v4_LS_ablation.xlsx`](results/revision/R1d_v4_LS_ablation.xlsx) | raw output |
| [`results/revision/R1e_strict_final.xlsx`](results/revision/R1e_strict_final.xlsx) | raw output |

The workbooks hold the raw solver output behind the tables above: per-unit schedules, per-hour costs, constraint checks and run statistics.


## Requirements

MATLAB, Python. Python notebooks: `numpy`, `pandas`, `scipy`, `matplotlib` (as imported). MATLAB scripts: R2021a+.

## Citation

```bibtex
@article{Ikhsan_2026, title={Structural feasibility handling in non-convex economic dispatch: Integrating fuzzy C-means clustering with a diagnostically-redesigned genetic algorithm}, volume={0}, ISSN={2146-5703}, url={http://dx.doi.org/10.36922/IJOCTA026400306}, DOI={10.36922/ijocta026400306}, number={0}, journal={An International Journal of Optimization and Control: Theories & Applications (IJOCTA)}, publisher={AccScience Publishing}, author={Ikhsan, Rifki Rahman Nur and Suhartono, Efri and Raharjo, Jangkung and Yustika, Lindiasari Martha and Wijaya, I Gede Putu Oka Indra}, year={2026}, month=Nov, pages={026400306} }
```

## License

[![CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](LICENSE)

Licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). **Attribution is required**: any use of this code, results, or figures, including in publications, must cite:

> Rifki Rahman Nur Ikhsan; Efri Suhartono; Jangkung Raharjo; Lindiasari Martha Yustika; I Gede Putu Oka Indra Wijaya (2026). Structural feasibility handling in non-convex economic dispatch: Integrating fuzzy C-means clustering with a diagnostically-redesigned genetic algorithm. *An International Journal of Optimization and Control: Theories & Applications (IJOCTA)*. https://doi.org/10.36922/IJOCTA026400306
