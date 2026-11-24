function Pop = apply_poz_batch(Pop, lb, ub, POZ, ev)
% Vectorized-over-rows POZ projection: loops only over units that
% actually have a prohibited zone (few, if any) and, within a unit,
% over its (typically 2-3) intervals to flag violators with plain
% vector comparisons (no arrayfun, which is slow in Octave).
%
% The nearest-feasible-boundary candidate set for a given unit depends
% only on that unit's lb/ub/intervals, NOT on any individual's value --
% so it is built once per unit per call and then every flagged
% individual in that unit is projected in one vectorized nearest-point
% lookup (no per-individual scalar project_poz() calls, which used to
% dominate runtime whenever many individuals landed inside a zone at
% once -- e.g. PSO/WOA's less-localized position updates on a
% POZ-constrained system like the 15-unit benchmark).
    N_ = size(Pop, 2);
    for j = 1:N_
        iv = POZ{j};
        if isempty(iv), continue; end
        col = Pop(:,j);
        inzone = false(size(col));
        for k = 1:size(iv,1)
            inzone = inzone | (col >= iv(k,1) & col <= iv(k,2));
        end
        idx = find(inzone);
        if isempty(idx), continue; end

        cand = [lb(j); ub(j)];
        for k = 1:size(iv,1)
            cand = [cand; max(lb(j), iv(k,1)-ev); min(ub(j), iv(k,2)+ev)]; %#ok<AGROW>
        end
        candInzone = false(size(cand));
        for k = 1:size(iv,1)
            candInzone = candInzone | (cand >= iv(k,1) & cand <= iv(k,2));
        end
        cand = cand(~candInzone);
        if isempty(cand), continue; end

        pvals = col(idx);
        dists = abs(bsxfun(@minus, pvals, cand'));
        [~, bi] = min(dists, [], 2);
        col(idx) = cand(bi);
        Pop(:,j) = col;
    end
end
