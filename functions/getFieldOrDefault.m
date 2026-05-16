function value = getFieldOrDefault(s, fieldName, defaultValue)
    % Safely read an optional field or table variable.
    % This helper is used throughout the project to avoid repeating
    % `isfield`/`isempty` checks, and it also supports single-row tables
    % returned by `readtable` so CSV-backed metadata can reuse the same API.
    if nargin < 3
        defaultValue = [];
    end

    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
        return;
    end

    if istable(s) && any(strcmp(s.Properties.VariableNames, fieldName)) && height(s) >= 1
        candidate = s.(fieldName);
        if iscell(candidate)
            candidate = candidate{1};
        elseif isnumeric(candidate) || islogical(candidate) || isstring(candidate) || ischar(candidate)
            candidate = candidate(1, :);
            if numel(candidate) == 1
                candidate = candidate(1);
            end
        else
            candidate = candidate(1, :);
        end

        if ~isempty(candidate)
            value = candidate;
            return;
        end
    end

    value = defaultValue;
end
