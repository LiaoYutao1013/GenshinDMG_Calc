function merged = applyStructOverrides(base, overrides)
    % Merge an override struct into a base struct without touching fields
    % that were not explicitly provided by the caller.
    merged = base;
    if nargin < 2 || isempty(overrides)
        return;
    end

    overrideFields = fieldnames(overrides);
    for i = 1:numel(overrideFields)
        fieldName = overrideFields{i};
        merged.(fieldName) = overrides.(fieldName);
    end
end
