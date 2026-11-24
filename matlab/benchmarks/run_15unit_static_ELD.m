function result = run_15unit_static_ELD(varargin)
%RUN_15UNIT_STATIC_ELD  FCM-PbGA (static variant) on the 15-Unit ELD
%Test System (Al-Roomi benchmark: ramp-rate/POZ/valve-point dataset,
%solved here as a SINGLE-PERIOD dispatch with Kron's B-loss added,
%which is the classic literature convention for this exact 15-unit
%table).
%
%   result = RUN_15UNIT_STATIC_ELD() runs with the tuned defaults (30
%   independent runs) and returns a struct:
%     result.best_cost, .mean_cost, .std_cost, .costs (Nx1),
%     result.best_P (dispatch, MW), result.best_conv (convergence curve),
%     result.lit_lo, .lit_hi (literature comparison band, $/h),
%     result.is_top_performer (best_cost <= lit_hi), result.gap_pct
%
%   result = RUN_15UNIT_STATIC_ELD('N_RUNS', 5) overrides any option
%   (see `defaults` below) via Name/Value pairs, e.g. for a quick
%   smoke test: RUN_15UNIT_STATIC_ELD('N_RUNS', 3, 'SAVE_RESULTS', false).
%
%   Standard demand: D = 2630 MW.
%   Literature best-known: ~$32,697.28-$32,706.52/h (Artificial Eco
%   System / MP-CJAYA).
%
%   NOTE: this is a *different* use of the 15-unit dataset than the
%   project's main 24-hour dynamic UC study (main_FCM_PbGA*.m /
%   Revisi/FCM_PbGA_v1.m), which dispatches the same units against an
%   hourly load curve with ramp-rate/UC coupling across hours. Both
%   are valid, published problem formulations for this exact unit
%   table; they are kept side by side rather than merged.

    SCRIPT_DIR = fileparts(mfilename('fullpath'));
    if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
    addpath(fullfile(SCRIPT_DIR,'lib'));

    defaults.N_RUNS       = 30;
    defaults.BASE_SEED    = 30;
    defaults.VERBOSE      = true;
    defaults.SAVE_RESULTS = true;
    opts = merge_options(defaults, varargin);

    DATA_DIR = fullfile(SCRIPT_DIR,'data');
    RES_DIR  = fullfile(SCRIPT_DIR,'results');
    if opts.SAVE_RESULTS && ~exist(RES_DIR,'dir'), mkdir(RES_DIR); end

    if opts.VERBOSE, fprintf('=== FCM-PbGA (static) : 15-Unit ELD Test System ===\n'); end

    %% ---- Data ----
    U = dlmread(fullfile(DATA_DIR,'15unit_units_numeric.csv'), ',', 1, 0);
    Pmin = U(:,2); Pmax = U(:,3); a_c = U(:,4); b_c = U(:,5); c_c = U(:,6);
    d_c  = U(:,7); e_c  = U(:,8);
    % columns 9-11 (Pnow, Rup, Rdown) are for the dynamic multi-hour study
    % only and are not used here (single dispatch period -> no ramp state).
    Bij = dlmread(fullfile(DATA_DIR,'15unit_Bij.csv'), ',', 1, 0);
    B0i = dlmread(fullfile(DATA_DIR,'15unit_B0i.csv'), ',', 1, 0);
    B00 = str2double(fileread(fullfile(DATA_DIR,'15unit_B00.txt')));

    N_ = length(Pmin);
    POZ = cell(N_,1);
    fid = fopen(fullfile(DATA_DIR,'15unit_poz.txt'));
    for i=1:N_
        ln = fgetl(fid);
        POZ{i} = parse_poz_cell(ln);
    end
    fclose(fid);

    D = 2630; EV = 1e-6;
    LIT_LO = 32697.28; LIT_HI = 32706.52;

    if opts.VERBOSE
        fprintf('Units:%d | Demand:%.0f MW | sum(Pmin)=%.0f sum(Pmax)=%.0f\n', ...
            N_, D, sum(Pmin), sum(Pmax));
        fprintf(['Constraints/effects active: VPE=Yes | POZ=Yes (units 1,5,6,12) | ' ...
            'B-Loss=Yes (Kron, %dx%d) | Ramp-Rate=No (single dispatch period) | UC=No | ' ...
            'Emission=No (not modeled for this system -- no official data)\n'], N_, N_);
    end

    %% ---- GA parameters (FCM-PbGA static) ----
    GA.POPSIZE=150; GA.NGEN=500; GA.CXPB=0.9; GA.MUTPB=0.45; GA.INDPB=0.35;
    GA.SIGMA_FRAC=0.28; GA.SIGMA_DECAY=0.988; GA.TOURNSIZE=3; GA.ELITE_K=2;
    GA.ISLANDS=6; GA.MIG_INTERVAL=20; GA.MIG_K=3;
    GA.LOCAL_SEARCH=true; GA.LS_ITER=6000;
    GA.FCM_SEED_FRAC=0.15; GA.FCM_SEED_SIGMA=0.05;
    % Reheat mutation sigma after a long stall instead of only ever
    % decaying it, to keep probing for a better valve-point combination.
    GA.REHEAT_ENABLE=true; GA.STAGNATION_WINDOW=40; GA.REHEAT_FACTOR=3.0;
    FCM.N_CLUSTERS=3; FCM.MIN_SAMPLES=5; FCM.M=2; FCM.ERROR=0.005; FCM.MAXITER=300;
    N_RUNS = opts.N_RUNS; BASE_SEED = opts.BASE_SEED;

    %% ---- Run loop with FCM cross-run seeding ----
    costs = zeros(N_RUNS,1); best_conv = []; best_cost = inf; best_P = [];
    history = [];
    for run=1:N_RUNS
        ip = [];
        if size(history,1) >= FCM.MIN_SAMPLES
            try
                cctr = fcm_cluster_lite(history, FCM.N_CLUSTERS, FCM.M, FCM.ERROR, FCM.MAXITER);
                ip = pick_center(cctr, mean(history,1)');
            catch
            end
        end
        % Loss-coupled system: restrict most of the balance-repair
        % correction to a handful of wide-range, non-POZ units (see
        % pick_slack_units*.m), RANDOMIZED per run so independent runs
        % settle the loss fixed point along different unit subsets --
        % this diversifies which valve-point local optimum is found more
        % than random-seed alone (see README.md).
        adjW = pick_slack_units_random(Pmin, Pmax, POZ, 4+mod(run,3), 0.10, 8000+run);
        [P,fval,conv] = island_ga_static(D,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c, ...
            Bij,B0i,B00,POZ,GA,BASE_SEED+run,ip,EV,adjW);
        costs(run)=fval; history=[history;P'];
        if fval<best_cost, best_cost=fval; best_P=P; best_conv=conv; end
        if opts.VERBOSE
            fprintf('Run %2d/%d  $%.4f  (Ploss=%.3f MW)\n', run, N_RUNS, fval, ...
                compute_ploss(P,Bij,B0i,B00));
        end
    end

    gap_pct = 100*(best_cost-LIT_HI)/LIT_HI;
    is_top = best_cost <= LIT_HI;

    if opts.VERBOSE
        fprintf('\n--- 15-Unit (static) Result ---\n');
        fprintf('Best  : $%.4f\n', best_cost);
        fprintf('Mean  : $%.4f +/- $%.4f\n', mean(costs), std(costs));
        fprintf('Literature best-known range: $%.2f - $%.2f\n', LIT_LO, LIT_HI);
        if is_top
            fprintf('*** TOP PERFORMER: within/below the literature best-known band. ***\n');
        else
            fprintf('Gap to literature: $%.4f (%.4f%%)\n', best_cost-LIT_HI, gap_pct);
        end
    end

    %% ---- Save ----
    if opts.SAVE_RESULTS
        fid = fopen(fullfile(RES_DIR,'15unit_static_best_dispatch.csv'),'w');
        fprintf(fid,'Unit,Pmin,Pmax,P_MW\n');
        for i=1:N_, fprintf(fid,'%d,%.1f,%.1f,%.6f\n', i, Pmin(i), Pmax(i), best_P(i)); end
        fclose(fid);
        csvwrite(fullfile(RES_DIR,'15unit_static_all_run_costs.csv'), costs);
        csvwrite(fullfile(RES_DIR,'15unit_static_convergence.csv'), best_conv);
        plot_convergence(best_conv, '15-Unit ELD (static): Convergence (Best Run)', ...
            fullfile(RES_DIR,'15unit_static_convergence.png'));
        if opts.VERBOSE
            fprintf('Saved: results/15unit_static_best_dispatch.csv, 15unit_static_all_run_costs.csv, 15unit_static_convergence.{csv,png}\n');
        end
    end

    %% ---- Return ----
    result.system          = '15-unit';
    result.demand_MW       = D;
    result.best_cost       = best_cost;
    result.mean_cost       = mean(costs);
    result.std_cost        = std(costs);
    result.costs           = costs;
    result.best_P          = best_P;
    result.best_conv       = best_conv;
    result.lit_lo          = LIT_LO;
    result.lit_hi          = LIT_HI;
    result.is_top_performer= is_top;
    result.gap_pct         = gap_pct;
    result.constraints = struct('VPE',true,'POZ',true,'BLoss',true, ...
        'RampRate',false,'UC',false,'Emission',false);
end
