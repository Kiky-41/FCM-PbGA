%% run_semua_revisi_local.m — MASTER RUNNER (jalankan di MATLAB lokal)
% Copy SEMUA file .m dari Revisi_Jawaban/ ke folder Revisi/ (sejajar
% FCM_PbGA_v1.m, ELD_Test_System.xlsx, powerdemand.xlsx,
% FCM_PbGA_v4_Results.xlsx), lalu di MATLAB: run_semua_revisi_local
%
% Menu:
%   1 = verifikasi environment (wajib pertama kali)
%   2 = R1.2 audit constraint v4 — CEPAT (baca xlsx, tanpa re-run) ~1 mnt
%   3 = R1.1 ablasi FCM v4 (30 run) — BERAT (jam-jaman, overnight)
%   4 = R1.4 ablasi LS v4 (30 run) — BERAT
%   5 = R2.5 CEC2020 (butuh ./CEC2020/cec20_basic_func.m) — SEDANG
% Untuk R1.1/R1.4: butuh local functions dari FCM_PbGA_v1.m (lihat header
% tiap file, opsi A: paste blok ini sebagai section di FCM_PbGA_v1.m).

clear; clc;
SCRIPT_DIR = fileparts(mfilename('fullpath'));
if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
cd(SCRIPT_DIR);

fprintf(['Pilih:\n 1=verify  2=R1.2 audit(cepat)  3=R1.1 FCM-ablasi(berat)' ...
    '  4=R1.4 LS-ablasi(berat)  5=CEC2020\n']);
pil = input('Pilihan [1-5] (atau 0=semua yg cepat 1+2): ');

if pil==1 || pil==0, verify_env; end
if pil==2 || pil==0, run_R1b_v4_constraint_audit; end
if pil==3, run_R1a_v4_FCM_ablation; end
if pil==4, run_R1d_v4_LS_ablation; end
if pil==5, run_CEC2020_FCMPbGA; end
fprintf('Selesai.\n');
