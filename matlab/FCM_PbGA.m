%% ============================================================
%  FCM-PbGA: Feasibility-Aware Non-Convex Economic Dispatch
%  Thermal Power Systems (15-Unit Benchmark)
%  ED + UC + VPE + POZ + Ramp-Rate Constraints
% ============================================================
%  v9.0: consolidated v6.0 (main study, vanilla benchmarks,
%  budget-matched benchmarks, ablation study) into one script.
%
%  v9.0-v11.0 history (superseded, kept here for traceability):
%  Introduced FCM-PbGA-v2, combining four novelties on top of the
%  original "Full" architecture -- N1 adaptive island merging
%  (6->3->1), N2 stagnation-triggered mutation reheating, N3
%  POZ-aware crossover, N4 aggressive FCM seeding. Diagnostics
%  (Section 4.9 of the paper) showed v2 significantly beat "Full"
%  but still lost to a budget-matched vanilla GA. v3 then adopted
%  GA_matched's operator hyperparameters (low elitism, wide
%  non-decaying mutation) on top of v2's structure, narrowing the
%  gap further but still not closing it (v3 vs GA_matched:
%  $2,164.48, 0.33%, p=1.7e-7, Cohen's d=1.53).
%
%  v12.0 (THIS VERSION): v2 and v3 are removed and replaced by
%  FCM-PbGA-v4, which tests whether v3's residual gap came from
%  overhead in the early 6/3-island phase (generations 1-200) that
%  survived even after adopting GA_matched's operators. v4 removes
%  the island phase entirely (single population from generation 1)
%  while retaining FCM seeding (N4) and POZ-aware crossover (N3) --
%  so FCM stays a core component, per the research proposal -- and
%  keeps GA_matched's operator hyperparameters (ELITE_K=1,
%  SIGMA_FRAC=0.20, SIGMA_DECAY=1.0/no decay, INDPB=0.20). N1 and N2
%  are dropped outright rather than merged down or disabled in place.
%  Runs for the full N_RUNS=30, saves its own schedule export
%  (FCM_PbGA_v4_Results.xlsx), is included in the Final Comprehensive
%  Comparison (now referenced against v4), and gets a dedicated
%  V4-focused verdict table (V4_Comparison_Results.xlsx) directly
%  answering "does v4 finally close the gap to budget-matched GA".
%
%  Everything from v6.0 (main FCM-PbGA 30-run results, vanilla
%  benchmarks, budget-matched benchmarks, ablation study) is UNCHANGED
%  and still runs first, so those numbers continue to reproduce
%  identically. N_RUNS_ABLATION and N_RUNS_MATCHED default to 30
%  (full rigour); lower to 15 if runtime is a concern.
% ============================================================
clc; clear; close all;
rng(42);
% [FIX] Reduce graphics-timeout risk in headless/MATLAB Online sessions:
% painters is a software renderer and avoids waiting on hardware/OpenGL
% initialisation that is often unavailable or slow to respond in cloud
% sessions. This is a global default; safe_save() also sets it per-figure.
set(0,'DefaultFigureRenderer','painters');

fprintf('=== FCM-PbGA Economic Dispatch v12.0 (consolidated + v4) ===\n');

%% ---- Paths ----
SCRIPT_DIR = fileparts(mfilename('fullpath'));
if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
UNIT_DATA_PATH   = fullfile(SCRIPT_DIR, 'ELD_Test_System.xlsx');
DEMAND_DATA_PATH = fullfile(SCRIPT_DIR, 'powerdemand.xlsx');
OUTPUT_FILE      = fullfile(SCRIPT_DIR, 'FCM_PbGA_Results.xlsx');
CONV_CURVE_FILE  = fullfile(SCRIPT_DIR, 'Convergence_Curves.xlsx');
STAT_FILE        = fullfile(SCRIPT_DIR, 'Statistical_Tests.xlsx');
SENS_FILE        = fullfile(SCRIPT_DIR, 'Sensitivity_Analysis.xlsx');
FIG_DIR          = fullfile(SCRIPT_DIR, 'Figures');
ABLATION_FILE    = fullfile(SCRIPT_DIR, 'Ablation_Study.xlsx');
MATCHED_FILE     = fullfile(SCRIPT_DIR, 'Budget_Matched_Results.xlsx');
MATCHED_STAT_FILE= fullfile(SCRIPT_DIR, 'Budget_Matched_Statistical_Tests.xlsx');
V4_OUTPUT_FILE   = fullfile(SCRIPT_DIR, 'FCM_PbGA_v4_Results.xlsx');
FINAL_COMPARISON_FILE = fullfile(SCRIPT_DIR, 'Final_Comprehensive_Comparison.xlsx');
% --- NEW v12.0 output file ---
V4_COMPARISON_FILE = fullfile(SCRIPT_DIR, 'V4_Comparison_Results.xlsx');
if ~exist(FIG_DIR,'dir'), mkdir(FIG_DIR); end

%% ---- Load Data ----
unit_data   = readtable(UNIT_DATA_PATH,'VariableNamingRule','preserve','TextType','string');
demand_data = readtable(DEMAND_DATA_PATH);
N=height(unit_data); T=height(demand_data);
Pmin=unit_data.pmin; Pmax=unit_data.pmax;
a_c=unit_data.a; b_c=unit_data.b; c_c=unit_data.c;
d_c=unit_data.d; e_c=unit_data.e;
RU=unit_data.rampup; RD=unit_data.rampdown; Pnow=unit_data.Pnow;
POZ=parse_poz_table(unit_data);
demand=demand_data.load;
fprintf('Units:%d | Hours:%d | Demand:%.0f MW\n',N,T,sum(demand));

%% ---- FCM-PbGA Parameters (proposed - enhanced) -- UNCHANGED from v6.0 ----
GA.POPSIZE      = 200;
GA.NGEN         = 300;
GA.CXPB         = 0.85;
GA.MUTPB        = 0.30;
GA.INDPB        = 0.15;
GA.SIGMA_FRAC   = 0.12;
GA.SIGMA_DECAY  = 0.97;
GA.TOURNSIZE    = 3;
GA.ELITE_K      = 4;
GA.ISLANDS      = 6;
GA.MIG_INTERVAL = 25;
GA.MIG_K        = 3;
GA.LOCAL_SEARCH = true;
GA.LS_ITER      = 20;
GA.SEED         = 42;

%% ---- Vanilla Benchmark Parameters -- UNCHANGED from v6.0 ----
GA_bench              = GA;
GA_bench.POPSIZE      = 50;
GA_bench.NGEN         = 100;
GA_bench.ELITE_K      = 1;
GA_bench.SIGMA_FRAC   = 0.20;
GA_bench.INDPB        = 0.20;
GA_bench.ISLANDS      = 1;
GA_bench.MIG_K        = 0;
GA_bench.LOCAL_SEARCH = false;
GA_bench.SIGMA_DECAY  = 1.0;

FCM.N_CLUSTERS=5; FCM.MIN_SAMPLES=8; FCM.M=2; FCM.ERROR=0.005; FCM.MAXITER=500;
PENALTY=1e9; DEMAND_TOL=1e-4; POZ_EPS=1e-6; N_RUNS=30;

% Raised to 30 by default for this consolidated, publication-grade run.
% Lower to 15 if you need faster turnaround (still gives reasonable
% statistical power for t-tests/Wilcoxon, as used in v6.0).
N_RUNS_ABLATION = 30;
N_RUNS_MATCHED  = 30;

%% ---- [NEW v12.0] FCM-PbGA-v4: replaces v2/v3 entirely. Diagnosis from
%       v3's remaining $2,164.48 (0.33%) gap to budget-matched GA
%       suggested residual overhead from the early 6/3-island phase
%       (generations 1-200) even though v3 already used GA_matched's
%       operator hyperparameters. v4 removes the island phase
%       entirely -- single population from generation 1 onward -- to
%       test whether that overhead was the remaining cause. FCM
%       seeding (N4) and POZ-aware crossover (N3) are retained (FCM
%       stays a core component, per the research proposal); N1
%       (island merging) is removed outright rather than merged down
%       to 1, and N2 (reheating) stays disabled since sigma never
%       decays (SIGMA_DECAY=1.0, adopted from GA_matched). ----
GA_v4                     = GA;                    % start from original architecture identity
GA_v4.ISLAND_SCHEDULE      = 1;                     % single population from generation 1 (no island phase)
GA_v4.MERGE_GENS           = [];                     % no merge events -- nothing to merge
GA_v4.REHEAT_ENABLE       = false;                  % redundant: sigma never decays below
GA_v4.STAGNATION_WINDOW   = 15;                     % unused (REHEAT_ENABLE=false), kept for struct completeness
GA_v4.REHEAT_FACTOR       = 2.5;                    % unused
GA_v4.POZ_AWARE_CROSSOVER = true;                   % N3 retained
GA_v4.FCM_SEED_FRAC       = 0.15;                   % N4 retained -- FCM stays core, per proposal
GA_v4.FCM_SEED_SIGMA      = 0.05;
GA_v4.ELITE_K             = 1;                      % adopted from GA_matched (was 4)
GA_v4.SIGMA_FRAC          = 0.20;                   % adopted from GA_matched (was 0.12)
GA_v4.SIGMA_DECAY         = 1.0;                    % adopted from GA_matched: no decay (was 0.97)
GA_v4.INDPB               = 0.20;                   % adopted from GA_matched (was 0.15)
GA_v4.SEED                = 42 + 777777;

%% ---- [reference] GA_champion: matched-budget vanilla GA (v7.0 winner) ----
%  Included only in the FINAL COMPREHENSIVE COMPARISON below via the
%  budget-matched benchmark run (GA field of bench_costs_matched);
%  no separate run needed here.

%% ============================================================
%  FCM-PbGA MAIN LOOP ("Full") -- UNCHANGED, identical to v6.0
% ============================================================
all_costs_runs =zeros(N_RUNS,T);
total_cost_runs=zeros(N_RUNS,1);
fcm_conv_runs  =zeros(N_RUNS,GA.NGEN);
main_schedule_raw=zeros(T,N); main_schedule_adjusted=zeros(T,N);
main_uc_schedule=zeros(T,N); main_costs=zeros(T,1);
main_power=zeros(T,1); main_comp_time=zeros(T,1);
best_run_cost   = inf;
best_schedule_raw      = zeros(T,N);
best_schedule_adjusted = zeros(T,N);
best_uc_schedule       = zeros(T,N);
best_costs             = zeros(T,1);
best_power             = zeros(T,1);
best_comp_time         = zeros(T,1);

fprintf('\n--- FCM-PbGA (Full): %d runs ---\n',N_RUNS);
for run=1:N_RUNS
    [sr,sa,uc_s,ch,ph,th,conv_acc] = solve_horizon(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
        RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA,FCM,N,T,run,true,Pnow);
    fcm_conv_runs(run,:)=conv_acc';
    all_costs_runs(run,:)=ch'; total_cost_runs(run)=sum(ch);
    if run==1
        main_schedule_raw=sr; main_schedule_adjusted=sa;
        main_uc_schedule=uc_s; main_costs=ch; main_power=ph; main_comp_time=th;
    end
    if total_cost_runs(run) < best_run_cost
        best_run_cost          = total_cost_runs(run);
        best_schedule_raw      = sr;
        best_schedule_adjusted = sa;
        best_uc_schedule       = uc_s;
        best_costs             = ch;
        best_power             = ph;
        best_comp_time         = th;
    end
    fprintf('Run%2d/%d  $%.2f\n',run,N_RUNS,total_cost_runs(run));
end

%% ============================================================
%  BENCHMARKS (vanilla budget: pop=50, gen=100) -- UNCHANGED
% ============================================================
fprintf('\nBenchmarks (%d runs)...\n',N_RUNS);
[bench_costs,bench_power,bench_schedules,bench_conv]=run_benchmarks(...
    demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,PENALTY,...
    DEMAND_TOL,POZ_EPS,N,T,N_RUNS,GA,GA_bench);

%% ============================================================
%  BUDGET-MATCHED BENCHMARKS -- UNCHANGED from v6.0 (now 30 runs by default)
% ============================================================
fprintf('\n--- Budget-Matched Benchmarks (%d runs, pop=%d, gen=%d) ---\n', ...
    N_RUNS_MATCHED, GA.POPSIZE, GA.NGEN);

GA_bench_matched              = GA_bench;
GA_bench_matched.POPSIZE      = GA.POPSIZE;
GA_bench_matched.NGEN         = GA.NGEN;

[bench_costs_matched,bench_power_matched,bench_schedules_matched,bench_conv_matched] = ...
    run_benchmarks(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,PENALTY,...
    DEMAND_TOL,POZ_EPS,N,T,N_RUNS_MATCHED,GA,GA_bench_matched);

save_benchmark_excel(MATCHED_FILE,bench_costs_matched,bench_power_matched,...
    bench_schedules_matched,demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,N,T,DEMAND_TOL,POZ_EPS);

run_statistical_tests(MATCHED_STAT_FILE, all_costs_runs(1:N_RUNS_MATCHED,:), ...
    bench_costs_matched, N_RUNS_MATCHED);

%% ============================================================
%  COMPONENT-WISE ABLATION STUDY -- UNCHANGED from v6.0 (now 30 runs)
% ============================================================
fprintf('\n--- Ablation Study (%d runs per variant) ---\n', N_RUNS_ABLATION);

ablation_variants = struct();
ablation_use_fcm  = struct();

ablation_variants.Full          = GA;
ablation_use_fcm.Full           = true;

ablation_variants.NoFCM         = GA;
ablation_variants.NoFCM.SEED    = GA.SEED + 111111;
ablation_use_fcm.NoFCM          = false;

ablation_variants.NoLS          = GA;
ablation_variants.NoLS.LOCAL_SEARCH = false;
ablation_variants.NoLS.SEED     = GA.SEED + 222222;
ablation_use_fcm.NoLS           = true;

ablation_variants.NoIslands     = GA;
ablation_variants.NoIslands.ISLANDS = 1;
ablation_variants.NoIslands.MIG_K   = 0;
ablation_variants.NoIslands.SEED    = GA.SEED + 333333;
ablation_use_fcm.NoIslands      = true;

ablation_variants.NoMigration       = GA;
ablation_variants.NoMigration.MIG_K = 0;
ablation_variants.NoMigration.SEED  = GA.SEED + 444444;
ablation_use_fcm.NoMigration        = true;

variant_names = fieldnames(ablation_variants);
ablation_costs = struct();
for vi = 1:numel(variant_names)
    vname     = variant_names{vi};
    GA_v      = ablation_variants.(vname);
    use_fcm_v = ablation_use_fcm.(vname);
    costs_v   = zeros(N_RUNS_ABLATION,1);
    for run=1:N_RUNS_ABLATION
        [~,~,~,ch,~,~,~] = solve_horizon(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
            RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA_v,FCM,N,T,run,use_fcm_v,Pnow);
        costs_v(run) = sum(ch);
        fprintf('  [Ablation:%-11s] Run %2d/%d  $%.2f\n', vname, run, N_RUNS_ABLATION, costs_v(run));
    end
    ablation_costs.(vname) = costs_v;
end

save_ablation_excel(ABLATION_FILE, ablation_costs, N_RUNS_ABLATION);

%% ============================================================
%  [NEW v12.0] PROPOSED METHOD v4 (FCM-PbGA-v4: single population
%  from generation 1, GA_matched operators, FCM + POZ-aware
%  crossover retained -- replaces v2 and v3 entirely)
% ============================================================
fprintf('\n--- FCM-PbGA-v4 (single population, GA_matched operators): %d runs ---\n', N_RUNS);

all_costs_runs_v4 = zeros(N_RUNS,T);
total_cost_runs_v4 = zeros(N_RUNS,1);
best_run_cost_v4   = inf;
best_schedule_raw_v4      = zeros(T,N);
best_schedule_adjusted_v4 = zeros(T,N);
best_uc_schedule_v4       = zeros(T,N);
best_costs_v4             = zeros(T,1);
best_power_v4             = zeros(T,1);
best_comp_time_v4         = zeros(T,1);

for run=1:N_RUNS
    [sr,sa,uc_s,ch,ph,th,~] = solve_horizon_novel(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
        RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA_v4,FCM,N,T,run,true,Pnow);
    all_costs_runs_v4(run,:)=ch'; total_cost_runs_v4(run)=sum(ch);
    if total_cost_runs_v4(run) < best_run_cost_v4
        best_run_cost_v4          = total_cost_runs_v4(run);
        best_schedule_raw_v4      = sr;
        best_schedule_adjusted_v4 = sa;
        best_uc_schedule_v4       = uc_s;
        best_costs_v4             = ch;
        best_power_v4             = ph;
        best_comp_time_v4         = th;
    end
    fprintf('Run%2d/%d  $%.2f\n',run,N_RUNS,total_cost_runs_v4(run));
end

fprintf('FCM-PbGA-v4 best run: $%.2f | mean $%.2f +/- $%.2f\n', ...
    best_run_cost_v4, mean(total_cost_runs_v4), std(total_cost_runs_v4));

save_results_excel(V4_OUTPUT_FILE,best_schedule_raw_v4,best_schedule_adjusted_v4,...
    best_uc_schedule_v4,best_costs_v4,best_power_v4,best_comp_time_v4,demand,...
    Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,N,T,DEMAND_TOL,POZ_EPS);

%% ============================================================
%  [NEW v9.0] FINAL COMPREHENSIVE COMPARISON
%  Original Full, FCM-PbGA-v4, vanilla-budget benchmarks, and
%  budget-matched benchmarks, all in one statistical comparison.
% ============================================================
fprintf('\n--- Final Comprehensive Comparison ---\n');

final_costs = struct();
final_costs.Full             = total_cost_runs;                 % original, 6 islands, N_RUNS
final_costs.FCM_PbGA_v4       = total_cost_runs_v4;              % [NEW v12.0] single population + GA_matched operators
bm = fieldnames(bench_costs);
for mi=1:length(bm)
    final_costs.([bm{mi} '_vanilla']) = sum(bench_costs.(bm{mi}),2);
end
bmm = fieldnames(bench_costs_matched);
for mi=1:length(bmm)
    if strcmp(bmm{mi},'MeritOrder'), continue; end  % identical deterministic value already in *_vanilla
    final_costs.([bmm{mi} '_matched']) = sum(bench_costs_matched.(bmm{mi}),2);
end

% Truncate everything to the smallest common run count for a fair
% pairwise comparison (matched-budget runs may be fewer than N_RUNS
% if N_RUNS_MATCHED was lowered from the default 30).
fcnames = fieldnames(final_costs);
min_nr = N_RUNS;
for i=1:numel(fcnames), min_nr = min(min_nr, numel(final_costs.(fcnames{i}))); end
for i=1:numel(fcnames), final_costs.(fcnames{i}) = final_costs.(fcnames{i})(1:min_nr); end

save_final_comparison_excel(FINAL_COMPARISON_FILE, final_costs, min_nr);

%% ============================================================
%  [NEW v12.0] V4-FOCUSED VERDICT: Full vs v4 vs GA_matched
%  Direct answer to "does FCM-PbGA-v4 (single population, no island
%  phase at all) finally close the gap to budget-matched GA?"
%  GA_matched costs are reused directly from bench_costs_matched
%  above (no re-run needed), guaranteeing consistency within this
%  session.
% ============================================================
fprintf('\n--- V4-Focused Verdict (vs GA_matched) ---\n');

v4_verdict = struct();
v4_verdict.Full         = total_cost_runs;
v4_verdict.FCM_PbGA_v4  = total_cost_runs_v4;
v4_verdict.GA_matched   = sum(bench_costs_matched.GA,2);

vnames = fieldnames(v4_verdict);
vmin_nr = N_RUNS;
for i=1:numel(vnames), vmin_nr = min(vmin_nr, numel(v4_verdict.(vnames{i}))); end
for i=1:numel(vnames), v4_verdict.(vnames{i}) = v4_verdict.(vnames{i})(1:vmin_nr); end

save_v4_comparison_excel(V4_COMPARISON_FILE, v4_verdict, vmin_nr);

fprintf('\n=== V4 VERDICT SUMMARY (mean, %d runs each) ===\n', vmin_nr);
vm = zeros(numel(vnames),1);
for i=1:numel(vnames), vm(i) = mean(v4_verdict.(vnames{i})); end
[vm_sorted, vidx] = sort(vm);
for i=1:numel(vnames)
    fprintf('  %d. %-14s  $%.2f\n', i, vnames{vidx(i)}, vm_sorted(i));
end
if strcmp(vnames{vidx(1)}, 'FCM_PbGA_v4')
    fprintf('*** FCM-PbGA-v4 now beats GA_matched -- gap closed. ***\n');
else
    gap = mean(v4_verdict.FCM_PbGA_v4) - mean(v4_verdict.GA_matched);
    fprintf('FCM-PbGA-v4 vs GA_matched remaining gap: $%.2f (%.3f%%)\n', gap, 100*gap/mean(v4_verdict.GA_matched));
end

%% ============================================================
%  SAVE & PLOT (original v5.0/v6.0 outputs) -- UNCHANGED
% ============================================================
fprintf('\nSaving...\n');
fprintf('Best run: $%.2f (run=%d)\n', best_run_cost, ...
    find(total_cost_runs == best_run_cost, 1));
save_results_excel(OUTPUT_FILE,best_schedule_raw,best_schedule_adjusted,...
    best_uc_schedule,best_costs,best_power,best_comp_time,demand,...
    Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,N,T,DEMAND_TOL,POZ_EPS);
save_benchmark_excel(OUTPUT_FILE,bench_costs,bench_power,bench_schedules,...
    demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,N,T,DEMAND_TOL,POZ_EPS);
fill_fcm_comparison(OUTPUT_FILE,best_schedule_adjusted,best_uc_schedule,...
    demand,a_c,b_c,c_c,d_c,e_c,Pmin,N,T);
save_convergence_excel(CONV_CURVE_FILE,all_costs_runs,bench_costs,...
    fcm_conv_runs,bench_conv,N_RUNS,GA.NGEN);
run_statistical_tests(STAT_FILE,all_costs_runs,bench_costs,N_RUNS);
run_sensitivity_analysis(SENS_FILE,demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
    RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,N,T,GA,FCM);
plot_all_figures(FIG_DIR,all_costs_runs,bench_costs,fcm_conv_runs,bench_conv,...
    best_schedule_adjusted,best_costs,best_power,demand,total_cost_runs,...
    T,N,GA.NGEN,N_RUNS);

fprintf('\n=== DONE ===\n');
fprintf('Full FCM-PbGA:    Best $%.2f  Mean+/-Std: $%.2f+/-$%.2f\n',...
    min(total_cost_runs),mean(total_cost_runs),std(total_cost_runs));
fprintf('FCM-PbGA-v4:      Best $%.2f  Mean+/-Std: $%.2f+/-$%.2f\n',...
    min(total_cost_runs_v4),mean(total_cost_runs_v4),std(total_cost_runs_v4));
fprintf('\n[v12.0] New outputs:\n');
fprintf('  %s  (FCM-PbGA-v4 best-run schedule)\n', V4_OUTPUT_FILE);
fprintf('  %s  (Full vs v4 vs all vanilla/matched benchmarks, incl. Cohen''s d)\n', FINAL_COMPARISON_FILE);
fprintf('  %s  (focused verdict: v4 vs GA_matched)\n', V4_COMPARISON_FILE);
fprintf('  %s  (budget-matched GA/PSO/GWO/WOA schedules)\n', MATCHED_FILE);
fprintf('  %s  (component ablation: Full/NoFCM/NoLS/NoIslands/NoMigration)\n', ABLATION_FILE);

%% ============================================================
%  FUNCTIONS
%% ============================================================

function POZ=parse_poz_table(ud)
    N=height(ud); POZ=cell(N,1); pc=ud.poz;
    for i=1:N
        if iscell(pc),raw=pc{i};else,raw=pc(i);end
        if isnumeric(raw)
            if isnan(raw)||raw==0,POZ{i}=[];continue;end; s=num2str(raw);
        elseif ischar(raw)||isstring(raw), s=char(raw);
        else,POZ{i}=[];continue;end
        s=strtrim(s);
        if isempty(s)||strcmp(s,'0')||strcmpi(s,'nan'),POZ{i}=[];continue;end
        nums=regexp(s,'[\d.]+','match'); vals=cellfun(@str2double,nums);
        vals=vals(~isnan(vals)); iv=[];
        for k=1:2:length(vals)-1
            lo=min(vals(k),vals(k+1));hi=max(vals(k),vals(k+1));
            if hi>lo,iv=[iv;lo,hi];end,end
        POZ{i}=iv;
    end
end

function f=in_poz(p,iv)
    f=false;if isempty(iv),return;end
    for k=1:size(iv,1),if p>=iv(k,1)&&p<=iv(k,2),f=true;return;end,end
end

function p=project_poz(p,iv,lb,ub,ev)
    p=max(lb,min(ub,p));if isempty(iv)||~in_poz(p,iv),return;end
    c=[lb;ub];for k=1:size(iv,1),c=[c;max(lb,iv(k,1)-ev);min(ub,iv(k,2)+ev)];end
    ok=c(~arrayfun(@(x)in_poz(x,iv),c));
    if isempty(ok),return;end,[~,i]=min(abs(ok-p));p=ok(i);
end

function P=apply_poz_vec(P,lv,uv,uc,POZ,ev)
    for i=1:length(P)
        if uc(i)==0,P(i)=0;else,P(i)=project_poz(P(i),POZ{i},lv(i),uv(i),ev);end,end
end

function m=max_feas_poz(iv,lb,ub,ev)
    if isempty(iv)||~in_poz(ub,iv),m=ub;return;end
    c=[lb;ub];for k=1:size(iv,1),c=[c;max(lb,iv(k,1)-ev);min(ub,iv(k,2)+ev)];end
    ok=c(~arrayfun(@(x)in_poz(x,iv),c));
    if isempty(ok),m=project_poz(ub,iv,lb,ub,ev);else,m=max(ok);end
end

function uc=apply_uc_basic(D,Pmin,Pmax)
    uc=ones(length(Pmin),1);
    if sum(Pmin)<=D&&sum(Pmax)>=D,return;end
    if D<sum(Pmin)
        uc=zeros(length(Pmin),1);[~,od]=sort(Pmax,'descend');
        for i=1:length(od),uc(od(i))=1;
            if sum(Pmin.*uc)<=D&&sum(Pmax.*uc)>=D,return;end,end,end
end

function uc=escalate_uc_poz(D,uc,Pmin,Pmax,POZ,ev)
    tm=0;for i=1:length(uc),if uc(i)==1,tm=tm+max_feas_poz(POZ{i},Pmin(i),Pmax(i),ev);end,end
    if tm>=D-1e-6,return;end
    off=find(uc==0);g=zeros(length(off),1);
    for k=1:length(off),g(k)=max_feas_poz(POZ{off(k)},Pmin(off(k)),Pmax(off(k)),ev);end
    [~,od]=sort(g,'descend');
    for k=od'
        uc(off(k))=1;tm=0;
        for j=1:length(uc),if uc(j)==1,tm=tm+max_feas_poz(POZ{j},Pmin(j),Pmax(j),ev);end,end
        if tm>=D-1e-6,return;end,end
end

function [bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin)
    P=P.*uc;
    bc=(a_c+b_c.*P+c_c.*P.^2).*uc;
    vc=abs(d_c.*sin(e_c.*(Pmin-P))).*uc;
end

function fc=sum_fuel_cost(P_on,on,uc,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,ev)
    P=zeros(length(uc),1);P(on)=P_on;
    P=apply_poz_vec(P,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
    [bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
    fc=sum(bc+vc);
end

function v=objective(P_on,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,ev)
    P=zeros(length(uc),1);P(on)=P_on;
    P=apply_poz_vec(P,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
    [bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
    v=sum(bc+vc)+pen*max(0,D-sum(P))^2;
    for i=1:length(P)
        if uc(i)==1&&in_poz(P(i),POZ{i})
            iv=POZ{i};dp=inf;
            for k=1:size(iv,1)
                if P(i)>=iv(k,1)&&P(i)<=iv(k,2)
                    dp=min(dp,min(abs(P(i)-iv(k,1)),abs(P(i)-iv(k,2))));end,end
            v=v+1e7+1e5*dp;end,end
end

function P=repair_demand_geq(P,D,lv,uv,uc,POZ,tol,ev)
    P=max(lv,min(uv,P));P=apply_poz_vec(P,lv,uv,uc,POZ,ev);
    for iter=1:100
        if sum(P)>=D-tol,break;end
        df=D-sum(P);hr=max(0,(uv-P).*uc);hs=sum(hr);
        if hs<1e-12,break;end
        P=P+df*(hr/hs);P=max(lv,min(uv,P));P=apply_poz_vec(P,lv,uv,uc,POZ,ev);
    end
    if sum(P)<D-tol
        hr=max(0,(uv-P).*uc);[~,j]=max(hr);P(j)=min(uv(j),P(j)+(D-sum(P)));end
end

function P=final_balance_geq(P,D,lv,uv,uc,POZ,ev)
    for iter=1:80
        if sum(P)>=D-1e-4,break;end
        df=D-sum(P);hr=max(0,(uv-P).*uc);hs=sum(hr);
        if hs<1e-12,break;end
        P=P+min(df,hs)*(hr/hs);P=max(lv,min(uv,P));
        P=apply_poz_vec(P,lv,uv,uc,POZ,ev);end
end

function P_adj=enforce_ramp_poz_demand(pP,cP,D,uc,puc,Pmin,Pmax,RU,RD,POZ,tol,ev)
    N_=length(uc);lb=zeros(N_,1);ub=zeros(N_,1);
    for i=1:N_
        if uc(i)==0,lb(i)=0;ub(i)=0;
        elseif puc(i)==0,lb(i)=0;ub(i)=min(Pmax(i),RU(i));
        else,lb(i)=max(Pmin(i),pP(i)-RD(i));ub(i)=min(Pmax(i),pP(i)+RU(i));end
        if ub(i)<lb(i),ub(i)=lb(i);end,end
    P_adj=max(lb,min(ub,cP));P_adj=apply_poz_vec(P_adj,lb,ub,uc,POZ,ev);
    P_adj=repair_demand_geq(P_adj,D,lb,ub,uc,POZ,tol,ev);
    P_adj=max(lb,min(ub,P_adj));P_adj=apply_poz_vec(P_adj,lb,ub,uc,POZ,ev);
end

function [P_on,fv]=local_search(P_on,fv,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,GA,lb,ub,ev)
    sig=(ub-lb)*0.03;no=length(P_on);
    for ls=1:GA.LS_ITER
        i=randi(no);Pt=P_on;Pt(i)=max(lb(i),min(ub(i),Pt(i)+randn*sig(i)));
        ft=objective(Pt,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,ev);
        if ft<fv,fv=ft;P_on=Pt;end,end
end

function [P_best,bv,cc]=island_ga_optimize(D,uc,ip,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA,sv,ev)
    rng(sv); on=find(uc==1);no=length(on);
    cc=zeros(GA.NGEN,1);
    if no==0,P_best=zeros(length(uc),1);bv=inf;return;end
    lb=Pmin(on);ub=max(Pmax(on),lb+1e-9);
    obj=@(x) objective(x,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,ev);
    isz=floor(GA.POPSIZE/GA.ISLANDS)*ones(1,GA.ISLANDS);
    isz(end)=isz(end)+(GA.POPSIZE-sum(isz));
    isl=cell(GA.ISLANDS,1);ifl=cell(GA.ISLANDS,1);
    for s=1:GA.ISLANDS
        pop=lb'+rand(isz(s),no).*(ub'-lb');
        if s==1&&~isempty(ip),pop(1,:)=max(lb',min(ub',ip(on)'));end
        if s==2&&sum(ub)>1e-9,pop(1,:)=min(ub',max(lb',(D/sum(ub)*ub)'));end
        ft=arrayfun(@(j)obj(pop(j,:)'),1:isz(s))';
        isl{s}=pop;ifl{s}=ft;
    end
    sig=(ub-lb)*GA.SIGMA_FRAC;sig=max(sig,1e-12);
    gbv=inf;gbo=lb;
    pure_fn=@(x) sum_fuel_cost(x,on,uc,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,ev);
    for gen=1:GA.NGEN
        sig=sig*GA.SIGMA_DECAY;sig=max(sig,(ub-lb)*0.005);
        for s=1:GA.ISLANDS
            pop=isl{s};ft=ifl{s};ns=size(pop,1);
            [~,od]=sort(ft);ke=min(GA.ELITE_K,ns);
            ep=pop(od(1:ke),:);ef=ft(od(1:ke));
            no2=ns-ke;offs=zeros(no2,no);of=zeros(no2,1);
            for k=1:no2
                t1=randperm(ns,min(GA.TOURNSIZE,ns));[~,bi]=min(ft(t1));p1=pop(t1(bi),:);
                t2=randperm(ns,min(GA.TOURNSIZE,ns));[~,b2]=min(ft(t2));p2=pop(t2(b2),:);
                ch=p1;
                if rand()<GA.CXPB
                    al=0.5;d2=abs(p1-p2);
                    ch=min(p1,p2)-al*d2+rand(1,no).*(abs(p1-p2)+2*al*d2);end
                if rand()<GA.MUTPB
                    mk=rand(1,no)<GA.INDPB;
                    if any(mk),ch(mk)=ch(mk)+randn(1,sum(mk)).*sig(mk)';end,end
                ch=max(lb',min(ub',ch));offs(k,:)=ch;of(k)=obj(ch');
            end
            isl{s}=[ep;offs];ifl{s}=[ef;of];
        end
        if GA.ISLANDS>1&&mod(gen,GA.MIG_INTERVAL)==0
            mg=cell(GA.ISLANDS,1);mf=cell(GA.ISLANDS,1);
            for s=1:GA.ISLANDS
                [~,os]=sort(ifl{s});km=min(GA.MIG_K,length(os));
                mg{s}=isl{s}(os(1:km),:);mf{s}=ifl{s}(os(1:km));end
            for s=1:GA.ISLANDS
                dst=mod(s,GA.ISLANDS)+1;[~,od2]=sort(ifl{dst},'descend');
                kr=min(GA.MIG_K,length(od2));
                for r=1:kr,isl{dst}(od2(r),:)=mg{s}(r,:);ifl{dst}(od2(r))=mf{s}(r);end,end
        end
        for s=1:GA.ISLANDS
            [fs,is]=min(ifl{s});
            if fs<gbv,gbv=fs;gbo=isl{s}(is,:)';end,end
        cc(gen)=pure_fn(gbo);
    end
    if GA.LOCAL_SEARCH
        [gbo,gbv]=local_search(gbo,gbv,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,GA,lb,ub,ev);
        cc(end)=pure_fn(gbo);end
    P_best=zeros(length(uc),1);P_best(on)=gbo;
    P_best=apply_poz_vec(P_best,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
    bv=gbv;
end

%% ---- Novel island GA: N1-N4 (used by FCM-PbGA-v4 via GA struct fields;
%       v4 sets ISLAND_SCHEDULE=1 so the N1 island-merge machinery is
%       simply never triggered) ----
function [P_best,bv,cc]=island_ga_optimize_novel(D,uc,ip,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA,sv,ev)
    rng(sv); on=find(uc==1);no=length(on);
    cc=zeros(GA.NGEN,1);
    if no==0,P_best=zeros(length(uc),1);bv=inf;return;end
    lb=Pmin(on);ub=max(Pmax(on),lb+1e-9);
    obj=@(x) objective(x,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,ev);

    schedule = GA.ISLAND_SCHEDULE;                 % N1
    merge_gens = GA.MERGE_GENS;
    cur_islands = schedule(1);
    sched_idx = 1;

    isz=floor(GA.POPSIZE/cur_islands)*ones(1,cur_islands);
    isz(end)=isz(end)+(GA.POPSIZE-sum(isz));
    isl=cell(cur_islands,1);ifl=cell(cur_islands,1);

    for s=1:cur_islands                            % N4
        pop=lb'+rand(isz(s),no).*(ub'-lb');
        if ~isempty(ip)
            n_seed = min(isz(s), max(1, round(GA.FCM_SEED_FRAC*isz(s))));
            base = max(lb',min(ub',ip(on)'));
            for si=1:n_seed
                noise = randn(1,no).*GA.FCM_SEED_SIGMA.*(ub'-lb');
                pop(si,:) = max(lb',min(ub',base+noise));
            end
        end
        if s==2&&sum(ub)>1e-9,pop(1,:)=min(ub',max(lb',(D/sum(ub)*ub)'));end
        ft=arrayfun(@(j)obj(pop(j,:)'),1:isz(s))';
        isl{s}=pop;ifl{s}=ft;
    end

    sig=(ub-lb)*GA.SIGMA_FRAC;sig=max(sig,1e-12);
    sig0=sig;
    gbv=inf;gbo=lb;
    pure_fn=@(x) sum_fuel_cost(x,on,uc,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,ev);
    stag_counter=0;

    for gen=1:GA.NGEN
        if sched_idx<numel(schedule) && gen==merge_gens(sched_idx)      % N1
            new_count = schedule(sched_idx+1);
            [isl,ifl] = merge_islands_cells(isl,ifl,new_count);
            cur_islands = new_count;
            sched_idx = sched_idx+1;
        end

        if GA.REHEAT_ENABLE && stag_counter>=GA.STAGNATION_WINDOW       % N2
            sig = min(sig.*GA.REHEAT_FACTOR, sig0);
            stag_counter = 0;
        else
            sig = sig*GA.SIGMA_DECAY;
        end
        sig = max(sig,(ub-lb)*0.005);

        prev_gbv = gbv;

        for s=1:cur_islands
            pop=isl{s};ft=ifl{s};ns=size(pop,1);
            [~,od]=sort(ft);ke=min(GA.ELITE_K,ns);
            ep=pop(od(1:ke),:);ef=ft(od(1:ke));
            no2=ns-ke;offs=zeros(no2,no);of=zeros(no2,1);
            for k=1:no2
                t1=randperm(ns,min(GA.TOURNSIZE,ns));[~,bi]=min(ft(t1));p1=pop(t1(bi),:);
                t2=randperm(ns,min(GA.TOURNSIZE,ns));[~,b2]=min(ft(t2));p2=pop(t2(b2),:);
                ch=p1;
                if rand()<GA.CXPB
                    al=0.5;d2=abs(p1-p2);
                    ch=min(p1,p2)-al*d2+rand(1,no).*(abs(p1-p2)+2*al*d2);end
                if rand()<GA.MUTPB
                    mk=rand(1,no)<GA.INDPB;
                    if any(mk),ch(mk)=ch(mk)+randn(1,sum(mk)).*sig(mk)';end,end
                ch=max(lb',min(ub',ch));
                if GA.POZ_AWARE_CROSSOVER                                % N3
                    for j=1:no
                        uj = on(j);
                        if ~isempty(POZ{uj})
                            ch(j)=project_poz(ch(j),POZ{uj},lb(j),ub(j),ev);
                        end
                    end
                end
                offs(k,:)=ch;of(k)=obj(ch');
            end
            isl{s}=[ep;offs];ifl{s}=[ef;of];
        end

        if cur_islands>1 && mod(gen,GA.MIG_INTERVAL)==0
            mg=cell(cur_islands,1);mf=cell(cur_islands,1);
            for s=1:cur_islands
                [~,os]=sort(ifl{s});km=min(GA.MIG_K,length(os));
                mg{s}=isl{s}(os(1:km),:);mf{s}=ifl{s}(os(1:km));end
            for s=1:cur_islands
                dst=mod(s,cur_islands)+1;[~,od2]=sort(ifl{dst},'descend');
                kr=min(GA.MIG_K,length(od2));
                for r=1:kr,isl{dst}(od2(r),:)=mg{s}(r,:);ifl{dst}(od2(r))=mf{s}(r);end,end
        end

        for s=1:cur_islands
            [fs,is]=min(ifl{s});
            if fs<gbv,gbv=fs;gbo=isl{s}(is,:)';end,end

        if gbv < prev_gbv-1e-9, stag_counter=0; else, stag_counter=stag_counter+1; end

        cc(gen)=pure_fn(gbo);
    end

    if GA.LOCAL_SEARCH
        [gbo,gbv]=local_search(gbo,gbv,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,GA,lb,ub,ev);
        cc(end)=pure_fn(gbo);end
    P_best=zeros(length(uc),1);P_best(on)=gbo;
    P_best=apply_poz_vec(P_best,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
    bv=gbv;
end

function [isl_new,ifl_new] = merge_islands_cells(isl_old,ifl_old,new_count)
    old_count = numel(isl_old);
    edges = round(linspace(0,old_count,new_count+1));
    isl_new = cell(new_count,1); ifl_new = cell(new_count,1);
    for g=1:new_count
        idxs = (edges(g)+1):edges(g+1);
        isl_new{g} = vertcat(isl_old{idxs});
        ifl_new{g} = vertcat(ifl_old{idxs});
    end
end

function c=fcm_clustering(data,nc,m,eps,mi)
    [ns,nd]=size(data);nc=min(nc,ns);ix=randperm(ns,nc);c=data(ix,:);
    for it=1:mi
        U=zeros(nc,ns);
        for k=1:nc,for j=1:ns
            ds=zeros(nc,1);
            for l=1:nc,ds(l)=max(norm(data(j,:)-c(l,:))^2,1e-300);end
            U(k,j)=1/sum((ds(k)./ds).^(1/(m-1)));end,end
        cn=zeros(nc,nd);
        for k=1:nc,uk=U(k,:)'.^m;cn(k,:)=(uk'*data)/sum(uk);end
        if norm(cn-c,'fro')<eps,c=cn;break;end;c=cn;end
end

function ps=pick_center(c,ref)
    ds=zeros(size(c,1),1);for k=1:size(c,1),ds(k)=norm(c(k,:)'-ref);end
    [~,i]=min(ds);ps=c(i,:)';
end

function [sr,sa,uc_s,ch,ph,th,conv_acc] = solve_horizon(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
    RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA,FCM,N,T,run,use_fcm_seed,Pnow)
    rng(GA.SEED+run-1);
    history_P=[]; last_P=zeros(N,1);
    sr=zeros(T,N); sa=zeros(T,N); uc_s=zeros(T,N);
    ch=zeros(T,1); ph=zeros(T,1); th=zeros(T,1);
    conv_acc=zeros(GA.NGEN,1);
    prev_P=Pnow; prev_uc=ones(N,1);
    for t=1:T
        ts=tic; D=demand(t);
        uc=apply_uc_basic(D,Pmin,Pmax);
        uc=escalate_uc_poz(D,uc,Pmin,Pmax,POZ,POZ_EPS);
        ip=[];
        if use_fcm_seed && size(history_P,1)>=FCM.MIN_SAMPLES
            try,c_=fcm_clustering(history_P,FCM.N_CLUSTERS,FCM.M,FCM.ERROR,FCM.MAXITER);
                ip=pick_center(c_,last_P);catch;end
        end
        sd=GA.SEED*100+t+(run-1)*1000;
        [P_opt,~,cc]=island_ga_optimize(D,uc,ip,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
            POZ,PENALTY,GA,sd,POZ_EPS);
        conv_acc=conv_acc+cc;
        P_opt=repair_demand_geq(P_opt,D,Pmin.*uc,Pmax.*uc,uc,POZ,DEMAND_TOL,POZ_EPS);
        sr(t,:)=P_opt'; uc_s(t,:)=uc'; th(t)=toc(ts);
        if t==1, P_adj=P_opt;
        else
            P_adj=enforce_ramp_poz_demand(prev_P,P_opt,D,uc,prev_uc,...
                Pmin,Pmax,RU,RD,POZ,DEMAND_TOL,POZ_EPS);
        end
        P_adj=final_balance_geq(P_adj,D,Pmin.*uc,Pmax.*uc,uc,POZ,POZ_EPS);
        sa(t,:)=P_adj';
        [bc,vc]=compute_cost(P_adj,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
        ch(t)=sum(bc+vc); ph(t)=sum(P_adj);
        prev_P=P_adj; prev_uc=uc; last_P=P_adj; history_P=[history_P;P_adj'];
    end
end

function [sr,sa,uc_s,ch,ph,th,conv_acc] = solve_horizon_novel(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
    RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA,FCM,N,T,run,use_fcm_seed,Pnow)
    rng(GA.SEED+run-1);
    history_P=[]; last_P=zeros(N,1);
    sr=zeros(T,N); sa=zeros(T,N); uc_s=zeros(T,N);
    ch=zeros(T,1); ph=zeros(T,1); th=zeros(T,1);
    conv_acc=zeros(GA.NGEN,1);
    prev_P=Pnow; prev_uc=ones(N,1);
    for t=1:T
        ts=tic; D=demand(t);
        uc=apply_uc_basic(D,Pmin,Pmax);
        uc=escalate_uc_poz(D,uc,Pmin,Pmax,POZ,POZ_EPS);
        ip=[];
        if use_fcm_seed && size(history_P,1)>=FCM.MIN_SAMPLES
            try,c_=fcm_clustering(history_P,FCM.N_CLUSTERS,FCM.M,FCM.ERROR,FCM.MAXITER);
                ip=pick_center(c_,last_P);catch;end
        end
        sd=GA.SEED*100+t+(run-1)*1000;
        [P_opt,~,cc]=island_ga_optimize_novel(D,uc,ip,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
            POZ,PENALTY,GA,sd,POZ_EPS);
        conv_acc=conv_acc+cc;
        P_opt=repair_demand_geq(P_opt,D,Pmin.*uc,Pmax.*uc,uc,POZ,DEMAND_TOL,POZ_EPS);
        sr(t,:)=P_opt'; uc_s(t,:)=uc'; th(t)=toc(ts);
        if t==1, P_adj=P_opt;
        else
            P_adj=enforce_ramp_poz_demand(prev_P,P_opt,D,uc,prev_uc,...
                Pmin,Pmax,RU,RD,POZ,DEMAND_TOL,POZ_EPS);
        end
        P_adj=final_balance_geq(P_adj,D,Pmin.*uc,Pmax.*uc,uc,POZ,POZ_EPS);
        sa(t,:)=P_adj';
        [bc,vc]=compute_cost(P_adj,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
        ch(t)=sum(bc+vc); ph(t)=sum(P_adj);
        prev_P=P_adj; prev_uc=uc; last_P=P_adj; history_P=[history_P;P_adj'];
    end
end

function [bc_s,bp_s,bsc,bcv]=run_benchmarks(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
    RU,RD,POZ,pen,tol,ev,N,T,NR,GA,GA_bench)
    ms={'GA','PSO','GWO','WOA','MeritOrder'};M=length(ms);
    bc_s=struct();bp_s=struct();bsc=struct();bcv=struct();
    for m=1:M
        mth=ms{m};cts=zeros(NR,T);pw=zeros(NR,T);
        cv=zeros(NR,GA.NGEN);bc=inf;bs=zeros(T,N);
        fprintf('  [%d/%d] %s\n',m,M,mth);
        for run=1:NR
            rng(GA.SEED+run+m*10000);pP=Pmax*0.5;pu=ones(N,1);
            sr=zeros(T,N);ca=zeros(GA.NGEN,1);
            for t=1:T
                D=demand(t);sd=GA.SEED*100+t+run*1000+m*1e6;
                uc=apply_uc_basic(D,Pmin,Pmax);
                uc=escalate_uc_poz(D,uc,Pmin,Pmax,POZ,ev);
                switch mth
                    case 'GA'
                        [P,~,cc]=simple_ga(D,uc,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA_bench,sd,ev);
                        cc=[cc;repmat(cc(end),GA.NGEN-GA_bench.NGEN,1)];
                    case 'PSO'
                        [P,~,cc]=simple_pso(D,uc,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA_bench,sd,ev);
                        cc=[cc;repmat(cc(end),GA.NGEN-GA_bench.NGEN,1)];
                    case 'GWO'
                        [P,~,cc]=simple_gwo(D,uc,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA_bench,sd,ev);
                        cc=[cc;repmat(cc(end),GA.NGEN-GA_bench.NGEN,1)];
                    case 'WOA'
                        [P,~,cc]=simple_woa(D,uc,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA_bench,sd,ev);
                        cc=[cc;repmat(cc(end),GA.NGEN-GA_bench.NGEN,1)];
                    case 'MeritOrder'
                        P=merit_order_dispatch(D,uc,Pmin,Pmax,b_c,c_c);
                        cc=zeros(GA.NGEN,1);
                end
                ca=ca+cc;
                if t>1,P=enforce_ramp_poz_demand(pP,P,D,uc,pu,Pmin,Pmax,RU,RD,POZ,tol,ev);end
                P=final_balance_geq(P,D,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
                [bcc,vcc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
                cts(run,t)=sum(bcc+vcc);pw(run,t)=sum(P);sr(t,:)=P';pP=P;pu=uc;
            end
            cv(run,:)=ca';
            if sum(cts(run,:))<bc, bc=sum(cts(run,:)); bs=sr; end
        end
        bc_s.(mth)=cts;bp_s.(mth)=pw;bsc.(mth)=bs;bcv.(mth)=cv;
    end
end

function [P,bv,cc]=simple_ga(D,uc,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA,sv,ev)
    rng(sv);on=find(uc==1);no=length(on);cc=zeros(GA.NGEN,1);
    if no==0,P=zeros(length(uc),1);bv=inf;return;end
    lb=Pmin(on);ub=max(Pmax(on),lb+1e-9);
    obj=@(x) objective(x,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,ev);
    pop=lb'+rand(GA.POPSIZE,no).*(ub'-lb');
    ft=arrayfun(@(i)obj(pop(i,:)'),1:GA.POPSIZE)';
    gbv=min(ft);sig=(ub-lb)*GA.SIGMA_FRAC;sig=max(sig,1e-12);
    for gen=1:GA.NGEN
        [~,od]=sort(ft);ke=min(GA.ELITE_K,GA.POPSIZE);
        ep=pop(od(1:ke),:);ef=ft(od(1:ke));
        no2=GA.POPSIZE-ke;offs=zeros(no2,no);of2=zeros(no2,1);
        for k=1:no2
            t1=randperm(GA.POPSIZE,min(3,GA.POPSIZE));[~,bi]=min(ft(t1));p1=pop(t1(bi),:);
            t2=randperm(GA.POPSIZE,min(3,GA.POPSIZE));[~,b2]=min(ft(t2));p2=pop(t2(b2),:);
            ch=p1;
            if rand()<GA.CXPB
                al=0.5;d2=abs(p1-p2);ch=min(p1,p2)-al*d2+rand(1,no).*(abs(p1-p2)+2*al*d2);end
            if rand()<GA.MUTPB
                mk=rand(1,no)<GA.INDPB;
                if any(mk),ch(mk)=ch(mk)+randn(1,sum(mk)).*sig(mk)';end,end
            ch=max(lb',min(ub',ch));offs(k,:)=ch;of2(k)=obj(ch');
        end
        pop=[ep;offs];ft=[ef;of2];gbv=min(gbv,min(ft));
        [~,bi_]=min(ft);Ptmp=zeros(length(uc),1);Ptmp(on)=pop(bi_,:)';
        Ptmp=apply_poz_vec(Ptmp,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
        [bc_,vc_]=compute_cost(Ptmp,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
        cc(gen)=sum(bc_+vc_);
    end
    [bv,idx]=min(ft);P=zeros(length(uc),1);P(on)=pop(idx,:)';
    P=apply_poz_vec(P,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
end

function [P,bv,cc]=simple_pso(D,uc,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA,sv,ev)
    rng(sv);on=find(uc==1);no=length(on);cc=zeros(GA.NGEN,1);
    if no==0,P=zeros(length(uc),1);bv=inf;return;end
    lb=Pmin(on);ub=max(Pmax(on),lb+1e-9);
    obj=@(x) objective(x,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,ev);
    np=GA.POPSIZE;pos=lb'+rand(np,no).*(ub'-lb');vel=zeros(np,no);pb=pos;
    pf=arrayfun(@(i)obj(pos(i,:)'),1:np)';[gbv,gi]=min(pf);gb=pos(gi,:);
    w=0.729;c1=1.494;c2=1.494;
    for gen=1:GA.NGEN
        vel=w*vel+c1*rand(np,no).*(pb-pos)+c2*rand(np,no).*(gb-pos);
        pos=max(lb',min(ub',pos+vel));
        ft=arrayfun(@(i)obj(pos(i,:)'),1:np)';
        btr=ft<pf;pb(btr,:)=pos(btr,:);pf(btr)=ft(btr);
        [fm,gi]=min(pf);if fm<gbv,gbv=fm;gb=pb(gi,:);end
        Ptmp=zeros(length(uc),1);Ptmp(on)=gb';
        Ptmp=apply_poz_vec(Ptmp,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
        [bc_,vc_]=compute_cost(Ptmp,uc,a_c,b_c,c_c,d_c,e_c,Pmin);cc(gen)=sum(bc_+vc_);
    end
    P=zeros(length(uc),1);P(on)=gb';P=apply_poz_vec(P,Pmin.*uc,Pmax.*uc,uc,POZ,ev);bv=gbv;
end

function [P,bv,cc]=simple_gwo(D,uc,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA,sv,ev)
    rng(sv);on=find(uc==1);no=length(on);cc=zeros(GA.NGEN,1);
    if no==0,P=zeros(length(uc),1);bv=inf;return;end
    lb=Pmin(on);ub=max(Pmax(on),lb+1e-9);
    obj=@(x) objective(x,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,ev);
    np=GA.POPSIZE;pos=lb'+rand(np,no).*(ub'-lb');
    ft=arrayfun(@(i)obj(pos(i,:)'),1:np)';
    [~,od]=sort(ft);al=pos(od(1),:);af=ft(od(1));bt=pos(od(2),:);dl=pos(od(3),:);
    for gen=1:GA.NGEN
        av=2*(1-gen/GA.NGEN);
        for i=1:np
            A1=2*av*rand(1,no)-av;C1=2*rand(1,no);X1=al-A1.*abs(C1.*al-pos(i,:));
            A2=2*av*rand(1,no)-av;C2=2*rand(1,no);X2=bt-A2.*abs(C2.*bt-pos(i,:));
            A3=2*av*rand(1,no)-av;C3=2*rand(1,no);X3=dl-A3.*abs(C3.*dl-pos(i,:));
            pos(i,:)=max(lb',min(ub',(X1+X2+X3)/3));end
        ft=arrayfun(@(i)obj(pos(i,:)'),1:np)';
        [~,od]=sort(ft);al=pos(od(1),:);af=ft(od(1));bt=pos(od(2),:);dl=pos(od(3),:);
        Ptmp=zeros(length(uc),1);Ptmp(on)=al';
        Ptmp=apply_poz_vec(Ptmp,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
        [bc_,vc_]=compute_cost(Ptmp,uc,a_c,b_c,c_c,d_c,e_c,Pmin);cc(gen)=sum(bc_+vc_);
    end
    P=zeros(length(uc),1);P(on)=al';P=apply_poz_vec(P,Pmin.*uc,Pmax.*uc,uc,POZ,ev);bv=af;
end

function [P,bv,cc]=simple_woa(D,uc,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA,sv,ev)
    rng(sv);on=find(uc==1);no=length(on);cc=zeros(GA.NGEN,1);
    if no==0,P=zeros(length(uc),1);bv=inf;return;end
    lb=Pmin(on);ub=max(Pmax(on),lb+1e-9);
    obj=@(x) objective(x,on,uc,D,a_c,b_c,c_c,d_c,e_c,Pmin,Pmax,POZ,pen,ev);
    np=GA.POPSIZE;pos=lb'+rand(np,no).*(ub'-lb');
    ft=arrayfun(@(i)obj(pos(i,:)'),1:np)';[gbv,gi]=min(ft);gb=pos(gi,:);bw=1;
    for gen=1:GA.NGEN
        av=2*(1-gen/GA.NGEN);
        for i=1:np
            if rand()<0.5
                A=2*av*rand(1,no)-av;C=2*rand(1,no);
                pos(i,:)=gb-A.*abs(C.*gb-pos(i,:));
            else,l=(rand()-0.5)*2;Dw=abs(gb-pos(i,:));
                pos(i,:)=Dw.*exp(bw*l).*cos(2*pi*l)+gb;end
            pos(i,:)=max(lb',min(ub',pos(i,:)));end
        ft=arrayfun(@(i)obj(pos(i,:)'),1:np)';
        [fm,gi]=min(ft);if fm<gbv,gbv=fm;gb=pos(gi,:);end
        Ptmp=zeros(length(uc),1);Ptmp(on)=gb';
        Ptmp=apply_poz_vec(Ptmp,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
        [bc_,vc_]=compute_cost(Ptmp,uc,a_c,b_c,c_c,d_c,e_c,Pmin);cc(gen)=sum(bc_+vc_);
    end
    P=zeros(length(uc),1);P(on)=gb';P=apply_poz_vec(P,Pmin.*uc,Pmax.*uc,uc,POZ,ev);bv=gbv;
end

function P=merit_order_dispatch(D,uc,Pmin,Pmax,b_c,c_c)
    N_=length(uc);on=find(uc==1);mc=b_c+2*c_c.*((Pmin+Pmax)/2);
    [~,od]=sort(mc(on));P=zeros(N_,1);rem_=D;
    for k=1:length(od),i=on(od(k));P(i)=min(Pmax(i),rem_);P(i)=max(Pmin(i),P(i));
        rem_=rem_-P(i);if rem_<=0,break;end,end
end

%% ---- Excel savers ----
function save_results_excel(fn,sr,sa,us,co,pw,ct,dm,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,N,T,tol,ev)
    un=arrayfun(@(i)sprintf('U%d',i),1:N,'UniformOutput',false);hr=(1:T)';
    hdr=[{'Hour','Demand_MW'},un,{'Tot_Power_MW','Tot_Cost_USD','Time_s'}];
    d=zeros(T,N+5);
    for t=1:T
        P=sa(t,:)';uc=us(t,:)';[bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
        d(t,:)=[t,dm(t),P',sum(P),sum(bc+vc),ct(t)];end
    writetable(array2table(d,'VariableNames',hdr),fn,'Sheet','Schedule_Adjusted');
    dr=zeros(T,N+5);
    for t=1:T
        P=sr(t,:)';uc=us(t,:)';[bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
        dr(t,:)=[t,dm(t),P',sum(P),sum(bc+vc),ct(t)];end
    writetable(array2table(dr,'VariableNames',hdr),fn,'Sheet','Schedule_Raw');
    writetable(array2table([hr,dm,us],'VariableNames',[{'Hour','Demand_MW'},un]),fn,'Sheet','Unit_Commitment');
    ch2={'Hour','Demand_MW'};
    for i=1:N,ch2{end+1}=sprintf('U%d_B',i);ch2{end+1}=sprintf('U%d_V',i);ch2{end+1}=sprintf('U%d_T',i);end
    ch2{end+1}='Total_USD';cd=zeros(T,N*3+3);
    for t=1:T
        P=sa(t,:)';uc=us(t,:)';[bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
        row=[t,dm(t)];for i=1:N,row=[row,bc(i),vc(i),bc(i)+vc(i)];end;cd(t,:)=[row,sum(bc+vc)];end
    writetable(array2table(cd,'VariableNames',ch2),fn,'Sheet','Cost_Breakdown');
    bh=zeros(T,1);vh=zeros(T,1);
    for t=1:T
        P=sa(t,:)';uc=us(t,:)';[bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);bh(t)=sum(bc);vh(t)=sum(vc);end
    smm=table(hr,dm,pw,bh,vh,co,ct,...
        'VariableNames',{'Hour','Demand_MW','Power_MW','Base_USD','VPE_USD','Total_USD','Time_s'});
    smm.Surplus_MW=pw-dm;smm.Surplus_Pct=(pw-dm)./dm*100;smm.Bal_Violated=(pw-dm)<-tol;
    writetable(smm,fn,'Sheet','Summary');
    pb_v=(pw-dm)<-tol;
    writetable(table(hr,dm,pw,pw-dm,(pw-dm)./dm*100,pb_v,...
        'VariableNames',{'Hour','Demand_MW','Generated_MW','Surplus_MW','Surplus_Pct','Bal_Violated'}),...
        fn,'Sheet','FCM_PowerBalance');
    gl=zeros(T,N);gv=false(T,N);
    for t=1:T,P=sa(t,:);uc=us(t,:);
        for i=1:N,gl(t,i)=P(i);
            if uc(i)==0,gv(t,i)=P(i)>tol;else,gv(t,i)=P(i)<Pmin(i)-tol||P(i)>Pmax(i)+tol;end,end,end
    writetable(array2table([hr,gl],'VariableNames',[{'Hour'},un]),fn,'Sheet','FCM_GenLimPow');
    gvh=[{'Hour'},arrayfun(@(i)sprintf('U%d_Viol',i),1:N,'UniformOutput',false)];
    writetable(array2table([hr,double(gv)],'VariableNames',gvh),fn,'Sheet','FCM_GenLimViol');
    if T>1
        rr=zeros(T-1,N);rv=false(T-1,N);
        for t=2:T
            r=sa(t,:)-sa(t-1,:);rr(t-1,:)=r;uc=us(t,:);puc=us(t-1,:);
            for i=1:N,if uc(i)==0,continue;end,if puc(i)==0&&uc(i)==1,continue;end
                rv(t-1,i)=r(i)>RU(i)+tol||r(i)<-RD(i)-tol;end,end
        writetable(array2table([(2:T)',rr],'VariableNames',[{'Hour'},un]),fn,'Sheet','FCM_RampRates');
        rvh=[{'Hour'},arrayfun(@(i)sprintf('U%d_RV',i),1:N,'UniformOutput',false)];
        writetable(array2table([(2:T)',double(rv)],'VariableNames',rvh),fn,'Sheet','FCM_RampViol');
    end
    pz=false(T,N);
    for t=1:T,P=sa(t,:);for i=1:N,pz(t,i)=in_poz(P(i),POZ{i});end,end
    pzh=[{'Hour'},arrayfun(@(i)sprintf('U%d_POZ',i),1:N,'UniformOutput',false)];
    writetable(array2table([(1:T)',double(pz)],'VariableNames',pzh),fn,'Sheet','FCM_POZViol');
    fprintf('Results saved: %s\n',fn);
end

function save_benchmark_excel(fn,bc_s,bp_s,bsc,dm,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,N,T,tol,ev)
    ms=fieldnames(bsc);un=arrayfun(@(i)sprintf('U%d',i),1:N,'UniformOutput',false);hr=(1:T)';

    all_methods = [{'FCM_PbGA'}, ms'];
    n_meth = length(all_methods);
    cmp_base  = zeros(T, n_meth);
    cmp_vpe   = zeros(T, n_meth);
    cmp_total = zeros(T, n_meth);
    cmp_power = zeros(T, n_meth);

    for mi=1:length(ms)
        mn=ms{mi};sc=bsc.(mn);uc_m=double(sc>1e-6);
        bh=zeros(T,1);vh=zeros(T,1);

        cb_hdr={'Hour','Demand_MW'};
        for i=1:N
            cb_hdr{end+1}=sprintf('U%d_Base',i);
            cb_hdr{end+1}=sprintf('U%d_VPE',i);
            cb_hdr{end+1}=sprintf('U%d_Total',i);
        end
        cb_hdr{end+1}='Tot_Base_USD';
        cb_hdr{end+1}='Tot_VPE_USD';
        cb_hdr{end+1}='Tot_Cost_USD';
        cb_data=zeros(T, N*3+5);
        for t=1:T
            P=sc(t,:)';uc=uc_m(t,:)';
            [bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
            bh(t)=sum(bc);vh(t)=sum(vc);
            row=[t,dm(t)];
            for i=1:N, row=[row,bc(i),vc(i),bc(i)+vc(i)]; end
            cb_data(t,:)=[row, sum(bc), sum(vc), sum(bc+vc)];
        end
        writetable(array2table(cb_data,'VariableNames',cb_hdr),fn,'Sheet',['CostBD_' mn]);

        sd=[hr,dm,sc,sum(sc,2),bh,vh,bh+vh];
        sh=[{'Hour','Dem_MW'},un,{'TotPow_MW','Base_USD','VPE_USD','TotCost_USD'}];
        writetable(array2table(sd,'VariableNames',sh),fn,'Sheet',['Sched_' mn]);

        bp2=sum(sc,2);pbv=(bp2-dm)<-tol;
        writetable(table(hr,dm,bp2,bp2-dm,(bp2-dm)./dm*100,pbv,...
            'VariableNames',{'Hour','Dem_MW','Gen_MW','Surp_MW','Surp_Pct','Bal_Viol'}),...
            fn,'Sheet',['PwBal_' mn]);

        gl=zeros(T,N);gv=false(T,N);
        for t=1:T,P=sc(t,:);uc=uc_m(t,:);
            for i=1:N,gl(t,i)=P(i);
                if uc(i)==0,gv(t,i)=P(i)>tol;else,gv(t,i)=P(i)<Pmin(i)-tol||P(i)>Pmax(i)+tol;end,end,end
        writetable(array2table([hr,gl],'VariableNames',[{'Hour'},un]),fn,'Sheet',['GenPow_' mn]);
        gvh=[{'Hour'},arrayfun(@(i)sprintf('U%d_V',i),1:N,'UniformOutput',false)];
        writetable(array2table([hr,double(gv)],'VariableNames',gvh),fn,'Sheet',['GenViol_' mn]);

        if T>1
            rr=zeros(T-1,N);rv=false(T-1,N);
            for t=2:T
                r=sc(t,:)-sc(t-1,:);rr(t-1,:)=r;uc=uc_m(t,:);puc=uc_m(t-1,:);
                for i=1:N,if uc(i)==0,continue;end,if puc(i)==0&&uc(i)==1,continue;end
                    rv(t-1,i)=r(i)>RU(i)+tol||r(i)<-RD(i)-tol;end,end
            writetable(array2table([(2:T)',rr],'VariableNames',[{'Hour'},un]),fn,'Sheet',['Ramp_' mn]);
            rvh=[{'Hour'},arrayfun(@(i)sprintf('U%d_V',i),1:N,'UniformOutput',false)];
            writetable(array2table([(2:T)',double(rv)],'VariableNames',rvh),fn,'Sheet',['RmpV_' mn]);
        end

        pz=false(T,N);
        for t=1:T,P=sc(t,:);for i=1:N,pz(t,i)=in_poz(P(i),POZ{i});end,end
        pzh=[{'Hour'},arrayfun(@(i)sprintf('U%d_POZ',i),1:N,'UniformOutput',false)];
        writetable(array2table([(1:T)',double(pz)],'VariableNames',pzh),fn,'Sheet',['POZ_' mn]);

        tc=sum(bc_s.(mn),2);
        writetable(table((1:size(tc,1))',tc,'VariableNames',{'Run','TotCost_USD'}),...
            fn,'Sheet',['Runs_' mn]);

        cmp_base(:,mi+1)  = bh;
        cmp_vpe(:,mi+1)   = vh;
        cmp_total(:,mi+1) = bh+vh;
        cmp_power(:,mi+1) = sum(sc,2);

        fprintf('  Saved: %s\n',mn);
    end

    meth_hdr = all_methods;
    bc_cmp_hdr = [{'Hour','Demand_MW'}, meth_hdr];
    writetable(array2table([hr,dm,cmp_base],'VariableNames',bc_cmp_hdr), fn,'Sheet','Compare_BaseCost');
    writetable(array2table([hr,dm,cmp_vpe],'VariableNames',bc_cmp_hdr), fn,'Sheet','Compare_VPECost');
    writetable(array2table([hr,dm,cmp_total],'VariableNames',bc_cmp_hdr), fn,'Sheet','Compare_TotalCost');
    writetable(array2table([hr,dm,cmp_power],'VariableNames',bc_cmp_hdr), fn,'Sheet','Compare_Power');

    gt_data = [sum(cmp_base,1); sum(cmp_vpe,1); sum(cmp_total,1)];
    gt_hdr  = meth_hdr;
    gt_rows = {'Total_Base_USD','Total_VPE_USD','Total_Cost_USD'};
    gt_tbl  = array2table(gt_data,'VariableNames',gt_hdr,'RowNames',gt_rows);
    writetable(gt_tbl,fn,'Sheet','Compare_GrandTotal','WriteRowNames',true);

    fprintf('  Comparison sheets saved.\n');
end

function fill_fcm_comparison(fn,sa,us,dm,a_c,b_c,c_c,d_c,e_c,Pmin,N,T)
    hr=(1:T)';
    bh=zeros(T,1);vh=zeros(T,1);
    for t=1:T
        P=sa(t,:)';uc=us(t,:)';
        [bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
        bh(t)=sum(bc);vh(t)=sum(vc);
    end

    comp_sheets = {'Compare_BaseCost','Compare_VPECost','Compare_TotalCost','Compare_Power'};
    fcm_data    = {bh, vh, bh+vh, bh+vh};
    pw = zeros(T,1);
    for t=1:T, pw(t)=sum(sa(t,:)); end
    fcm_data{4} = pw;

    for k=1:length(comp_sheets)
        try
            tbl = readtable(fn,'Sheet',comp_sheets{k});
            tbl.FCM_PbGA = fcm_data{k};
            writetable(tbl,fn,'Sheet',comp_sheets{k});
        catch
        end
    end

    un=arrayfun(@(i)sprintf('U%d',i),1:N,'UniformOutput',false);
    cb_hdr={'Hour','Demand_MW'};
    for i=1:N
        cb_hdr{end+1}=sprintf('U%d_Base',i);
        cb_hdr{end+1}=sprintf('U%d_VPE',i);
        cb_hdr{end+1}=sprintf('U%d_Total',i);
    end
    cb_hdr{end+1}='Tot_Base_USD';
    cb_hdr{end+1}='Tot_VPE_USD';
    cb_hdr{end+1}='Tot_Cost_USD';
    cb_data=zeros(T, N*3+5);
    for t=1:T
        P=sa(t,:)';uc=us(t,:)';
        [bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
        row=[t,dm(t)];
        for i=1:N, row=[row,bc(i),vc(i),bc(i)+vc(i)]; end
        cb_data(t,:)=[row, sum(bc), sum(vc), sum(bc+vc)];
    end
    writetable(array2table(cb_data,'VariableNames',cb_hdr),fn,'Sheet','CostBD_FCM_PbGA');

    try
        gt = readtable(fn,'Sheet','Compare_GrandTotal','ReadRowNames',true);
        gt.FCM_PbGA = [sum(bh); sum(vh); sum(bh+vh)];
        writetable(gt,fn,'Sheet','Compare_GrandTotal','WriteRowNames',true);
    catch; end

    fprintf('  FCM-PbGA comparison columns updated.\n');
end

function save_convergence_excel(fn,fc,bc_s,fcv,bcv,NR,NG)
    mall=[{'FCM_PbGA'},fieldnames(bc_s)'];M=length(mall);gens=(1:NG)';
    mc=zeros(NG,M);sc2=zeros(NG,M);
    mc(:,1)=mean(fcv,1)';sc2(:,1)=std(fcv,0,1)';
    bm=fieldnames(bcv);
    for mi=1:length(bm)
        mc(:,mi+1)=mean(bcv.(bm{mi}),1)';sc2(:,mi+1)=std(bcv.(bm{mi}),0,1)';end
    hm=[{'Gen'},arrayfun(@(m)sprintf('Mean_%s',mall{m}),1:M,'UniformOutput',false)];
    hs=[{'Gen'},arrayfun(@(m)sprintf('Std_%s',mall{m}),1:M,'UniformOutput',false)];
    writetable(array2table([gens,mc],'VariableNames',hm),fn,'Sheet','MeanConvergence');
    writetable(array2table([gens,sc2],'VariableNames',hs),fn,'Sheet','StdConvergence');
    td=sum(fc,2);for mi=1:length(bm),td=[td,sum(bc_s.(bm{mi}),2)];end
    writetable(array2table([(1:NR)',td],'VariableNames',[{'Run'},mall]),fn,'Sheet','TotalCost_AllRuns');
    sd=zeros(M,5);
    for mi=1:M,x=td(:,mi);sd(mi,:)=[mean(x),std(x),min(x),max(x),median(x)];end
    writetable(array2table(sd,'VariableNames',{'Mean','Std','Min','Max','Median'},'RowNames',mall'),...
        fn,'Sheet','Cost_Stats','WriteRowNames',true);
    fprintf('Convergence saved: %s\n',fn);
end

function run_statistical_tests(fn,fc,bc_s,NR)
    ms=fieldnames(bc_s);M=length(ms);
    ft=sum(fc,2);bt=zeros(NR,M);
    for m=1:M,bt(:,m)=sum(bc_s.(ms{m}),2);end
    at=[ft,bt];an=[{'FCM_PbGA'},ms'];Nm=M+1;
    desc=zeros(Nm,5);
    for m=1:Nm,x=at(:,m);desc(m,:)=[mean(x),std(x),min(x),max(x),median(x)];end
    writetable(array2table(desc,'VariableNames',{'Mean','Std','Min','Max','Median'},'RowNames',an'),...
        fn,'Sheet','Descriptive','WriteRowNames',true);
    da=reshape(at,[],1);ga2=[];
    for m=1:Nm,ga2=[ga2;repmat(m,NR,1)];end
    [pa,~]=anova1(da,ga2,'off');
    writetable(table({'ANOVA'},pa,pa<0.05,'VariableNames',{'Test','p','Sig'}),fn,'Sheet','ANOVA');
    [pf,~]=friedman(at,1,'off');
    writetable(table({'Friedman'},pf,pf<0.05,'VariableNames',{'Test','p','Sig'}),fn,'Sheet','Friedman');
    gm=mean(at);n=NR;MSE=mean(var(at));qc=4.17;se=sqrt(MSE/n);rws={};
    for i=1:Nm,for j=i+1:Nm
        dv=abs(gm(i)-gm(j));qv=dv/se;rws{end+1}={an{i},an{j},dv,qv,qv>qc};end,end
    writetable(cell2table(vertcat(rws{:}),'VariableNames',{'M1','M2','Diff','q','Sig'}),fn,'Sheet','Tukey_HSD');
    r2={};r3={};r4={};
    for m=1:M
        [h,p,ci]=ttest2(ft,bt(:,m));r2{end+1}={'FCM_PbGA',ms{m},p,h,ci(1),ci(2)};
        [pw2,hw]=ranksum(ft,bt(:,m));r3{end+1}={'FCM_PbGA',ms{m},pw2,hw};
        pooled_std = sqrt(((NR-1)*var(ft)+(NR-1)*var(bt(:,m)))/(2*NR-2));
        if pooled_std<eps, pooled_std = eps; end
        d = (mean(ft)-mean(bt(:,m)))/pooled_std;
        ad = abs(d);
        if ad<0.2,      mag='negligible';
        elseif ad<0.5,  mag='small';
        elseif ad<0.8,  mag='medium';
        else,           mag='large';
        end
        r4{end+1}={'FCM_PbGA',ms{m},d,mag};
    end
    writetable(cell2table(vertcat(r2{:}),'VariableNames',{'M1','M2','p','Rej','CI_Lo','CI_Hi'}),fn,'Sheet','t_Test');
    writetable(cell2table(vertcat(r3{:}),'VariableNames',{'M1','M2','p','Sig'}),fn,'Sheet','Wilcoxon');
    writetable(cell2table(vertcat(r4{:}),'VariableNames',{'M1','M2','CohensD','Magnitude'}),fn,'Sheet','Effect_Size');
    fprintf('Stats saved: %s\n',fn);
end

function save_ablation_excel(fn, ablation_costs, NR)
    names = fieldnames(ablation_costs);
    M = numel(names);
    data = zeros(NR, M);
    for i=1:M, data(:,i) = ablation_costs.(names{i}); end
    writetable(array2table([(1:NR)', data], 'VariableNames',[{'Run'}, names']), fn, 'Sheet','Runs');
    desc = zeros(M,5);
    for i=1:M
        x = data(:,i);
        desc(i,:) = [mean(x), std(x), min(x), max(x), median(x)];
    end
    writetable(array2table(desc,'VariableNames',{'Mean','Std','Min','Max','Median'},'RowNames',names'),...
        fn, 'Sheet','Descriptive','WriteRowNames',true);
    full_idx = find(strcmp(names,'Full'),1);
    rows = {};
    if ~isempty(full_idx)
        full_data = data(:,full_idx);
        for i=1:M
            if i==full_idx, continue; end
            other = data(:,i);
            [h,p]  = ttest2(full_data, other);
            [pw,~] = ranksum(full_data, other);
            pooled_std = sqrt(((NR-1)*var(full_data)+(NR-1)*var(other))/(2*NR-2));
            if pooled_std<eps, pooled_std = eps; end
            d = (mean(full_data)-mean(other))/pooled_std;
            rows(end+1,:) = {names{i}, mean(full_data)-mean(other), p, pw, d, h}; %#ok<AGROW>
        end
        writetable(cell2table(rows,'VariableNames',...
            {'Variant_vs_Full','MeanDiff_Full_minus_Variant','t_p','Wilcoxon_p','CohensD','Reject_H0_at_5pct'}),...
            fn, 'Sheet','Comparisons');
    end
    fprintf('Ablation results saved: %s\n', fn);
end

%% ---- Final comprehensive comparison saver (referenced vs v4) ----
function save_final_comparison_excel(fn, costs_struct, NR)
    names = fieldnames(costs_struct);
    M = numel(names);
    data = zeros(NR, M);
    for i=1:M, data(:,i) = costs_struct.(names{i}); end
    writetable(array2table([(1:NR)', data], 'VariableNames',[{'Run'}, names']), fn, 'Sheet','Runs');

    desc = zeros(M,5);
    for i=1:M
        x = data(:,i);
        desc(i,:) = [mean(x), std(x), min(x), max(x), median(x)];
    end
    writetable(array2table(desc,'VariableNames',{'Mean','Std','Min','Max','Median'},'RowNames',names'),...
        fn, 'Sheet','Descriptive','WriteRowNames',true);

    da = reshape(data,[],1); grp = [];
    for i=1:M, grp=[grp; repmat(i,NR,1)]; end %#ok<AGROW>
    [pa,~] = anova1(da,grp,'off');
    writetable(table({'ANOVA'},pa,pa<0.05,'VariableNames',{'Test','p','Sig'}), fn, 'Sheet','ANOVA');
    [pf,~] = friedman(data,1,'off');
    writetable(table({'Friedman'},pf,pf<0.05,'VariableNames',{'Test','p','Sig'}), fn, 'Sheet','Friedman');

    % Pairwise: every method vs FCM_PbGA_v4 (updated reference for v12.0)
    ref_idx = find(strcmp(names,'FCM_PbGA_v4'),1);
    rows = {};
    if ~isempty(ref_idx)
        ref = data(:,ref_idx);
        for i=1:M
            if i==ref_idx, continue; end
            other = data(:,i);
            [h,p] = ttest2(ref, other);
            [pw,~] = ranksum(ref, other);
            pooled_std = sqrt(((NR-1)*var(ref)+(NR-1)*var(other))/(2*NR-2));
            if pooled_std<eps, pooled_std = eps; end
            d = (mean(ref)-mean(other))/pooled_std;
            ad=abs(d);
            if ad<0.2,mag='negligible';elseif ad<0.5,mag='small';elseif ad<0.8,mag='medium';else,mag='large';end
            rows(end+1,:) = {names{i}, mean(ref)-mean(other), p, pw, d, mag, h}; %#ok<AGROW>
        end
        writetable(cell2table(rows,'VariableNames',...
            {'Method_vs_FCM_PbGA_v4','MeanDiff_v4_minus_Method','t_p','Wilcoxon_p','CohensD','Magnitude','Reject_H0_at_5pct'}),...
            fn, 'Sheet','Comparisons');
    end
    fprintf('Final comprehensive comparison saved: %s\n', fn);
end

%% ---- [NEW v12.0] V4-focused verdict saver (referenced vs v4) ----
function save_v4_comparison_excel(fn, results, NR)
    names = fieldnames(results);
    M = numel(names);
    data = zeros(NR, M);
    for i=1:M, data(:,i) = results.(names{i}); end
    writetable(array2table([(1:NR)', data], 'VariableNames',[{'Run'}, names']), fn, 'Sheet','Runs');

    desc = zeros(M,5);
    for i=1:M
        x = data(:,i);
        desc(i,:) = [mean(x), std(x), min(x), max(x), median(x)];
    end
    writetable(array2table(desc,'VariableNames',{'Mean','Std','Min','Max','Median'},'RowNames',names'),...
        fn, 'Sheet','Descriptive','WriteRowNames',true);

    da = reshape(data,[],1); grp = [];
    for i=1:M, grp=[grp; repmat(i,NR,1)]; end %#ok<AGROW>
    [pa,~] = anova1(da,grp,'off');
    writetable(table({'ANOVA'},pa,pa<0.05,'VariableNames',{'Test','p','Sig'}), fn, 'Sheet','ANOVA');
    [pf,~] = friedman(data,1,'off');
    writetable(table({'Friedman'},pf,pf<0.05,'VariableNames',{'Test','p','Sig'}), fn, 'Sheet','Friedman');

    % Pairwise: every method vs FCM_PbGA_v4 (negative d favours v4)
    ref_idx = find(strcmp(names,'FCM_PbGA_v4'),1);
    rows = {};
    if ~isempty(ref_idx)
        ref = data(:,ref_idx);
        for i=1:M
            if i==ref_idx, continue; end
            other = data(:,i);
            [h,p] = ttest2(ref, other);
            [pw,~] = ranksum(ref, other);
            pooled_std = sqrt(((NR-1)*var(ref)+(NR-1)*var(other))/(2*NR-2));
            if pooled_std<eps, pooled_std = eps; end
            d = (mean(ref)-mean(other))/pooled_std;
            ad=abs(d);
            if ad<0.2,mag='negligible';elseif ad<0.5,mag='small';elseif ad<0.8,mag='medium';else,mag='large';end
            rows(end+1,:) = {names{i}, mean(ref)-mean(other), p, pw, d, mag, h}; %#ok<AGROW>
        end
        writetable(cell2table(rows,'VariableNames',...
            {'Method_vs_FCM_PbGA_v4','MeanDiff_v4_minus_Method','t_p','Wilcoxon_p','CohensD','Magnitude','Reject_H0_at_5pct'}),...
            fn, 'Sheet','Comparisons');
    end
    fprintf('V4 comparison results saved: %s\n', fn);
end

function run_sensitivity_analysis(fn,dm,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
    RU,RD,POZ,pen,tol,ev,N,T,GA,FCM)
    ir=[1,2,4,6,8];ic=zeros(size(ir));
    for k=1:length(ir),GA_k=GA;GA_k.ISLANDS=ir(k);ic(k)=run_single(dm,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,pen,tol,ev,N,T,GA_k,FCM);end
    pr=[80,120,160,200,250];pc=zeros(size(pr));
    for k=1:length(pr),GA_k=GA;GA_k.POPSIZE=pr(k);pc(k)=run_single(dm,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,pen,tol,ev,N,T,GA_k,FCM);end
    gr=[100,150,200,250,300];gc=zeros(size(gr));
    for k=1:length(gr),GA_k=GA;GA_k.NGEN=gr(k);gc(k)=run_single(dm,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,pen,tol,ev,N,T,GA_k,FCM);end
    cr=[2,3,4,5,6];cc_=zeros(size(cr));
    for k=1:length(cr),FC_k=FCM;FC_k.N_CLUSTERS=cr(k);cc_(k)=run_single(dm,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,pen,tol,ev,N,T,GA,FC_k);end
    writetable(array2table([ir',ic',ic'/min(ic)*100],'VariableNames',{'Islands','Cost','Pct'}),fn,'Sheet','Islands');
    writetable(array2table([pr',pc',pc'/min(pc)*100],'VariableNames',{'PopSize','Cost','Pct'}),fn,'Sheet','PopSize');
    writetable(array2table([gr',gc',gc'/min(gc)*100],'VariableNames',{'Gens','Cost','Pct'}),fn,'Sheet','Generations');
    writetable(array2table([cr',cc_',cc_'/min(cc_)*100],'VariableNames',{'Clusters','Cost','Pct'}),fn,'Sheet','FCM_Clusters');
    fprintf('Sensitivity saved: %s\n',fn);
end

function tc=run_single(dm,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,RU,RD,POZ,pen,tol,ev,N,T,GA,FCM)
    rng(GA.SEED);hp=[];lp=zeros(N,1);pp=Pmax*0.5;pu=ones(N,1);tc=0;
    for t=1:T
        D=dm(t);uc=apply_uc_basic(D,Pmin,Pmax);uc=escalate_uc_poz(D,uc,Pmin,Pmax,POZ,ev);
        ip=[];
        if size(hp,1)>=FCM.MIN_SAMPLES
            try,ct=fcm_clustering(hp,FCM.N_CLUSTERS,FCM.M,FCM.ERROR,FCM.MAXITER);ip=pick_center(ct,lp);catch;end,end
        [P,~,~]=island_ga_optimize(D,uc,ip,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,pen,GA,GA.SEED*100+t,ev);
        P=repair_demand_geq(P,D,Pmin.*uc,Pmax.*uc,uc,POZ,tol,ev);
        if t>1,P=enforce_ramp_poz_demand(pp,P,D,uc,pu,Pmin,Pmax,RU,RD,POZ,tol,ev);end
        P=final_balance_geq(P,D,Pmin.*uc,Pmax.*uc,uc,POZ,ev);
        [bc,vc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);tc=tc+sum(bc+vc);
        pp=P;pu=uc;lp=P;hp=[hp;P'];end
end

function plot_all_figures(FD,ac,bc_s,fcv,bcv,sa,co,pw,dm,tc,T,N,NG,NR)
    if ~exist(FD,'dir'),mkdir(FD);end
    bm=fieldnames(bc_s);an=[{'FCM_PbGA'},bm'];M=length(an);
    clr=lines(M);gens=1:NG;lw=2.0;

    function safe_save(fig_h, base_path)
        % [FIX] print() can hang/timeout in headless sessions (MATLAB
        % Online, batch/cloud runs) WITHOUT throwing a catchable error --
        % it only emits a "Graphics timeout occurred" WARNING, so the
        % previous try/catch never reached its exportgraphics fallback.
        % exportgraphics() uses a different, more robust rendering path
        % and is now tried FIRST. savefig(.fig) is skipped entirely: it
        % is not needed for the paper and was adding a third render pass
        % (and its own timeout risk) for no benefit.
        set(fig_h, 'Renderer', 'painters');
        drawnow('expose');
        ok = false;
        try
            exportgraphics(fig_h, [base_path '.png'], 'Resolution', 150);
            ok = true;
        catch
        end
        if ~ok
            try
                print(fig_h, base_path, '-dpng', '-r150');
            catch ME
                fprintf('  [warn] Could not save %s: %s\n', base_path, ME.message);
            end
        end
    end

    fm  = mean(fcv,1);
    fs  = std(fcv,0,1);
    [~,best_run_fcm]=min(sum(fcv,2));
    fcm_best = fcv(best_run_fcm,:);

    bench_mc   = cell(length(bm),1);
    bench_best = cell(length(bm),1);
    for mi=1:length(bm)
        bench_mc{mi}=mean(bcv.(bm{mi}),1);
        [~,br]=min(sum(bcv.(bm{mi}),2));
        bench_best{mi}=bcv.(bm{mi})(br,:);
    end

    all_finals=[fm(end)];
    for mi=1:length(bm),all_finals=[all_finals,bench_mc{mi}(end)];end
    y_min_c=min(all_finals)*0.990;
    y_max_c=max(all_finals)*1.050;

    fcm_best_m=cummin_vec(fcm_best);
    fm_m      =cummin_vec(fm);
    bench_mc_m  =cell(length(bm),1);
    bench_best_m=cell(length(bm),1);
    for mi=1:length(bm)
        bench_mc_m{mi}  =cummin_vec(bench_mc{mi});
        bench_best_m{mi}=cummin_vec(bench_best{mi});
    end

    line_colors={'b','r',[0.85 0.65 0],'m','g','c'};
    lw_c=1.8;

    fig=figure('Visible','off','Position',[50 50 900 600]);
    set(fig,'Color','w'); hold on;
    plot(1:NG,fcm_best_m,'b-','LineWidth',lw_c+0.4,'DisplayName','FCM-PbGA');
    for mi=1:length(bm)
        plot(1:NG,bench_best_m{mi},'Color',line_colors{mi+1},...
            'LineStyle','-','LineWidth',lw_c,'DisplayName',bm{mi});
    end
    xlim([1 NG]);ylim([y_min_c,y_max_c]);
    xlabel('Generation','FontSize',13);
    ylabel('Objective Function (Total Cost, USD)','FontSize',13);
    title('Convergence Curves: FCM-PbGA vs Benchmarks (Best Run)','FontSize',13);
    legend('Location','northeast','FontSize',11,'Box','on');
    grid on;box on;set(gca,'FontSize',11);
    safe_save(fig, fullfile(FD,'fig1_convergence_best_run'));
    close(fig);

    fig=figure('Visible','off','Position',[50 50 900 600]);
    set(fig,'Color','w'); hold on;
    gv=1:NG;
    fill([gv,fliplr(gv)],[fm_m+fs,fliplr(fm_m-fs)],...
        'b','FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
    plot(gv,fm_m,'b-','LineWidth',lw_c+0.4,'DisplayName','FCM-PbGA (mean)');
    for mi=1:length(bm)
        plot(gv,bench_mc_m{mi},'Color',line_colors{mi+1},...
            'LineStyle','-','LineWidth',lw_c,'DisplayName',bm{mi});
    end
    xlim([1 NG]);ylim([y_min_c,y_max_c]);
    xlabel('Generation','FontSize',13);
    ylabel('Mean Total Cost (USD)','FontSize',13);
    title('Convergence Curves: FCM-PbGA vs Benchmarks (Mean, 30 Runs)','FontSize',13);
    legend('Location','northeast','FontSize',11,'Box','on');
    grid on;box on;set(gca,'FontSize',11);
    safe_save(fig, fullfile(FD,'fig1b_convergence_mean'));
    close(fig);

    fig=figure('Visible','off','Position',[50 50 900 600]);
    set(fig,'Color','w'); hold on;
    cm=cool(NR);
    for r=1:NR
        cr=cummin_vec(fcv(r,:));
        plot(1:NG,cr,'Color',[cm(r,:),0.30],'LineWidth',0.7);
    end
    plot(1:NG,fm_m,'k-','LineWidth',2.5,'DisplayName','Mean (30 runs)');
    xlim([1 NG]);ylim([y_min_c,y_max_c]);
    xlabel('Generation','FontSize',13);ylabel('Total Cost (USD)','FontSize',13);
    title('FCM-PbGA: All 30 Independent Runs','FontSize',13);
    legend({'Mean'},'Location','northeast','FontSize',11);
    grid on;box on;set(gca,'FontSize',11);
    safe_save(fig, fullfile(FD,'fig2_fcm_allruns'));
    close(fig);

    td=sum(ac,2);
    for mi=1:length(bm),td=[td,sum(bc_s.(bm{mi}),2)];end
    fig=figure('Visible','off','Position',[50 50 1050 620]);
    set(fig,'Color','w');
    bplt=boxplot(td,'Labels',an,'Colors',clr,'Symbol','o');
    set(bplt,'LineWidth',1.5);
    ylabel('Total Operating Cost (USD)','FontSize',13);
    title('Cost Distribution — All Methods (30 Runs)','FontSize',13);
    xtickangle(20);grid on;box on;
    safe_save(fig, fullfile(FD,'fig3_boxplot'));
    close(fig);

    means_=mean(td);stds_=std(td);
    fig=figure('Visible','off','Position',[50 50 950 580]);
    set(fig,'Color','w');
    b4=bar(1:M,means_,0.6,'FaceColor','flat');
    for mi=1:M,b4.CData(mi,:)=clr(mi,:);end
    hold on;errorbar(1:M,means_,stds_,'k.','LineWidth',1.5,'CapSize',8);
    set(gca,'XTick',1:M,'XTickLabel',an,'FontSize',11);xtickangle(20);
    ylabel('Mean Total Cost (USD)','FontSize',13);
    title('Mean +/- Std — All Methods (30 Runs)','FontSize',13);
    rng2_=range(means_);if rng2_<1,rng2_=1;end
    for mi=1:M
        text(mi,means_(mi)+stds_(mi)+rng2_*0.02,...
            sprintf('USD%.0f',means_(mi)),...
            'HorizontalAlignment','center','FontSize',8,'FontWeight','bold');
    end
    grid on;box on;
    safe_save(fig, fullfile(FD,'fig4_mean_std'));
    close(fig);

    fig=figure('Visible','off','Position',[50 50 900 500]);
    set(fig,'Color','w');
    plot(1:T,dm,'b-o','LineWidth',2,'MarkerSize',6,'DisplayName','Demand');
    hold on;
    plot(1:T,pw,'r--s','LineWidth',2,'MarkerSize',6,'DisplayName','FCM-PbGA');
    xlabel('Hour','FontSize',13);ylabel('Power (MW)','FontSize',13);
    legend('Location','best','FontSize',11);grid on;box on;
    title('Demand vs. FCM-PbGA Generation','FontSize',13);
    safe_save(fig, fullfile(FD,'fig5_demand_vs_gen'));
    close(fig);

    fig=figure('Visible','off','Position',[50 50 900 500]);
    set(fig,'Color','w');
    bar(1:T,co,'FaceColor',[0.2 0.6 0.8]);
    xlabel('Hour','FontSize',13);ylabel('Cost (USD)','FontSize',13);
    title('Hourly Operating Cost — FCM-PbGA (Best Run)','FontSize',13);
    grid on;box on;
    safe_save(fig, fullfile(FD,'fig6_hourly_cost'));
    close(fig);

    fig=figure('Visible','off','Position',[50 50 1100 600]);
    set(fig,'Color','w');
    bar(1:T,sa,'stacked');
    xlabel('Hour','FontSize',13);ylabel('Power (MW)','FontSize',13);
    title('Unit-wise Dispatch Stack — FCM-PbGA','FontSize',13);
    legend(arrayfun(@(i)sprintf('U%d',i),1:N,'UniformOutput',false),...
        'Location','eastoutside','FontSize',7);
    grid on;
    safe_save(fig, fullfile(FD,'fig7_dispatch_stack'));
    close(fig);

    sp=pw-dm;spp=sp./dm*100;
    fig=figure('Visible','off','Position',[50 50 900 500]);
    set(fig,'Color','w');
    yyaxis left;
    bar(1:T,sp,'FaceColor',[0.3 0.7 0.3]);
    ylabel('Surplus (MW)','FontSize',13);
    yyaxis right;
    plot(1:T,spp,'ro-','LineWidth',1.5);
    ylabel('Surplus (%)','FontSize',13);
    xlabel('Hour','FontSize',13);
    title('Power Balance Surplus per Hour — FCM-PbGA','FontSize',13);
    grid on;
    safe_save(fig, fullfile(FD,'fig8_surplus'));
    close(fig);

    fprintf('Figures saved: %s\n',FD);
end

function y=cummin_vec(x)
    y=x; cur=x(1);
    for i=2:length(x)
        if x(i)<cur, cur=x(i); end
        y(i)=cur;
    end
end