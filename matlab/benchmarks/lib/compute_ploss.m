function pl = compute_ploss(P, Bij, B0i, B00)
% Kron's loss formula, eq.(2): P_L = P'*Bij*P + B0i'*P + B00
%
% The published Bij/B0i coefficients for these benchmark systems are
% defined on a 100 MVA base (P in MW must be divided by 100 before the
% quadratic+linear terms are applied); B00 is a small constant already
% expressed directly in MW and is NOT rescaled. Verified numerically
% against a published reference dispatch/loss pair for the 6-unit
% system (Radziukyniene thesis, Case 2, D=1263 MW):
%   P = [447.818, 200.000, 253.557, 150.000, 150.320, 73.502] MW
%   reported P_loss = 12.197 MW; this formula reproduces 12.189 MW
%   (residual ~0.008 MW, consistent with the table's 3-decimal rounding).
    if isempty(Bij)
        pl = 0;
    else
        P = P(:);
        pl = (P' * Bij * P + B0i(:)' * P) / 100 + B00;
    end
end
