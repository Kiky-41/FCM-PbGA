function em = compute_emission_batch(Pop, alpha, beta, gamma, xi, delta)
%COMPUTE_EMISSION_BATCH  Vectorized emission function for a whole
%population. Pop: ns x N. alpha,beta,gamma,xi,delta: N x 1 (broadcast
%as row vectors). See compute_emission.m for the per-unit formula.
    q = bsxfun(@plus, bsxfun(@times, Pop, beta'), alpha') + bsxfun(@times, Pop.^2, gamma');
    ex = bsxfun(@times, xi', exp(bsxfun(@times, delta', Pop)));
    em = sum(q + ex, 2);
end
