function result = run_benchmark_comparison(system, varargin)
%RUN_BENCHMARK_COMPARISON  Compare FCM-PbGA against five standard
%metaheuristics -- PSO, DE, a plain (non-island, non-FCM) GA, ABC, and
%WOA -- on one static ELD benchmark system, with a full statistical
%comparison: descriptive stats, one-way ANOVA, the Friedman test, and
%pairwise (FCM-PbGA vs each competitor) Welch's t-test + Wilcoxon
%rank-sum test.
%
%   result = RUN_BENCHMARK_COMPARISON('6unit')
%   result = RUN_BENCHMARK_COMPARISON('13unit', 'N_RUNS', 10, 'SAVE_RESULTS', false)
%
%   system: one of '6unit', '13unit', '15unit', '40unit'.
%
%   All five competitor algorithms use the SAME repair-based
%   feasibility decoder as FCM-PbGA (lib/repair_balance_batch.m +
%   lib/compute_valve_cost_batch.m: box limits, prohibited zones, and
%   the exact power-balance equality are always enforced by repair, so
%   fitness is pure fuel cost with no penalty term for any algorithm),
%   and are each given the SAME evaluation budget (POPSIZE*NGEN,
%   matched to this system's tuned FCM-PbGA budget -- see
%   lib/load_static_system.m). This isolates what is actually being
%   compared to search-strategy quality, not differences in constraint
%   handling or computational budget. None of the five baselines gets
%   FCM/smooth-economic seeding, stagnation reheating, or the memetic
%   local search that FCM-PbGA itself uses -- those are exactly the
%   novel ingredients under test.
%
%   All statistical tests are implemented from scratch in lib/*_manual.m
%   using only BETAINC / GAMMAINC / ERF (core MATLAB and Octave
%   functions), so this needs no Statistics and Machine Learning
%   Toolbox -- it runs unmodified on MATLAB Online's free tier or on
%   Octave without the 'statistics' package.
%
%   Options (Name/Value):
%     'N_RUNS'       Independent runs per algorithm (default: 20 for
%                    6/13/15-unit, 12 for 40-unit)
%     'BASE_SEED'    RNG seed offset (default 100)
%     'VERBOSE'      Print progress + summary tables (default true)
%     'SAVE_RESULTS' Save CSVs to results/ (default true)
%
%   Returns a struct:
%     result.system, result.algorithms (1x6 cellstr: {'FCM-PbGA','PSO',
%       'DE','GA','ABC','WOA'})
%     result.costs        N_RUNS x 6 matrix (one column per algorithm)
%     result.summary       1x6 struct array: algorithm/best/mean/std/median/worst
%     result.anova          struct: p, F, df1, df2  (one-way ANOVA across all 6)
%     result.friedman        struct: p, chi2, df     (Friedman test across all 6)
%     result.pairwise        1x5 struct array (FCM-PbGA vs each competitor):
%                            algorithm, ttest_p, ranksum_p

    SCRIPT_DIR = fileparts(mfilename('fullpath'));
    if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
    addpath(SCRIPT_DIR);
    addpath(fullfile(SCRIPT_DIR,'lib'));

    switch lower(system)
        case {'6unit','6-unit'},   def_runs = 20; def_seed = 100;
        case {'13unit','13-unit'}, def_runs = 20; def_seed = 100;
        case {'15unit','15-unit'}, def_runs = 15; def_seed = 100;
        case {'40unit','40-unit'}, def_runs = 12; def_seed = 100;
        otherwise
            error('run_benchmark_comparison:badSystem', ...
                'Unknown system "%s". Use one of: 6unit, 13unit, 15unit, 40unit.', system);
    end

    defaults.N_RUNS       = def_runs;
    defaults.BASE_SEED    = def_seed;
    defaults.VERBOSE      = true;
    defaults.SAVE_RESULTS = true;
    opts = merge_options(defaults, varargin);

    RES_DIR = fullfile(SCRIPT_DIR,'results');
    if opts.SAVE_RESULTS && ~exist(RES_DIR,'dir'), mkdir(RES_DIR); end

    S = load_static_system(system);
    N_RUNS = opts.N_RUNS; BASE_SEED = opts.BASE_SEED;
    N_ = length(S.Pmin);

    if opts.VERBOSE
        fprintf('=== Benchmark Comparison: %s system (D=%.0f MW, %d runs/algorithm) ===\n', ...
            S.system, S.D, N_RUNS);
    end

    algNames = {'FCM-PbGA','PSO','DE','GA','ABC','WOA'};
    costs = zeros(N_RUNS, 6);

    %% ---- FCM-PbGA: reuse the already-tuned callable function ----
    if opts.VERBOSE, fprintf('-- FCM-PbGA --\n'); end
    switch lower(system)
        case {'6unit','6-unit'}
            rFCM = run_6unit_ELD('N_RUNS',N_RUNS,'BASE_SEED',BASE_SEED,'VERBOSE',false,'SAVE_RESULTS',false);
        case {'13unit','13-unit'}
            rFCM = run_13unit_ELD('N_RUNS',N_RUNS,'BASE_SEED',BASE_SEED,'VERBOSE',false,'SAVE_RESULTS',false);
        case {'15unit','15-unit'}
            rFCM = run_15unit_static_ELD('N_RUNS',N_RUNS,'BASE_SEED',BASE_SEED,'VERBOSE',false,'SAVE_RESULTS',false);
        case {'40unit','40-unit'}
            rFCM = run_40unit_ELD('N_RUNS',N_RUNS,'BASE_SEED',BASE_SEED,'VERBOSE',false,'SAVE_RESULTS',false);
    end
    costs(:,1) = rFCM.costs;
    if opts.VERBOSE, fprintf('   best=$%.4f mean=$%.4f\n', rFCM.best_cost, rFCM.mean_cost); end

    %% ---- Competitor algorithms (matched evaluation budget) ----
    POP = S.BUDGET.POPSIZE; NGEN = S.BUDGET.NGEN;

    PSOp.POPSIZE=POP; PSOp.NGEN=NGEN; PSOp.W_MAX=0.9; PSOp.W_MIN=0.4; PSOp.C1=1.6; PSOp.C2=1.6; PSOp.VEL_FRAC=0.2;
    DEp.POPSIZE=POP;  DEp.NGEN=NGEN;  DEp.F=0.6; DEp.CR=0.9;
    GAp.POPSIZE=POP;  GAp.NGEN=NGEN;  GAp.CXPB=0.9; GAp.MUTPB=0.4; GAp.INDPB=0.3; ...
        GAp.SIGMA_FRAC=0.25; GAp.SIGMA_DECAY=0.99; GAp.TOURNSIZE=3; GAp.ELITE_K=2;
    ABCp.POPSIZE=POP; ABCp.NGEN=NGEN; ABCp.LIMIT=max(20, round(POP*N_/2));
    WOAp.POPSIZE=POP; WOAp.NGEN=NGEN; WOAp.B_SPIRAL=1;

    algFuns = {
        @(sd) pso_static(S.D,S.Pmin,S.Pmax,S.a,S.b,S.c,S.d,S.e,S.Bij,S.B0i,S.B00,S.POZ,PSOp,sd,S.EV), ...
        @(sd) de_static(S.D,S.Pmin,S.Pmax,S.a,S.b,S.c,S.d,S.e,S.Bij,S.B0i,S.B00,S.POZ,DEp,sd,S.EV), ...
        @(sd) ga_simple_static(S.D,S.Pmin,S.Pmax,S.a,S.b,S.c,S.d,S.e,S.Bij,S.B0i,S.B00,S.POZ,GAp,sd,S.EV), ...
        @(sd) abc_static(S.D,S.Pmin,S.Pmax,S.a,S.b,S.c,S.d,S.e,S.Bij,S.B0i,S.B00,S.POZ,ABCp,sd,S.EV), ...
        @(sd) woa_static(S.D,S.Pmin,S.Pmax,S.a,S.b,S.c,S.d,S.e,S.Bij,S.B0i,S.B00,S.POZ,WOAp,sd,S.EV) ...
    };

    bestConv = cell(1,6);
    bestConv{1} = rFCM.best_conv;
    for ai = 1:5
        if opts.VERBOSE, fprintf('-- %s --\n', algNames{ai+1}); end
        bestf = inf; bestc = [];
        for run = 1:N_RUNS
            [~, fval, cv] = algFuns{ai}(BASE_SEED + run + ai*1000);
            costs(run, ai+1) = fval;
            if fval < bestf, bestf = fval; bestc = cv; end
        end
        bestConv{ai+1} = bestc;
        if opts.VERBOSE
            fprintf('   best=$%.4f mean=$%.4f\n', min(costs(:,ai+1)), mean(costs(:,ai+1)));
        end
    end

    %% ---- Descriptive stats ----
    summary = struct('algorithm',{},'best',{},'mean',{},'std',{},'median',{},'worst',{});
    for k_ = 1:6
        summary(k_).algorithm = algNames{k_};
        summary(k_).best   = min(costs(:,k_));
        summary(k_).mean   = mean(costs(:,k_));
        summary(k_).std    = std(costs(:,k_));
        summary(k_).median = median(costs(:,k_));
        summary(k_).worst  = max(costs(:,k_));
    end

    %% ---- Omnibus tests ----
    [anova_p, anova_F, anova_df1, anova_df2] = anova1_manual(costs);
    [fried_p, fried_chi2, fried_df] = friedman_manual(costs);

    %% ---- Pairwise: FCM-PbGA vs each competitor ----
    pairwise = struct('algorithm',{},'ttest_p',{},'ranksum_p',{});
    for ai = 1:5
        [tp,~,~] = ttest2_manual(costs(:,1), costs(:,ai+1));
        [rp,~,~] = ranksum_manual(costs(:,1), costs(:,ai+1));
        pairwise(ai).algorithm = algNames{ai+1};
        pairwise(ai).ttest_p   = tp;
        pairwise(ai).ranksum_p = rp;
    end

    if opts.VERBOSE
        fprintf('\n--- %s: Summary ---\n', S.system);
        fprintf('%-10s %14s %14s %10s %14s\n', 'Algorithm','Best','Mean','Std','Median');
        for k_ = 1:6
            fprintf('%-10s %14.4f %14.4f %10.4f %14.4f\n', summary(k_).algorithm, ...
                summary(k_).best, summary(k_).mean, summary(k_).std, summary(k_).median);
        end
        fprintf('\nOne-way ANOVA: F(%d,%d)=%.4f, p=%.6g %s\n', ...
            anova_df1, anova_df2, anova_F, anova_p, sig_str(anova_p));
        fprintf('Friedman test: chi2(%d)=%.4f, p=%.6g %s\n', ...
            fried_df, fried_chi2, fried_p, sig_str(fried_p));
        fprintf('\nPairwise vs FCM-PbGA:\n');
        fprintf('%-10s %14s %14s\n', 'Algorithm','t-test p','Wilcoxon p');
        for ai = 1:5
            fprintf('%-10s %14.6g %14.6g %s\n', pairwise(ai).algorithm, ...
                pairwise(ai).ttest_p, pairwise(ai).ranksum_p, ...
                sig_str(min(pairwise(ai).ttest_p, pairwise(ai).ranksum_p)));
        end
        fprintf('(*** p<0.001, ** p<0.01, * p<0.05, ns = not significant)\n');
    end

    %% ---- Save ----
    if opts.SAVE_RESULTS
        csvwrite(fullfile(RES_DIR, sprintf('%s_comparison_costs.csv', S.system)), costs);

        fid = fopen(fullfile(RES_DIR, sprintf('%s_comparison_summary.csv', S.system)), 'w');
        fprintf(fid, 'Algorithm,Best,Mean,Std,Median,Worst\n');
        for k_ = 1:6
            fprintf(fid, '%s,%.6f,%.6f,%.6f,%.6f,%.6f\n', summary(k_).algorithm, ...
                summary(k_).best, summary(k_).mean, summary(k_).std, summary(k_).median, summary(k_).worst);
        end
        fclose(fid);

        fid = fopen(fullfile(RES_DIR, sprintf('%s_comparison_stats.csv', S.system)), 'w');
        fprintf(fid, 'Test,Statistic,df,p_value\n');
        fprintf(fid, 'ANOVA,%.6f,%d/%d,%.8f\n', anova_F, anova_df1, anova_df2, anova_p);
        fprintf(fid, 'Friedman,%.6f,%d,%.8f\n', fried_chi2, fried_df, fried_p);
        for ai = 1:5
            fprintf(fid, 'ttest_FCMPbGA_vs_%s,,,%.8f\n', pairwise(ai).algorithm, pairwise(ai).ttest_p);
            fprintf(fid, 'ranksum_FCMPbGA_vs_%s,,,%.8f\n', pairwise(ai).algorithm, pairwise(ai).ranksum_p);
        end
        fclose(fid);

        plot_convergence_multi(bestConv, algNames, sprintf('%s: Convergence (best run per algorithm)', S.system), ...
            fullfile(RES_DIR, sprintf('%s_comparison_convergence.png', S.system)));

        if opts.VERBOSE
            fprintf('\nSaved: results/%s_comparison_costs.csv, _summary.csv, _stats.csv, _convergence.png\n', S.system);
        end
    end

    %% ---- Return ----
    result.system     = S.system;
    result.algorithms = algNames;
    result.costs      = costs;
    result.summary    = summary;
    result.anova      = struct('p',anova_p, 'F',anova_F, 'df1',anova_df1, 'df2',anova_df2);
    result.friedman   = struct('p',fried_p, 'chi2',fried_chi2, 'df',fried_df);
    result.pairwise   = pairwise;
    result.best_conv  = bestConv;  % 1x6 cell array, best-run convergence curve per algorithm
end

function s = sig_str(p)
    if p < 0.001, s = '***';
    elseif p < 0.01, s = '**';
    elseif p < 0.05, s = '*';
    else, s = 'ns';
    end
end
