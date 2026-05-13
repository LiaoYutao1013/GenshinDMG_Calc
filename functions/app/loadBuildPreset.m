function build = loadBuildPreset(characterName, presetId)
    % 按预设 ID 读取角色构筑。
    presets = listBuildPresetsForCharacter(characterName);
    ids = string({presets.Id});
    idx = find(ids == string(presetId), 1, 'first');
    if isempty(idx)
        idx = 1;
    end

    preset = presets(idx);
    switch preset.SourceType
        case "default"
            cfg = getDefaultCharacterConfig(characterName);
            build = cfg.Build;

        case "csv"
            build = localReadBuildCsv(preset.Path);

        otherwise
            cfg = getDefaultCharacterConfig(characterName);
            build = cfg.Build;
    end
end

function build = localReadBuildCsv(filePath)
    if ~isfile(filePath)
        build = struct();
        return;
    end

    tbl = readtable(filePath, 'TextType', 'string');
    if isempty(tbl)
        build = struct();
        return;
    end

    raw = table2struct(tbl(1, :), 'ToScalar', true);
    fieldNames = fieldnames(raw);
    build = struct();
    for i = 1:numel(fieldNames)
        fieldName = fieldNames{i};
        build.(fieldName) = localNormalizeValue(raw.(fieldName));
    end
end

function value = localNormalizeValue(raw)
    if isstring(raw)
        if isscalar(raw)
            raw = char(raw);
        else
            raw = char(join(raw, ', '));
        end
    end

    if ischar(raw)
        numericValue = str2double(strtrim(raw));
        if ~isnan(numericValue)
            value = numericValue;
        else
            value = raw;
        end
        return;
    end

    value = raw;
end
