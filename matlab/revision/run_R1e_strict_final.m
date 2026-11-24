%% run_R1e_strict_final.m — FINAL: v4-strict vs matched-GA-strict (30 run, POZ fix)
% Search IDENTIK dgn revisi (seed sama) — hanya final mapping raw->final
% diganti strict_repair_horizon (nol pelanggaran). Audit ketat SEMUA run.
% Output: R1e_strict_final.mat/.xlsx/.txt
addpath(fullfile(fileparts(mfilename('fullpath')),'lib'));
SCRIPT_DIR = fileparts(mfilename('fullpath'));
if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
diary(fullfile(SCRIPT_DIR,'R1e_log.txt')); diary on;
N_RUNS = 30;

[unit_data, POZ]=load_unit_data_fixed(fullfile(SCRIPT_DIR,'ELD_Test_System.xlsx')); % FIX R1: paksa kolom poz sbg string (readtable default -> double/NaN = POZ hilang)
demand_data = readtable(fullfile(SCRIPT_DIR,'powerdemand.xlsx'));
N=height(unit_data); T=height(demand_data);
Pmin=unit_data.pmin; Pmax=unit_data.pmax;
a_c=unit_data.a; b_c=unit_data.b; c_c=unit_data.c; d_c=unit_data.d; e_c=unit_data.e;
RU=unit_data.rampup; RD=unit_data.rampdown; Pnow=unit_data.Pnow;
demand=demand_data.load;

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

GB=GA0; GB.LOCAL_SEARCH=false; GB.FCM_SEED_FRAC=0; GB.SEED=42;
GB.POZ_AWARE_CROSSOVER=false;

cV=zeros(N_RUNS,1); cG=zeros(N_RUNS,1);
vB=zeros(N_RUNS,1); vR=zeros(N_RUNS,1); vP=zeros(N_RUNS,1); vL=zeros(N_RUNS,1);
gB=zeros(N_RUNS,1); gR=zeros(N_RUNS,1); gP=zeros(N_RUNS,1); gL=zeros(N_RUNS,1);
bestV=inf; bestVsa=[]; bestVuc=[];
for run=1:N_RUNS
    tic;
    [sr,~,us,~,~,~,~]=solve_horizon_novel(demand,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,...
        RU,RD,POZ,PENALTY,DEMAND_TOL,POZ_EPS,GA0,FCM,N,T,run,true,Pnow);
    [saf,ucf,costf,~]=strict_repair_horizon(sr,us,demand,Pmin,Pmax,RU,RD,POZ,Pnow,a_c,b_c,c_c,d_c,e_c,Pmin);
    cV(run)=sum(costf);
    vv=audit_counts(saf,ucf,demand,Pmin,Pmax,RU,RD,POZ,Pnow,N,T);
    vB(run)=vv(1); vR(run)=vv(2); vP(run)=vv(3); vL(run)=vv(4);
    if cV(run)<bestV, bestV=cV(run); bestVsa=saf; bestVuc=ucf; end
    fprintf('[v4strict] run %2d total=%.2f viol=[%d %d %d %d] (%.0fs)\n',run,cV(run),vv,toc);
    save(fullfile(SCRIPT_DIR,'R1e_strict_final.mat'),'cV','cG','vB','vR','vP','vL','gB','gR','gP','gL');
end
for run=1:N_RUNS
    tic;
    rng(42+run+1*10000); pP=Pmax*0.5; pu=ones(N,1);
    sr=zeros(T,N); us=zeros(T,N);
    for t=1:T
        D=demand(t); sd=42*100+t+run*1000+1*1e6;
        uc=apply_uc_basic(D,Pmin,Pmax);
        uc=escalate_uc_poz(D,uc,Pmin,Pmax,POZ,POZ_EPS);
        [P,~,~]=simple_ga(D,uc,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c,POZ,PENALTY,GB,sd,POZ_EPS);
        sr(t,:)=P'; us(t,:)=uc'; pP=P; pu=uc;
    end
    [sg,ug,cg,~]=strict_repair_horizon(sr,us,demand,Pmin,Pmax,RU,RD,POZ,Pnow,a_c,b_c,c_c,d_c,e_c,Pmin);
    cG(run)=sum(cg);
    gg=audit_counts(sg,ug,demand,Pmin,Pmax,RU,RD,POZ,Pnow,N,T);
    gB(run)=gg(1); gR(run)=gg(2); gP(run)=gg(3); gL(run)=gg(4);
    fprintf('[GAstrict] run %2d total=%.2f viol=[%d %d %d %d] (%.0fs)\n',run,cG(run),gg,toc);
    save(fullfile(SCRIPT_DIR,'R1e_strict_final.mat'),'cV','cG','vB','vR','vP','vL','gB','gR','gP','gL');
end
save(fullfile(SCRIPT_DIR,'R1e_best.mat'),'bestVsa','bestVuc','bestV');

[p_pt,t_pt,df_pt]=paired_ttest_manual(cV,cG);
[p_sr,~,z_sr]=signrank_manual(cV,cG);
[p_rs,~,~]=ranksum_manual(cV,cG);
sp=sqrt(((N_RUNS-1)*std(cV)^2+(N_RUNS-1)*std(cG)^2)/(2*N_RUNS-2));
d=(mean(cV)-mean(cG))/sp;
fid=fopen(fullfile(SCRIPT_DIR,'R1e_strict_final_stats.txt'),'w');
fprintf(fid,'R1e FINAL STRICT (POZ fix + strict repair) v4 vs matched-GA, N=%d\n',N_RUNS);
fprintf(fid,'v4strict : mean=%.2f std=%.2f best=%.2f worst=%.2f median=%.2f\n',mean(cV),std(cV),min(cV),max(cV),median(cV));
fprintf(fid,'GAstrict : mean=%.2f std=%.2f best=%.2f worst=%.2f median=%.2f\n',mean(cG),std(cG),min(cG),max(cG),median(cG));
fprintf(fid,'diff=%.2f (%.4f%%)\n',mean(cV)-mean(cG),100*(mean(cV)-mean(cG))/mean(cG));
fprintf(fid,'paired-t t=%.3f df=%d p=%.4g | signrank z=%.3f p=%.4g | ranksum p=%.4g | d=%.3f\n',t_pt,df_pt,p_pt,z_sr,p_sr,p_rs,d);
if p_pt<0.05, fprintf(fid,'VERDICT: signifikan (alpha=0.05)\n'); else fprintf(fid,'VERDICT: statistical tie (n.s.)\n'); end
fprintf(fid,'v4strict violations 30 runs: bal=%d ramp=%d poz=%d lim=%d (unit-hours=%d)\n',sum(vB),sum(vR),sum(vP),sum(vL),N_RUNS*T*N);
fprintf(fid,'GAstrict violations 30 runs: bal=%d ramp=%d poz=%d lim=%d\n',sum(gB),sum(gR),sum(gP),sum(gL));
fclose(fid);
type(fullfile(SCRIPT_DIR,'R1e_strict_final_stats.txt'));
writetable(table(cV,cG,'VariableNames',{'v4strict','GAstrict'}),fullfile(SCRIPT_DIR,'R1e_strict_final.xlsx'),'Sheet','per_run');
writetable(table(vB,vR,vP,vL,gB,gR,gP,gL,'VariableNames',{'v4_bal','v4_ramp','v4_poz','v4_lim','GA_bal','GA_ramp','GA_poz','GA_lim'}), ...
    fullfile(SCRIPT_DIR,'R1e_strict_final.xlsx'),'Sheet','viol_per_run');
writetable(table(mean(cV),std(cV),mean(cG),std(cG),mean(cV)-mean(cG),p_pt,p_sr,p_rs,d, ...
    sum(vB)+sum(vR)+sum(vP)+sum(vL),sum(gB)+sum(gR)+sum(gP)+sum(gL), ...
    'VariableNames',{'mean_v4','std_v4','mean_GA','std_GA','diff','p_paired_t','p_signrank','p_ranksum','d','v4_viol_total','GA_viol_total'}), ...
    fullfile(SCRIPT_DIR,'R1e_strict_final.xlsx'),'Sheet','summary');
diary off;
fprintf('R1e SELESAI\n');

function vv = audit_counts(P,UC,demand,Pmin,Pmax,RU,RD,POZ,Pnow,N,T)
    n_bal=0; n_ramp=0; n_poz=0; n_lim=0;
    PP=[Pnow'; P]; UU=[ones(1,N); UC];
    for t=1:T
        if max(0,demand(t)-sum(P(t,:)))>1e-4, n_bal=n_bal+1; end
        for i=1:N
            p=P(t,i);
            if UC(t,i)<0.5
                if abs(p)>1e-6, n_lim=n_lim+1; end
                continue;
            end
            if p<Pmin(i)-1e-6||p>Pmax(i)+1e-6, n_lim=n_lim+1; end
            if UU(t,i)>0.5
                if p-PP(t,i)>RU(i)+1e-6||PP(t,i)-p>RD(i)+1e-6, n_ramp=n_ramp+1; end
            else
                if p<Pmin(i)-1e-6||p>min(Pmax(i),Pmin(i)+RU(i))+1e-6, n_ramp=n_ramp+1; end
            end
            iv=POZ{i};
            for k=1:size(iv,1)
                if p>iv(k,1)+1e-9&&p<iv(k,2)-1e-9, n_poz=n_poz+1; break; end
            end
        end
    end
    vv=[n_bal,n_ramp,n_poz,n_lim];
end
