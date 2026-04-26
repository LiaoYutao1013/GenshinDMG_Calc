function value = getFieldOrDefault(s, fieldName, defaultValue)
    % 安全读取结构体中的可选字段。
    % 当结构体为空、字段不存在，或字段值本身为空时，统一返回
    % defaultValue，减少上层反复写 isfield / isempty 的样板代码。
    if nargin < 3
        defaultValue = [];
    end

    % 只有在字段存在且字段值非空时才返回原始值。
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end
