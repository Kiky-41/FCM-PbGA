%% run_CEC2020_FCMPbGA.m — R2.5 FINAL (kode resmi CEC2020, tanpa toolbox)
% Suite resmi: F1 unimodal; F2-F4 multimodal; F5-F7 hybrid; F8-F10 komposisi.
% Protokol mengikuti preseden Wu et al. 2022 (Entropy): D=10, MaxFES=10000,
% populasi 100, 30 run, AVG/STD + Wilcoxon rank-sum alpha=0.05.
% v4-core generik (single-pop, BLX-alpha, Gaussian no-decay, elitisme 1,
% FCM-centroid seeding 15%) vs GA polos (seeding OFF), FES identik.
% Butuh: folder CEC2020/Matlab version/ sebagai cwd (cec20_func.mexw64 +
% input_data/). Output: CEC2020_results.xlsx/.txt
addpath(fullfile(fileparts(mfilename('fullpath')),'lib'));
ROOT = fileparts(mfilename('fullpath'));
if isempty(ROOT), ROOT = pwd; end
CECDIR = fullfile(ROOT,'CEC2020','Matlab version');
cd(CECDIR);
diary(fullfile(ROOT,'CEC2020_log.txt')); diary on;

D = 10; POP = 100; MAXFES = 10000; N_RUNS = 30;
GENS = floor(MAXFES/POP);
fprintf('CEC2020 D=%d POP=%d MAXFES=%d GENS=%d RUNS=%d\n', D, POP, MAXFES, GENS, N_RUNS);

res = zeros(10,7);  % v4mean v4std v4best GAmean GAstd GAbest p_ranksum
for fn = 1:10
    cv = zeros(N_RUNS,1); gv = zeros(N_RUNS,1);
    for r = 1:N_RUNS
        cv(r) = v4core(fn,D,POP,GENS,0.15,1000+r);
        gv(r) = v4core(fn,D,POP,GENS,0.00,2000+r);
    end
    [p_rs,~,~] = ranksum_manual(cv,gv);
    res(fn,:) = [mean(cv),std(cv),min(cv),mean(gv),std(gv),min(gv),p_rs];
    fprintf('F%-2d v4: %.4e +- %.2e best %.4e | GA: %.4e +- %.2e best %.4e | p=%.4g %s\n', ...
        fn, res(fn,1),res(fn,2),res(fn,3),res(fn,4),res(fn,5),res(fn,6),p_rs, ...
        ternary(res(fn,1)<res(fn,4),'v4<GA','v4>=GA'));
    save(fullfile(ROOT,'CEC2020_results.mat'),'res');
end
T = array2table([(1:10)',res],'VariableNames',{'Func','v4_mean','v4_std','v4_best','GA_mean','GA_std','GA_best','p_ranksum'});
writetable(T, fullfile(ROOT,'CEC2020_results.xlsx'));
disp(T);
diary off;
fprintf('CEC2020 SELESAI\n');

function best = v4core(fn,D,POP,GENS,seedFrac,seed)
    rng(seed);
    lb = -100; ub = 100;
    X = lb + (ub-lb)*rand(POP,D);            % POP x D
    if seedFrac > 0                          % surrogate FCM-centroid seeding
        C = mean(X(1:max(8,round(POP*0.2)),:),1);
        nS = ceil(seedFrac*POP);
        X(1:nS,:) = C + 0.05*(ub-lb)*randn(nS,D);
        X = max(lb,min(ub,X));
    end
    F = cec20_func(X',fn)';                  % 1 call = POP evals
    [best,bi] = min(F);
    SIG = 0.2*(ub-lb);
    for g = 1:GENS
        Xn = zeros(POP,D); Xn(1,:) = X(bi,:);
        for i = 2:POP
            % tournament jujur dari fitness array:
            idx = randi(POP,3,1); [~,w] = min(F(idx)); p1 = X(idx(w),:);
            idx = randi(POP,3,1); [~,w] = min(F(idx)); p2 = X(idx(w),:);
            ch = p1;
            if rand < 0.85
                d2 = abs(p1-p2);
                ch = min(p1,p2)-0.5*d2 + rand(1,D).*(2*d2+2*0.5*d2);
            end
            if rand < 0.3
                mk = rand(1,D) < 0.2;
                ch(mk) = ch(mk) + SIG*randn(1,sum(mk));
            end
            Xn(i,:) = max(lb,min(ub,ch));
        end
        F = cec20_func(Xn',fn)';
        X = Xn; [b2,bi] = min(F); best = min(best,b2);
    end
end

function s = ternary(c,a,b)
if c, s = a; else, s = b; end
end
