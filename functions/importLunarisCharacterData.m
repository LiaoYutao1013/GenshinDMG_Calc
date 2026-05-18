function summary = importLunarisCharacterData(characterRequests, options)
    % 从 Lunaris 拉取角色基础数据与技能倍率，并落地为工程统一使用的本地数据包。
    % 目标：
    % 1. 在 data/<Character> 下生成 characters_*.csv、talents_*.csv、rotation_*.txt；
    % 2. 在 data/lunaris/characters 下缓存原始 JSON，便于后续逐角色精修；
    % 3. 尽量沿用项目现有“扁平 CSV + 本地 rotation 文本”的数据风格。
    if nargin < 1 || isempty(characterRequests)
        summary = table();
        return;
    end
    if nargin < 2
        options = struct();
    end

    initProjectPaths();
    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    cacheRoot = fullfile(projectRoot, 'data', 'lunaris', 'characters');
    if exist(cacheRoot, 'dir') ~= 7
        mkdir(cacheRoot);
    end

    versionInfo = webread('https://api.lunaris.moe/data/version.json');
    version = string(getFieldOrDefault(versionInfo, 'version', "latest"));
    language = string(getFieldOrDefault(options, 'Language', "en"));
    overwrite = logical(getFieldOrDefault(options, 'Overwrite', true));

    normalized = localNormalizeRequests(characterRequests);
    rows = repmat(struct( ...
        'Key', "", ...
        'Id', "", ...
        'DisplayName', "", ...
        'Version', version, ...
        'DataFolder', "", ...
        'Status', "", ...
        'Message', ""), numel(normalized), 1);

    for i = 1:numel(normalized)
        req = normalized(i);
        rows(i).Key = req.Key;
        rows(i).Id = req.Id;
        rows(i).DisplayName = req.DisplayName;
        rows(i).DataFolder = string(fullfile(projectRoot, 'data', char(req.Key)));

        try
            jsonData = localFetchCharacterJson(version, language, req);
            localWriteCharacterDataset(projectRoot, cacheRoot, version, req, jsonData, overwrite);
            rows(i).Status = "ok";
            rows(i).Message = "imported";
        catch ME
            rows(i).Status = "error";
            rows(i).Message = string(ME.message);
        end
    end

    summary = struct2table(rows);
end

function requests = localNormalizeRequests(characterRequests)
    if isstruct(characterRequests)
        requests = characterRequests;
        return;
    end

    if isstring(characterRequests) || ischar(characterRequests)
        characterRequests = cellstr(string(characterRequests));
    end

    requests = repmat(struct('Key', "", 'Id', "", 'DisplayName', "", 'AvatarKey', ""), numel(characterRequests), 1);
    preset = localPresetCharacterMap();
    for i = 1:numel(characterRequests)
        token = string(characterRequests{i});
        tokenKey = lower(regexprep(char(token), '\s+', ''));
        if isKey(preset, tokenKey)
            requests(i) = preset(tokenKey);
        else
            liveMatch = localLookupCharacterRequest(token);
            if liveMatch.Found
                requests(i) = rmfield(liveMatch, 'Found');
            else
                requests(i).Key = token;
                requests(i).DisplayName = token;
            end
        end
    end
end

function preset = localPresetCharacterMap()
    preset = containers.Map('KeyType', 'char', 'ValueType', 'any');
    entries = { ...
        'navia',      "Navia",      "10000091", "Navia",    "Navia"; ...
        'gaming',     "Gaming",     "10000092", "Gaming",   "Gaming"; ...
        'chiori',     "Chiori",     "10000094", "Chiori",   "Chiori"; ...
        'sigewinne',  "Sigewinne",  "10000095", "Sigewinne","Sigewinne"; ...
        'sethos',     "Sethos",     "10000097", "Sethos",   "Sethos"; ...
        'clorinde',   "Clorinde",   "10000098", "Clorinde", "Clorinde"; ...
        'emilie',     "Emilie",     "10000099", "Emilie",   "Emilie"; ...
        'kachina',    "Kachina",    "10000100", "Kachina",  "Kachina"; ...
        'kinich',     "Kinich",     "10000101", "Kinich",   "Kinich"; ...
        'ororon',     "Ororon",     "10000105", "Ororon",   "Olorun"; ...
        'olorun',     "Ororon",     "10000105", "Ororon",   "Olorun"; ...
        'lanyan',     "LanYan",     "10000108", "Lan Yan",  "Lanyan"; ...
        'mizuki',     "Mizuki",     "10000109", "Yumemizuki Mizuki", "Mizuki"; ...
        'yumemizukimizuki', "Mizuki", "10000109", "Yumemizuki Mizuki", "Mizuki"; ...
        'ifa',        "Ifa",        "10000113", "Ifa",      "Ifa"; ...
        'dahlia',     "Dahlia",     "10000115", "Dahlia",   "Dahlia"; ...
        'aino',       "Aino",       "10000121", "Aino",     "Aino"; ...
        'jahoda',     "Jahoda",     "10000124", "Jahoda",   "Jahoda"; ...
        'illuga',     "Illuga",     "10000127", "Illuga",   "Illuga"; ...
        'varka',      "Varka",      "10000128", "Varka",    "Varka"; ...
        'lohen',      "Lohen",      "10000129", "Lohen",    "Lohen"; ...
        'prune',      "Prune",      "10000132", "Prune",    "Prune"; ...
        'alhaitham',  "Alhaitham",  "10000078", "Alhaitham","Alhaitham"; ...
        'yaoyao',     "Yaoyao",     "10000077", "Yaoyao",   "Yaoyao"; ...
        'faruzan',    "Faruzan",    "10000076", "Faruzan",  "Faruzan"; ...
        'wanderer',   "Wanderer",   "10000075", "Wanderer", "Wanderer"; ...
        'layla',      "Layla",      "10000074", "Layla",    "Layla"; ...
        'nahida',     "Nahida",     "10000073", "Nahida",   "Nahida"; ...
        'candace',    "Candace",    "10000072", "Candace",  "Candace"; ...
        'cyno',       "Cyno",       "10000071", "Cyno",     "Cyno"; ...
        'dori',       "Dori",       "10000068", "Dori",     "Dori"; ...
        'collei',     "Collei",     "10000067", "Collei",   "Collei" ...
    };
    for i = 1:size(entries, 1)
        preset(entries{i, 1}) = struct( ...
            'Key', entries{i, 2}, ...
            'Id', entries{i, 3}, ...
            'DisplayName', entries{i, 4}, ...
            'AvatarKey', entries{i, 5});
    end
end

function match = localLookupCharacterRequest(token)
    match = struct('Key', "", 'Id', "", 'DisplayName', "", 'AvatarKey', "", 'Found', false);
    token = string(token);

    aliasMap = localRequestAliasMap();
    normalizedInput = lower(regexprep(char(token), '[^a-z0-9]', ''));
    if isKey(aliasMap, normalizedInput)
        desiredKey = string(aliasMap(normalizedInput));
    else
        desiredKey = string(regexprep(char(token), '[^A-Za-z0-9]', ''));
    end

    liveEntries = localReadLiveCharacterIndex();
    if isempty(liveEntries)
        return;
    end

    target = lower(regexprep(char(desiredKey), '[^a-z0-9]', ''));
    for i = 1:numel(liveEntries)
        if strcmp(lower(regexprep(char(liveEntries(i).Key), '[^a-z0-9]', '')), target)
            match = liveEntries(i);
            match.Found = true;
            return;
        end
    end

    displayTarget = lower(regexprep(char(token), '[^a-z0-9]', ''));
    for i = 1:numel(liveEntries)
        if strcmp(lower(regexprep(char(liveEntries(i).DisplayName), '[^a-z0-9]', '')), displayTarget) ...
                || strcmp(lower(regexprep(char(liveEntries(i).AvatarKey), '[^a-z0-9]', '')), displayTarget)
            match = liveEntries(i);
            match.Found = true;
            return;
        end
    end

    avatarMatch = localLookupCharacterRequestFromAvatarDb(desiredKey, token);
    if avatarMatch.Found
        match = avatarMatch;
    end
end

function aliasMap = localRequestAliasMap()
    aliasMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    aliasMap('hutao') = 'Hutao';
    aliasMap('liuyun') = 'Xianyun';
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
    aliasMap('olorun') = 'Ororon';
    aliasMap('lanyan') = 'LanYan';
    aliasMap('mizuki') = 'Mizuki';
    aliasMap('yumemizukimizuki') = 'Mizuki';
    aliasMap('shougun') = 'RaidenShogun';
    aliasMap('raidenshogun') = 'RaidenShogun';
    aliasMap('kokomi') = 'SangonomiyaKokomi';
    aliasMap('sangonomiyakokomi') = 'SangonomiyaKokomi';
    aliasMap('sara') = 'KujouSara';
    aliasMap('kujousara') = 'KujouSara';
    aliasMap('kazuha') = 'KaedeharaKazuha';
    aliasMap('kaedeharakazuha') = 'KaedeharaKazuha';
end

function entries = localReadLiveCharacterIndex()
    persistent cache
    if ~isempty(cache)
        entries = cache;
        return;
    end

    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    rows = repmat(struct('Key', "", 'Id', "", 'DisplayName', "", 'AvatarKey', "", 'Found', false), 1, 0);
    cacheDir = fullfile(projectRoot, 'data', 'lunaris', 'characters');
    cacheFiles = dir(fullfile(cacheDir, '*.json'));
    for i = 1:numel(cacheFiles)
        [row, ok] = localReadCharacterIndexEntryFromCache(cacheFiles(i));
        if ok
            rows(end + 1) = row; %#ok<AGROW>
        end
    end

    if isempty(rows)
        livePath = fullfile(projectRoot, '__lunaris_charlist_live.json');
        if exist(livePath, 'file') == 2
            try
                payload = jsondecode(fileread(livePath));
                fields = fieldnames(payload);
                for i = 1:numel(fields)
                    item = payload.(fields{i});
                    if ~isstruct(item) || ~isfield(item, 'enName')
                        continue;
                    end

                    displayName = string(getFieldOrDefault(item, 'enName', ""));
                    if strlength(displayName) == 0 || startsWith(displayName, "Traveler", 'IgnoreCase', true) ...
                            || startsWith(displayName, "Manekin", 'IgnoreCase', true)
                        continue;
                    end

                    [key, avatarKey] = localCanonicalCharacterKey(displayName);
                    rows(end + 1) = struct( ... %#ok<AGROW>
                        'Key', key, ...
                        'Id', string(fields{i}), ...
                        'DisplayName', displayName, ...
                        'AvatarKey', avatarKey, ...
                        'Found', false);
                end
            catch
            end
        end
    end

    entries = localUniqueCharacterEntries(rows);
    cache = entries;
end

function [entry, ok] = localReadCharacterIndexEntryFromCache(fileInfo)
    entry = struct('Key', "", 'Id', "", 'DisplayName', "", 'AvatarKey', "", 'Found', false);
    ok = false;
    filePath = fullfile(fileInfo.folder, fileInfo.name);

    try
        payload = jsondecode(fileread(filePath));
    catch
        return;
    end

    if ~isstruct(payload) || ~isfield(payload, 'info')
        return;
    end

    displayName = string(getFieldOrDefault(payload.info, 'name', ""));
    if strlength(displayName) == 0 || startsWith(displayName, "Traveler", 'IgnoreCase', true) ...
            || startsWith(displayName, "Manekin", 'IgnoreCase', true)
        return;
    end

    idToken = regexp(fileInfo.name, '^(\d+)_', 'tokens', 'once');
    if isempty(idToken)
        return;
    end

    [key, avatarKey] = localCanonicalCharacterKey(displayName);
    entry = struct( ...
        'Key', key, ...
        'Id', string(idToken{1}), ...
        'DisplayName', displayName, ...
        'AvatarKey', avatarKey, ...
        'Found', false);
    ok = true;
end

function entries = localUniqueCharacterEntries(rows)
    entries = repmat(struct('Key', "", 'Id', "", 'DisplayName', "", 'AvatarKey', "", 'Found', false), 1, 0);
    if isempty(rows)
        return;
    end

    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    for i = 1:numel(rows)
        token = lower(regexprep(char(rows(i).Key), '[^a-z0-9]', ''));
        if isKey(seen, token)
            continue;
        end
        seen(token) = true;
        entries(end + 1) = rows(i); %#ok<AGROW>
    end
end

function match = localLookupCharacterRequestFromAvatarDb(desiredKey, token)
    match = struct('Key', "", 'Id', "", 'DisplayName', "", 'AvatarKey', "", 'Found', false);
    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    avatarDbPath = fullfile(projectRoot, 'data', 'AvatarExcelConfigData.js');
    if exist(avatarDbPath, 'file') ~= 2
        return;
    end

    avatarEntries = localReadAvatarEntries(avatarDbPath);
    if isempty(avatarEntries)
        return;
    end

    aliasMap = localAvatarAliasMap();
    targetKey = lower(regexprep(char(desiredKey), '[^a-z0-9]', ''));
    displayTarget = lower(regexprep(char(token), '[^a-z0-9]', ''));

    for i = 1:numel(avatarEntries)
        rawName = string(getFieldOrDefault(avatarEntries(i), '_name', ""));
        if strlength(rawName) == 0 || startsWith(rawName, "Player", 'IgnoreCase', true)
            continue;
        end

        [key, avatarKey, displayName] = localResolveAvatarCharacterMapping(rawName, aliasMap);
        keyToken = lower(regexprep(char(key), '[^a-z0-9]', ''));
        avatarToken = lower(regexprep(char(avatarKey), '[^a-z0-9]', ''));
        displayToken = lower(regexprep(char(displayName), '[^a-z0-9]', ''));
        rawToken = lower(regexprep(char(rawName), '[^a-z0-9]', ''));

        if strcmp(keyToken, targetKey) || strcmp(avatarToken, displayTarget) ...
                || strcmp(displayToken, displayTarget) || strcmp(rawToken, displayTarget)
            numericId = getFieldOrDefault(avatarEntries(i), '_id', []);
            if isempty(numericId)
                return;
            end
            fullId = string(sprintf('%08d', 10000000 + double(numericId)));
            match = struct( ...
                'Key', key, ...
                'Id', fullId, ...
                'DisplayName', displayName, ...
                'AvatarKey', avatarKey, ...
                'Found', true);
            return;
        end
    end
end

function entries = localReadAvatarEntries(filePath)
    entries = repmat(struct(), 1, 0);
    rawText = fileread(filePath);
    chunks = localExtractTopLevelObjects(rawText);
    for i = 1:numel(chunks)
        try
            item = jsondecode(chunks{i});
        catch
            continue;
        end
        if isstruct(item) && isfield(item, '_name') && isfield(item, '_id')
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

function [key, avatarKey, displayName] = localResolveAvatarCharacterMapping(rawName, aliasMap)
    key = string(rawName);
    avatarKey = string(rawName);
    displayName = string(rawName);
    mapKey = char(string(rawName));
    if isKey(aliasMap, mapKey)
        alias = aliasMap(mapKey);
        key = string(alias.Key);
        avatarKey = string(alias.AvatarKey);
        displayName = string(alias.DisplayName);
    end
end

function [key, avatarKey] = localCanonicalCharacterKey(displayName)
    avatarKey = string(regexprep(char(displayName), '[^A-Za-z0-9]', ''));
    key = avatarKey;
    switch lower(char(avatarKey))
        case 'hutao'
            key = "Hutao";
        case 'kaedeharakazuha'
            key = "KaedeharaKazuha";
            avatarKey = "Kazuha";
        case 'kujousara'
            key = "KujouSara";
            avatarKey = "Sara";
        case 'sangonomiyakokomi'
            key = "SangonomiyaKokomi";
            avatarKey = "Kokomi";
        case 'raidenshogun'
            key = "RaidenShogun";
            avatarKey = "Shougun";
        case 'yumemizukimizuki'
            key = "Mizuki";
            avatarKey = "Mizuki";
    end
end

function jsonData = localFetchCharacterJson(version, language, req)
    if strlength(req.Id) == 0
        error('Character ID missing for %s.', req.Key);
    end
    url = sprintf('https://api.lunaris.moe/data/%s/%s/char/%s.json', ...
        char(version), char(language), char(req.Id));
    jsonData = webread(url);
end

function localWriteCharacterDataset(projectRoot, cacheRoot, version, req, jsonData, overwrite)
    dataFolder = fullfile(projectRoot, 'data', char(req.Key));
    if exist(dataFolder, 'dir') ~= 7
        mkdir(dataFolder);
    end

    cachePath = fullfile(cacheRoot, sprintf('%s_%s.json', char(req.Id), char(req.Key)));
    localWriteJson(cachePath, jsonData);

    characterCsv = fullfile(dataFolder, sprintf('characters_%s.csv', char(req.Key)));
    talentCsv = fullfile(dataFolder, sprintf('talents_%s.csv', char(req.Key)));
    rotationTxt = fullfile(dataFolder, sprintf('rotation_%s.txt', char(req.Key)));
    metaJson = fullfile(dataFolder, sprintf('lunaris_%s.json', char(req.Key)));

    if overwrite || exist(characterCsv, 'file') ~= 2
        baseTable = localBuildCharacterBaseTable(req, jsonData);
        writetable(baseTable, characterCsv);
    end
    if overwrite || exist(talentCsv, 'file') ~= 2
        talentTable = localBuildTalentTable(jsonData);
        writetable(talentTable, talentCsv);
    end
    if overwrite || exist(rotationTxt, 'file') ~= 2
        fid = fopen(rotationTxt, 'w');
        cleaner = onCleanup(@() fclose(fid));
        fprintf(fid, 'AUTO\n');
    end

    meta = struct( ...
        'Key', req.Key, ...
        'Id', req.Id, ...
        'DisplayName', req.DisplayName, ...
        'AvatarKey', req.AvatarKey, ...
        'Version', version, ...
        'ImportedAt', char(datetime('now', 'TimeZone', 'local', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    localWriteJson(metaJson, meta);
end

function tbl = localBuildCharacterBaseTable(req, jsonData)
    info = jsonData.info;
    attr = localFindLevel90Attribute(info.attributes);
    [ascType, ascValue] = localResolveAscension(attr);

    tbl = table( ...
        string(req.DisplayName), ...
        double(getFieldOrDefault(attr, 'hp', 0)), ...
        double(getFieldOrDefault(attr, 'atk', 0)), ...
        double(getFieldOrDefault(attr, 'def', 0)), ...
        90, ...
        string(ascType), ...
        ascValue, ...
        string(localNormalizeWeaponType(getFieldOrDefault(info, 'weapon', ""))), ...
        string(localNormalizeElement(getFieldOrDefault(info, 'element', ""))), ...
        'VariableNames', {'Name','BaseHP','BaseATK','BaseDEF','Level', ...
        'AscensionType','AscensionValue','Weapon','Element'});
end

function attr = localFindLevel90Attribute(attributes)
    attr = struct('hp', 0, 'atk', 0, 'def', 0);
    if isempty(attributes)
        return;
    end

    if isstruct(attributes)
        levels = zeros(1, numel(attributes));
        for i = 1:numel(attributes)
            levels(i) = double(getFieldOrDefault(attributes(i), 'level', 0));
        end
        idx = find(levels == 90, 1, 'first');
        if isempty(idx)
            idx = numel(attributes);
        end
        attr = attributes(idx);
    end
end

function [ascType, ascValue] = localResolveAscension(attr)
    ascType = "None";
    ascValue = 0;
    fieldNames = fieldnames(attr);
    ignored = {'level', 'ascension', 'hp', 'atk', 'def'};
    for i = 1:numel(fieldNames)
        fieldName = string(fieldNames{i});
        if any(strcmpi(fieldName, ignored))
            continue;
        end
        rawValue = attr.(fieldNames{i});
        numericValue = localParseNumericScalar(rawValue);
        ascType = localNormalizeAscensionType(fieldName);
        if contains(fieldName, "%")
            ascValue = numericValue / 100;
        else
            ascValue = numericValue;
        end
        return;
    end
end

function talentTable = localBuildTalentTable(jsonData)
    rows = repmat(struct( ...
        'Skill', "", ...
        'Param', "", ...
        'ScalingType', "", ...
        'Level1', NaN, ...
        'Level2', NaN, ...
        'Level3', NaN, ...
        'Level4', NaN, ...
        'Level5', NaN, ...
        'Level6', NaN, ...
        'Level7', NaN, ...
        'Level8', NaN, ...
        'Level9', NaN, ...
        'Level10', NaN, ...
        'Level11', NaN, ...
        'Level12', NaN, ...
        'Level13', NaN, ...
        'Level14', NaN, ...
        'Level15', NaN), 0, 1);

    groupMap = { ...
        'normalattack', "Normal"; ...
        'elementalskill', "Skill"; ...
        'elementalburst', "Burst"};

    skills = jsonData.skills;
    for i = 1:size(groupMap, 1)
        fieldName = groupMap{i, 1};
        skillName = groupMap{i, 2};
        if ~isfield(skills, fieldName)
            continue;
        end
        multipliers = getFieldOrDefault(skills.(fieldName), 'multipliers', struct());
        keys = string(fieldnames(multipliers));
        for j = 1:numel(keys)
            key = keys(j);
            values = multipliers.(key);
            row = struct( ...
                'Skill', skillName, ...
                'Param', localNormalizeParamKey(key), ...
                'ScalingType', localInferScalingType(key, values), ...
                'Level1', NaN, ...
                'Level2', NaN, ...
                'Level3', NaN, ...
                'Level4', NaN, ...
                'Level5', NaN, ...
                'Level6', NaN, ...
                'Level7', NaN, ...
                'Level8', NaN, ...
                'Level9', NaN, ...
                'Level10', NaN, ...
                'Level11', NaN, ...
                'Level12', NaN, ...
                'Level13', NaN, ...
                'Level14', NaN, ...
                'Level15', NaN);

            for k = 1:min(15, numel(values))
                row.(sprintf('Level%d', k)) = localParseMultiplierValue(values{k});
            end
            rows(end + 1) = row; %#ok<AGROW>
        end
    end

    talentTable = struct2table(rows);
end

function localWriteJson(filePath, data)
    fid = fopen(filePath, 'w');
    if fid == -1
        error('Unable to open file for write: %s', filePath);
    end
    cleaner = onCleanup(@() fclose(fid));
    try
        rawText = jsonencode(data, 'PrettyPrint', true);
    catch
        rawText = jsonencode(data);
    end
    fprintf(fid, '%s', rawText);
end

function value = localNormalizeWeaponType(rawValue)
    token = lower(char(string(rawValue)));
    switch token
        case {'weapon_sword_one_hand', 'sword'}
            value = "Sword";
        case {'weapon_claymore', 'claymore'}
            value = "Claymore";
        case {'weapon_pole', 'weapon_polearm', 'polearm', 'pole'}
            value = "Pole";
        case {'weapon_bow', 'bow'}
            value = "Bow";
        case {'weapon_catalyst', 'catalyst'}
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

function value = localNormalizeAscensionType(rawField)
    token = lower(char(string(rawField)));
    if contains(token, 'crit dmg')
        value = "CD";
    elseif contains(token, 'crit rate')
        value = "CR";
    elseif contains(token, 'energy recharge')
        value = "ER";
    elseif contains(token, 'elemental mastery')
        value = "EM";
    elseif contains(token, 'healing')
        value = "HB";
    elseif contains(token, 'atk')
        value = "ATK";
    elseif contains(token, 'hp')
        value = "HP";
    elseif contains(token, 'def')
        value = "DEF";
    else
        value = string(rawField);
    end
end

function value = localNormalizeParamKey(rawKey)
    key = string(rawKey);
    key = replace(key, {' ', '/', '-', ':', '.', ',', '(', ')', ''''}, '');
    key = replace(key, '×', 'x');
    key = regexprep(char(key), '[^A-Za-z0-9]', '');
    value = string(key);
end

function scalingType = localInferScalingType(rawKey, rawValues)
    textBlob = lower(char(string(rawKey)));
    if ~isempty(rawValues)
        sample = lower(char(string(rawValues{1})));
        textBlob = [textBlob ' ' sample];
    end

    if contains(textBlob, 'elemental mastery')
        scalingType = "EM";
    elseif contains(textBlob, 'max hp') || contains(textBlob, 'hp')
        scalingType = "HP";
    elseif contains(textBlob, 'def')
        scalingType = "DEF";
    else
        scalingType = "ATK";
    end
end

function value = localParseMultiplierValue(rawValue)
    text = char(string(rawValue));
    if isempty(text)
        value = NaN;
        return;
    end

    matches = regexp(text, '([\d\.]+)', 'tokens');
    if isempty(matches)
        value = NaN;
        return;
    end

    nums = zeros(1, numel(matches));
    for i = 1:numel(matches)
        nums(i) = str2double(matches{i}{1});
    end

    if contains(text, '%')
        nums = nums / 100;
    end
    value = sum(nums);
end

function value = localParseNumericScalar(rawValue)
    if isnumeric(rawValue)
        value = double(rawValue);
        return;
    end
    text = char(string(rawValue));
    token = regexp(text, '([\d\.]+)', 'tokens', 'once');
    if isempty(token)
        value = 0;
    else
        value = str2double(token{1});
    end
end
