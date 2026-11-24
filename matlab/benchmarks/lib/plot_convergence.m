function plot_convergence(conv, titleStr, filepath)
%PLOT_CONVERGENCE  Save a convergence-curve PNG (best-cost-so-far vs.
%generation/iteration) to filepath. Uses a headless (invisible) figure
%so it works in a non-interactive/sandboxed MATLAB or Octave session.
%Silently skipped (with a warning, not an error) if plotting fails for
%any reason -- e.g. no graphics backend available -- so a missing
%chart never breaks a results-saving pipeline.
    try
        fig = figure('visible','off');
        plot(1:numel(conv), conv, 'LineWidth', 1.5);
        xlabel('Generation / Iteration');
        ylabel('Best cost so far ($/h)');
        title(titleStr, 'Interpreter', 'none');
        grid on;
        print(fig, filepath, '-dpng', '-r120');
        close(fig);
    catch err
        warning('plot_convergence:failed', ...
            'Could not save convergence plot "%s": %s', filepath, err.message);
    end
end
