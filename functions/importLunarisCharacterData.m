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
            requests(i).Key = token;
            requests(i).DisplayName = token;
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
