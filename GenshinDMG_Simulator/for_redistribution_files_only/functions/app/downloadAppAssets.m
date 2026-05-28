function summary = downloadAppAssets()
    % 批量下载 GUI 所需素材，并整理到项目内的 art 目录。
    % 下载范围：
    % 1. 角色头像：getCharacterRegistry 中全部角色；
    % 2. 武器图标：data/weapons.csv 中全部武器；
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

    weapons = readtable(fullfile(projectRoot, 'data', 'weapons.csv'), 'TextType', 'string');
    weaponNames = unique(weapons.Name, 'stable');
    weaponReal = 0;
    weaponFallback = 0;
    for i = 1:numel(weaponNames)
        path = string(getEquipmentBadge('weapon', weaponNames(i), weaponNames(i), "", weaponDir, [0.55 0.64 0.76]));
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
