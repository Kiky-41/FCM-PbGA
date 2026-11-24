function [Pbest, fbest, conv] = ga_simple_static(D, lb, ub, a, b, c, d, e, Bij, B0i, B00, POZ, GA, seed, ev)
%GA_SIMPLE_STATIC  Plain single-population real-coded GA baseline
%(BLX crossover + Gaussian mutation with decay, tournament selection,
%elitism) -- i.e. the "GA" row from the main project's benchmark list,
%with NO island structure, NO FCM/smooth-economic seeding, NO
%stagnation reheat, and NO memetic local search. This is exactly what
%FCM-PbGA (island_ga_static.m) reduces to if you strip every one of its
%namesake additions, so the comparison shows what those additions are
%worth.
%
% GA fields: POPSIZE, NGEN, CXPB, MUTPB, INDPB, SIGMA_FRAC, SIGMA_DECAY,
% TOURNSIZE, ELITE_K.

    if nargin < 15 || isempty(ev), ev = 1e-6; end
    rng(seed);
    N_ = length(lb); lbr = lb'; ubr = ub'; NP = GA.POPSIZE;

    pop = bsxfun(@plus, lbr, bsxfun(@times, rand(NP, N_), (ubr - lbr)));
    pop = repair_balance_batch(pop, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 60);
    fit = compute_valve_cost_batch(pop, a, b, c, d, e, lb);

    sig = max((ub - lb) * GA.SIGMA_FRAC, 1e-9);
    conv = zeros(GA.NGEN, 1);

    for gen = 1:GA.NGEN
        sig = max(sig * GA.SIGMA_DECAY, (ub - lb) * 0.004);

        [~, od] = sort(fit);
        ke = min(GA.ELITE_K, NP);
        ep = pop(od(1:ke), :); ef = fit(od(1:ke));
        n_off = NP - ke;

        T = min(GA.TOURNSIZE, NP);
        idxT1 = randi(NP, n_off, T); ftT1 = fit(idxT1);
        [~, loc1] = min(ftT1, [], 2);
        sel1 = idxT1(sub2ind(size(idxT1), (1:n_off)', loc1));
        idxT2 = randi(NP, n_off, T); ftT2 = fit(idxT2);
        [~, loc2] = min(ftT2, [], 2);
        sel2 = idxT2(sub2ind(size(idxT2), (1:n_off)', loc2));
        p1 = pop(sel1,:); p2 = pop(sel2,:);

        ch = p1;
        cxmask = rand(n_off,1) < GA.CXPB;
        al = 0.5; dd = abs(p1 - p2);
        child = min(p1,p2) - al*dd + rand(n_off, N_) .* (dd + 2*al*dd);
        ch(cxmask,:) = child(cxmask,:);

        mutind = rand(n_off,1) < GA.MUTPB;
        genemsk = rand(n_off, N_) < GA.INDPB;
        fullmsk = bsxfun(@and, mutind, genemsk);
        noise = bsxfun(@times, randn(n_off, N_), sig');
        ch = ch + fullmsk .* noise;

        ch = max(lbr, min(ubr, ch));
        ch = repair_balance_batch(ch, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 40);
        of = compute_valve_cost_batch(ch, a, b, c, d, e, lb);

        pop = [ep; ch]; fit = [ef; of];
        conv(gen) = min(fit);
    end

    [fbest, bi] = min(fit); Pbest = pop(bi,:)';
end
