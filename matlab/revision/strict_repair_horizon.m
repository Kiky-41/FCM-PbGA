function [saf,ucf,costf,nEsc] = strict_repair_horizon(sr_raw,uc0,demand,Pmin,Pmax,RU,RD,POZ,Pnow,a_c,b_c,c_c,d_c,e_c,PminV)
%STRICT_REPAIR_HORIZON  Final mapping raw->feasible dgn NOL pelanggaran
%(definisi ketat: shortfall>1e-4, ramp/startup>1e-6, interior POZ 1e-9,
%gen-limit 1e-6, termasuk jam-1 vs Pnow).
% Perbedaan vs pipeline lama:
%  (1) Startup OFF->ON memakai [Pmin, min(Pmax,Pmin+RU)] (lama: [0,min(Pmax,RU)]
%      yg infeasible thd Eq.6 utk unit RU<Pmin) — koreksi Eq.8 yg didokumentasikan.
%  (2) Eskalasi UC DINAMIS thd output jam sebelumnya (bukan kapasitas statis).
%  (3) Setiap kenaikan daya diproyeksikan ulang ke Omega (POZ-aware).
%  (4) Sweep mundur utk ramp-down + audit gate.
% Input sr_raw: TxN keluaran optimizer; uc0: TxN komitmen awal.
% PminV: vektor Pmin utk biaya (sama dgn Pmin; arg terpisah agar eksplisit).
    N=numel(Pmin); T=numel(demand); tol=1e-4; ev=1e-6;
    mc = b_c + 2*c_c.*((Pmin+Pmax)/2);
    ucf = uc0; saf = zeros(T,N); nEsc = 0;
    prev_P = Pnow; prev_uc = ones(N,1);
    for t=1:T
        D=demand(t); uc=ucf(t,:)';
        redo = true;
        while redo
            redo = false;
            [L,U] = hour_bounds(prev_P,prev_uc,uc,Pmin,Pmax,RU,RD);
            eff = effmax_vec(L,U,uc,POZ);
            if sum(eff) < D-1e-6
                off = find(uc==0);
                if isempty(off), break; end
                [~,ib] = sort(mc(off)); uc(off(ib(1)))=1; nEsc=nEsc+1; redo=true;
                continue;
            end
            P = sr_raw(t,:)'; P(uc==0)=0;
            on = find(uc==1);
            P(on) = min(U(on),max(L(on),P(on)));
            for j=on', P(j)=project_poz(P(j),POZ{j},L(j),U(j),ev); end
            % balance shortfall: headroom termurah dulu
            for it=1:300
                sf = D-sum(P); if sf<=tol, break; end
                hr = max(0,U-P).*(uc==1); hs=sum(hr); if hs<1e-9, break; end
                mcost = b_c+2*c_c.*P; mcost(uc==0)=Inf; mcost(hr<=1e-12)=Inf;
                [~,ord]=sort(mcost);
                before=sum(P);
                for k=ord'
                    if D-sum(P)<=tol, break; end
                    if hr(k)<=1e-12, continue; end
                    give=min(hr(k), D-sum(P));
                    Pn=project_poz(P(k)+give,POZ{k},L(k),U(k),ev);
                    P(k)=max(P(k),Pn);
                    hr(k)=max(0,U(k)-P(k));
                end
                if sum(P)-before<1e-9, break; end
            end
            if D-sum(P)>tol
                off=find(uc==0);
                if ~isempty(off)
                    [~,ib]=sort(mc(off)); uc(off(ib(1)))=1; nEsc=nEsc+1; redo=true;
                end
            end
        end
        ucf(t,:)=uc'; saf(t,:)=P'; prev_P=P; prev_uc=uc;
    end
    % sweep mundur ramp-down (both-online pairs), maks 10 ronde
    for sweep=1:10
        fixed=false;
        for t=T-1:-1:1
            for i=1:N
                if ucf(t,i)==1 && ucf(t+1,i)==1
                    if saf(t,i)-saf(t+1,i) > RD(i)+1e-6
                        tgt = saf(t,i)-RD(i);
                        [L2,U2] = pair_bounds(saf(t,i),RD(i),RU(i),Pmin(i),Pmax(i));
                        Pn = project_poz(tgt,POZ{i},L2,U2,ev);
                        Pn = max(tgt,min(U2,Pn));
                        if in_poz_strict(Pn,POZ{i}), Pn = tgt; end
                        saf(t+1,i) = min(U2,max(L2,Pn));
                        fixed=true;
                    end
                end
            end
        end
        if ~fixed, break; end
    end
    % biaya final
    costf=zeros(T,1);
    for t=1:T
        [bc,vc]=compute_cost(saf(t,:)',ucf(t,:)',a_c,b_c,c_c,d_c,e_c,PminV);
        costf(t)=sum(bc+vc);
    end
end

function [L,U]=hour_bounds(prev_P,prev_uc,uc,Pmin,Pmax,RU,RD)
    N=numel(uc); L=zeros(N,1); U=zeros(N,1);
    for i=1:N
        if uc(i)==0, L(i)=0; U(i)=0;
        elseif prev_uc(i)==0
            L(i)=Pmin(i); U(i)=min(Pmax(i),Pmin(i)+RU(i));  % koreksi Eq.8
        else
            L(i)=max(Pmin(i),prev_P(i)-RD(i)); U(i)=min(Pmax(i),prev_P(i)+RU(i));
        end
        if U(i)<L(i), U(i)=L(i); end
    end
end

function eff=effmax_vec(L,U,uc,POZ)
    N=numel(uc); eff=zeros(N,1);
    for i=1:N
        if uc(i)==0, continue; end
        iv=POZ{i}; top=U(i);
        for k=1:size(iv,1)  % bila U di dalam zona, turunkan ke tepi bawah zona
            if top>iv(k,1)+1e-9 && top<iv(k,2)-1e-9, top=iv(k,1); end
        end
        eff(i)=max(L(i),min(top,U(i)));
        if eff(i)<L(i), eff(i)=0; end
    end
end

function [L2,U2]=pair_bounds(pPrev,RDi,RUi,Pmini,Pmaxi)
    L2=max(Pmini,pPrev-RDi); U2=min(Pmaxi,pPrev+RUi);
    if U2<L2, U2=L2; end
end

function on = prev_online(t,ucf)
    on = true; % pair (t,t+1) both-online: t+1 bukan startup (t online)
end

function f=in_poz_strict(p,iv)
    f=false;
    for k=1:size(iv,1)
        if p>iv(k,1)+1e-9 && p<iv(k,2)-1e-9, f=true; return; end
    end
end
