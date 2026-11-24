# FCM-PbGA

**Structural feasibility handling in non-convex economic dispatch: Integrating fuzzy C-means clustering with a diagnostically-redesigned genetic algorithm**

Ikhsan, Rifki Rahman Nur · Suhartono, Efri · Raharjo, Jangkung · Yustika, Lindiasari Martha · Wijaya, I Gede Putu Oka Indra  
*IJOCTA, 2026*  
[![DOI](https://img.shields.io/badge/DOI-10.36922%2FIJOCTA026400306-blue)](https://doi.org/10.36922/IJOCTA026400306)

Fuzzy C-Means Population-Based Genetic Algorithm for non-convex economic dispatch with VPE, POZ, ramp-rate and unit commitment.

## Abstract

Practical thermal economic dispatch (ED) problems with valve-point effects (VPE), prohibited operating zones (POZ), ramp-rate limits, and unit commitment (UC) decisions are non-smooth, non-convex, and fragmented, which defeats gradient-based solvers. This paper presents a feasibility-aware computational intelligence framework—the Fuzzy C-Means Population-Based Genetic Algorithm (FCM-PbGA)—that embeds commitment-consistent encoding, FCM-guided initialisation, ramp-feasible bounds, POZ-aware projection, and Lamarckian refinement in a single-population evolutionary architecture. The framework is evaluated on the IEEE 15-unit, 24-hour benchmark (30 trials). The initial island-based architecture (Stage 1) achieves $662,173 ± $2,151. Budget-matched re-runs and ablation isolate architecture from budget: fixed six-island partitioning proves counterproductive, and the matched GA outperforms Stage 1. Three redesigns follow: adaptive merging, reheating, POZaware crossover and fractional seeding close 49% of the gap; corrected operators close an additional 36%; and removing islands entirely (v4) reaches $655,073.62 ± $1,469—a statistical tie with the matched GA (p = 0.199, d = −0.34) under published conditions, and a significant lead (p = 5.2 × 10−6, d = −1.34) with correctly loaded POZ sets and strict repair. Zero power-balance, ramp-rate, POZ, and generation-limit violations are verified over 10,800 unit-hours. The study demonstrates a diagnose-then-redesign methodology for constrained engineering scheduling.


## Proposed method

FCM-PbGA combines a feasibility-preserving chromosome with an island-based genetic algorithm. Fuzzy C-Means clusters historical dispatch vectors and seeds the population near the cluster centre closest to the previous hour; ramp- and POZ-aware projection keeps every candidate feasible; BLX-$\alpha$ crossover and adaptive Gaussian mutation explore; ring migration shares elites; and a greedy Lamarckian search refines the final dispatch.

### Objective (valve-point, unit commitment)

$$\min F(\mathbf{P},\mathbf{u})=\sum_{i=1}^{N}u_i\left(a_i+b_iP_i+c_iP_i^2+\left|d_i\sin\!\left(e_i\left(P_i^{\min}-P_i\right)\right)\right|\right)$$

subject to

$$\sum_iP_i=P_D+P_L,\qquad u_iP_i^{\min}\le P_i\le u_iP_i^{\max},\qquad \sum_iu_iP_i^{\max}\ge P_D$$

$$P_i\notin\bigcup_{k=1}^{K_i}\left[P_{i,k}^{L},P_{i,k}^{U}\right],\qquad -R_i^{D}\le P_i^{t}-P_i^{t-1}\le R_i^{U}$$

### Ramp- and POZ-feasible region

$$L_i^{t}=
\begin{cases}
0, & u_i^{t-1}=0,\ u_i^{t}=1\\
\max\!\left(P_i^{\min},P_i^{t-1}-R_i^{D}\right), & \text{otherwise}
\end{cases}
\qquad
U_i^{t}=
\begin{cases}
\min\!\left(P_i^{\max},R_i^{U}\right), & u_i^{t-1}=0,\ u_i^{t}=1\\
\min\!\left(P_i^{\max},P_i^{t-1}+R_i^{U}\right), & \text{otherwise}
\end{cases}$$

$$\Omega_i^{t}=\left[L_i^{t},U_i^{t}\right]\setminus\bigcup_{k=1}^{K_i}Z_{i,k},\qquad P_i\leftarrow\Pi_{\Omega_i^{t}}(P_i)=\arg\min_{y\in\Omega_i^{t}}|y-P_i|$$

### FCM seeding

$$J_{\mathrm{FCM}}=\sum_{j=1}^{M}\sum_{k=1}^{C}u_{kj}^{m}\left\|\mathbf{x}_j-\mathbf{c}_k\right\|_2^2,\qquad \sum_{k=1}^{C}u_{kj}=1$$

$$\mathbf{c}_k=\frac{\sum_{j=1}^{M}u_{kj}^{m}\mathbf{x}_j}{\sum_{j=1}^{M}u_{kj}^{m}},\qquad
u_{kj}=\left(\sum_{l=1}^{C}\left(\frac{\left\|\mathbf{x}_j-\mathbf{c}_k\right\|_2}{\left\|\mathbf{x}_j-\mathbf{c}_l\right\|_2}\right)^{\frac{2}{m-1}}\right)^{-1}$$

$$k^*=\arg\min_k\left\|\mathbf{c}_k-\mathbf{P}^{t-1}\right\|_2,\qquad \mathbf{P}^{t}_{\text{seed}}=\mathbf{c}_{k^*}$$

### Genetic operators

Tournament selection over a pool $\mathcal{T}$ of size $\kappa$:

$$\boldsymbol{\theta}^{\text{sel}}=\arg\min_{\boldsymbol{\theta}\in\mathcal{T}}F(\boldsymbol{\theta})$$

BLX-$\alpha$ crossover:

$$\theta_j'\sim\mathcal{U}\!\left(\min(\theta_j^{(1)},\theta_j^{(2)})-\alpha\Delta_j,\ \max(\theta_j^{(1)},\theta_j^{(2)})+\alpha\Delta_j\right),\qquad \Delta_j=\left|\theta_j^{(1)}-\theta_j^{(2)}\right|$$

Gaussian mutation with adaptive scale:

$$\theta_j\leftarrow\theta_j+\eta_j,\quad \eta_j\sim\mathcal{N}(0,\sigma_j^2),\qquad \sigma_j^{(0)}=\gamma\left(P_{i_j}^{\max}-P_{i_j}^{\min}\right),\qquad \sigma_j^{(g+1)}=\max\!\left(\rho\sigma_j^{(g)},\sigma_j^{\min}\right)$$

Ring migration every $G_{\text{mig}}$ generations:

$$\mathcal{M}_s^{g}=\operatorname{Best}_{K_{\text{mig}}}\left(\mathcal{P}_s^{g}\right),\qquad \mathcal{P}_{s+1}^{g}\leftarrow\left(\mathcal{P}_{s+1}^{g}\setminus\operatorname{Worst}_{K_{\text{mig}}}\right)\cup\mathcal{M}_s^{g}$$

### Lamarckian refinement and fitness

One random gene is perturbed per iteration with $\sigma_{\text{ls}}=0.03\left(P_{i_j}^{\max}-P_{i_j}^{\min}\right)$ and accepted only if it lowers the cost:

$$\boldsymbol{\theta}^{(\ell)}=\boldsymbol{\theta}'\ \text{if}\ F(\boldsymbol{\theta}')<F(\boldsymbol{\theta}^{(\ell-1)}),\quad \text{else}\ \boldsymbol{\theta}^{(\ell-1)}$$

Residual infeasibility is penalised:

$$\delta^{t}=\max\!\left(0,P_D^{t}-\sum_iP_i^{t}\right),\qquad J=F+\lambda(\delta^{t})^2+\sum_{i\in\mathcal{V}^{t}}\left(\beta_0+\beta_1\min\left\{\left|P_i-P_{i,k}^{L}\right|,\left|P_i-P_{i,k}^{U}\right|\right\}\right)$$

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
