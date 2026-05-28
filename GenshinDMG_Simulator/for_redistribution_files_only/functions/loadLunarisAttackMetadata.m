function attacks = loadLunarisAttackMetadata(characterName)
    % 从项目本地缓存的 Lunaris 角色 JSON 中读取攻击条目，
    % 提供给通用模拟器做 ApplyGauge / ICD 的自动补全。
    persistent attackCache
    if isempty(attackCache)
        attackCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
    end

    cacheKey = char(string(characterName));
    if isKey(attackCache, cacheKey)
        attacks = attackCache(cacheKey);
        return;
    end

    attacks = repmat(localEmptyAttack(), 1, 0);
    jsonPath = localResolveCharacterJsonPath(characterName);
    if strlength(jsonPath) == 0 || exist(char(jsonPath), 'file') ~= 2
        attackCache(cacheKey) = attacks;
        return;
    end

    try
        payload = jsondecode(fileread(char(jsonPath)));
    catch
        attackCache(cacheKey) = attacks;
        return;
    end

    if ~isstruct(payload) || ~isfield(payload, 'attacks') || isempty(payload.attacks)
        attackCache(cacheKey) = attacks;
        return;
    end

    rawAttacks = payload.attacks;
    for i = 1:numel(rawAttacks)
        item = rawAttacks(i);
        damageParam = string(getFieldOrDefault(item, 'damageParam', ""));
        baseDamageParam = localBaseDamageParam(damageParam);
        icdRule = string(getFieldOrDefault(item, 'icd_rule', ""));
        attacks(end + 1) = struct( ... %#ok<AGROW>
            'Name', string(getFieldOrDefault(item, 'name', "")), ...
            'NormalizedName', localNormalizeToken(getFieldOrDefault(item, 'name', "")), ...
            'DamageParam', damageParam, ...
            'BaseDamageParam', baseDamageParam, ...
            'NormalizedDamageParam', localNormalizeToken(baseDamageParam), ...
            'ICDSource', string(getFieldOrDefault(item, 'icd_source', "")), ...
            'NormalizedICDSource', localNormalizeToken(getFieldOrDefault(item, 'icd_source', "")), ...
            'ICDRule', icdRule, ...
            'ICDConfig', localParseICDRule(icdRule), ...
            'GaugeUnits', localParseGaugeUnits(getFieldOrDefault(item, 'gauge', "")), ...
            'Element', localNormalizeElement(getFieldOrDefault(item, 'element', "")), ...
            'AttackType', string(getFieldOrDefault(item, 'attackType', "")), ...
            'StrikeType', string(getFieldOrDefault(item, 'strikeType', "")));
    end

    attackCache(cacheKey) = attacks;
end

function jsonPath = localResolveCharacterJsonPath(characterName)
    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    jsonPath = "";

    metaPath = fullfile(projectRoot, 'data', char(string(characterName)), ...
        sprintf('lunaris_%s.json', char(string(characterName))));
    if exist(metaPath, 'file') == 2
        try
            meta = jsondecode(fileread(metaPath));
            characterId = string(getFieldOrDefault(meta, 'Id', ""));
            if strlength(characterId) > 0
                exact = dir(fullfile(projectRoot, 'data', 'lunaris', 'characters', ...
                    sprintf('%s_*.json', char(characterId))));
                if ~isempty(exact)
                    jsonPath = string(fullfile(exact(1).folder, exact(1).name));
                    return;
                end
            end
        catch
        end
    end

    fallback = dir(fullfile(projectRoot, 'data', 'lunaris', 'characters', ...
        sprintf('*_%s.json', char(string(characterName)))));
    if ~isempty(fallback)
        jsonPath = string(fullfile(fallback(1).folder, fallback(1).name));
    end
end

function attack = localEmptyAttack()
    attack = struct( ...
        'Name', "", ...
        'NormalizedName', "", ...
        'DamageParam', "", ...
        'BaseDamageParam', "", ...
        'NormalizedDamageParam', "", ...
        'ICDSource', "", ...
        'NormalizedICDSource', "", ...
        'ICDRule', "", ...
        'ICDConfig', localParseICDRule("Independent"), ...
        'GaugeUnits', 0, ...
        'Element', "", ...
        'AttackType', "", ...
        'StrikeType', "");
end

function baseDamageParam = localBaseDamageParam(damageParam)
    damageParam = string(damageParam);
    if damageParam == "-" || strlength(damageParam) == 0
        baseDamageParam = "";
        return;
    end

    pieces = split(damageParam, "|");
    baseDamageParam = string(pieces(1));
end

function gaugeUnits = localParseGaugeUnits(rawGauge)
    token = char(string(rawGauge));
    parts = regexp(token, '([\d\.]+)\s*U', 'tokens', 'once');
    if isempty(parts)
        gaugeUnits = 0;
    else
        gaugeUnits = str2double(parts{1});
    end
    if isnan(gaugeUnits)
        gaugeUnits = 0;
    end
end

function config = localParseICDRule(ruleText)
    ruleText = string(ruleText);
    normalized = lower(char(ruleText));

    config = struct('Kind', "Independent", 'Hits', 1, 'Window', 0);
    if strlength(ruleText) == 0 || ruleText == "-" || contains(normalized, 'independent')
        return;
    end

    if contains(normalized, 'standard')
        config.Kind = "Windowed";
        config.Hits = 3;
        config.Window = 2.5;
        return;
    end

    tokens = regexp(normalized, '(\d+)\s*hits?\s*/\s*([\d\.]+)\s*s', 'tokens', 'once');
    if isempty(tokens)
        return;
    end

    config.Kind = "Windowed";
    config.Hits = max(1, str2double(tokens{1}));
    config.Window = max(0, str2double(tokens{2}));
end

function normalized = localNormalizeToken(value)
    normalized = string(lower(regexprep(char(string(value)), '[^a-z0-9]', '')));
end

function element = localNormalizeElement(rawElement)
    switch lower(char(string(rawElement)))
        case {'fire', 'pyro'}
            element = "Pyro";
        case {'water', 'hydro'}
            element = "Hydro";
        case {'ice', 'cryo'}
            element = "Cryo";
        case {'elec', 'electro'}
            element = "Electro";
        case {'wind', 'anemo'}
            element = "Anemo";
        case {'rock', 'geo'}
            element = "Geo";
        case {'grass', 'dendro'}
            element = "Dendro";
        otherwise
            element = "";
    end
end
