function P = lambda_iteration_smooth(D, lb, ub, b, c, Bij, B0i, B00, ev)
% LAMBDA_ITERATION_SMOOTH  Classical equal-incremental-cost ("lambda
% iteration" with loss penalty factors) solution to the SMOOTH
% (valve-point-free) quadratic-cost economic dispatch problem:
%   minimize sum(b_i P_i + c_i P_i^2)
%   s.t.     sum(P) - P_loss(P) = D,  lb <= P <= ub
%
% This ignores the valve-point ripple (d,e) entirely -- it is not
% meant to be the final answer, only a very good, well-defined
% "economic center" to seed the GA population with. The GA then only
% has to search, per unit, which local valve-point ripple to settle
% into around this center, instead of also having to discover the
% right overall generation/loss balance from scratch. This is the
% standard "seed around the smooth optimum" strategy used in the
% valve-point ED literature.
%
% Uses the classical penalty-factor formula:
%   P_i(lambda) = (lambda*(1-ITL_i) - b_i) / (2 c_i)
%   ITL_i = d(P_loss)/d(P_i) = (2*(Bij*P)_i + B0i(i)) / 100
% with an outer fixed-point loop to update ITL from the previous
% estimate of P, and an inner bisection on lambda to match the exact
% (non-linearized) power balance sum(P)-P_loss(P)=D.

    if nargin < 9, ev = 1e-6; end
    N_ = length(lb);
    hasLoss = ~isempty(Bij);
    P = (lb + ub) / 2;

    lam_lo = min(b) - 1;
    lam_hi = max(b + 2*c.*ub) * 1.5 + 1;

    for outer = 1:12
        if hasLoss
            ITL = (2*(Bij*P) + B0i(:)) / 100;
            ITL = max(-0.5, min(0.5, ITL)); % keep well-posed
        else
            ITL = zeros(N_,1);
        end

        lo = lam_lo; hi = lam_hi;
        for bis = 1:50
            lam = (lo + hi) / 2;
            Pt = (lam*(1 - ITL) - b) ./ (2*c);
            Pt = max(lb, min(ub, Pt));
            bal = sum(Pt) - compute_ploss(Pt, Bij, B0i, B00) - D;
            if bal > 0
                hi = lam;
            else
                lo = lam;
            end
        end
        Pnew = max(lb, min(ub, (lam*(1 - ITL) - b) ./ (2*c)));
        if norm(Pnew - P) < 1e-6, P = Pnew; break; end
        P = Pnew;
    end

    % final exact-balance polish (handles any residual mismatch, and
    % any POZ-free box-constraint slack) using the generic repair.
    P = repair_balance(P, D, lb, ub, Bij, B0i, B00, {}, ev, 1e-8, 100);
end
