clc;
clear;
close all;

%% Load Data dari Excel
filename = 'Convergence_Curves.xlsx';

% Membaca sheet MeanConvergence
meanData = readtable(filename, 'Sheet', 'MeanConvergence');

%% Ambil Data
Gen = meanData.Gen;

FCM_PbGA = meanData.Mean_FCM_PbGA;
GA        = meanData.Mean_GA;
PSO       = meanData.Mean_PSO;
GWO       = meanData.Mean_GWO;
WOA       = meanData.Mean_WOA;

%% Plot Convergence Curve
figure('Color','w');

plot(Gen, FCM_PbGA, 'r-', 'LineWidth', 2);
hold on;
plot(Gen, GA, 'b--', 'LineWidth', 2);
plot(Gen, PSO, 'g-.', 'LineWidth', 2);
plot(Gen, GWO, 'm:', 'LineWidth', 2);
plot(Gen, WOA, 'k-', 'LineWidth', 2);

%% Label dan Tampilan
xlabel('Generation');
ylabel('Objective Function Value');
%title('Convergence Curve Comparison');

legend('FCM-PbGA', 'GA', 'PSO', 'GWO', 'WOA', ...
    'Location', 'northeast');

grid on;
box on;
set(gca, 'FontSize', 12, 'LineWidth', 1.2);

%% Optional: Simpan Gambar
saveas(gcf, 'ConvergenceCurve.png');