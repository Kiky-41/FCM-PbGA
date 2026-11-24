function results = run_all_benchmark_comparisons(varargin)
%RUN_ALL_BENCHMARK_COMPARISONS  Run the FCM-PbGA vs PSO/DE/GA/ABC/WOA
%comparison (with full statistical tests) across all four static ELD
%benchmark systems (6/13/15/40-unit) and print a combined summary.
%
%   results = RUN_ALL_BENCHMARK_COMPARISONS() runs all four with each
%   system's own tuned defaults (see run_benchmark_comparison.m).
%
%   results = RUN_ALL_BENCHMARK_COMPARISONS('N_RUNS', 5, 'SAVE_RESULTS', false)
%   forwards Name/Value overrides to all four calls -- useful for a
%   quick smoke test of the whole suite.
%
%   results is a 1x4 struct array (see run_benchmark_comparison.m for
%   the per-system struct fields), one element per system.

    SCRIPT_DIR = fileparts(mfilename('fullpath'));
    if isempty(SCRIPT_DIR), SCRIPT_DIR = pwd; end
    addpath(SCRIPT_DIR);
    addpath(fullfile(SCRIPT_DIR,'lib'));

    systems = {'6unit','13unit','15unit','40unit'};
    results = [];
    for i = 1:numel(systems)
        fprintf('\n=========================================\n');
        r = run_benchmark_comparison(systems{i}, varargin{:});
        if isempty(results), results = r; else, results(end+1) = r; end %#ok<AGROW>
    end

    fprintf('\n\n=== Cross-System Best-Cost Summary ($/h) ===\n');
    fprintf('%-8s %10s %10s %10s %10s %10s %10s\n', ...
        'System','FCM-PbGA','PSO','DE','GA','ABC','WOA');
    for i = 1:numel(results)
        r = results(i);
        fprintf('%-8s', r.system);
        for k_ = 1:6
            fprintf(' %10.2f', r.summary(k_).best);
        end
        fprintf('\n');
    end

    fprintf('\n=== Cross-System Significance vs FCM-PbGA (Wilcoxon p) ===\n');
    fprintf('%-8s %10s %10s %10s %10s %10s\n', 'System','PSO','DE','GA','ABC','WOA');
    for i = 1:numel(results)
        r = results(i);
        fprintf('%-8s', r.system);
        for ai = 1:5
            fprintf(' %10.4g', r.pairwise(ai).ranksum_p);
        end
        fprintf('\n');
    end
end
