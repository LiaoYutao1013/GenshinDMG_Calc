function value = getFieldOrDefault(s, fieldName, defaultValue)
    % Read an optional field from a struct and fall back to a default when
    % the field is missing or empty.
    if nargin < 3
        defaultValue = [];
    end

    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end
