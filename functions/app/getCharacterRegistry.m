function registry = getCharacterRegistry()
    % Unified character registry for GUI and asset loading.
    % Prefer locally implemented character folders so GUI startup does not
    % depend on the external avatar database being perfectly parseable.
    persistent cachedRegistry
    if ~isempty(cachedRegistry)
        registry = cachedRegistry;
        return;
    end

    initProjectPaths();
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    aliasMap = localCharacterAliasMap();

    registry = localReadImplementedCharacters(projectRoot, aliasMap);
    registry = localMergeAvatarMetadata(registry, projectRoot, aliasMap);
    registry = localSortRegistry(registry);
    cachedRegistry = registry;
end

function registry = localReadImplementedCharacters(projectRoot, aliasMap)
    dataDir = fullfile(projectRoot, 'data');
    entries = dir(dataDir);
    registry = repmat(localEmptyRegistryItem(), 1, 0);

    for i = 1:numel(entries)
        if ~entries(i).isdir
            continue;
        end

        folderName = string(entries(i).name);
        if startsWith(folderName, ".")
            continue;
        end
        if any(folderName == ["lunaris", "presets"])
            continue;
        end

        folderPath = fullfile(entries(i).folder, entries(i).name);
        files = dir(fullfile(folderPath, 'characters_*.csv'));
        if isempty(files)
            continue;
        end

        csvPath = fullfile(files(1).folder, files(1).name);
        try
            tbl = readtable(csvPath, 'TextType', 'string');
        catch
            continue;
        end
        if isempty(tbl)
            continue;
        end

        key = localNormalizeCharacterKey(folderName);
        displayName = localResolveDisplayName(key, tbl, aliasMap);
        weaponType = localNormalizeWeaponType(localTableString(tbl, 'Weapon', 1));
        element = localNormalizeElement(localTableString(tbl, 'Element', 1));
        avatarKey = localResolveAvatarKeyFromLocalData(key, aliasMap);

        registry(end + 1) = struct( ... %#ok<AGROW>
            'Key', key, ...
            'DisplayName', displayName, ...
            'WeaponType', weaponType, ...
            'Element', element, ...
            'AvatarKey', avatarKey, ...
            'Implemented', true);
    end
end

function registry = localMergeAvatarMetadata(registry, projectRoot, aliasMap)
    avatarDbPath = fullfile(projectRoot, 'data', 'AvatarExcelConfigData.js');
    avatarEntries = localReadAvatarEntries(avatarDbPath);
    if isempty(avatarEntries)
        return;
    end

    existingKeys = string({registry.Key});
    for i = 1:numel(avatarEntries)
        rawName = string(getFieldOrDefault(avatarEntries(i), '_name', ""));
        if strlength(rawName) == 0 || startsWith(rawName, "Player", 'IgnoreCase', true)
            continue;
        end

        mapping = localResolveCharacterMapping(rawName, aliasMap);
        if ~mapping.Include
            continue;
        end

        displayName = mapping.DisplayName;
        weaponType = localNormalizeWeaponType(string(getFieldOrDefault(avatarEntries(i), 'Weapon', "")));
        element = localNormalizeElement(string(getFieldOrDefault(avatarEntries(i), 'Element', "")));
        avatarKey = localResolveAvatarKey(string(getFieldOrDefault(avatarEntries(i), 'Icon', "")), mapping.AvatarKey);

        [weaponType, element, implemented] = localOverrideWithCharacterCsv( ...
            projectRoot, mapping.Key, weaponType, element);

        idx = find(existingKeys == mapping.Key, 1, 'first');
        if isempty(idx)
            registry(end + 1) = struct( ... %#ok<AGROW>
                'Key', mapping.Key, ...
                'DisplayName', displayName, ...
                'WeaponType', weaponType, ...
                'Element', element, ...
                'AvatarKey', avatarKey, ...
                'Implemented', implemented);
            existingKeys(end + 1) = mapping.Key; %#ok<AGROW>
            continue;
        end

        if strlength(string(registry(idx).DisplayName)) == 0
            registry(idx).DisplayName = displayName;
        end
        if strlength(string(registry(idx).WeaponType)) == 0
            registry(idx).WeaponType = weaponType;
        end
        if strlength(string(registry(idx).Element)) == 0
            registry(idx).Element = element;
        end
        if strlength(string(registry(idx).AvatarKey)) == 0
            registry(idx).AvatarKey = avatarKey;
        end
        registry(idx).Implemented = registry(idx).Implemented || implemented;
    end
end

function entries = localReadAvatarEntries(filePath)
    entries = repmat(struct(), 1, 0);
    if exist(filePath, 'file') ~= 2
        return;
    end

    rawText = fileread(filePath);
    chunks = localExtractTopLevelObjects(rawText);
    for i = 1:numel(chunks)
        try
            item = jsondecode(chunks{i});
        catch
            continue;
        end
        if isstruct(item) && isfield(item, '_name')
            entries(end + 1) = item; %#ok<AGROW>
        end
    end
end

function chunks = localExtractTopLevelObjects(rawText)
    chunks = {};
    inString = false;
    escaped = false;
    depth = 0;
    startIndex = 0;

    for i = 1:numel(rawText)
        ch = rawText(i);
        if inString
            if escaped
                escaped = false;
            elseif ch == '\'
                escaped = true;
            elseif ch == '"'
                inString = false;
            end
            continue;
        end

        if ch == '"'
            inString = true;
        elseif ch == '{'
            if depth == 0
                startIndex = i;
            end
            depth = depth + 1;
        elseif ch == '}'
            depth = max(0, depth - 1);
            if depth == 0 && startIndex > 0
                chunks{end + 1} = rawText(startIndex:i); %#ok<AGROW>
                startIndex = 0;
            end
        end
    end
end

function aliasMap = localCharacterAliasMap()
    aliasMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    aliasMap('Hutao') = struct('Key', "Hutao", 'DisplayName', "Hu Tao", 'AvatarKey', "Hutao", 'Include', true);
    aliasMap('SkirkNew') = struct('Key', "Skirk", 'DisplayName', "Skirk", 'AvatarKey', "SkirkNew", 'Include', true);
    aliasMap('Liuyun') = struct('Key', "Xianyun", 'DisplayName', "Xianyun", 'AvatarKey', "Liuyun", 'Include', true);
    aliasMap('Lanyan') = struct('Key', "LanYan", 'DisplayName', "Lan Yan", 'AvatarKey', "Lanyan", 'Include', true);
    aliasMap('Olorun') = struct('Key', "Ororon", 'DisplayName', "Ororon", 'AvatarKey', "Olorun", 'Include', true);
    aliasMap('Liney') = struct('Key', "Lyney", 'DisplayName', "Lyney", 'AvatarKey', "Liney", 'Include', true);
    aliasMap('Linette') = struct('Key', "Lynette", 'DisplayName', "Lynette", 'AvatarKey', "Linette", 'Include', true);
    aliasMap('Baizhuer') = struct('Key', "Baizhu", 'DisplayName', "Baizhu", 'AvatarKey', "Baizhuer", 'Include', true);
    aliasMap('Heizo') = struct('Key', "ShikanoinHeizou", 'DisplayName', "Shikanoin Heizou", 'AvatarKey', "Heizo", 'Include', true);
    aliasMap('Shinobu') = struct('Key', "KukiShinobu", 'DisplayName', "Kuki Shinobu", 'AvatarKey', "Shinobu", 'Include', true);
    aliasMap('Ayato') = struct('Key', "KamisatoAyato", 'DisplayName', "Kamisato Ayato", 'AvatarKey', "Ayato", 'Include', true);
    aliasMap('Ayaka') = struct('Key', "KamisatoAyaka", 'DisplayName', "Kamisato Ayaka", 'AvatarKey', "Ayaka", 'Include', true);
    aliasMap('Yae') = struct('Key', "YaeMiko", 'DisplayName', "Yae Miko", 'AvatarKey', "Yae", 'Include', true);
    aliasMap('Yunjin') = struct('Key', "YunJin", 'DisplayName', "Yun Jin", 'AvatarKey', "Yunjin", 'Include', true);
    aliasMap('Itto') = struct('Key', "AratakiItto", 'DisplayName', "Arataki Itto", 'AvatarKey', "Itto", 'Include', true);
    aliasMap('Qin') = struct('Key', "Jean", 'DisplayName', "Jean", 'AvatarKey', "Qin", 'Include', true);
    aliasMap('Shougun') = struct('Key', "RaidenShogun", 'DisplayName', "Raiden Shogun", 'AvatarKey', "Shougun", 'Include', true);
    aliasMap('Kokomi') = struct('Key', "SangonomiyaKokomi", 'DisplayName', "Sangonomiya Kokomi", 'AvatarKey', "Kokomi", 'Include', true);
    aliasMap('Sara') = struct('Key', "KujouSara", 'DisplayName', "Kujou Sara", 'AvatarKey', "Sara", 'Include', true);
    aliasMap('Kazuha') = struct('Key', "KaedeharaKazuha", 'DisplayName', "Kaedehara Kazuha", 'AvatarKey', "Kazuha", 'Include', true);
end

function mapping = localResolveCharacterMapping(rawName, aliasMap)
    mapping = struct('Key', string(rawName), 'DisplayName', string(rawName), 'AvatarKey', string(rawName), 'Include', true);
    key = char(string(rawName));
    if isKey(aliasMap, key)
        alias = aliasMap(key);
        mapping.Key = string(alias.Key);
        mapping.DisplayName = string(alias.DisplayName);
        mapping.AvatarKey = string(alias.AvatarKey);
        mapping.Include = logical(alias.Include);
    end
end

function [weaponType, element, implemented] = localOverrideWithCharacterCsv(projectRoot, characterKey, weaponType, element)
    implemented = false;
    charFolder = fullfile(projectRoot, 'data', char(characterKey));
    if exist(charFolder, 'dir') ~= 7
        return;
    end

    files = dir(fullfile(charFolder, 'characters_*.csv'));
    if isempty(files)
        return;
    end

    implemented = true;
    tbl = readtable(fullfile(files(1).folder, files(1).name), 'TextType', 'string');
    if isempty(tbl)
        return;
    end

    csvWeapon = localTableString(tbl, 'Weapon', 1);
    csvElement = localTableString(tbl, 'Element', 1);
    if strlength(csvWeapon) > 0
        weaponType = localNormalizeWeaponType(csvWeapon);
    end
    if strlength(csvElement) > 0
        element = localNormalizeElement(csvElement);
    end
end

function avatarKey = localResolveAvatarKey(iconField, fallbackKey)
    avatarKey = string(fallbackKey);
    iconField = string(iconField);
    if strlength(iconField) == 0
        return;
    end
    if startsWith(iconField, "UI_AvatarIcon_")
        avatarKey = erase(iconField, "UI_AvatarIcon_");
    else
        avatarKey = iconField;
    end
end

function key = localNormalizeCharacterKey(folderName)
    rawKey = string(folderName);
    if any(rawKey == ["Furina", "Columbina", "Skirk", "Escoffier", "Citlali", "Xianyun"])
        key = rawKey;
        return;
    end
    key = rawKey;
end

function displayName = localResolveDisplayName(key, tbl, aliasMap)
    displayName = string(key);
    aliasNames = values(aliasMap);
    for i = 1:numel(aliasNames)
        alias = aliasNames{i};
        if string(alias.Key) == key
            displayName = string(alias.DisplayName);
            return;
        end
    end

    nameValue = localTableString(tbl, 'Name', 1);
    if strlength(nameValue) > 0 && localLooksLikeAsciiName(nameValue)
        displayName = nameValue;
    end
end

function tf = localLooksLikeAsciiName(value)
    chars = char(string(value));
    if isempty(chars)
        tf = false;
        return;
    end
    tf = all((chars >= 32 & chars <= 126) | chars == 9);
end

function avatarKey = localResolveAvatarKeyFromLocalData(key, aliasMap)
    avatarKey = string(key);
    aliasNames = keys(aliasMap);
    for i = 1:numel(aliasNames)
        alias = aliasMap(aliasNames{i});
        if string(alias.Key) == key
            avatarKey = string(alias.AvatarKey);
            return;
        end
    end
end

function value = localNormalizeWeaponType(rawValue)
    token = lower(char(string(rawValue)));
    switch token
        case {'sword', 'weapon_sword_one_hand'}
            value = "Sword";
        case {'claymore', 'weapon_claymore'}
            value = "Claymore";
        case {'pole', 'polearm', 'weapon_pole'}
            value = "Pole";
        case {'bow', 'weapon_bow'}
            value = "Bow";
        case {'catalyst', 'weapon_catalyst'}
            value = "Catalyst";
        otherwise
            value = string(rawValue);
    end
end

function value = localNormalizeElement(rawValue)
    token = lower(char(string(rawValue)));
    switch token
        case {'fire', 'pyro'}
            value = "Pyro";
        case {'water', 'hydro'}
            value = "Hydro";
        case {'ice', 'cryo'}
            value = "Cryo";
        case {'elec', 'electro'}
            value = "Electro";
        case {'wind', 'anemo'}
            value = "Anemo";
        case {'rock', 'geo'}
            value = "Geo";
        case {'grass', 'dendro', 'dendro_'}
            value = "Dendro";
        otherwise
            value = string(rawValue);
    end
end

function value = localTableString(tbl, fieldName, rowIndex)
    value = "";
    if nargin < 3
        rowIndex = 1;
    end
    if isempty(tbl) || ~ismember(fieldName, tbl.Properties.VariableNames) || rowIndex > height(tbl)
        return;
    end
    value = string(tbl.(fieldName)(rowIndex));
end

function item = localEmptyRegistryItem()
    item = struct( ...
        'Key', "", ...
        'DisplayName', "", ...
        'WeaponType', "", ...
        'Element', "", ...
        'AvatarKey', "", ...
        'Implemented', false);
end

function registry = localSortRegistry(registry)
    if isempty(registry)
        return;
    end

    implemented = double([registry.Implemented]).';
    keys = string({registry.Key}).';
    orderTable = table(-implemented, keys, (1:numel(registry)).', ...
        'VariableNames', {'ImplementedRank', 'Key', 'Index'});
    orderTable = sortrows(orderTable, {'ImplementedRank', 'Key'}, {'ascend', 'ascend'});
    registry = registry(orderTable.Index);
end
