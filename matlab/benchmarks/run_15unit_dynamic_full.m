function result = run_15unit_dynamic_full(varargin)
%RUN_15UNIT_DYNAMIC_FULL  FCM-PbGA on the 15-Unit system as a full
%24-hour DYNAMIC dispatch combining every constraint/effect this
%project has data for on this system in one model:
%   POZ (prohibited operating zones), VPE (valve-point effects),
%   B-Loss (Kron's transmission-loss formula), Ramp-Rate limits, and a
%   simple merit-order Unit Commitment schedule (needed for feasibility
%   -- see lib/build_uc_schedule.m -- since the load curve dips below
%   the all-units-committed sum(Pmin) at several hours).
%
%   This is DIFFERENT from both existing 15-unit studies in this
%   project, and is kept side by side with them rather than merged:
%     - Static_Benchmarks/run_15unit_static_ELD.m: single dispatch
%       period, POZ+VPE+B-Loss, no ramp/UC/hours.
%     - main_FCM_PbGA*.m / Revisi/FCM_PbGA_v1.m: the original 24-hour
%       dynamic study, POZ+VPE+Ramp+UC, but NO transmission losses.
%   This function is the first to combine B-Loss with the ramp/UC
%   24-hour formulation for this system. There is no published
%   literature baseline for this EXACT combined formulation (it isn't
%   a standard benchmark table from a paper), so -- unlike the static
%   solvers -- this does not report a lit_lo/lit_hi/is_top_performer
%   comparison. Treat its numbers as this project's own internal
%   result, not a claim of beating a cited state of the art.
%
%   Data: unit table + ramp rates + POZ come from
%   data/15unit_units_numeric.csv + data/15unit_poz.txt (same source
%   used by run_15unit_static_ELD.m); B-loss matrices from
%   data/15unit_Bij.csv / 15unit_B0i.csv / 15unit_B00.txt (same
%   validated Kron coefficients); the 24-hour load curve from
%   data/15unit_loadcurve_24h.csv (exported from this project's own
%   powerdemand.xlsx, the same demand profile the original dynamic
%   study already uses for this exact unit table).
%
%   result = RUN_15UNIT_DYNAMIC_FULL() runs with tuned defaults (10
%   independent full-schedule runs) and returns a struct:
%     result.total_cost, .mean_total_cost, .std_total_cost,
%       .total_costs (Nx1, one per independent run)
%     result.best_schedule   24x15 dispatch matrix (MW), winning run
%     result.best_hourly_cost, .best_hourly_ploss   24x1 each
%     result.best_UC          24x15 logical, which units were committed
%     result.best_conv         concatenated convergence trace across
%                              all 24 hours of the winning run (each
%                              hour's GA trace appended in sequence)
%     result.demand_MW        24x1 load curve used
%
%   result = RUN_15UNIT_DYNAMIC_FULL('N_RUNS', 3, 'SAVE_RESULTS', false)
%   overrides any option via Name/Value pairs, same pattern as the
%   other callable functions in this folder.

    SCRIPT_DIR = fileparts(mfilename('fullpath'));
    if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
    addpath(fullfile(SCRIPT_DIR,'lib'));

    defaults.N_RUNS       = 8;
    defaults.BASE_SEED    = 700;
    defaults.VERBOSE      = true;
    defaults.SAVE_RESULTS = true;
    opts = merge_options(defaults, varargin);

    DATA_DIR = fullfile(SCRIPT_DIR,'data');
    RES_DIR  = fullfile(SCRIPT_DIR,'results');
    if opts.SAVE_RESULTS && ~exist(RES_DIR,'dir'), mkdir(RES_DIR); end

    if opts.VERBOSE, fprintf('=== FCM-PbGA (dynamic, full) : 15-Unit, 24-hour, POZ+VPE+B-Loss+Ramp+UC ===\n'); end

    %% ---- Data ----
    U = dlmread(fullfile(DATA_DIR,'15unit_units_numeric.csv'), ',', 1, 0);
    Pmin = U(:,2); Pmax = U(:,3); a_c = U(:,4); b_c = U(:,5); c_c = U(:,6);
    d_c  = U(:,7); e_c  = U(:,8); Pnow0 = U(:,9); Rup = U(:,10); Rdown = U(:,11);
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
    LC = dlmread(fullfile(DATA_DIR,'15unit_loadcurve_24h.csv'), ',', 1, 0);
    loadcurve = LC(:,2);
    T = numel(loadcurve);
    EV = 1e-6;

    if opts.VERBOSE
        fprintf('Units:%d | Hours:%d | Demand range: %.0f-%.0f MW | sum(Pmin)=%.0f sum(Pmax)=%.0f\n', ...
            N_, T, min(loadcurve), max(loadcurve), sum(Pmin), sum(Pmax));
        fprintf(['Constraints/effects active: VPE=Yes | POZ=Yes (units 1,5,6,12) | ' ...
            'B-Loss=Yes (Kron, %dx%d) | Ramp-Rate=Yes | UC=Yes (merit-order heuristic) | ' ...
            'Emission=No (not modeled for this system -- no official data)\n'], N_, N_);
    end

    %% ---- Unit commitment schedule (merit-order feasibility heuristic) ----
    UC = build_uc_schedule(Pmin, Pmax, a_c, b_c, loadcurve);
    if opts.VERBOSE
        n_on_per_hour = sum(UC,2);
        fprintf('Units committed per hour (min/mean/max): %d / %.1f / %d\n', ...
            min(n_on_per_hour), mean(n_on_per_hour), max(n_on_per_hour));
    end

    %% ---- Per-hour GA settings (each hour is warm-started from the ----
    %% previous hour's dispatch, so a much smaller budget than the
    %% single-period static solvers suffices per hour).
    GA.POPSIZE=50; GA.NGEN=60; GA.CXPB=0.9; GA.MUTPB=0.4; GA.INDPB=0.3;
    GA.SIGMA_FRAC=0.2; GA.SIGMA_DECAY=0.96; GA.TOURNSIZE=3; GA.ELITE_K=2;
    GA.ISLANDS=2; GA.MIG_INTERVAL=10; GA.MIG_K=2;
    GA.LOCAL_SEARCH=true; GA.LS_ITER=400;
    GA.FCM_SEED_FRAC=0.4; GA.FCM_SEED_SIGMA=0.04;  % seeds around the warm-start "ip"

    N_RUNS = opts.N_RUNS; BASE_SEED = opts.BASE_SEED;

    total_costs = zeros(N_RUNS,1);
    best_total = inf; best_schedule = []; best_hourly_cost = []; best_hourly_ploss = [];
    best_conv_all = []; best_UC = UC;

    for run = 1:N_RUNS
        schedule = zeros(T, N_);
        hourly_cost = zeros(T,1); hourly_ploss = zeros(T,1);
        conv_all = [];
        Pnow_track = Pnow0;
        % Hour 1 is intentionally NOT ramp-constrained against the given
        % Pnow (prev_on starts all-false): Pnow represents a pre-horizon
        % operating point that was never solved jointly with THIS run's
        % hour-1 unit-commitment decision, so treating it as a hard ramp
        % floor can silently demand more capacity than hour 1's demand
        % needs (a high-Pnow unit "instantly decommitted" by the UC
        % heuristic would otherwise still be forced near its old output
        % by units that stayed committed, an artifact of mixing an
        % externally-given initial condition with a freshly-computed UC
        % schedule, not a real ramp violation). Pnow is still used as the
        % hour-1 GA warm-start hint (ip_t below) -- just not as a bound.
        % From hour 2 onward, ramp bounds are computed from this run's
        % OWN previously solved dispatch, which is self-consistent by
        % construction.
        prev_on = false(1, N_);
        for t = 1:T
            on = UC(t,:);
            idx = find(on);
            n_on = numel(idx);

            lb_t = Pmin(idx); ub_t = Pmax(idx);
            continuing = on & prev_on;
            for kk = 1:n_on
                u = idx(kk);
                if continuing(u)
                    lb_t(kk) = max(Pmin(u), Pnow_track(u) - Rdown(u));
                    ub_t(kk) = min(Pmax(u), Pnow_track(u) + Rup(u));
                end
                % else: just-started this hour (or hour 1) -> full
                % [Pmin,Pmax] range (no startup-ramp data given, so no
                % ramp constraint applies for a unit's first hour on).
            end

            ip_t = max(lb_t, min(ub_t, Pnow_track(idx)));

            seed_t = BASE_SEED + run*1000 + t;
            [Psub, fval, conv] = island_ga_static(loadcurve(t), lb_t, ub_t, ...
                a_c(idx), b_c(idx), c_c(idx), d_c(idx), e_c(idx), ...
                Bij(idx,idx), B0i(idx), B00, POZ(idx), GA, seed_t, ip_t, EV);

            P_full = zeros(N_,1);
            P_full(idx) = Psub;
            schedule(t,:) = P_full';
            hourly_cost(t) = fval;
            hourly_ploss(t) = compute_ploss(Psub, Bij(idx,idx), B0i(idx), B00);
            conv_all = [conv_all; conv]; %#ok<AGROW>

            % Safety net: verify the power-balance equality actually
            % holds (sum(P) - Ploss = D) rather than silently trusting
            % the repair step -- an infeasible ramp/UC combination at
            % this hour would otherwise fail silently.
            balance_err = sum(Psub) - hourly_ploss(t) - loadcurve(t);
            if abs(balance_err) > 1.0
                warning('run_15unit_dynamic_full:balance', ...
                    'Run %d, hour %d: power balance off by %.2f MW (sum(P)=%.1f, Ploss=%.2f, D=%.1f) -- likely an infeasible ramp/UC combination at this hour.', ...
                    run, t, balance_err, sum(Psub), hourly_ploss(t), loadcurve(t));
            end

            Pnow_track(idx) = Psub;
            prev_on = on;
        end

        total_costs(run) = sum(hourly_cost);
        if opts.VERBOSE
            fprintf('Run %2d/%d  total=$%.2f (sum of hourly fuel cost)\n', run, N_RUNS, total_costs(run));
        end
        if total_costs(run) < best_total
            best_total = total_costs(run);
            best_schedule = schedule;
            best_hourly_cost = hourly_cost;
            best_hourly_ploss = hourly_ploss;
            best_conv_all = conv_all;
        end
    end

    if opts.VERBOSE
        fprintf('\n--- 15-Unit Dynamic (full) Result ---\n');
        fprintf('Best total cost (24h)  : $%.2f\n', best_total);
        fprintf('Mean total cost (24h)  : $%.2f +/- $%.2f\n', mean(total_costs), std(total_costs));
        fprintf('Total transmission loss (best run): %.2f MWh\n', sum(best_hourly_ploss));
        fprintf('(No published literature baseline exists for this exact combined\n');
        fprintf(' POZ+VPE+B-Loss+Ramp+UC 24-hour formulation -- see function help.)\n');
    end

    %% ---- Save ----
    if opts.SAVE_RESULTS
        fid = fopen(fullfile(RES_DIR,'15unit_dynamic_full_schedule.csv'),'w');
        fprintf(fid, 'Hour,Demand_MW');
        for i=1:N_, fprintf(fid, ',Unit%d_MW', i); end
        fprintf(fid, ',HourlyCost,HourlyPloss_MW\n');
        for t=1:T
            fprintf(fid, '%d,%.1f', t, loadcurve(t));
            fprintf(fid, ',%.4f', best_schedule(t,:));
            fprintf(fid, ',%.4f,%.4f\n', best_hourly_cost(t), best_hourly_ploss(t));
        end
        fclose(fid);

        csvwrite(fullfile(RES_DIR,'15unit_dynamic_full_all_run_totalcosts.csv'), total_costs);
        csvwrite(fullfile(RES_DIR,'15unit_dynamic_full_convergence.csv'), best_conv_all);
        plot_convergence(best_conv_all, '15-Unit Dynamic (full): Convergence across all 24 hours (best run)', ...
            fullfile(RES_DIR,'15unit_dynamic_full_convergence.png'));

        if opts.VERBOSE
            fprintf('Saved: results/15unit_dynamic_full_schedule.csv, _all_run_totalcosts.csv, _convergence.{csv,png}\n');
        end
    end

    %% ---- Return ----
    result.system            = '15-unit-dynamic-full';
    result.demand_MW         = loadcurve;
    result.total_cost        = best_total;
    result.mean_total_cost   = mean(total_costs);
    result.std_total_cost    = std(total_costs);
    result.total_costs       = total_costs;
    result.best_schedule     = best_schedule;
    result.best_hourly_cost  = best_hourly_cost;
    result.best_hourly_ploss = best_hourly_ploss;
    result.best_UC           = best_UC;
    result.best_conv         = best_conv_all;
    result.constraints = struct('VPE',true,'POZ',true,'BLoss',true, ...
        'RampRate',true,'UC',true,'Emission',false);
end
