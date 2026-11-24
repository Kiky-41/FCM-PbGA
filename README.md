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

$$k^{*}=\arg\min_k\left\Vert\mathbf{c}_k-\mathbf{P}^{t-1}\right\Vert_2,\qquad \mathbf{P}^{t}_{\text{seed}}=\mathbf{c}_{k^{*}}.$$

### Genetic operators

Parents are chosen by tournament:

$$\boldsymbol{\theta}^{\text{sel}}=\arg\min_{\boldsymbol{\theta}\in\mathcal{T}}F(\boldsymbol{\theta}),\qquad |\mathcal{T}|=\kappa.$$

An offspring gene is either copied from the first parent or sampled in the expanded parental interval:

$$\theta_j'\sim\mathcal{U}\left(\min(\theta_j^{(1)},\theta_j^{(2)})-\alpha\Delta_j,~\max(\theta_j^{(1)},\theta_j^{(2)})+\alpha\Delta_j\right),\qquad \Delta_j=\left|\theta_j^{(1)}-\theta_j^{(2)}\right|.$$

Mutation adds a Gaussian perturbation whose scale starts as a fraction of the unit range and decays over generations:

$$\theta_j\leftarrow\theta_j+\eta_j,\quad \eta_j\sim\mathcal{N}(0,\sigma_j^2),\qquad \sigma_j^{(0)}=\gamma\left(P_{i_j}^{\max}-P_{i_j}^{\min}\right),\qquad \sigma_j^{(g+1)}=\max\left(\rho\sigma_j^{(g)},\sigma_j^{\min}\right).$$

The decay turns broad exploration into fine exploitation. Ring migration moves the best members of island $s$ into the neighbouring island:

$$\mathcal{M}_s^{g}=\operatorname{Best}_{K_{\text{mig}}}\left(\mathcal{P}_s^{g}\right),\qquad \mathcal{P}_{s+1}^{g}\leftarrow\left(\mathcal{P}_{s+1}^{g}\setminus\operatorname{Worst}_{K_{\text{mig}}}\left(\mathcal{P}_{s+1}^{g}\right)\right)\cup\mathcal{M}_s^{g}.$$

### Lamarckian refinement and fitness

The local search perturbs one randomly chosen gene with $\sigma_{\text{ls}}=0.03\left(P_{i_j}^{\max}-P_{i_j}^{\min}\right)$ and accepts it only if the cost falls:

$$\boldsymbol{\theta}^{(\ell)}=\boldsymbol{\theta}'~\text{if}~F(\boldsymbol{\theta}')<F(\boldsymbol{\theta}^{(\ell-1)}),\quad \text{otherwise}~\boldsymbol{\theta}^{(\ell-1)}.$$

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
