%% run_R1a_v4_FCM_ablation.m — R1.1 FINAL (koreksi gate NoFCM)
% v4-Full vs v4-NoFCM + faktorial sinergi FCM x POZ-aware.
% Arms (SEED sama 42+777777, budget identik, 30 run):
%   A Full    : use_fcm_seed=true,  POZ_AWARE=true
%   B NoFCM   : use_fcm_seed=false, POZ_AWARE=true   (SATU-SATUNYA beda vs A)
%   C FCMonly : use_fcm_seed=true,  POZ_AWARE=false
%   D Neither : use_fcm_seed=false, POZ_AWARE=false
% Statistik toolbox-free (lib/): paired_ttest_manual, signrank_manual,
% ranksum_manual, anova1_manual, friedman_manual. Output .mat/.xlsx/.txt.
addpath(fullfile(fileparts(mfilename('fullpath')),'lib'));
SCRIPT_DIR = fileparts(mfilename('fullpath'));
if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
diary(fullfile(SCRIPT_DIR,'R1a_log.txt')); diary on;
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

arms = struct('tag',{'A_Full','B_NoFCM','C_FCMonly','D_Neither'}, ...
              'fcm',{true,false,true,false}, 'poz',{true,true,false,false});
tot = zeros(N_RUNS,4); npoz = zeros(N_RUNS,4);
for a = 1:4
    GA_v = GA0;
    GA_v.POZ_AWARE_CROSSOVER = arms(a).poz;
    fcmflag = arms(a).fcm;
    fprintf('=== Arm %s (fcm=%d poz=%d) ===\n', arms(a).tag, fcmflag, arms(a).poz);
    for run = 1:N_RUNS
        tic;
        [sr,sa,~,ch,~,~,~] = solve_horizon_novel(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
            RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA_v,FCM,N,T,run,fcmflag,Pnow);
        tot(run,a) = sum(ch);
        npoz(run,a) = count_poz_raw(sr,POZ,N,T);
        fprintf('[%s] run %2d/%d total=%.2f npoz_raw=%d (%.0fs)\n', ...
            arms(a).tag, run, N_RUNS, tot(run,a), npoz(run,a), toc);
    end
    save(fullfile(SCRIPT_DIR,'R1a_v4_FCM_ablation.mat'),'tot','npoz');
end

% ---- statistik A vs B ----
A = tot(:,1); B = tot(:,2); C = tot(:,3); D = tot(:,4);
[p_pt, t_pt, df_pt] = paired_ttest_manual(A,B);
[p_sr, ~, z_sr] = signrank_manual(A,B);
[p_rs, ~, ~] = ranksum_manual(A,B);
[p_an, F_an, ~, ~] = anova1_manual([A,B]);
[p_fr, ~, ~] = friedman_manual([A,B]);
sp = sqrt(((N_RUNS-1)*std(A)^2+(N_RUNS-1)*std(B)^2)/(2*N_RUNS-2));
d = (mean(A)-mean(B))/sp;
% interaksi sinergi pada mean: (A-D) - ((B-D)+(C-D))
inter = (mean(A)-mean(D)) - ((mean(B)-mean(D)) + (mean(C)-mean(D)));
% efek FCM pada jumlah POZ mentah (mekanisme): A vs B, C vs D
[~, ~, ~] = signrank_manual(npoz(:,1),npoz(:,2)); %#ok<ASGLU>

fid = fopen(fullfile(SCRIPT_DIR,'R1a_v4_FCM_ablation_stats.txt'),'w');
fprintf(fid,'R1.1 v4-Full(A) vs v4-NoFCM(B), N=%d, SEED sama, budget sama\n',N_RUNS);
fprintf(fid,'A Full   : mean=%.2f std=%.2f best=%.2f worst=%.2f median=%.2f meanPozRaw=%.2f\n',mean(A),std(A),min(A),max(A),median(A),mean(npoz(:,1)));
fprintf(fid,'B NoFCM  : mean=%.2f std=%.2f best=%.2f worst=%.2f median=%.2f meanPozRaw=%.2f\n',mean(B),std(B),min(B),max(B),median(B),mean(npoz(:,2)));
fprintf(fid,'C FCMonly: mean=%.2f std=%.2f meanPozRaw=%.2f\n',mean(C),std(C),mean(npoz(:,3)));
fprintf(fid,'D Neither: mean=%.2f std=%.2f meanPozRaw=%.2f\n',mean(D),std(D),mean(npoz(:,4)));
fprintf(fid,'diff A-B = %.2f\n', mean(A)-mean(B));
fprintf(fid,'paired t: t=%.3f df=%d p=%.4g\n', t_pt, df_pt, p_pt);
fprintf(fid,'signed-rank: z=%.3f p=%.4g\n', z_sr, p_sr);
fprintf(fid,'ranksum p=%.4g | ANOVA F=%.3f p=%.4g | Friedman p=%.4g\n', p_rs, F_an, p_an, p_fr);
fprintf(fid,'Cohen d (pooled) = %.3f\n', d);
fprintf(fid,'interaction (A-D)-((B-D)+(C-D)) = %.2f (negatif = sinergi)\n', inter);
fclose(fid);
type(fullfile(SCRIPT_DIR,'R1a_v4_FCM_ablation_stats.txt'));

writetable(array2table(tot,'VariableNames',{'A_Full','B_NoFCM','C_FCMonly','D_Neither'}), ...
    fullfile(SCRIPT_DIR,'R1a_v4_FCM_ablation.xlsx'),'Sheet','per_run_costs');
writetable(array2table(npoz,'VariableNames',{'A_Full','B_NoFCM','C_FCMonly','D_Neither'}), ...
    fullfile(SCRIPT_DIR,'R1a_v4_FCM_ablation.xlsx'),'Sheet','per_run_pozraw');
summ = table(mean(A),std(A),mean(B),std(B),mean(A)-mean(B),p_pt,p_sr,p_rs,p_an,p_fr,d,inter, ...
    'VariableNames',{'meanA','stdA','meanB','stdB','diffAB','p_paired_t','p_signrank','p_ranksum','p_ANOVA','p_Friedman','Cohens_d','interaction'});
writetable(summ, fullfile(SCRIPT_DIR,'R1a_v4_FCM_ablation.xlsx'),'Sheet','summary');
diary off;
fprintf('R1a SELESAI\n');

function n = count_poz_raw(sr,POZ,N,T)
n = 0;
for t = 1:T
    for i = 1:N
        p = sr(t,i); iv = POZ{i};
        for k = 1:size(iv,1)
            if p > iv(k,1)+1e-9 && p < iv(k,2)-1e-9, n = n+1; break; end
        end
    end
end
end
