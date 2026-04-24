function value = getFieldOrDefault(s, fieldName, defaultValue)
    if nargin < 3
        defaultValue = [];
    end

    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end
