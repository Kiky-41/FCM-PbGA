function f = in_poz(p, iv)
    f = false;
    if isempty(iv), return; end
    for k = 1:size(iv,1)
        if p >= iv(k,1) && p <= iv(k,2), f = true; return; end
    end
end
