%% smoke_v4.m — uji asap 1 run v4-Full vs v4-NoFCM (validasi pipeline)
% Jalankan di folder Revisi/:  matlab -batch "smoke_v4"
addpath(fullfile(fileparts(mfilename('fullpath')),'lib'));
SCRIPT_DIR = fileparts(mfilename('fullpath'));
if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
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
FCM.N_CLUSTERS=5; FCM.MIN_SAMPLES=8; FCM.M=2; FCM.ERROR=0.005; FCM.MAXITER=500;
PENALTY=1e9; DEMAND_TOL=1e-4; POZ_EPS=1e-6;

GA_v4=GA0;
GA_v4.ISLAND_SCHEDULE=1; GA_v4.MERGE_GENS=[];
GA_v4.REHEAT_ENABLE=false; GA_v4.STAGNATION_WINDOW=15; GA_v4.REHEAT_FACTOR=2.5;
GA_v4.POZ_AWARE_CROSSOVER=true;
GA_v4.FCM_SEED_FRAC=0.15; GA_v4.FCM_SEED_SIGMA=0.05;

tic;
[sr1,sa1,~,ch1,~,~,~]=solve_horizon_novel(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
    RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA_v4,FCM,N,T,1,true,Pnow);
t1=toc; fprintf('Full  run1 total=%.2f time=%.1fs\n', sum(ch1), t1);
tic;
[sr0,sa0,~,ch0,~,~,~]=solve_horizon_novel(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
    RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA_v4,FCM,N,T,1,false,Pnow);
t0=toc; fprintf('NoFCM run1 total=%.2f time=%.1fs\n', sum(ch0), t0);
fprintf('SMOKE OK\n');
