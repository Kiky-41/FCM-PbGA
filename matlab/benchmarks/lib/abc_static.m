function [Pbest, fbest, conv] = abc_static(D, lb, ub, a, b, c, d, e, Bij, B0i, B00, POZ, ABC, seed, ev)
%ABC_STATIC  Artificial Bee Colony baseline for static valve-point ELD
%(employed bees / onlooker bees / scout bees), using the same
%repair-based feasibility decoder as FCM-PbGA. Vectorized across food
%sources (one random dimension perturbed per source per phase, as in
%the canonical ABC).
%
% ABC fields: POPSIZE (= number of food sources SN), NGEN (cycles),
% LIMIT (trial-count threshold before a source is scouted/replaced).

    if nargin < 15 || isempty(ev), ev = 1e-6; end
    rng(seed);
    N_ = length(lb); lbr = lb'; ubr = ub'; SN = ABC.POPSIZE;

    pop = bsxfun(@plus, lbr, bsxfun(@times, rand(SN, N_), (ubr - lbr)));
    pop = repair_balance_batch(pop, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 60);
    fit = compute_valve_cost_batch(pop, a, b, c, d, e, lb);
    trial_cnt = zeros(SN,1);
    conv = zeros(ABC.NGEN, 1);
    rows = (1:SN)';

    for gen = 1:ABC.NGEN
        %% ---- Employed bee phase ----
        partner = mod(rows - 1 + randi(SN-1, SN, 1), SN) + 1;
        dim = randi(N_, SN, 1);
        phi = 2*rand(SN,1) - 1;
        cand = pop;
        linidx = sub2ind(size(cand), rows, dim);
        cand(linidx) = pop(linidx) + phi .* (pop(linidx) - pop(sub2ind(size(pop), partner, dim)));
        cand = max(lbr, min(ubr, cand));
        cand = repair_balance_batch(cand, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 40);
        cfit = compute_valve_cost_batch(cand, a, b, c, d, e, lb);
        improve = cfit < fit;
        pop(improve,:) = cand(improve,:); fit(improve) = cfit(improve);
        trial_cnt(improve) = 0; trial_cnt(~improve) = trial_cnt(~improve) + 1;

        %% ---- Onlooker bee phase (roulette-wheel selection by quality) ----
        quality = (max(fit) - fit) + 1e-12;
        prob = quality / sum(quality);
        cs = cumsum(prob);
        r = rand(SN,1);
        [~, sel] = max(bsxfun(@le, r, cs'), [], 2);

        partner2 = mod(sel - 1 + randi(SN-1, SN, 1), SN) + 1;
        dim2 = randi(N_, SN, 1);
        phi2 = 2*rand(SN,1) - 1;
        srcvals = pop(sub2ind(size(pop), sel, dim2));
        partnervals = pop(sub2ind(size(pop), partner2, dim2));
        cand2 = pop(sel,:);
        linidx2 = sub2ind(size(cand2), rows, dim2);
        cand2(linidx2) = srcvals + phi2 .* (srcvals - partnervals);
        cand2 = max(lbr, min(ubr, cand2));
        cand2 = repair_balance_batch(cand2, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 40);
        cfit2 = compute_valve_cost_batch(cand2, a, b, c, d, e, lb);

        improve2 = cfit2 < fit(sel);
        selimp = sel(improve2);
        pop(selimp,:) = cand2(improve2,:); fit(selimp) = cfit2(improve2);
        trial_cnt(selimp) = 0;
        noimp = sel(~improve2);
        trial_cnt(noimp) = trial_cnt(noimp) + 1;

        %% ---- Scout bee phase ----
        scouts = trial_cnt >= ABC.LIMIT;
        if any(scouts)
            ns = sum(scouts);
            newpop = bsxfun(@plus, lbr, bsxfun(@times, rand(ns, N_), (ubr - lbr)));
            newpop = repair_balance_batch(newpop, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 60);
            newfit = compute_valve_cost_batch(newpop, a, b, c, d, e, lb);
            pop(scouts,:) = newpop; fit(scouts) = newfit; trial_cnt(scouts) = 0;
        end

        conv(gen) = min(fit);
    end

    [fbest, bi] = min(fit); Pbest = pop(bi,:)';
end
