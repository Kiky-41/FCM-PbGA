function UC = build_uc_schedule(Pmin, Pmax, a, b, loadcurve)
%BUILD_UC_SCHEDULE  Simple merit-order unit-commitment schedule for a
%multi-hour load curve.
%
%   UC = BUILD_UC_SCHEDULE(Pmin, Pmax, a, b, loadcurve)
%
%   loadcurve: T x 1 hourly demand. Returns UC: T x N logical, which
%   units are committed (ON) each hour.
%
%   Method: units are ranked by average full-load cost
%   (a_i + b_i*Pmax_i)/Pmax_i (merit order, ignoring the small
%   valve-point ripple for ranking purposes -- standard practice).
%   For each hour, start with every unit committed, then decommit the
%   worst-average-cost unit repeatedly while sum(Pmin) over the
%   committed set still exceeds that hour's demand (so the demand is
%   always reachable without going below any committed unit's minimum
%   output), and separately verify sum(Pmax) over the committed set
%   covers demand (recommitting from merit order if not, which should
%   not occur here since total system Pmax comfortably exceeds peak
%   demand).
%
%   This is a deliberately simple capacity-feasibility heuristic: it
%   does NOT model minimum-up/minimum-down time, startup cost, or
%   spinning reserve, so a unit can in principle be committed, then
%   decommitted, then recommitted across nearby hours if the load
%   curve dips and recovers quickly. That is a real simplification
%   relative to a full UC formulation (and relative to this project's
%   own main_FCM_PbGA*.m, which has a more elaborate commitment-
%   escalation scheme) -- it exists here only to make a combined
%   POZ+VPE+B-loss+Ramp dynamic dispatch feasible at low-load hours,
%   not as a UC research contribution in its own right.
    N_ = length(Pmin);
    T = numel(loadcurve);
    avgcost = (a + b.*Pmax) ./ Pmax;
    [~, meritOrder] = sort(avgcost);           % best (cheapest) first
    worstFirst = flipud(meritOrder(:));        % worst (priciest) first

    UC = true(T, N_);
    for t = 1:T
        D = loadcurve(t);
        on = true(1, N_);
        for k = 1:numel(worstFirst)
            if sum(Pmin(on)) <= D, break; end
            u = worstFirst(k);
            if on(u)
                on(u) = false;
            end
        end
        % Safety: make sure enough capacity remains; recommit from merit
        % order (cheapest first) if the decommit loop went too far.
        for k = 1:numel(meritOrder)
            if sum(Pmax(on)) >= D, break; end
            u = meritOrder(k);
            on(u) = true;
        end
        UC(t,:) = on;
    end
end
