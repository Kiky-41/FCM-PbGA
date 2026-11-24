function result = run_40unit_ELD(varargin)
%RUN_40UNIT_ELD  FCM-PbGA (static variant) on the 40-Unit ELD Test
%System (Al-Roomi benchmark, valve-point effects, losses neglected).
%
%   result = RUN_40UNIT_ELD() runs with the tuned defaults (30
%   independent runs) and returns a struct:
%     result.best_cost, .mean_cost, .std_cost, .costs (Nx1) -- FUEL COST
%       ONLY, always, regardless of INCLUDE_EMISSION (so the literature
%       comparison below stays apples-to-apples)
%     result.best_P (dispatch, MW), result.best_conv (convergence curve),
%     result.lit_lo, .lit_hi (literature comparison band, $/h),
%     result.is_top_performer (best_cost <= lit_hi), result.gap_pct
%     result.best_emission, .mean_emission (emission of the SAME
%       dispatch, in the dataset's emission units -- always computed
%       and reported so you can see the emission "cost" of the pure
%       fuel-cost-optimal dispatch, but only actually MINIMIZED as part
%       of the search objective when INCLUDE_EMISSION is true)
%     result.price_penalty_factor (h; NaN if INCLUDE_EMISSION is false)
%
%   result = RUN_40UNIT_ELD('N_RUNS', 5) overrides any option (see
%   `defaults` below) via Name/Value pairs, e.g. for a quick smoke
%   test: RUN_40UNIT_ELD('N_RUNS', 3, 'SAVE_RESULTS', false).
%
%   result = RUN_40UNIT_ELD('INCLUDE_EMISSION', true) additionally
%   minimizes a combined objective, fuel_cost + h*emission, where h is
%   the standard "price penalty factor" (Dhillon & Kothari): each
%   unit's own full-load cost-to-emission ratio F_i(Pmax_i)/E_i(Pmax_i),
%   averaged across units -- see run_13unit_ELD.m for the same method.
%   Emission coefficients (alpha/beta/gamma/xi/delta, eq. 3) are the
%   ones already present in data/40unit_units.csv columns 9-13
%   (previously unused). Off by default so the already-validated
%   top-performer fuel-cost numbers are unchanged unless explicitly
%   requested.
%
%   Standard demand: D = 10500 MW.
%   Literature best-known: ~$121,412.54-$121,480.10/h (Artificial Eco
%   System / MP-CJAYA).
%
%   NOTE: smooth-seeding + reheat (used for 6/13/15-unit) was tested on
%   this system and found to make results slightly WORSE (best
%   $121,499.87 vs $121,463.65 without it, across 5 seeds each), so
%   this system intentionally keeps the plain FCM-seeded GA.

    SCRIPT_DIR = fileparts(mfilename('fullpath'));
    if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
    addpath(fullfile(SCRIPT_DIR,'lib'));

    defaults.N_RUNS           = 30;
    defaults.BASE_SEED        = 9;
    defaults.VERBOSE          = true;
    defaults.SAVE_RESULTS     = true;
    defaults.INCLUDE_EMISSION = false;
    opts = merge_options(defaults, varargin);

    DATA_DIR = fullfile(SCRIPT_DIR,'data');
    RES_DIR  = fullfile(SCRIPT_DIR,'results');
    if opts.SAVE_RESULTS && ~exist(RES_DIR,'dir'), mkdir(RES_DIR); end

    if opts.VERBOSE, fprintf('=== FCM-PbGA (static) : 40-Unit ELD Test System ===\n'); end

    %% ---- Data ----
    U = dlmread(fullfile(DATA_DIR,'40unit_units.csv'), ',', 1, 0);
    Pmin = U(:,2); Pmax = U(:,3); a_c = U(:,4); b_c = U(:,5); c_c = U(:,6);
    d_c  = U(:,7); e_c  = U(:,8);
    % columns 9-13 (alpha,beta,gamma,xi,delta) are emission coefficients,
    % eq.(3) -- used only when opts.INCLUDE_EMISSION is true.
    alpha_c = U(:,9); beta_c = U(:,10); gamma_c = U(:,11); xi_c = U(:,12); delta_c = U(:,13);
    Bij = []; B0i = []; B00 = 0;                 % network loss neglected (per source)
    POZ = cell(length(Pmin),1);                  % no prohibited zones
    D    = 10500; EV = 1e-6;
    LIT_LO = 121412.54; LIT_HI = 121480.10;

    N_ = length(Pmin);
    if opts.VERBOSE
        fprintf('Units:%d | Demand:%.0f MW | sum(Pmin)=%.0f sum(Pmax)=%.0f\n', ...
            N_, D, sum(Pmin), sum(Pmax));
        if opts.INCLUDE_EMISSION, emStr = 'Yes (combined fuel+h*emission objective)'; else emStr = 'No (fuel-cost-only objective; pass INCLUDE_EMISSION=true to enable)'; end
        fprintf(['Constraints/effects active: VPE=Yes | POZ=No (none in this system) | ' ...
            'B-Loss=No (neglected per source) | Ramp-Rate=No | UC=No | Emission=%s\n'], emStr);
    end

    %% ---- Emission price-penalty factor (only used if enabled) ----
    EM = []; H = 0; h_penalty = NaN;
    if opts.INCLUDE_EMISSION
        EM = struct('alpha',alpha_c,'beta',beta_c,'gamma',gamma_c,'xi',xi_c,'delta',delta_c);
        [~, Fmax_pu] = compute_valve_cost(Pmax, a_c, b_c, c_c, d_c, e_c, Pmin);
        [~, Emax_pu] = compute_emission(Pmax, alpha_c, beta_c, gamma_c, xi_c, delta_c);
        h_penalty = mean(Fmax_pu ./ max(Emax_pu, 1e-9));
        H = h_penalty;
        if opts.VERBOSE
            fprintf('Emission included: price penalty factor h = %.6f\n', h_penalty);
        end
    end

    %% ---- GA parameters (FCM-PbGA static) ----
    GA.POPSIZE=200; GA.NGEN=900; GA.CXPB=0.9; GA.MUTPB=0.45; GA.INDPB=0.35;
    GA.SIGMA_FRAC=0.3; GA.SIGMA_DECAY=0.992; GA.TOURNSIZE=3; GA.ELITE_K=2;
    GA.ISLANDS=8; GA.MIG_INTERVAL=20; GA.MIG_K=3;
    GA.LOCAL_SEARCH=true; GA.LS_ITER=15000;
    GA.FCM_SEED_FRAC=0.15; GA.FCM_SEED_SIGMA=0.05;
    FCM.N_CLUSTERS=3; FCM.MIN_SAMPLES=5; FCM.M=2; FCM.ERROR=0.005; FCM.MAXITER=300;
    N_RUNS = opts.N_RUNS; BASE_SEED = opts.BASE_SEED;

    %% ---- Run loop with FCM cross-run seeding ----
    costs = zeros(N_RUNS,1); emissions = zeros(N_RUNS,1);
    best_conv = []; best_cost = inf; best_P = []; best_emission = 0;
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
        [P,~,conv] = island_ga_static(D,Pmin,Pmax,a_c,b_c,c_c,d_c,e_c, ...
            Bij,B0i,B00,POZ,GA,BASE_SEED+run,ip,EV,[],EM,H);
        fval = compute_valve_cost(P, a_c, b_c, c_c, d_c, e_c, Pmin);
        em   = compute_emission(P, alpha_c, beta_c, gamma_c, xi_c, delta_c);
        costs(run)=fval; emissions(run)=em; history=[history;P'];
        if fval<best_cost, best_cost=fval; best_P=P; best_conv=conv; best_emission=em; end
        if opts.VERBOSE
            if opts.INCLUDE_EMISSION
                fprintf('Run %2d/%d  $%.4f  emission=%.4f\n', run, N_RUNS, fval, em);
            else
                fprintf('Run %2d/%d  $%.4f\n', run, N_RUNS, fval);
            end
        end
    end

    gap_pct = 100*(best_cost-LIT_HI)/LIT_HI;
    is_top = best_cost <= LIT_HI;

    if opts.VERBOSE
        fprintf('\n--- 40-Unit Result ---\n');
        fprintf('Best  : $%.4f\n', best_cost);
        fprintf('Mean  : $%.4f +/- $%.4f\n', mean(costs), std(costs));
        if opts.INCLUDE_EMISSION
            fprintf('Emission of best dispatch: %.4f (mean %.4f +/- %.4f)\n', ...
                best_emission, mean(emissions), std(emissions));
        end
        fprintf('Literature best-known range: $%.2f - $%.2f\n', LIT_LO, LIT_HI);
        if is_top
            fprintf('*** TOP PERFORMER: within/below the literature best-known band. ***\n');
        else
            fprintf('Gap to literature: $%.4f (%.4f%%)\n', best_cost-LIT_HI, gap_pct);
        end
    end

    %% ---- Save ----
    % NOTE: file names get an '_emission' suffix when INCLUDE_EMISSION is
    % true, so an emission-mode run never silently overwrites the
    % canonical fuel-only-objective result files (40unit_best_dispatch.csv
    % etc.) used for the literature comparison / README tables.
    if opts.SAVE_RESULTS
        if opts.INCLUDE_EMISSION, suffix = '_emission'; else, suffix = ''; end
        fid = fopen(fullfile(RES_DIR, sprintf('40unit%s_best_dispatch.csv', suffix)),'w');
        fprintf(fid,'Unit,Pmin,Pmax,P_MW\n');
        for i=1:N_, fprintf(fid,'%d,%.1f,%.1f,%.6f\n', i, Pmin(i), Pmax(i), best_P(i)); end
        fclose(fid);
        csvwrite(fullfile(RES_DIR, sprintf('40unit%s_all_run_costs.csv', suffix)), costs);
        csvwrite(fullfile(RES_DIR, sprintf('40unit%s_convergence.csv', suffix)), best_conv);
        plot_convergence(best_conv, '40-Unit ELD: Convergence (Best Run)', ...
            fullfile(RES_DIR, sprintf('40unit%s_convergence.png', suffix)));
        if opts.INCLUDE_EMISSION
            csvwrite(fullfile(RES_DIR, sprintf('40unit%s_all_run_emissions.csv', suffix)), emissions);
        end
        if opts.VERBOSE
            fprintf('Saved: results/40unit%s_best_dispatch.csv, 40unit%s_all_run_costs.csv, 40unit%s_convergence.{csv,png}\n', ...
                suffix, suffix, suffix);
        end
    end

    %% ---- Return ----
    result.system              = '40-unit';
    result.demand_MW           = D;
    result.best_cost            = best_cost;
    result.mean_cost            = mean(costs);
    result.std_cost             = std(costs);
    result.costs                = costs;
    result.best_P               = best_P;
    result.best_conv            = best_conv;
    result.lit_lo                = LIT_LO;
    result.lit_hi                = LIT_HI;
    result.is_top_performer      = is_top;
    result.gap_pct               = gap_pct;
    result.best_emission         = best_emission;
    result.mean_emission         = mean(emissions);
    result.emissions             = emissions;
    result.price_penalty_factor  = h_penalty;
    result.constraints = struct('VPE',true,'POZ',false,'BLoss',false, ...
        'RampRate',false,'UC',false,'Emission',opts.INCLUDE_EMISSION);
end
