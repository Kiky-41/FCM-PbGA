function opts = merge_options(defaults, args)
% MERGE_OPTIONS  Overlay Name/Value pairs (as passed via a function's
% own varargin) onto a defaults struct, so a callable run_*_ELD.m
% function can be invoked either with no arguments (uses the tuned
% defaults) or with overrides, e.g.:
%   run_6unit_ELD('N_RUNS', 5, 'VERBOSE', false)
% Unknown option names raise an error (helps catch typos) rather than
% being silently ignored.
    opts = defaults;
    if isempty(args), return; end
    if mod(numel(args), 2) ~= 0
        error('merge_options:oddArgs', ...
            'Options must be given as Name/Value pairs.');
    end
    for i = 1:2:numel(args)
        name = args{i};
        if ~(ischar(name) || isstring(name))
            error('merge_options:badName', ...
                'Option name at position %d must be a string.', i);
        end
        name = char(name);
        if ~isfield(opts, name)
            valid = strjoin(fieldnames(opts), ', ');
            error('merge_options:unknownOption', ...
                'Unknown option "%s". Valid options: %s', name, valid);
        end
        opts.(name) = args{i+1};
    end
end
