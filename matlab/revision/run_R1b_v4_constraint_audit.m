%% run_R1b_v4_constraint_audit.m — R1.2 FINAL (perbaikan slicing kolom U1..U15)
% Audit independen raw vs adjusted (15 unit x 24 jam): power-balance
% shortfall, ramp (+startup-cap), POZ, generation limits. N + maks MW.
% Output: R1b_v4_constraint_audit.xlsx + tabel LaTeX di console.
clear; clc;
addpath(fullfile(fileparts(mfilename('fullpath')),'lib'));
SCRIPT_DIR = fileparts(mfilename('fullpath'));
if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
V4_FILE = fullfile(SCRIPT_DIR, 'FCM_PbGA_v4_Results.xlsx');
ELD_FILE= fullfile(SCRIPT_DIR, 'ELD_Test_System.xlsx');
OUT_XLSX= fullfile(SCRIPT_DIR, 'R1b_v4_constraint_audit.xlsx');

unit_data = readtable(ELD_FILE,'VariableNamingRule','preserve','TextType','string');
Pmin=double(unit_data.pmin); Pmax=double(unit_data.pmax);
RU=double(unit_data.rampup); RD=double(unit_data.rampdown);
POZ=parse_poz_table(unit_data);
N=numel(Pmin);

Traw = readtable(V4_FILE,'Sheet','Schedule_Raw');
Tadj = readtable(V4_FILE,'Sheet','Schedule_Adjusted');
Tuc  = readtable(V4_FILE,'Sheet','Unit_Commitment');
ucols = arrayfun(@(i)sprintf('U%d',i),1:15,'UniformOutput',false);
RAW = Traw{:,ucols}; ADJ = Tadj{:,ucols}; UC = Tuc{:,ucols};
demand = Traw.Demand_MW; T = numel(demand);
assert(all(size(RAW)==[T,N]) && all(size(ADJ)==[T,N]) && all(size(UC)==[T,N]));

Araw = audit_schedule(RAW,UC,demand,Pmin,Pmax,RU,RD,POZ,N,T);
Aadj = audit_schedule(ADJ,UC,demand,Pmin,Pmax,RU,RD,POZ,N,T);
fprintf('--- PRE-REPAIR (raw) ---\n'); disp(Araw.summary);
fprintf('--- POST-REPAIR (adjusted) ---\n'); disp(Aadj.summary);

summary = table({'Power-balance (MW shortfall)';'Ramp-rate';'POZ';'Gen-limits'}, ...
    [Araw.n_bal; Araw.n_ramp; Araw.n_poz; Araw.n_lim], ...
    [Araw.mag_bal; Araw.mag_ramp; Araw.mag_poz; Araw.mag_lim], ...
    [Aadj.n_bal; Aadj.n_ramp; Aadj.n_poz; Aadj.n_lim], ...
    [Aadj.mag_bal; Aadj.mag_ramp; Aadj.mag_poz; Aadj.mag_lim], ...
    'VariableNames', {'Constraint','Nviol_pre','MaxMag_pre','Nviol_post','MaxMag_post'});
writetable(summary, OUT_XLSX, 'Sheet','v4_before_after');
writetable(Araw.detail, OUT_XLSX, 'Sheet','detail_pre');
writetable(Aadj.detail, OUT_XLSX, 'Sheet','detail_post');
fprintf('Tersimpan: %s\n', OUT_XLSX);
fprintf('\n--- LaTeX ---\n');
fprintf(['\\begin{tabular}{l rr rr}\\toprule\nConstraint & N_{pre} & Max_{pre} & N_{post} & Max_{post}\\\\\\midrule\n' ...
    'Power balance & %d & %.4g MW & %d & %.4g MW\\\\\nRamp rate & %d & %.4g MW & %d & %.4g MW\\\\\n' ...
    'POZ & %d & %.4g MW & %d & %.4g MW\\\\\nGen. limits & %d & %.4g MW & %d & %.4g MW\\\\\\bottomrule\\end{tabular}\n'], ...
    Araw.n_bal,Araw.mag_bal,Aadj.n_bal,Aadj.mag_bal, Araw.n_ramp,Araw.mag_ramp,...
    Aadj.n_ramp,Aadj.mag_ramp, Araw.n_poz,Araw.mag_poz,Aadj.n_poz,Aadj.mag_poz,...
    Araw.n_lim,Araw.mag_lim,Aadj.n_lim,Aadj.mag_lim);

function A = audit_schedule(P,UC,demand,Pmin,Pmax,RU,RD,POZ,N,T)
    n_bal=0; mag_bal=0; n_ramp=0; mag_ramp=0; n_poz=0; mag_poz=0; n_lim=0; mag_lim=0;
    dh=[]; du=[]; dt={}; dm=[];
    for t=1:T
        sf = max(0, demand(t)-sum(P(t,:)));
        if sf > 1e-4, n_bal=n_bal+1; mag_bal=max(mag_bal,sf);
            dh=[dh;t]; du=[du;0]; dt=[dt;{'balance'}]; dm=[dm;sf]; end
        for i=1:N
            p=P(t,i);
            if UC(t,i)<0.5
                if abs(p)>1e-6, n_lim=n_lim+1; mag_lim=max(mag_lim,abs(p));
                    dh=[dh;t]; du=[du;i]; dt=[dt;{'offline_nonzero'}]; dm=[dm;abs(p)]; end
                continue;
            end
            if p < Pmin(i)-1e-6 || p > Pmax(i)+1e-6
                n_lim=n_lim+1;
                v = max(Pmin(i)-p, p-Pmax(i));
                mag_lim=max(mag_lim,v);
                dh=[dh;t]; du=[du;i]; dt=[dt;{'genlim'}]; dm=[dm;v]; end
            if t>1
                if UC(t-1,i)>0.5
                    up=p-P(t-1,i); dn=P(t-1,i)-p;
                    if up > RU(i)+1e-6, n_ramp=n_ramp+1; mag_ramp=max(mag_ramp,up-RU(i));
                        dh=[dh;t]; du=[du;i]; dt=[dt;{'ramp_up'}]; dm=[dm;up-RU(i)]; end
                    if dn > RD(i)+1e-6, n_ramp=n_ramp+1; mag_ramp=max(mag_ramp,dn-RD(i));
                        dh=[dh;t]; du=[du;i]; dt=[dt;{'ramp_dn'}]; dm=[dm;dn-RD(i)]; end
                else
                    cap=min(Pmax(i),RU(i));
                    if p>cap+1e-6, n_ramp=n_ramp+1; mag_ramp=max(mag_ramp,p-cap);
                        dh=[dh;t]; du=[du;i]; dt=[dt;{'startup_cap'}]; dm=[dm;p-cap]; end
                end
            end
            iv=POZ{i};
            for k=1:size(iv,1)
                if p>iv(k,1)+1e-9 && p<iv(k,2)-1e-9
                    n_poz=n_poz+1;
                    v=min(abs(p-iv(k,1)),abs(p-iv(k,2)));
                    mag_poz=max(mag_poz,v);
                    dh=[dh;t]; du=[du;i]; dt=[dt;{'poz'}]; dm=[dm;v]; break;
                end
            end
        end
    end
    if isempty(dh)
        detail=table([],[],{},[],'VariableNames',{'hour','unit','type','magnitude'});
    else
        detail=table(dh,du,dt,dm,'VariableNames',{'hour','unit','type','magnitude'});
    end
    A=struct('n_bal',n_bal,'mag_bal',mag_bal,'n_ramp',n_ramp,'mag_ramp',mag_ramp,...
        'n_poz',n_poz,'mag_poz',mag_poz,'n_lim',n_lim,'mag_lim',mag_lim,...
        'summary',table(n_bal,n_ramp,n_poz,n_lim,mag_bal,mag_ramp,mag_poz,mag_lim),...
        'detail',detail);
end
