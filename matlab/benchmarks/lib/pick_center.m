function ps = pick_center(c, ref)
    ds = zeros(size(c,1),1);
    for k = 1:size(c,1)
        ds(k) = norm(c(k,:)' - ref);
    end
    [~, i] = min(ds);
    ps = c(i,:)';
end
