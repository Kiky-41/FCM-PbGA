function [p, tstat, df] = ttest2_manual(x, y)
%TTEST2_MANUAL  Two-sample Welch's t-test (unequal variances), computed
%from scratch so it needs no Statistics/Machine Learning Toolbox --
%only BETAINC, which is a core MATLAB/Octave function. Returns the
%two-sided p-value via the exact identity
%   p = betainc( df/(df+t^2), df/2, 1/2 )
%which holds for the Student t-distribution regardless of the sign of t.
    x = x(:); y = y(:);
    n1 = numel(x); n2 = numel(y);
    m1 = mean(x); m2 = mean(y);
    v1 = var(x); v2 = var(y);
    se2 = v1/n1 + v2/n2;
    if se2 <= 0
        tstat = 0; df = n1 + n2 - 2; p = 1; return;
    end
    tstat = (m1 - m2) / sqrt(se2);
    df = se2^2 / ( (v1/n1)^2/(n1-1) + (v2/n2)^2/(n2-1) );
    p = betainc(df/(df + tstat^2), df/2, 0.5);
end
