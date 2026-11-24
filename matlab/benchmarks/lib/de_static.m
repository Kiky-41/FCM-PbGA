function [Pbest, fbest, conv] = de_static(D, lb, ub, a, b, c, d, e, Bij, B0i, B00, POZ, DE, seed, ev)
%DE_STATIC  Standard Differential Evolution (DE/rand/1/bin) baseline
%for static valve-point ELD, using the same repair-based feasibility
%decoder as FCM-PbGA. Vanilla DE: no island structure, no seeding
%tricks, no local search.
%
% DE fields: POPSIZE, NGEN, F (differential weight), CR (crossover rate).

    if nargin < 15 || isempty(ev), ev = 1e-6; end
    rng(seed);
    N_ = length(lb); lbr = lb'; ubr = ub'; NP = DE.POPSIZE;

    pop = bsxfun(@plus, lbr, bsxfun(@times, rand(NP, N_), (ubr - lbr)));
    pop = repair_balance_batch(pop, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 60);
    fit = compute_valve_cost_batch(pop, a, b, c, d, e, lb);
    conv = zeros(DE.NGEN, 1);
    idx = (1:NP)';

    for gen = 1:DE.NGEN
        % r1/r2/r3: distinct-from-self random partners (cyclic shift by
        % a nonzero random offset, vectorized -- small chance r1/r2/r3
        % coincide with each other, a standard acceptable simplification).
        r1 = mod(idx - 1 + randi(NP-1, NP, 1), NP) + 1;
        r2 = mod(idx - 1 + randi(NP-1, NP, 1), NP) + 1;
        r3 = mod(idx - 1 + randi(NP-1, NP, 1), NP) + 1;
        mutant = pop(r1,:) + DE.F * (pop(r2,:) - pop(r3,:));

        crossmask = rand(NP, N_) < DE.CR;
        jrand = randi(N_, NP, 1);
        forceidx = sub2ind(size(crossmask), idx, jrand);
        crossmask(forceidx) = true;

        trial = pop;
        trial(crossmask) = mutant(crossmask);
        trial = max(lbr, min(ubr, trial));
        trial = repair_balance_batch(trial, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 40);
        tfit = compute_valve_cost_batch(trial, a, b, c, d, e, lb);

        better = tfit < fit;
        pop(better,:) = trial(better,:); fit(better) = tfit(better);
        conv(gen) = min(fit);
    end

    [fbest, bi] = min(fit); Pbest = pop(bi,:)';
end
