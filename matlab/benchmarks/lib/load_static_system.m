function S = load_static_system(name)
%LOAD_STATIC_SYSTEM  Load raw problem data for one static ELD benchmark
%system (6/13/15/40-unit) as a plain struct, independent of any solver.
%Used by the competitor-algorithm benchmark driver
%(run_benchmark_comparison.m) so PSO/DE/GA/ABC/WOA can be evaluated on
%exactly the same D/Pmin/Pmax/cost-coefficients/loss-matrix/POZ data as
%FCM-PbGA, without duplicating the data-loading code already inside
%each run_*_ELD.m.
%
%   S = LOAD_STATIC_SYSTEM('6unit')   (also accepts '13unit','15unit','40unit')
%
%   Returns: S.system, S.D, S.Pmin, S.Pmax, S.a, S.b, S.c, S.d, S.e,
%   S.Bij, S.B0i, S.B00, S.POZ, S.LIT_LO, S.LIT_HI, S.EV, and
%   S.BUDGET.POPSIZE / S.BUDGET.NGEN (a population-size/generation-count
%   pair chosen to match this system's tuned FCM-PbGA computational
%   budget, so competitor algorithms get the same evaluation budget --
%   same POPSIZE*NGEN -- for a fair comparison).

    SCRIPT_DIR = fileparts(fileparts(mfilename('fullpath')));  % .../Static_Benchmarks
    DATA_DIR = fullfile(SCRIPT_DIR,'data');
    EV = 1e-6;

    switch lower(name)
        case {'6unit','6-unit'}
            U = dlmread(fullfile(DATA_DIR,'6unit_units.csv'), ',', 1, 0);
            Pmin=U(:,2); Pmax=U(:,3); a=U(:,4); b=U(:,5); c=U(:,6); d=U(:,7); e=U(:,8);
            Bij = dlmread(fullfile(DATA_DIR,'6unit_Bij.csv'), ',', 1, 0);
            B0i = dlmread(fullfile(DATA_DIR,'6unit_B0i.csv'), ',', 1, 0);
            B00 = str2double(fileread(fullfile(DATA_DIR,'6unit_B00.txt')));
            POZ = cell(length(Pmin),1);
            D = 1263; LIT_LO = 15442.00; LIT_HI = 15450.00;
            BUDGET.POPSIZE = 150; BUDGET.NGEN = 600;
            sysname = '6-unit';

        case {'13unit','13-unit'}
            U = dlmread(fullfile(DATA_DIR,'13unit_units.csv'), ',', 1, 0);
            Pmin=U(:,2); Pmax=U(:,3); a=U(:,4); b=U(:,5); c=U(:,6); d=U(:,7); e=U(:,8);
            Bij = []; B0i = []; B00 = 0;
            POZ = cell(length(Pmin),1);
            D = 1800; LIT_LO = 17988.99; LIT_HI = 17994.07;
            BUDGET.POPSIZE = 200; BUDGET.NGEN = 800;
            sysname = '13-unit';

        case {'15unit','15-unit'}
            U = dlmread(fullfile(DATA_DIR,'15unit_units_numeric.csv'), ',', 1, 0);
            Pmin=U(:,2); Pmax=U(:,3); a=U(:,4); b=U(:,5); c=U(:,6); d=U(:,7); e=U(:,8);
            Bij = dlmread(fullfile(DATA_DIR,'15unit_Bij.csv'), ',', 1, 0);
            B0i = dlmread(fullfile(DATA_DIR,'15unit_B0i.csv'), ',', 1, 0);
            B00 = str2double(fileread(fullfile(DATA_DIR,'15unit_B00.txt')));
            N_ = length(Pmin);
            POZ = cell(N_,1);
            fid = fopen(fullfile(DATA_DIR,'15unit_poz.txt'));
            for i=1:N_
                ln = fgetl(fid);
                POZ{i} = parse_poz_cell(ln);
            end
            fclose(fid);
            D = 2630; LIT_LO = 32697.28; LIT_HI = 32706.52;
            BUDGET.POPSIZE = 150; BUDGET.NGEN = 500;
            sysname = '15-unit';

        case {'40unit','40-unit'}
            U = dlmread(fullfile(DATA_DIR,'40unit_units.csv'), ',', 1, 0);
            Pmin=U(:,2); Pmax=U(:,3); a=U(:,4); b=U(:,5); c=U(:,6); d=U(:,7); e=U(:,8);
            Bij = []; B0i = []; B00 = 0;
            POZ = cell(length(Pmin),1);
            D = 10500; LIT_LO = 121412.54; LIT_HI = 121480.10;
            BUDGET.POPSIZE = 200; BUDGET.NGEN = 900;
            sysname = '40-unit';

        otherwise
            error('load_static_system:badSystem', ...
                'Unknown system "%s". Use one of: 6unit, 13unit, 15unit, 40unit.', name);
    end

    S.system = sysname;
    S.D = D; S.Pmin = Pmin; S.Pmax = Pmax;
    S.a = a; S.b = b; S.c = c; S.d = d; S.e = e;
    S.Bij = Bij; S.B0i = B0i; S.B00 = B00; S.POZ = POZ;
    S.LIT_LO = LIT_LO; S.LIT_HI = LIT_HI; S.EV = EV;
    S.BUDGET = BUDGET;
end
