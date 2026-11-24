function c = fcm_cluster_lite(data, nc, m, eps_, mi)
% Minimal from-scratch Fuzzy C-Means (same algorithm as the main
% FCM-PbGA study), used here to cluster the best solutions found by
% previous independent runs and seed the next run's population --
% the single-period analogue of the hourly FCM history-seeding used
% in the 15-unit dynamic dispatch study.
    [ns, nd] = size(data);
    nc = min(nc, ns);
    ix = randperm(ns, nc);
    c = data(ix,:);
    for it = 1:mi
        U = zeros(nc, ns);
        for k = 1:nc
            for j = 1:ns
                ds = zeros(nc,1);
                for l = 1:nc
                    ds(l) = max(norm(data(j,:) - c(l,:))^2, 1e-300);
                end
                U(k,j) = 1 / sum((ds(k)./ds).^(1/(m-1)));
            end
        end
        cn = zeros(nc, nd);
        for k = 1:nc
            uk = U(k,:)'.^m;
            cn(k,:) = (uk' * data) / sum(uk);
        end
        if norm(cn - c, 'fro') < eps_, c = cn; break; end
        c = cn;
    end
end
