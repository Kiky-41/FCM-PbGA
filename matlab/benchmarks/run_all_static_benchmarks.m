function results = run_all_static_benchmarks(varargin)
%RUN_ALL_STATIC_BENCHMARKS  Run all four static ELD benchmarks
%(6/13/15/40-unit) back to back and print a combined comparison table.
%
%   results = RUN_ALL_STATIC_BENCHMARKS() runs each system's callable
%   function (run_6unit_ELD, run_13unit_ELD, run_15unit_static_ELD,
%   run_40unit_ELD) with its own tuned defaults and returns a 1x4 struct
%   array, one element per system, each with the same fields documented
%   in the individual functions (best_cost, mean_cost, std_cost, costs,
%   best_P, best_conv, lit_lo, lit_hi, is_top_performer, gap_pct, system,
%   demand_MW).
%
%   RUN_ALL_STATIC_BENCHMARKS('N_RUNS', 3, 'SAVE_RESULTS', false) passes
%   the given Name/Value overrides through to ALL four system functions
%   -- useful for a quick smoke test of the whole suite, e.g.:
%       run_all_static_benchmarks('N_RUNS', 2, 'SAVE_RESULTS', false)
%
%   Per-system BASE_SEED defaults differ (each system was tuned
%   separately) and are left untouched unless explicitly overridden here
%   -- an explicit 'BASE_SEED' passed to this function is applied to all
%   four, which is only meaningful for a smoke test, not for reproducing
%   the tuned production numbers.
%
%   VERBOSE defaults to true for each system's own run log; this
%   wrapper's own summary table prints regardless (pass 'VERBOSE', false
%   to silence only the per-run logs while still getting the table).

    SCRIPT_DIR = fileparts(mfilename('fullpath'));
    if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
    addpath(SCRIPT_DIR);
    addpath(fullfile(SCRIPT_DIR,'lib'));

    fprintf('=== FCM-PbGA Static Benchmark Suite (6/13/15/40-unit) ===\n\n');

    fprintf('--- Running 6-unit ---\n');
    r6  = run_6unit_ELD(varargin{:});
    fprintf('\n--- Running 13-unit ---\n');
    r13 = run_13unit_ELD(varargin{:});
    fprintf('\n--- Running 15-unit ---\n');
    r15 = run_15unit_static_ELD(varargin{:});
    fprintf('\n--- Running 40-unit ---\n');
    r40 = run_40unit_ELD(varargin{:});

    results = [r6, r13, r15, r40];

    fprintf('\n\n=== Combined Comparison ===\n');
    fprintf('%-8s %14s %14s %14s %10s %8s\n', ...
        'System', 'Best ($/h)', 'Mean ($/h)', 'Lit.Hi ($/h)', 'Gap(%)', 'Top?');
    for k = 1:numel(results)
        r = results(k);
        if r.is_top_performer
            tag = 'YES';
        else
            tag = 'no';
        end
        fprintf('%-8s %14.4f %14.4f %14.2f %10.4f %8s\n', ...
            r.system, r.best_cost, r.mean_cost, r.lit_hi, r.gap_pct, tag);
    end
    n_top = sum(arrayfun(@(r) r.is_top_performer, results));
    fprintf('\n%d/%d systems are top performers (best cost within/below the cited literature band).\n', ...
        n_top, numel(results));
end
