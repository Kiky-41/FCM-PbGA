function [Pbest, fbest, conv] = woa_static(D, lb, ub, a, b, c, d, e, Bij, B0i, B00, POZ, WOA, seed, ev)
%WOA_STATIC  Whale Optimization Algorithm baseline for static
%valve-point ELD (encircling prey / bubble-net spiral / search for
%prey), using the same repair-based feasibility decoder as FCM-PbGA.
%Canonical WOA replaces the whole population every iteration (no greedy
%retention against the previous generation).
%
% WOA fields: POPSIZE, NGEN, B_SPIRAL (logarithmic spiral shape constant).

    if nargin < 15 || isempty(ev), ev = 1e-6; end
    rng(seed);
    N_ = length(lb); lbr = lb'; ubr = ub'; NP = WOA.POPSIZE;

    pop = bsxfun(@plus, lbr, bsxfun(@times, rand(NP, N_), (ubr - lbr)));
    pop = repair_balance_batch(pop, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 60);
    fit = compute_valve_cost_batch(pop, a, b, c, d, e, lb);
    [gbestf, gi] = min(fit); gbest = pop(gi,:);
    conv = zeros(WOA.NGEN, 1);

    for gen = 1:WOA.NGEN
        aco = 2 - 2*gen/WOA.NGEN;
        r1 = rand(NP,1); r2 = rand(NP,1);
        Avec = 2*aco*r1 - aco;
        Cvec = 2*r2;
        p = rand(NP,1);
        l = 2*rand(NP,1) - 1;

        newpop = pop;

        % Encircling prey (|A|<1) and bubble-net search-for-prey (|A|>=1)
        idxEnc = (p < 0.5) & (abs(Avec) < 1);
        Dvec = abs(bsxfun(@times, Cvec, gbest) - pop);
        cand1 = bsxfun(@minus, gbest, bsxfun(@times, Avec, Dvec));

        idxSearch = (p < 0.5) & (abs(Avec) >= 1);
        randIdx = randi(NP, NP, 1);
        Xrand = pop(randIdx,:);
        Dvec2 = abs(bsxfun(@times, Cvec, Xrand) - pop);
        cand2 = Xrand - bsxfun(@times, Avec, Dvec2);

        % Spiral bubble-net attack (p>=0.5)
        Dprime = abs(bsxfun(@minus, gbest, pop));
        spiralfac = exp(WOA.B_SPIRAL * l) .* cos(2*pi*l);
        cand3 = bsxfun(@times, Dprime, spiralfac) + gbest;

        newpop(idxEnc,:) = cand1(idxEnc,:);
        newpop(idxSearch,:) = cand2(idxSearch,:);
        idxSpiral = p >= 0.5;
        newpop(idxSpiral,:) = cand3(idxSpiral,:);

        newpop = max(lbr, min(ubr, newpop));
        newpop = repair_balance_batch(newpop, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 40);
        newfit = compute_valve_cost_batch(newpop, a, b, c, d, e, lb);

        pop = newpop; fit = newfit;
        [mgf, mgi] = min(fit);
        if mgf < gbestf, gbestf = mgf; gbest = pop(mgi,:); end
        conv(gen) = gbestf;
    end

    Pbest = gbest'; fbest = gbestf;
end
