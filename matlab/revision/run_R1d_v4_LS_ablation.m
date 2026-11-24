%% run_R1d_v4_LS_ablation.m — R1.4 FINAL (koreksi SEED sama + stats manual)
% v4 (LOCAL_SEARCH=true, LS_ITER=20) vs v4-NoLS (false). SEED sama,
% 30 run. Output .mat/.xlsx/.txt.
addpath(fullfile(fileparts(mfilename('fullpath')),'lib'));
SCRIPT_DIR = fileparts(mfilename('fullpath'));
if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
diary(fullfile(SCRIPT_DIR,'R1d_log.txt')); diary on;
N_RUNS = 30;

unit_data   = readtable(fullfile(SCRIPT_DIR,'ELD_Test_System.xlsx'),'VariableNamingRule','preserve','TextType','string');
demand_data = readtable(fullfile(SCRIPT_DIR,'powerdemand.xlsx'));
N=height(unit_data); T=height(demand_data);
Pmin=unit_data.pmin; Pmax=unit_data.pmax;
a_c=unit_data.a; b_c=unit_data.b; c_c=unit_data.c; d_c=unit_data.d; e_c=unit_data.e;
RU=unit_data.rampup; RD=unit_data.rampdown; Pnow=unit_data.Pnow;
POZ=parse_poz_table(unit_data); demand=demand_data.load;

GA0.POPSIZE=200; GA0.NGEN=300; GA0.CXPB=0.85; GA0.MUTPB=0.30;
GA0.INDPB=0.20; GA0.SIGMA_FRAC=0.20; GA0.SIGMA_DECAY=1.0;
GA0.TOURNSIZE=3; GA0.ELITE_K=1; GA0.ISLANDS=1;
GA0.MIG_INTERVAL=25; GA0.MIG_K=0;
GA0.LOCAL_SEARCH=true; GA0.LS_ITER=20; GA0.SEED=42+777777;
GA0.ISLAND_SCHEDULE=1; GA0.MERGE_GENS=[];
GA0.REHEAT_ENABLE=false; GA0.STAGNATION_WINDOW=15; GA0.REHEAT_FACTOR=2.5;
GA0.POZ_AWARE_CROSSOVER=true;
GA0.FCM_SEED_FRAC=0.15; GA0.FCM_SEED_SIGMA=0.05;
FCM.N_CLUSTERS=5; FCM.MIN_SAMPLES=8; FCM.M=2; FCM.ERROR=0.005; FCM.MAXITER=500;
PENALTY=1e9; DEMAND_TOL=1e-4; POZ_EPS=1e-6;

GA_nols = GA0; GA_nols.LOCAL_SEARCH = false;
cF = zeros(N_RUNS,1); cN = zeros(N_RUNS,1);
for run = 1:N_RUNS
    tic;
    [~,~,~,ch,~,~,~] = solve_horizon_novel(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
        RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA0,FCM,N,T,run,true,Pnow);
    cF(run) = sum(ch);
    fprintf('[v4  ] run %2d total=%.2f (%.0fs)\n', run, cF(run), toc);
end
save(fullfile(SCRIPT_DIR,'R1d_v4_LS_ablation.mat'),'cF','cN');
for run = 1:N_RUNS
    tic;
    [~,~,~,ch,~,~,~] = solve_horizon_novel(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
        RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA_nols,FCM,N,T,run,true,Pnow);
    cN(run) = sum(ch);
    fprintf('[NoLS] run %2d total=%.2f (%.0fs)\n', run, cN(run), toc);
end
save(fullfile(SCRIPT_DIR,'R1d_v4_LS_ablation.mat'),'cF','cN');

[p_pt, t_pt, df_pt] = paired_ttest_manual(cF,cN);
[p_sr, ~, z_sr] = signrank_manual(cF,cN);
[p_rs, ~, ~] = ranksum_manual(cF,cN);
[p_an, F_an, ~, ~] = anova1_manual([cF,cN]);
[p_fr, ~, ~] = friedman_manual([cF,cN]);
sp = sqrt(((N_RUNS-1)*std(cF)^2+(N_RUNS-1)*std(cN)^2)/(2*N_RUNS-2));
d = (mean(cF)-mean(cN))/sp;
fid = fopen(fullfile(SCRIPT_DIR,'R1d_v4_LS_ablation_stats.txt'),'w');
fprintf(fid,'R1.4 v4 vs v4-NoLS, N=%d\n',N_RUNS);
fprintf(fid,'v4   : mean=%.2f std=%.2f best=%.2f worst=%.2f median=%.2f\n',mean(cF),std(cF),min(cF),max(cF),median(cF));
fprintf(fid,'NoLS : mean=%.2f std=%.2f best=%.2f worst=%.2f median=%.2f\n',mean(cN),std(cN),min(cN),max(cN),median(cN));
fprintf(fid,'diff=%.2f paired-t: t=%.3f df=%d p=%.4g | signrank z=%.3f p=%.4g\n', mean(cF)-mean(cN),t_pt,df_pt,p_pt,z_sr,p_sr);
fprintf(fid,'ranksum p=%.4g | ANOVA F=%.3f p=%.4g | Friedman p=%.4g | d=%.3f\n', p_rs,F_an,p_an,p_fr,d);
fclose(fid);
type(fullfile(SCRIPT_DIR,'R1d_v4_LS_ablation_stats.txt'));
writetable(table(cF,cN,'VariableNames',{'v4','v4_NoLS'}),fullfile(SCRIPT_DIR,'R1d_v4_LS_ablation.xlsx'),'Sheet','per_run');
writetable(table(mean(cF),std(cF),mean(cN),std(cN),mean(cF)-mean(cN),p_pt,p_sr,p_rs,p_an,p_fr,d, ...
    'VariableNames',{'mean_v4','std_v4','mean_NoLS','std_NoLS','diff','p_paired_t','p_signrank','p_ranksum','p_ANOVA','p_Friedman','d'}), ...
    fullfile(SCRIPT_DIR,'R1d_v4_LS_ablation.xlsx'),'Sheet','summary');
diary off;
fprintf('R1d SELESAI\n');
