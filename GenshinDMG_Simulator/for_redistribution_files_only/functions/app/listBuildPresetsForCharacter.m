function presets = listBuildPresetsForCharacter(characterName)
    % 列出角色在 GUI 中可选的构筑预设。
    % 预设来源按优先级分为：
    % 1. 角色默认构筑；
    % 2. 角色目录下 artifacts_<Character>.csv；
    % 3. data/presets 下与角色名匹配的额外 CSV。
    initProjectPaths();

    registry = getCharacterRegistry();
    key = string(characterName);
    displayName = key;
    idx = find(string({registry.Key}) == key, 1, 'first');
    if ~isempty(idx)
        displayName = string(registry(idx).DisplayName);
    end

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    presets = struct('Id', {}, 'DisplayName', {}, 'SourceType', {}, 'Path', {});

    presets(end + 1) = struct( ... %#ok<AGROW>
        'Id', "default", ...
        'DisplayName', "默认构筑", ...
        'SourceType', "default", ...
        'Path', "");

    characterCsv = fullfile(projectRoot, 'data', char(key), sprintf('artifacts_%s.csv', char(key)));
    if isfile(characterCsv)
        presets(end + 1) = struct( ... %#ok<AGROW>
            'Id', "character_csv", ...
            'DisplayName', "角色CSV面板", ...
            'SourceType', "csv", ...
            'Path', string(characterCsv));
    end

    presetDir = fullfile(projectRoot, 'data', 'presets');
    if exist(presetDir, 'dir')
        presetFiles = dir(fullfile(presetDir, '*.csv'));
        matchTerms = unique([lower(key), lower(displayName)]);
        for i = 1:numel(presetFiles)
            fileName = string(presetFiles(i).name);
            lowered = lower(fileName);
            isMatch = false;
            for j = 1:numel(matchTerms)
                if contains(lowered, matchTerms(j))
                    isMatch = true;
                    break;
                end
            end
            if ~isMatch
                continue;
            end

            fullPath = fullfile(presetFiles(i).folder, presetFiles(i).name);
            presets(end + 1) = struct( ... %#ok<AGROW>
                'Id', "preset_" + string(i), ...
                'DisplayName', erase(fileName, ".csv"), ...
                'SourceType', "csv", ...
                'Path', string(fullPath));
        end
    end

    if isempty(presets)
        presets = struct( ...
            'Id', "default", ...
            'DisplayName', "默认构筑", ...
            'SourceType', "default", ...
            'Path', "");
    end
end
