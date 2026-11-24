%% run_R1c_GArematch.m — R1.3: rematch v4 vs budget-matched GA dgn POZ FIX
% Matched GA = vanilla GA (ELITE 1, SIGMA_FRAC 0.20, INDPB 0.20, single-pop,
% no-LS, no-decay) dgn POPSIZE 200 + NGEN 300 (budget ~53rb/jam, sama dgn v4).
% Seed & pipeline repair identik dgn run_benchmarks asli (m=1 utk GA).
% Dibandingkan vs v4 A-arm (R1a .mat) berpasangan per run-index + diuji
% paired-t / signed-rank / ranksum / Cohen d. Output .mat/.xlsx/.txt.
addpath(fullfile(fileparts(mfilename('fullpath')),'lib'));
SCRIPT_DIR = fileparts(mfilename('fullpath'));
if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
diary(fullfile(SCRIPT_DIR,'R1c_log.txt')); diary on;
N_RUNS = 30;

[unit_data, POZ]=load_unit_data_fixed(fullfile(SCRIPT_DIR,'ELD_Test_System.xlsx')); % FIX R1: paksa kolom poz sbg string (readtable default -> double/NaN = POZ hilang)
demand_data = readtable(fullfile(SCRIPT_DIR,'powerdemand.xlsx'));
N=height(unit_data); T=height(demand_data);
Pmin=unit_data.pmin; Pmax=unit_data.pmax;
a_c=unit_data.a; b_c=unit_data.b; c_c=unit_data.c; d_c=unit_data.d; e_c=unit_data.e;
RU=unit_data.rampup; RD=unit_data.rampdown; Pnow=unit_data.Pnow;
demand=demand_data.load;

GA.POPSIZE=200; GA.NGEN=300; GA.CXPB=0.85; GA.MUTPB=0.30; GA.INDPB=0.15;
GA.SIGMA_FRAC=0.12; GA.SIGMA_DECAY=0.97; GA.TOURNSIZE=3; GA.ELITE_K=4;
GA.ISLANDS=6; GA.MIG_INTERVAL=25; GA.MIG_K=3;
GA.LOCAL_SEARCH=true; GA.LS_ITER=20; GA.SEED=42;
GA_bench=GA; GA_bench.POPSIZE=50; GA_bench.NGEN=100; GA_bench.ELITE_K=1;
GA_bench.SIGMA_FRAC=0.20; GA_bench.INDPB=0.20; GA_bench.ISLANDS=1;
GA_bench.MIG_K=0; GA_bench.LOCAL_SEARCH=false; GA_bench.SIGMA_DECAY=1.0;
GBM=GA_bench; GBM.POPSIZE=GA.POPSIZE; GBM.NGEN=GA.NGEN;   % matched budget
PENALTY=1e9; DEMAND_TOL=1e-4; POZ_EPS=1e-6;

cts=zeros(N_RUNS,T);
for run=1:N_RUNS
    tic;
    rng(GA.SEED+run+1*10000); pP=Pmax*0.5; pu=ones(N,1); sr=zeros(T,N);
    for t=1:T
        D=demand(t); sd=GA.SEED*100+t+run*1000+1*1e6;
        uc=apply_uc_basic(D,Pmin,Pmax);
        uc=escalate_uc_poz(D,uc,Pmin,Pmax,POZ,POZ_EPS);
        [P,~,~]=simple_ga(D,uc,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,PENALTY,GBM,sd,POZ_EPS);
        if t>1,P=enforce_ramp_poz_demand(pP,P,D,uc,pu,Pmin,Pmax,RU,RD,POZ,DEMAND_TOL,POZ_EPS);end
        P=final_balance_geq(P,D,Pmin.*uc,Pmax.*uc,uc,POZ,POZ_EPS);
        [bcc,vcc]=compute_cost(P,uc,a_c,b_c,c_c,d_c,e_c,Pmin);
        cts(run,t)=sum(bcc+vcc); sr(t,:)=P'; pP=P; pu=uc;
    end
    fprintf('[GAmatched] run %2d total=%.2f (%.0fs)\n', run, sum(cts(run,:)), toc);
    save(fullfile(SCRIPT_DIR,'R1c_GArematch.mat'),'cts');
end
G = sum(cts,2);
S = load(fullfile(SCRIPT_DIR,'R1a_v4_FCM_ablation.mat'),'tot');
V = S.tot(:,1);
[p_pt,t_pt,df_pt]=paired_ttest_manual(V,G);
[p_sr,~,z_sr]=signrank_manual(V,G);
[p_rs,~,~]=ranksum_manual(V,G);
sp=sqrt(((N_RUNS-1)*std(V)^2+(N_RUNS-1)*std(G)^2)/(2*N_RUNS-2));
d=(mean(V)-mean(G))/sp;
fid=fopen(fullfile(SCRIPT_DIR,'R1c_GArematch_stats.txt'),'w');
fprintf(fid,'R1.3 REMATCH (POZ fix) v4 vs matched-GA, N=%d\n',N_RUNS);
fprintf(fid,'v4       : mean=%.2f std=%.2f best=%.2f worst=%.2f median=%.2f\n',mean(V),std(V),min(V),max(V),median(V));
fprintf(fid,'GAmatched: mean=%.2f std=%.2f best=%.2f worst=%.2f median=%.2f\n',mean(G),std(G),min(G),max(G),median(G));
fprintf(fid,'diff(v4-GA)=%.2f (%.3f%%)\n',mean(V)-mean(G),100*(mean(V)-mean(G))/mean(G));
fprintf(fid,'paired-t t=%.3f df=%d p=%.4g | signrank z=%.3f p=%.4g | ranksum p=%.4g | d=%.3f\n',t_pt,df_pt,p_pt,z_sr,p_sr,p_rs,d);
if p_pt<0.05, fprintf(fid,'VERDICT: signifikan (alpha=0.05)\n'); else fprintf(fid,'VERDICT: statistical tie (n.s.)\n'); end
fclose(fid);
type(fullfile(SCRIPT_DIR,'R1c_GArematch_stats.txt'));
writetable(table(V,G,'VariableNames',{'v4_Full','GA_matched'}),fullfile(SCRIPT_DIR,'R1c_GArematch.xlsx'),'Sheet','per_run');
writetable(table(mean(V),std(V),mean(G),std(G),mean(V)-mean(G),p_pt,p_sr,p_rs,d,'VariableNames', ...
    {'mean_v4','std_v4','mean_GA','std_GA','diff','p_paired_t','p_signrank','p_ranksum','d'}), ...
    fullfile(SCRIPT_DIR,'R1c_GArematch.xlsx'),'Sheet','summary');
diary off;
fprintf('R1c SELESAI\n');
