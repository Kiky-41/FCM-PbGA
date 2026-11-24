function iv = parse_poz_cell(s)
% PARSE_POZ_CELL  Parse a prohibited-operating-zone string such as
%   "185-225,305-335,420-450"  or  "230-225, 365-395 , 430-455"
% into an Mx2 matrix of [lo hi] intervals (auto-sorted per pair so a
% reversed pair such as "230-225" -- as printed verbatim in the source
% table -- is still handled correctly). Empty / NaN / '0' -> [].
%
% NOTE: the number regex intentionally does NOT allow a leading
% '-'/'+' sign (unlike a generic signed-number matcher): POZ boundaries
% are always non-negative MW values here, and a bare-hyphen range like
% "180-200" would otherwise be misread as the two numbers 180 and -200
% (the hyphen consumed as a minus sign instead of a separator), which
% silently produced wildly wrong, far-too-wide intervals such as
% [-200,180] instead of [180,200] -- a real bug found and fixed in this
% project (it affects every POZ string of the form "lo-hi" with no
% space around the hyphen, which is most of them).
    iv = [];
    if isnumeric(s)
        if isempty(s) || isnan(s) || s == 0, return; end
        s = num2str(s);
    elseif isstring(s)
        s = char(s);
    elseif ~ischar(s)
        return;
    end
    s = strtrim(s);
    if isempty(s) || strcmp(s,'0') || strcmpi(s,'nan'), return; end
    nums = regexp(s,'[0-9]*\.?[0-9]+','match');
    vals = cellfun(@str2double, nums);
    vals = vals(~isnan(vals));
    for k = 1:2:length(vals)-1
        lo = min(vals(k), vals(k+1));
        hi = max(vals(k), vals(k+1));
        if hi > lo
            iv = [iv; lo, hi]; %#ok<AGROW>
        end
    end
end
