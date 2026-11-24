function wgt = pick_slack_units_random(lb, ub, POZ, k, minor_weight, rng_seed)
% Randomized variant of pick_slack_units.m: instead of always
% designating the same k widest-range units as the balance-repair
% "slack" set, sample k units WITHOUT replacement with probability
% proportional to their operating range (POZ-bearing units strongly
% deprioritized). Different independent runs then settle the
% loss-balance fixed point along different subsets of units, which
% is what actually diversifies which valve-point local optimum an
% otherwise very strongly-attracting repair mechanism converges to
% (see Static_Benchmarks/README.md).
    if nargin < 6, rng_seed = []; end
    if ~isempty(rng_seed)
        state = rng(); rng(rng_seed);
    end
    N_ = length(lb);
    range = ub - lb;
    if ~isempty(POZ)
        hasPOZ = ~cellfun(@isempty, POZ);
        range(hasPOZ) = range(hasPOZ) * 0.3;
    end
    w = range / sum(range);
    idx = zeros(k,1);
    remaining = (1:N_)'; wr = w;
    for i = 1:min(k, N_)
        cw = cumsum(wr) / sum(wr);
        r = rand();
        pick = find(cw >= r, 1);
        idx(i) = remaining(pick);
        remaining(pick) = []; wr(pick) = [];
    end
    wgt = minor_weight * ones(N_, 1);
    wgt(idx(idx>0)) = 1.0;
    if ~isempty(rng_seed), rng(state); end
end
