function entry = getCharacterRegistryEntry(characterName)
    % Resolve a user-facing character name or alias into the registry entry.
    % This helper is shared by the dynamic import/generic-simulator path so
    % newly imported characters can join the unified pipeline without
    % touching every hard-coded switch table first.
    initProjectPaths();

    entry = struct( ...
        'Key', string(characterName), ...
        'DisplayName', string(characterName), ...
        'WeaponType', "", ...
        'Element', "", ...
        'AvatarKey', "", ...
        'Implemented', false, ...
        'Found', false);

    if nargin < 1 || strlength(string(characterName)) == 0
        return;
    end

    aliasTarget = localResolveAliasTarget(characterName);
    registry = getCharacterRegistry();
    if ~isempty(registry)
        idx = localFindRegistryIndex(registry, aliasTarget);
        if isempty(idx)
            idx = localFindRegistryIndex(registry, characterName);
        end
        if ~isempty(idx)
            entry = registry(idx);
            entry.Found = true;
            return;
        end
    end

    fallbackKey = localCanonicalFolderKey(aliasTarget);
    fallback = localReadCharacterCsvFallback(fallbackKey, characterName);
    if fallback.Found
        entry = fallback;
        return;
    end

    avatarFallback = localReadAvatarDbFallback(aliasTarget, characterName);
    if avatarFallback.Found
        entry = avatarFallback;
    end
end

function idx = localFindRegistryIndex(registry, characterName)
    idx = [];
    if isempty(registry)
        return;
    end

    query = localNormalizeLookup(characterName);
    keys = strings(1, numel(registry));
    displayNames = strings(1, numel(registry));
    avatarKeys = strings(1, numel(registry));
    for i = 1:numel(registry)
        keys(i) = localNormalizeLookup(registry(i).Key);
        displayNames(i) = localNormalizeLookup(registry(i).DisplayName);
        avatarKeys(i) = localNormalizeLookup(registry(i).AvatarKey);
    end

    idx = find(keys == query, 1, 'first');
    if ~isempty(idx)
        return;
    end

    idx = find(displayNames == query, 1, 'first');
    if ~isempty(idx)
        return;
    end

    idx = find(avatarKeys == query, 1, 'first');
end

function target = localResolveAliasTarget(characterName)
    aliasMap = localAliasMap();
    token = char(localNormalizeLookup(characterName));
    if isKey(aliasMap, token)
        target = string(aliasMap(token));
    else
        target = string(characterName);
    end
end

function aliasMap = localAliasMap()
    aliasMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    aliasMap('hutao') = 'Hutao';
    aliasMap('skirknew') = 'Skirk';
    aliasMap('liuyun') = 'Xianyun';
    aliasMap('lanyan') = 'LanYan';
    aliasMap('olorun') = 'Ororon';
    aliasMap('liney') = 'Lyney';
    aliasMap('linette') = 'Lynette';
    aliasMap('baizhuer') = 'Baizhu';
    aliasMap('heizo') = 'ShikanoinHeizou';
    aliasMap('shinobu') = 'KukiShinobu';
    aliasMap('ayato') = 'KamisatoAyato';
    aliasMap('ayaka') = 'KamisatoAyaka';
    aliasMap('yae') = 'YaeMiko';
    aliasMap('yunjin') = 'YunJin';
    aliasMap('itto') = 'AratakiItto';
    aliasMap('qin') = 'Jean';
    aliasMap('shougun') = 'RaidenShogun';
    aliasMap('kokomi') = 'SangonomiyaKokomi';
    aliasMap('sara') = 'KujouSara';
    aliasMap('kazuha') = 'KaedeharaKazuha';
    aliasMap('colunbina') = 'Columbina';
end

function key = localCanonicalFolderKey(characterName)
    target = localResolveAliasTarget(characterName);
    key = string(regexprep(char(string(target)), '[^A-Za-z0-9]', ''));
end

function entry = localReadCharacterCsvFallback(folderKey, originalName)
    entry = struct( ...
        'Key', string(folderKey), ...
        'DisplayName', string(originalName), ...
        'WeaponType', "", ...
        'Element', "", ...
        'AvatarKey', string(folderKey), ...
        'Implemented', false, ...
        'Found', false);

    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    charFolder = fullfile(projectRoot, 'data', char(folderKey));
    files = dir(fullfile(charFolder, 'characters_*.csv'));
    if isempty(files)
        return;
    end

    try
        tbl = readtable(fullfile(files(1).folder, files(1).name), 'TextType', 'string');
    catch
        return;
    end
    if isempty(tbl)
        return;
    end

    entry.DisplayName = localTableString(tbl, 'Name', 1);
    if strlength(entry.DisplayName) == 0
        entry.DisplayName = string(folderKey);
    end
    entry.WeaponType = localNormalizeWeaponType(localTableString(tbl, 'Weapon', 1));
    entry.Element = localNormalizeElement(localTableString(tbl, 'Element', 1));
    entry.Implemented = true;
    entry.Found = true;
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

function token = localNormalizeLookup(value)
    token = string(lower(regexprep(char(string(value)), '[^a-z0-9]', '')));
end

function entry = localReadAvatarDbFallback(aliasTarget, originalName)
    entry = struct( ...
        'Key', string(localCanonicalFolderKey(aliasTarget)), ...
        'DisplayName', string(originalName), ...
        'WeaponType', "", ...
        'Element', "", ...
        'AvatarKey', string(localCanonicalFolderKey(aliasTarget)), ...
        'Implemented', false, ...
        'Found', false);

    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    avatarDbPath = fullfile(projectRoot, 'data', 'AvatarExcelConfigData.js');
    if exist(avatarDbPath, 'file') ~= 2
        return;
    end

    rawText = fileread(avatarDbPath);
    chunks = localExtractTopLevelObjects(rawText);
    aliasMap = localAvatarAliasMap();
    target = char(localNormalizeLookup(aliasTarget));

    for i = 1:numel(chunks)
        try
            item = jsondecode(chunks{i});
        catch
            continue;
        end
        if ~isstruct(item) || ~isfield(item, '_name')
            continue;
        end

        rawName = item.('_name');
        [key, displayName, avatarKey] = localResolveAvatarMapping(rawName, aliasMap);
        keyToken = char(localNormalizeLookup(key));
        avatarToken = char(localNormalizeLookup(avatarKey));
        rawToken = char(localNormalizeLookup(rawName));
        if ~strcmp(keyToken, target) && ~strcmp(avatarToken, target) && ~strcmp(rawToken, target)
            continue;
        end

        entry.Key = key;
        entry.DisplayName = displayName;
        entry.AvatarKey = avatarKey;
        entry.WeaponType = localNormalizeWeaponType(string(getFieldOrDefault(item, 'Weapon', "")));
        entry.Element = localNormalizeElement(string(getFieldOrDefault(item, 'Element', "")));
        entry.Found = true;
        return;
    end
end

function aliasMap = localAvatarAliasMap()
    aliasMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    aliasMap('Hutao') = struct('Key', "Hutao", 'DisplayName', "Hu Tao", 'AvatarKey', "Hutao");
    aliasMap('Liuyun') = struct('Key', "Xianyun", 'DisplayName', "Xianyun", 'AvatarKey', "Liuyun");
    aliasMap('Lanyan') = struct('Key', "LanYan", 'DisplayName', "Lan Yan", 'AvatarKey', "Lanyan");
    aliasMap('Olorun') = struct('Key', "Ororon", 'DisplayName', "Ororon", 'AvatarKey', "Olorun");
    aliasMap('Liney') = struct('Key', "Lyney", 'DisplayName', "Lyney", 'AvatarKey', "Liney");
    aliasMap('Linette') = struct('Key', "Lynette", 'DisplayName', "Lynette", 'AvatarKey', "Linette");
    aliasMap('Baizhuer') = struct('Key', "Baizhu", 'DisplayName', "Baizhu", 'AvatarKey', "Baizhuer");
    aliasMap('Heizo') = struct('Key', "ShikanoinHeizou", 'DisplayName', "Shikanoin Heizou", 'AvatarKey', "Heizo");
    aliasMap('Shinobu') = struct('Key', "KukiShinobu", 'DisplayName', "Kuki Shinobu", 'AvatarKey', "Shinobu");
    aliasMap('Ayato') = struct('Key', "KamisatoAyato", 'DisplayName', "Kamisato Ayato", 'AvatarKey', "Ayato");
    aliasMap('Ayaka') = struct('Key', "KamisatoAyaka", 'DisplayName', "Kamisato Ayaka", 'AvatarKey', "Ayaka");
    aliasMap('Yae') = struct('Key', "YaeMiko", 'DisplayName', "Yae Miko", 'AvatarKey', "Yae");
    aliasMap('Yunjin') = struct('Key', "YunJin", 'DisplayName', "Yun Jin", 'AvatarKey', "Yunjin");
    aliasMap('Itto') = struct('Key', "AratakiItto", 'DisplayName', "Arataki Itto", 'AvatarKey', "Itto");
    aliasMap('Qin') = struct('Key', "Jean", 'DisplayName', "Jean", 'AvatarKey', "Qin");
    aliasMap('Shougun') = struct('Key', "RaidenShogun", 'DisplayName', "Raiden Shogun", 'AvatarKey', "Shougun");
    aliasMap('Kokomi') = struct('Key', "SangonomiyaKokomi", 'DisplayName', "Sangonomiya Kokomi", 'AvatarKey', "Kokomi");
    aliasMap('Sara') = struct('Key', "KujouSara", 'DisplayName', "Kujou Sara", 'AvatarKey', "Sara");
    aliasMap('Kazuha') = struct('Key', "KaedeharaKazuha", 'DisplayName', "Kaedehara Kazuha", 'AvatarKey', "Kazuha");
end

function [key, displayName, avatarKey] = localResolveAvatarMapping(rawName, aliasMap)
    key = string(rawName);
    displayName = string(rawName);
    avatarKey = string(rawName);
    rawToken = char(string(rawName));
    if isKey(aliasMap, rawToken)
        alias = aliasMap(rawToken);
        key = string(alias.Key);
        displayName = string(alias.DisplayName);
        avatarKey = string(alias.AvatarKey);
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
