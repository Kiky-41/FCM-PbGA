function Pop = repair_balance_batch(Pop, D, lb, ub, Bij, B0i, B00, POZ, ev, tol, maxIter, adjMask)
% Vectorized version of repair_balance() operating on a whole
% population matrix (ns x N) at once -- avoids per-individual Octave
% loops, which is what makes the 40-unit system tractable.
%
% adjMask (optional, 1xN or Nx1 logical): which units are allowed to
% absorb the balance correction. Default = all units. Restricting this
% to a small "slack" subset (see pick_slack_units.m) is important for
% loss-included systems: redistributing the correction across ALL N
% units every repair iteration otherwise erases most of the shape
% diversity the GA's crossover/mutation just introduced, because the
% loss term requires several correction iterations to reach its
% fixed point and each of those iterations reshapes the whole vector.
    if nargin < 12 || isempty(adjMask), adjMask = ones(1, size(Pop,2)); end
    if nargin < 11, maxIter = 60; end
    if nargin < 10, tol = 1e-5; end
    adjMask = double(adjMask(:))';
    hasLoss = ~isempty(Bij);
    hasPOZ  = ~isempty(POZ) && any(~cellfun(@isempty, POZ));
    ns = size(Pop,1);
    lbr = lb'; ubr = ub';
    Pop = max(lbr, min(ubr, Pop));
    if hasPOZ, Pop = apply_poz_batch(Pop, lb, ub, POZ, ev); end
    for it = 1:maxIter
        if hasLoss
            quad = sum((Pop * Bij) .* Pop, 2);
            lin  = Pop * B0i(:);
            pl = (quad + lin) / 100 + B00;
        else
            pl = zeros(ns,1);
        end
        net  = sum(Pop, 2) - pl;
        diff = D - net;
        if max(abs(diff)) < tol, break; end
        roomUp   = bsxfun(@times, max(0, ubr - Pop), adjMask);
        roomDown = bsxfun(@times, max(0, Pop - lbr), adjMask);
        maskUp = diff > 0;
        room = bsxfun(@times, maskUp, roomUp) + bsxfun(@times, ~maskUp, roomDown);
        sroom = sum(room, 2);
        active = abs(diff) >= tol & sroom > 1e-10;
        if any(active)
            Pop(active,:) = Pop(active,:) + bsxfun(@times, diff(active), ...
                bsxfun(@rdivide, room(active,:), sroom(active)));
        end
        Pop = max(lbr, min(ubr, Pop));
        if hasPOZ, Pop = apply_poz_batch(Pop, lb, ub, POZ, ev); end
    end
end
