function [idx, wgt] = pick_slack_units(lb, ub, POZ, k, minor_weight)
% Choose k "slack" units (widest operating range, and preferably free
% of prohibited-operating zones) to carry most of the power-balance
% repair correction, and return a continuous per-unit weight vector
% (1.0 for the chosen slack units, `minor_weight` for the rest).
%
% Restricting the repair correction to a small slack subset -- instead
% of reshaping every unit's output every repair iteration -- preserves
% the shape diversity the GA's crossover/mutation introduces, which
% matters once network losses require several fixed-point repair
% iterations per individual (see repair_balance_batch.m). A hard 0/1
% mask can occasionally deadlock (the slack units saturate at a bound
% before balance is reached), so non-slack units keep a small nonzero
% `minor_weight` share as a feasibility fallback.
    if nargin < 5, minor_weight = 0.05; end
    N_ = length(lb);
    range = ub - lb;
    if ~isempty(POZ)
        hasPOZ = ~cellfun(@isempty, POZ);
        range(hasPOZ) = range(hasPOZ) * 0.3;
    end
    [~, order] = sort(range, 'descend');
    idx = order(1:min(k, length(order)));
    wgt = minor_weight * ones(N_, 1);
    wgt(idx) = 1.0;
end
