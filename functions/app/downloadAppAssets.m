function summary = downloadAppAssets()
    % 批量下载 GUI 所需素材，并整理到项目内的 art 目录。
    % 下载范围：
    % 1. 角色头像：getCharacterRegistry 中全部角色；
    % 2. 武器图标：data/WeaponExcelConfigData.js 中全部武器；
    % 3. 圣遗物套装图标：getArtifactSetRegistry 中全部套装。
    initProjectPaths();

    appFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(fileparts(appFolder));
    artRoot = fullfile(projectRoot, 'art');
    portraitDir = fullfile(artRoot, 'portraits');
    weaponDir = fullfile(artRoot, 'weapons');
    artifactDir = fullfile(artRoot, 'artifacts');

    localEnsureDir(artRoot);
    localEnsureDir(portraitDir);
    localEnsureDir(weaponDir);
    localEnsureDir(artifactDir);

    registry = getCharacterRegistry();
    portraitReal = 0;
    portraitFallback = 0;
    for i = 1:numel(registry)
        path = string(getPortraitForCharacter(registry(i).Key, portraitDir));
        if contains(path, "_placeholder.png")
            portraitFallback = portraitFallback + 1;
        else
            portraitReal = portraitReal + 1;
        end
    end

    weapons = localReadWeapons(projectRoot);
    weaponReal = 0;
    weaponFallback = 0;
    for i = 1:numel(weapons)
        path = string(getEquipmentBadge('weapon', weapons(i).Key, weapons(i).Name, "", weaponDir, [0.55 0.64 0.76]));
        if contains(path, "_badge.png")
            weaponFallback = weaponFallback + 1;
        else
            weaponReal = weaponReal + 1;
        end
    end

    artifactRegistry = getArtifactSetRegistry();
    artifactReal = 0;
    artifactFallback = 0;
    for i = 1:numel(artifactRegistry)
        [displayName, ~, accentColor] = getArtifactSetTheme(artifactRegistry(i).Id);
        path = string(getEquipmentBadge('artifact', artifactRegistry(i).Id, displayName, "", artifactDir, accentColor));
        if contains(path, "_badge.png")
            artifactFallback = artifactFallback + 1;
        else
            artifactReal = artifactReal + 1;
        end
    end

    summary = struct( ...
        'ArtRoot', string(artRoot), ...
        'PortraitReal', portraitReal, ...
        'PortraitFallback', portraitFallback, ...
        'WeaponReal', weaponReal, ...
        'WeaponFallback', weaponFallback, ...
        'ArtifactReal', artifactReal, ...
        'ArtifactFallback', artifactFallback);
end

function localEnsureDir(dirPath)
    if exist(dirPath, 'dir') ~= 7
        mkdir(dirPath);
    end
end

function weapons = localReadWeapons(projectRoot)
    weapons = struct('Key', {}, 'Name', {});

    jsPath = fullfile(projectRoot, 'data', 'WeaponExcelConfigData.js');
    if exist(jsPath, 'file') == 2
        raw = fileread(jsPath);
        tokens = regexp(raw, '"Name"\s*:\s*"([^"]+)"[\s\S]*?"Icons"\s*:\s*"([^"]+)"', 'tokens');
        for i = 1:numel(tokens)
            weapons(end + 1) = struct('Key', string(tokens{i}{2}), 'Name', string(tokens{i}{1})); %#ok<AGROW>
        end
    end

    lunarisWeapons = localReadLunarisWeapons(projectRoot);
    if ~isempty(lunarisWeapons)
        weapons = [weapons, lunarisWeapons]; %#ok<AGROW>
    elseif isempty(weapons)
        fallbackTable = readtable(fullfile(projectRoot, 'data', 'weapons.csv'), 'TextType', 'string');
        for i = 1:height(fallbackTable)
            weapons(end + 1) = struct('Key', fallbackTable.Name(i), 'Name', fallbackTable.Name(i)); %#ok<AGROW>
        end
    end

    if isempty(weapons)
        return;
    end

    keys = string({weapons.Key});
    [~, uniqueIdx] = unique(keys, 'stable');
    weapons = weapons(uniqueIdx);
end

function weapons = localReadLunarisWeapons(projectRoot)
    weapons = struct('Key', {}, 'Name', {});
    listData = getLunarisWeaponList(projectRoot, true);
    if ~isstruct(listData) || isempty(fieldnames(listData))
        return;
    end

    keysList = fieldnames(listData);
    for i = 1:numel(keysList)
        item = listData.(keysList{i});
        iconKey = string(getFieldOrDefault(item, 'weaponIcon', getFieldOrDefault(item, 'icon', "")));
        if strlength(iconKey) == 0
            continue;
        end
        displayName = string(getFieldOrDefault(item, 'enName', getFieldOrDefault(item, 'name', iconKey)));
        weapons(end + 1) = struct('Key', iconKey, 'Name', displayName); %#ok<AGROW>
    end
end
