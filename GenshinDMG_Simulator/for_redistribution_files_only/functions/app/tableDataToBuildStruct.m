function build = tableDataToBuildStruct(rows)
    % 将 GUI 两列表格数据回写为角色 build struct。
    % 第一列要求为字段名，第二列为用户编辑后的值。该函数会尽量将字符串
    % 转成数值、逻辑值或保留为字符，以兼容当前工程各角色模拟器的字段读取方式。
    build = struct();
    if isempty(rows)
        return;
    end

    rowCount = size(rows, 1);
    for i = 1:rowCount
        fieldName = string(rows{i, 1});
        if strlength(fieldName) == 0
            continue;
        end

        value = rows{i, 2};
        build.(char(fieldName)) = localNormalizeValue(value);
    end
end

function value = localNormalizeValue(raw)
    if ismissing(raw)
        value = [];
        return;
    end

    if isnumeric(raw) || islogical(raw)
        value = raw;
        return;
    end

    if isstring(raw)
        raw = char(raw);
    end

    if ischar(raw)
        trimmed = strtrim(raw);
        if isempty(trimmed)
            value = '';
            return;
        end

        numericValue = str2double(trimmed);
        if ~isnan(numericValue)
            value = numericValue;
            return;
        end

        lowered = lower(trimmed);
        if any(strcmp(lowered, {'true', 'false'}))
            value = strcmp(lowered, 'true');
            return;
        end

        value = trimmed;
        return;
    end

    value = raw;
end
