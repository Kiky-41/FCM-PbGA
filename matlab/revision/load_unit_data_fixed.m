function [unit_data, POZ] = load_unit_data_fixed(xlsx_path)
%LOAD_UNIT_DATA_FIXED  Baca ELD_Test_System.xlsx dengan kolom poz DIPAKSA
%string, memperbaiki bug readtable bawaan yang menginferensi kolom poz
%sebagai double (teks zona -> NaN, nol -> 0) sehingga parse_poz_table
%menghasilkan POZ{i}=[] untuk SEMUA unit (POZ tidak pernah aktif).
%Dengan fix ini unit 1/5/6/13 mendapat zona POZ yang benar.
    opts = detectImportOptions(xlsx_path);
    ip = strcmpi(opts.VariableNames, 'poz');
    opts.VariableTypes(ip) = {'string'};
    opts.VariableNamingRule = 'preserve';
    unit_data = readtable(xlsx_path, opts);
    POZ = parse_poz_table(unit_data);
end
