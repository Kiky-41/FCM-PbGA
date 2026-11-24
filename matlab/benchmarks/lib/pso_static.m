function [Pbest, fbest, conv] = pso_static(D, lb, ub, a, b, c, d, e, Bij, B0i, B00, POZ, PSO, seed, ev)
%PSO_STATIC  Standard Particle Swarm Optimization baseline for static
%valve-point ELD, using the SAME repair-based feasibility decoder as
%FCM-PbGA (repair_balance_batch + compute_valve_cost_batch) so the
%comparison isolates search-strategy quality rather than differences in
%constraint handling. No island structure, no FCM/smooth seeding, no
%memetic local search -- this is meant as a vanilla PSO baseline.
%
% PSO fields: POPSIZE, NGEN, W_MAX, W_MIN (inertia weight, linearly
% decreasing), C1 (cognitive), C2 (social), VEL_FRAC (velocity clamp as
% a fraction of each unit's operating range).

    if nargin < 15 || isempty(ev), ev = 1e-6; end
    rng(seed);
    N_ = length(lb); lbr = lb'; ubr = ub'; rng_ = ubr - lbr;

    pos = bsxfun(@plus, lbr, bsxfun(@times, rand(PSO.POPSIZE, N_), rng_));
    pos = repair_balance_batch(pos, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 60);
    vmax = PSO.VEL_FRAC * rng_;
    vel = bsxfun(@times, (2*rand(PSO.POPSIZE, N_) - 1), vmax);
    fit = compute_valve_cost_batch(pos, a, b, c, d, e, lb);

    pbest = pos; pbestf = fit;
    [gbestf, gi] = min(pbestf); gbest = pbest(gi, :);
    conv = zeros(PSO.NGEN, 1);

    for gen = 1:PSO.NGEN
        w = PSO.W_MAX - (PSO.W_MAX - PSO.W_MIN) * gen / PSO.NGEN;
        r1 = rand(PSO.POPSIZE, N_); r2 = rand(PSO.POPSIZE, N_);
        vel = w*vel + PSO.C1*r1.*(pbest - pos) + PSO.C2*r2.*bsxfun(@minus, gbest, pos);
        vel = max(-vmax, min(vmax, vel));
        pos = pos + vel;
        pos = max(lbr, min(ubr, pos));
        pos = repair_balance_batch(pos, D, lb, ub, Bij, B0i, B00, POZ, ev, 1e-6, 40);
        fit = compute_valve_cost_batch(pos, a, b, c, d, e, lb);

        improve = fit < pbestf;
        pbest(improve,:) = pos(improve,:); pbestf(improve) = fit(improve);
        [mgf, mgi] = min(pbestf);
        if mgf < gbestf, gbestf = mgf; gbest = pbest(mgi,:); end
        conv(gen) = gbestf;
    end

    Pbest = gbest'; fbest = gbestf;
end
