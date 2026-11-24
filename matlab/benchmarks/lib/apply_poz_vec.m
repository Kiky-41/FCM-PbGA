function P = apply_poz_vec(P, lb, ub, POZ, ev)
    for i = 1:length(P)
        P(i) = project_poz(P(i), POZ{i}, lb(i), ub(i), ev);
    end
end
