function [total, per_unit] = compute_valve_cost(P, a, b, c, d, e, Pmin)
% Valve-point fuel cost, eq.(5): C_i = a_i + b_i P_i + c_i P_i^2
%                                        + |d_i sin(e_i (Pmin_i - P_i))|
    per_unit = a + b.*P + c.*P.^2 + abs(d .* sin(e .* (Pmin - P)));
    total = sum(per_unit);
end
