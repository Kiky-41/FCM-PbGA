function P = repair_balance(P, D, lb, ub, Bij, B0i, B00, POZ, ev, tol, maxIter, adjMask)
% Project P (an Nx1 real vector) onto the feasible manifold
%   lb <= P <= ub,  P not inside any prohibited-operating zone,
%   sum(P) - PLoss(P) = D   (equality power balance, losses optional)
%
% Uses an iterative headroom-weighted redistribution (bidirectional:
% works whether the candidate currently under- or over-generates),
% which is the standard "repair/decoder" trick for real-coded GAs on
% ELD problems -- it keeps every offspring exactly feasible so the GA
% objective can be pure fuel cost with no penalty term.
    if nargin < 12 || isempty(adjMask), adjMask = ones(length(P),1); end
    if nargin < 11, maxIter = 60; end
    if nargin < 10, tol = 1e-5; end
    adjMask = double(adjMask(:));
    N_ = length(P);
    hasLoss = ~isempty(Bij);
    P = max(lb, min(ub, P));
    if ~isempty(POZ)
        P = apply_poz_vec(P, lb, ub, POZ, ev);
    end
    for it = 1:maxIter
        if hasLoss
            pl = compute_ploss(P, Bij, B0i, B00);
        else
            pl = 0;
        end
        net = sum(P) - pl;
        diff = D - net;
        if abs(diff) < tol, break; end
        if diff > 0
            room = max(0, ub - P) .* adjMask;
        else
            room = max(0, P - lb) .* adjMask;
        end
        sroom = sum(room);
        if sroom < 1e-10, break; end
        P = P + diff * (room / sroom);
        P = max(lb, min(ub, P));
        if ~isempty(POZ)
            P = apply_poz_vec(P, lb, ub, POZ, ev);
        end
    end
end
