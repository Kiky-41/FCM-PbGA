%% verify_env.m — cek environment MATLAB lokal sebelum run revisi
% Dipanggil oleh run_semua_revisi_local (pilihan 1). Tidak butuh toolbox khusus.

clear; clc;
fprintf('MATLAB %s\n', version);
need = {'ELD_Test_System.xlsx','powerdemand.xlsx','FCM_PbGA_v1.m','FCM_PbGA_v4_Results.xlsx'};
ok = true;
for i=1:numel(need)
    e = exist(need{i},'file');
    fprintf('%-28s : %s\n', need{i}, ternary(e,'ADA','HILANG'));
    if ~e, ok=false; end
end
% cek fungsi statistik (Statistics Toolbox bila ada; fallback manual tersedia)
for f={'ttest','ranksum','anova1','friedman'}
    fprintf('fungsi %-12s : %s\n', f{1}, ternary(exist(f{1},'file'),'ADA','HILANG (pakai fallback manual di lib/)'));
end
if exist('CEC2020/cec20_basic_func.m','file')
    fprintf('CEC2020 resmi : ADA\n');
else
    fprintf('CEC2020 resmi : BELUM ADA — unduh Software.zip dari\n  https://github.com/P-N-Suganthan/2020-Bound-Constrained-Opt-Benchmark\n  extract ke ./CEC2020/\n');
end
fprintf(ternary(ok,'ENV OK — lanjut ke audit R1.2.\n','LENGKAPI file HILANG dulu.\n'));

function s = ternary(c,a,b)
if c, s=a; else, s=b; end
end
