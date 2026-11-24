# FCM-PbGA

**Structural feasibility handling in non-convex economic dispatch: Integrating fuzzy C-means clustering with a diagnostically-redesigned genetic algorithm**

Ikhsan, Rifki Rahman Nur · Suhartono, Efri · Raharjo, Jangkung · Yustika, Lindiasari Martha · Wijaya, I Gede Putu Oka Indra  
*IJOCTA, 2026*  
[![DOI](https://img.shields.io/badge/DOI-10.36922%2FIJOCTA026400306-blue)](https://doi.org/10.36922/IJOCTA026400306)

Fuzzy C-Means Population-Based Genetic Algorithm for non-convex economic dispatch with VPE, POZ, ramp-rate and unit commitment.

## Abstract

Practical thermal economic dispatch (ED) problems with valve-point effects (VPE), prohibited operating zones (POZ), ramp-rate limits, and unit commitment (UC) decisions are non-smooth, non-convex, and fragmented, which defeats gradient-based solvers. This paper presents a feasibility-aware computational intelligence framework—the Fuzzy C-Means Population-Based Genetic Algorithm (FCM-PbGA)—that embeds commitment-consistent encoding, FCM-guided initialisation, ramp-feasible bounds, POZ-aware projection, and Lamarckian refinement in a single-population evolutionary architecture. The framework is evaluated on the IEEE 15-unit, 24-hour benchmark (30 trials). The initial island-based architecture (Stage 1) achieves $662,173 ± $2,151. Budget-matched re-runs and ablation isolate architecture from budget: fixed six-island partitioning proves counterproductive, and the matched GA outperforms Stage 1. Three redesigns follow: adaptive merging, reheating, POZaware crossover and fractional seeding close 49% of the gap; corrected operators close an additional 36%; and removing islands entirely (v4) reaches $655,073.62 ± $1,469—a statistical tie with the matched GA (p = 0.199, d = −0.34) under published conditions, and a significant lead (p = 5.2 × 10−6, d = −1.34) with correctly loaded POZ sets and strict repair. Zero power-balance, ramp-rate, POZ, and generation-limit violations are verified over 10,800 unit-hours. The study demonstrates a diagnose-then-redesign methodology for constrained engineering scheduling.

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
