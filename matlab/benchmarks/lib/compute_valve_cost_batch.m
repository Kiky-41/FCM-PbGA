function fit = compute_valve_cost_batch(Pop, a, b, c, d, e, Pmin)
% Vectorized valve-point cost for a whole population.
% Pop: ns x N. a,b,c,d,e,Pmin: N x 1 (broadcast as row vectors).
    base  = bsxfun(@plus, bsxfun(@times, Pop, b'), a') + bsxfun(@times, Pop.^2, c');
    valve = abs(bsxfun(@times, d', sin(bsxfun(@times, e', bsxfun(@minus, Pmin', Pop)))));
    fit = sum(base + valve, 2);
end
