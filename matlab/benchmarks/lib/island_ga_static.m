function [Pbest, fbest, conv] = island_ga_static(D, lb, ub, a, b, c, d, e, ...
    Bij, B0i, B00, POZ, GA, seed, ip, ev, adjMask, EM, H)
% ISLAND_GA_STATIC  Repair-based real-coded island genetic algorithm
% for single-period (static) valve-point Economic Load Dispatch.
% Fully vectorized across the population/offspring dimension (only
% loops over generations and islands, both small) so it scales to the
% 40-unit system.
%
% Every individual is kept exactly feasible at all times (box limits,
% prohibited zones, and the power-balance equality sum(P)-Ploss(P)=D)
% via repair_balance_batch(), so fitness is pure fuel cost with no
% penalty term -- the FCM-PbGA "commitment/repair" philosophy carried
% over from the 15-unit dynamic study, applied to one dispatch period.
%
% GA fields used: POPSIZE, NGEN, CXPB, MUTPB, INDPB, SIGMA_FRAC,
% SIGMA_DECAY, TOURNSIZE, ELITE_K, ISLANDS, MIG_INTERVAL, MIG_K,
% LOCAL_SEARCH, LS_ITER, FCM_SEED_FRAC, FCM_SEED_SIGMA. Optional:
% SMOOTH_SEED_FRAC, SMOOTH_SEED_SIGMA (seed a fraction of the
% population around the valve-point-free "economic center" -- see
% lambda_iteration_smooth.m); REHEAT_ENABLE, STAGNATION_WINDOW,
% REHEAT_FACTOR (boost mutation sigma back up after a long stall
% instead of only ever decaying it, so the search can escape a strong
% local basin around a single valve-notch combination).
%
% ip: optional Nx1 "informed" seed vector (FCM cluster center from
%     previous independent runs); pass [] to disable.

    if nargin < 17 || isempty(adjMask), adjMask = true(length(lb),1); end
    if nargin < 18, EM = []; end
    if nargin < 19 || isempty(H), H = 0; end
    useEmission = ~isempty(EM) && H > 0;
    if ~isfield(GA,'SMOOTH_SEED_FRAC'), GA.SMOOTH_SEED_FRAC = 0; end
    if ~isfield(GA,'SMOOTH_SEED_SIGMA'), GA.SMOOTH_SEED_SIGMA = 0.08; end
    if ~isfield(GA,'REHEAT_ENABLE'), GA.REHEAT_ENABLE = false; end
    if ~isfield(GA,'STAGNATION_WINDOW'), GA.STAGNATION_WINDOW = 40; end
    if ~isfield(GA,'REHEAT_FACTOR'), GA.REHEAT_FACTOR = 3.0; end
    rng(seed);
    N_ = length(lb);
    conv = zeros(GA.NGEN, 1);

    isz = floor(GA.POPSIZE / GA.ISLANDS) * ones(1, GA.ISLANDS);
    isz(end) = isz(end) + (GA.POPSIZE - sum(isz));

    isl = cell(GA.ISLANDS, 1);
    ifl = cell(GA.ISLANDS, 1);

    smoothP = [];
    if GA.SMOOTH_SEED_FRAC > 0
        smoothP = lambda_iteration_smooth(D, lb, ub, b, c, Bij, B0i, B00, ev);
    end

    for s = 1:GA.ISLANDS
        pop = bsxfun(@plus, lb', bsxfun(@times, rand(isz(s), N_), (ub - lb)'));
        if ~isempty(ip)
            nseed = min(isz(s), max(1, round(GA.FCM_SEED_FRAC * isz(s))));
            base = max(lb', min(ub', ip'));
            noise = bsxfun(@times, randn(nseed, N_), GA.FCM_SEED_SIGMA .* (ub - lb)');
            pop(1:nseed,:) = max(bsxfun(@min, ub', bsxfun(@plus, base, noise)), lb');
        end
        if ~isempty(smoothP)
            n2 = min(isz(s), max(1, round(GA.SMOOTH_SEED_FRAC * isz(s))));
            base2 = smoothP';
            % noise varies per individual so different units are
            % nudged into different valve-point ripples around the
            % same shared economic center.
            noise2 = bsxfun(@times, randn(n2, N_), GA.SMOOTH_SEED_SIGMA .* (ub - lb)');
            rows2 = (isz(s)-n2+1):isz(s);
            pop(rows2,:) = max(bsxfun(@min, ub', bsxfun(@plus, base2, noise2)), lb');
        end
        pop = repair_balance_batch(pop, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 60, adjMask);
        ft = compute_valve_cost_batch(pop, a, b, c, d, e, lb);
        if useEmission
            ft = ft + H * compute_emission_batch(pop, EM.alpha, EM.beta, EM.gamma, EM.xi, EM.delta);
        end
        isl{s} = pop; ifl{s} = ft;
    end

    sig0 = max((ub - lb) * GA.SIGMA_FRAC, 1e-9);
    sig = sig0;
    gbv = inf; gbo = lb;
    stag_counter = 0;

    for gen = 1:GA.NGEN
        prev_gbv = gbv;
        if GA.REHEAT_ENABLE && stag_counter >= GA.STAGNATION_WINDOW
            sig = min(sig * GA.REHEAT_FACTOR, sig0);
            stag_counter = 0;
        else
            sig = max(sig * GA.SIGMA_DECAY, (ub - lb) * 0.004);
        end

        for s = 1:GA.ISLANDS
            pop = isl{s}; ft = ifl{s}; ns = size(pop, 1);
            [~, od] = sort(ft);
            ke = min(GA.ELITE_K, ns);
            ep = pop(od(1:ke), :); ef = ft(od(1:ke));
            n_off = ns - ke;

            T = min(GA.TOURNSIZE, ns);
            idxT1 = randi(ns, n_off, T); ftT1 = ft(idxT1);
            [~, loc1] = min(ftT1, [], 2);
            sel1 = idxT1(sub2ind(size(idxT1), (1:n_off)', loc1));
            idxT2 = randi(ns, n_off, T); ftT2 = ft(idxT2);
            [~, loc2] = min(ftT2, [], 2);
            sel2 = idxT2(sub2ind(size(idxT2), (1:n_off)', loc2));
            p1 = pop(sel1,:); p2 = pop(sel2,:);

            ch = p1;
            cxmask = rand(n_off,1) < GA.CXPB;
            al = 0.5; dd = abs(p1 - p2);
            child = min(p1,p2) - al*dd + rand(n_off, N_) .* (dd + 2*al*dd);
            ch(cxmask,:) = child(cxmask,:);

            mutind  = rand(n_off,1) < GA.MUTPB;
            genemsk = rand(n_off, N_) < GA.INDPB;
            fullmsk = bsxfun(@and, mutind, genemsk);
            noise = bsxfun(@times, randn(n_off, N_), sig');
            ch = ch + fullmsk .* noise;

            ch = max(lb', min(ub', ch));
            ch = repair_balance_batch(ch, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 40, adjMask);
            of = compute_valve_cost_batch(ch, a, b, c, d, e, lb);
            if useEmission
                of = of + H * compute_emission_batch(ch, EM.alpha, EM.beta, EM.gamma, EM.xi, EM.delta);
            end

            isl{s} = [ep; ch]; ifl{s} = [ef; of];
        end

        if GA.ISLANDS > 1 && mod(gen, GA.MIG_INTERVAL) == 0
            mg = cell(GA.ISLANDS,1); mf = cell(GA.ISLANDS,1);
            for s = 1:GA.ISLANDS
                [~, os_] = sort(ifl{s});
                km = min(GA.MIG_K, length(os_));
                mg{s} = isl{s}(os_(1:km), :); mf{s} = ifl{s}(os_(1:km));
            end
            for s = 1:GA.ISLANDS
                dst = mod(s, GA.ISLANDS) + 1;
                [~, od2] = sort(ifl{dst}, 'descend');
                kr = min(GA.MIG_K, length(od2));
                for r = 1:kr
                    isl{dst}(od2(r), :) = mg{s}(r, :);
                    ifl{dst}(od2(r)) = mf{s}(r);
                end
            end
        end

        for s = 1:GA.ISLANDS
            [fs, is_] = min(ifl{s});
            if fs < gbv, gbv = fs; gbo = isl{s}(is_, :)'; end
        end
        if gbv < prev_gbv - 1e-9
            stag_counter = 0;
        else
            stag_counter = stag_counter + 1;
        end
        conv(gen) = gbv;
    end

    if GA.LOCAL_SEARCH
        [gbo, gbv] = local_search_transfer(gbo, D, lb, ub, a, b, c, d, e, ...
            Bij, B0i, B00, POZ, GA.LS_ITER, ev, adjMask, EM, H);
        conv(end) = gbv;
    end

    Pbest = gbo;
    fbest = gbv;
end
