function [total, per_unit] = compute_emission(P, alpha, beta, gamma, xi, delta)
%COMPUTE_EMISSION  Standard quadratic-exponential emission function
%(eq. 3 in the same literature family that supplies alpha/beta/gamma/
%xi/delta for the 13-unit and 40-unit datasets):
%   E_i(P_i) = alpha_i + beta_i*P_i + gamma_i*P_i^2 + xi_i*exp(delta_i*P_i)
%(typically reported in lb/h or kg/h of pollutant, depending on the
%source paper -- treated here as dimensionless "emission units" since
%no unit was specified alongside the coefficients).
    per_unit = alpha + beta.*P + gamma.*P.^2 + xi.*exp(delta.*P);
    total = sum(per_unit);
end
