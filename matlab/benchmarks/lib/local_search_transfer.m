function [P, fval] = local_search_transfer(P, D, lb, ub, a, b, c, d, e, Bij, B0i, B00, POZ, iters, ev, adjMask, EM, H)
% Pairwise power-transfer hill-climbing: move a small amount of power
% from one unit to another (which keeps the balance constraint exact
% for the lossless case, and is re-balanced cheaply when losses/POZ
% are present). This is the memetic "local search" refinement step of
% FCM-PbGA, adapted to a single dispatch period.
%
% EM (optional, struct with alpha/beta/gamma/xi/delta) + H (optional,
% price-penalty-factor scalar): when both given (H>0), the local search
% hill-climbs on fuel-cost + H*emission instead of pure fuel cost, so
% the final polish stays consistent with a GA phase that was run with
% emission included (see island_ga_static.m).
    if nargin < 16 || isempty(adjMask), adjMask = true(length(P),1); end
    if nargin < 17, EM = []; end
    if nargin < 18 || isempty(H), H = 0; end
    useEmission = ~isempty(EM) && H > 0;
    N_ = length(P);
    hasLoss = ~isempty(Bij);
    hasPOZ  = ~isempty(POZ);
    fval = compute_valve_cost(P, a, b, c, d, e, lb);
    if useEmission
        fval = fval + H * compute_emission(P, EM.alpha, EM.beta, EM.gamma, EM.xi, EM.delta);
    end
    sigma0 = 0.06 * (ub - lb);
    for it = 1:iters
        frac  = it / iters;
        sigma = sigma0 * (1 - 0.9*frac);
        i = randi(N_);
        j = randi(N_);
        while j == i, j = randi(N_); end
        delta = randn() * sigma(i);
        Pt = P;
        newPi  = max(lb(i), min(ub(i), P(i) - delta));
        actual = P(i) - newPi;
        newPj  = max(lb(j), min(ub(j), P(j) + actual));
        actual2 = newPj - P(j);
        Pt(i) = P(i) - actual2;
        Pt(j) = newPj;
        if hasPOZ
            Pt(i) = project_poz(Pt(i), POZ{i}, lb(i), ub(i), ev);
            Pt(j) = project_poz(Pt(j), POZ{j}, lb(j), ub(j), ev);
        end
        if hasPOZ || hasLoss
            Pt = repair_balance(Pt, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 30, adjMask);
        end
        ft = compute_valve_cost(Pt, a, b, c, d, e, lb);
        if useEmission
            ft = ft + H * compute_emission(Pt, EM.alpha, EM.beta, EM.gamma, EM.xi, EM.delta);
        end
        if ft < fval
            P = Pt; fval = ft;
        end
    end
end
