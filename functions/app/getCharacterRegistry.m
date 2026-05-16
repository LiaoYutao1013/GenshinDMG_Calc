function registry = getCharacterRegistry()
    % Unified character registry for GUI and asset loading.
    % The source of truth is data/AvatarExcelConfigData.js, with a small
    % alias layer for characters whose internal keys differ from the
    % user-facing roster key used by the simulator.
    persistent cachedRegistry
    if ~isempty(cachedRegistry)
        registry = cachedRegistry;
        return;
    end

    initProjectPaths();
    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    avatarDbPath = fullfile(projectRoot, 'data', 'AvatarExcelConfigData.js');
    avatarEntries = localReadAvatarEntries(avatarDbPath);
    aliasMap = localCharacterAliasMap();

    registry = repmat(struct( ...
        'Key', "", ...
        'DisplayName', "", ...
        'WeaponType', "", ...
        'Element', "", ...
        'AvatarKey', "", ...
        'Implemented', false), 1, 0);

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

        registry(end + 1) = struct( ... %#ok<AGROW>
            'Key', mapping.Key, ...
            'DisplayName', displayName, ...
            'WeaponType', weaponType, ...
            'Element', element, ...
            'AvatarKey', avatarKey, ...
            'Implemented', implemented);
    end

    registry = localSortRegistry(registry);
    cachedRegistry = registry;
end

function entries = localReadAvatarEntries(filePath)
    if exist(filePath, 'file') ~= 2
        error('Avatar database not found: %s', filePath);
    end

    rawText = fileread(filePath);
    chunks = localExtractTopLevelObjects(rawText);
    entries = repmat(struct(), 1, 0);
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

    for i = 1:strlength(string(rawText))
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
    aliasMap('SkirkNew') = struct('Key', "Skirk", 'DisplayName', "Skirk", 'AvatarKey', "SkirkNew", 'Include', true);
    aliasMap('Liuyun') = struct('Key', "Xianyun", 'DisplayName', "Xianyun", 'AvatarKey', "Liuyun", 'Include', true);
    aliasMap('Lanyan') = struct('Key', "LanYan", 'DisplayName', "Lan Yan", 'AvatarKey', "Lanyan", 'Include', true);
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

    csvWeapon = string(tbl.Weapon(1));
    csvElement = string(tbl.Element(1));
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
        case {'grass', 'dendro'}
            value = "Dendro";
        otherwise
            value = string(rawValue);
    end
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
