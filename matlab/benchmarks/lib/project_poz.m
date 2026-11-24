function p = project_poz(p, iv, lb, ub, ev)
% Project p onto [lb,ub] \ interior(iv) -- pick the nearest feasible
% boundary point when p lands inside a prohibited zone.
    p = max(lb, min(ub, p));
    if isempty(iv) || ~in_poz(p, iv), return; end
    c = [lb; ub];
    for k = 1:size(iv,1)
        c = [c; max(lb, iv(k,1)-ev); min(ub, iv(k,2)+ev)]; %#ok<AGROW>
    end
    ok = c(~arrayfun(@(x) in_poz(x, iv), c));
    if isempty(ok), return; end
    [~, i] = min(abs(ok - p));
    p = ok(i);
end
