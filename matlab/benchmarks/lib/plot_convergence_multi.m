function plot_convergence_multi(convCell, names, titleStr, filepath)
%PLOT_CONVERGENCE_MULTI  Save an overlaid convergence-curve PNG (best
%cost so far vs. generation/iteration, one line per algorithm) to
%filepath. Each curve is normalized onto a common 0-100% x-axis
%("fraction of budget used") since different algorithms may run a
%different number of generations, so the curves stay comparable side
%by side. Headless (invisible figure); failures warn but never throw,
%so a missing chart never breaks a results-saving pipeline.
    try
        fig = figure('visible','off'); hold on;
        colors = lines(numel(convCell));
        for i = 1:numel(convCell)
            cv = convCell{i};
            if isempty(cv), continue; end
            xf = linspace(0, 100, numel(cv));
            plot(xf, cv, 'LineWidth', 1.5, 'Color', colors(i,:));
        end
        xlabel('% of generations/iterations used');
        ylabel('Best cost so far ($/h)');
        title(titleStr, 'Interpreter', 'none');
        legend(names, 'Location', 'northeast', 'Interpreter', 'none');
        grid on;
        print(fig, filepath, '-dpng', '-r120');
        close(fig);
    catch err
        warning('plot_convergence_multi:failed', ...
            'Could not save convergence plot "%s": %s', filepath, err.message);
    end
end
