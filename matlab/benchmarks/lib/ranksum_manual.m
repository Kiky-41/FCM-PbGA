function [p, U, z] = ranksum_manual(x, y)
%RANKSUM_MANUAL  Wilcoxon rank-sum / Mann-Whitney U test, computed from
%scratch (tie-corrected normal approximation with continuity
%correction), so it needs no Statistics/Machine Learning Toolbox --
%only ERF, a core MATLAB/Octave function. Valid for the sample sizes
%used here (>= ~10 runs per algorithm).
    x = x(:); y = y(:);
    n1 = numel(x); n2 = numel(y);
    all = [x; y];
    n = numel(all);

    [sortedVals, sortIdx] = sort(all);
    sortedRanks = (1:n)';
    i = 1;
    while i <= n
        j = i;
        while j < n && sortedVals(j+1) == sortedVals(i)
            j = j + 1;
        end
        if j > i
            sortedRanks(i:j) = mean(i:j);
        end
        i = j + 1;
    end
    ranks = zeros(n,1);
    ranks(sortIdx) = sortedRanks;

    R1 = sum(ranks(1:n1));
    U1 = R1 - n1*(n1+1)/2;
    U2 = n1*n2 - U1;
    U = min(U1, U2);

    [~, ~, ic] = unique(all);
    tcounts = accumarray(ic, 1);
    tcorr = sum(tcounts.^3 - tcounts) / (n*(n-1));
    sigmaU = sqrt(n1*n2/12 * ((n+1) - tcorr));

    muU = n1*n2/2;
    if sigmaU == 0
        z = 0;
    else
        z = (U1 - muU - 0.5*sign(U1 - muU)) / sigmaU;
    end
    p = 2 * (1 - local_normcdf(abs(z)));
    p = min(p, 1);
end

function y = local_normcdf(x)
    y = 0.5 * (1 + erf(x / sqrt(2)));
end
