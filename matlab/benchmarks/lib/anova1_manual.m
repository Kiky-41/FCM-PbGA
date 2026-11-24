function [p, Fstat, df1, df2] = anova1_manual(Y)
%ANOVA1_MANUAL  One-way ANOVA F-test, computed from scratch so it needs
%no Statistics/Machine Learning Toolbox -- only BETAINC, a core
%MATLAB/Octave function (via the exact F-distribution/incomplete-beta
%identity). Y: N x k matrix, independent samples of equal size N in
%each of k columns (groups/algorithms).
    [N, k] = size(Y);
    grandMean = mean(Y(:));
    means = mean(Y, 1)';
    SSB = N * sum((means - grandMean).^2);
    SSW = sum(sum(bsxfun(@minus, Y, means').^2));
    df1 = k - 1;
    df2 = k * (N - 1);
    MSB = SSB / df1;
    MSW = SSW / df2;
    if MSW <= 0
        Fstat = Inf; p = 0; return;
    end
    Fstat = MSB / MSW;
    x = df2 / (df2 + df1 * Fstat);
    p = betainc(x, df2/2, df1/2);
end
