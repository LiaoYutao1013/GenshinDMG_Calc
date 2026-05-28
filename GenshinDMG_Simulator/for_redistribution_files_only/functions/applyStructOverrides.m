function merged = applyStructOverrides(base, overrides)
    % 将 overrides 中显式给出的字段覆盖到 base 上。
    % 这里采用浅层合并策略：只替换当前层字段，不递归深入子结构。
    % 这样可以保证调用方只改自己关心的字段，其余默认值保持不变。
    merged = base;
    if nargin < 2 || isempty(overrides)
        return;
    end

    overrideFields = fieldnames(overrides);
    for i = 1:numel(overrideFields)
        % 逐字段覆盖，未提供的字段完全保留 base 中的原始值。
        fieldName = overrideFields{i};
        merged.(fieldName) = overrides.(fieldName);
    end
end
