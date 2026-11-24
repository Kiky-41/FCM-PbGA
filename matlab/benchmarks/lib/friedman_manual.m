function [p, chi2stat, df] = friedman_manual(Y)
%FRIEDMAN_MANUAL  Friedman rank-based non-parametric test across k
%treatments (algorithms) over n blocks (independent-run indices),
%computed from scratch so it needs no Statistics/Machine Learning
%Toolbox -- only GAMMAINC, a core MATLAB/Octave function (chi-square
%p-value via the exact chi-square/incomplete-gamma identity). Y: n x k
%matrix.
    [n, k] = size(Y);
    R = zeros(n, k);
    for i = 1:n
        row = Y(i,:);
        [~, idx] = sort(row);
        ranks = zeros(1,k); ranks(idx) = 1:k;
        [uv, ~, ic] = unique(row);
        for u = 1:numel(uv)
            members = find(ic == u);
            if numel(members) > 1
                ranks(members) = mean(ranks(members));
            end
        end
        R(i,:) = ranks;
    end
    Rj = sum(R, 1);
    chi2stat = (12 / (n*k*(k+1))) * sum(Rj.^2) - 3*n*(k+1);
    df = k - 1;
    p = 1 - gammainc(chi2stat/2, df/2);
end
