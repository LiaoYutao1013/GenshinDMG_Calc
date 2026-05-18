function [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        characterName, build, enemy, seqFile, talentLevel, constellation, teamContext, spec)
    % 通用 spec 驱动角色模拟器。
    % 这层用于承接大部分“已导入全量倍率，但暂未写独立状态机”的角色，实现：
    % 1. 统一入口与命座开关；
    % 2. AUTO 默认轮转兜底；
    % 3. 完整倍率表的参数查询与缩放类型识别；
    % 4. 状态窗口、层数、命中次数；
    % 5. 增幅反应、激化附加伤害、简化剧变反应。
    if nargin < 4 || isempty(seqFile)
        seqFile = "";
    end
    if nargin < 5 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 6 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 7 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', characterName, 'Constellation', constellation, 'Build', build)}, 20, struct());
    end
    if nargin < 8
        spec = struct();
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', 'data', char(string(characterName)));
    base = readtable(fullfile(dataFolder, sprintf('characters_%s.csv', char(string(characterName)))));
    talent = readtable(fullfile(dataFolder, sprintf('talents_%s.csv', char(string(characterName)))));
    actions = localReadActionSequence(seqFile, spec);

    scalingMode = localNormalizeScalingMode(getFieldOrDefault(spec, 'ScalingMode', "ATK"));
    element = string(getFieldOrDefault(spec, 'Element', getCharacterElement(characterName)));
    preferredAura = string(getFieldOrDefault(spec, 'PreferredAmplifyAura', ""));
    defaultDamageField = string(getFieldOrDefault(spec, 'DefaultDamageField', "SkillDMGBonus"));
    reactionBonusField = string(getFieldOrDefault(spec, 'ReactionBonusField', "ReactionDMGBonus"));

    [scaleValue, critRate, critDMG, atkValue, hpValue, defValue, emValue] = ...
        localResolveCoreStats(base, build, teamContext, scalingMode);
    baseCritRate = critRate;
    baseCritDMG = critDMG;
    enemyState = getFieldOrDefault(teamContext, 'EnemyState', createEnemyState(enemy, teamContext, element));

    state = struct( ...
        'SkillActiveTime', 0, ...
        'BurstActiveTime', 0, ...
        'Stacks', 0, ...
        'Marks', 0, ...
        'AuxCounter', 0, ...
        'CustomValue', 0);

    totalDMG = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = string(actions{i});
        actionTime = localResolveActionTime(action, spec);
        enemyState = advanceEnemyStateTime(enemyState, actionTime, element, teamContext);

        actionKey = localResolveActionKey(action, spec);
        actionSpec = localGetActionSpec(spec, actionKey);
        note = string(getFieldOrDefault(actionSpec, 'Note', ""));
        dmg = 0;

        if ~isstruct(actionSpec) || isempty(fieldnames(actionSpec))
            note = "Unknown action";
        else
            state = localApplyPreState(state, actionSpec, constellation);
            actionElement = string(getFieldOrDefault(actionSpec, 'ActionElement', element));
            reactionElement = string(getFieldOrDefault(actionSpec, 'ReactionElement', actionElement));

            talentGroup = char(string(getFieldOrDefault(actionSpec, 'TalentGroup', "Normal")));
            level = localResolveTalentLevel(talentLevel, constellation, talentGroup);
            paramName = localResolveTalentParamName( ...
                talent, talentGroup, char(string(getFieldOrDefault(actionSpec, 'Param', actionKey))));

            if strlength(string(paramName)) == 0
                note = localAppendNote(note, "missing talent param");
                mv = 0;
            else
                mv = getTalentValue(talent, talentGroup, paramName, level);
            end
            mv = mv ...
                + getFieldOrDefault(actionSpec, 'FlatMVBonus', 0) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1FlatMVBonus', 0), constellation, 1) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2FlatMVBonus', 0), constellation, 2) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6FlatMVBonus', 0), constellation, 6);
            if isfield(actionSpec, 'MVOverride')
                mv = getFieldOrDefault(actionSpec, 'MVOverride', mv);
            end

            actionScalingMode = localResolveActionScalingMode(actionSpec, talent, talentGroup, paramName, scalingMode);
            effectiveCritRate = min(1, baseCritRate ...
                + getFieldOrDefault(actionSpec, 'CritRateBonus', 0) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1CritRateBonus', 0), constellation, 1) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2CritRateBonus', 0), constellation, 2) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6CritRateBonus', 0), constellation, 6));
            effectiveCritDMG = baseCritDMG ...
                + getFieldOrDefault(actionSpec, 'CritDMGBonus', 0) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1CritDMGBonus', 0), constellation, 1) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2CritDMGBonus', 0), constellation, 2) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6CritDMGBonus', 0), constellation, 6);

            dynamicMultiplier = localResolveDynamicMultiplier(state, actionSpec, constellation);
            scaleComponent = localResolveScaleComponent( ...
                actionScalingMode, scaleValue, atkValue, hpValue, defValue, emValue, actionSpec);
            flatDirectBase = localResolveFlatDirectBase( ...
                atkValue, hpValue, defValue, emValue, actionSpec);
            extraBonus = localResolveDamageFieldBonus( ...
                build, string(getFieldOrDefault(actionSpec, 'DamageField', defaultDamageField))) ...
                + localResolveStateDamageBonus(state, actionSpec, constellation) ...
                + getFieldOrDefault(actionSpec, 'FlatDamageBonus', 0) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1DamageBonus', 0), constellation, 1) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2DamageBonus', 0), constellation, 2) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6DamageBonus', 0), constellation, 6);
            reactionBonus = getFieldOrDefault(build, char(reactionBonusField), 0) ...
                + getFieldOrDefault(actionSpec, 'ReactionBonus', 0);
            extraResShred = localResolveActionExtraResShred(state, actionSpec, constellation);
            localEnemy = localResolveActionEnemy(enemy, state, actionSpec, constellation);
            hitCount = max(1, round(double(getFieldOrDefault(actionSpec, 'HitCount', 1))));
            reactionTags = strings(0, 1);

            for hitIndex = 1:hitCount %#ok<NASGU>
                hitDMG = localDirectElementDamage( ...
                    actionElement, scaleComponent, mv * dynamicMultiplier, build, teamContext, localEnemy, ...
                    extraBonus, effectiveCritRate, effectiveCritDMG, extraResShred);
                if abs(flatDirectBase) > 1e-9
                    hitDMG = hitDMG + localDirectElementDamage( ...
                        actionElement, 1, flatDirectBase, build, teamContext, localEnemy, ...
                        extraBonus, effectiveCritRate, effectiveCritDMG, extraResShred);
                end

                if logical(getFieldOrDefault(actionSpec, 'AllowAmplify', 0))
                    [reactionMult, enemyState, reaction] = localResolveAmplify( ...
                        enemyState, actionElement, preferredAura, build, teamContext, reactionBonus);
                    hitDMG = hitDMG * reactionMult;
                    if reaction.Name ~= ""
                        reactionTags(end + 1, 1) = lower(string(reaction.Name)); %#ok<AGROW>
                    end
                end

                if logical(getFieldOrDefault(actionSpec, 'AllowCatalyze', 0))
                    [catalyzeDMG, catalyzeName] = localResolveCatalyzeDamage( ...
                        actionElement, build, teamContext, localEnemy, extraBonus, effectiveCritRate, effectiveCritDMG, reactionBonus, actionSpec, extraResShred);
                    hitDMG = hitDMG + catalyzeDMG;
                    if strlength(catalyzeName) > 0
                        reactionTags(end + 1, 1) = lower(string(catalyzeName)); %#ok<AGROW>
                    end
                end

                if logical(getFieldOrDefault(actionSpec, 'AllowTransformative', 0))
                    reactionBase = getFieldOrDefault(actionSpec, 'ReactionBaseDamage', 0) ...
                        + getFieldOrDefault(actionSpec, 'ReactionATKWeight', 0) * atkValue ...
                        + getFieldOrDefault(actionSpec, 'ReactionHPWeight', 0) * hpValue ...
                        + getFieldOrDefault(actionSpec, 'ReactionDEFWeight', 0) * defValue ...
                        + getFieldOrDefault(actionSpec, 'ReactionEMWeight', 0) * emValue;
                    if reactionBase > 0
                        em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
                        resShred = localElementResShred(reactionElement, build, teamContext) + extraResShred;
                        reactionCritRate = [];
                        reactionCritDMG = [];
                        if isfield(actionSpec, 'ReactionCritRate') || isfield(actionSpec, 'ReactionCritDMG') ...
                                || isfield(actionSpec, 'C6ReactionCritRate') || isfield(actionSpec, 'C6ReactionCritDMG')
                            reactionCritRate = getFieldOrDefault(actionSpec, 'ReactionCritRate', []) ...
                                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1ReactionCritRate', 0), constellation, 1) ...
                                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2ReactionCritRate', 0), constellation, 2) ...
                                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6ReactionCritRate', 0), constellation, 6);
                            reactionCritDMG = getFieldOrDefault(actionSpec, 'ReactionCritDMG', []) ...
                                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1ReactionCritDMG', 0), constellation, 1) ...
                                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2ReactionCritDMG', 0), constellation, 2) ...
                                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6ReactionCritDMG', 0), constellation, 6);
                        end
                        hitDMG = hitDMG + calcReactionDamage( ...
                            reactionBase, em, enemy, resShred, 1 + reactionBonus, reactionCritRate, reactionCritDMG);
                        reactionTags(end + 1, 1) = "reaction bonus"; %#ok<AGROW>
                    end
                end

                dmg = dmg + hitDMG;
            end

            reactionTags = unique(reactionTags(strlength(reactionTags) > 0), 'stable');
            for tagIndex = 1:numel(reactionTags)
                note = localAppendNote(note, reactionTags(tagIndex));
            end
            if hitCount > 1
                note = localAppendNote(note, "x" + string(hitCount));
            end

            state = localApplyPostState(state, actionSpec, constellation);
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {action, dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;
        state = localAdvanceSimpleState(state, actionTime);
    end

    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    dps = totalDMG / rotationTime;
end

function actions = localReadActionSequence(seqFile, spec)
    actions = {};
    if strlength(string(seqFile)) > 0 && exist(char(string(seqFile)), 'file') == 2
        actions = readRotationTokens(seqFile);
    end

    if isempty(actions) || (numel(actions) == 1 && strcmpi(char(string(actions{1})), 'AUTO'))
        if isfield(spec, 'DefaultRotation') && ~isempty(spec.DefaultRotation)
            if iscell(spec.DefaultRotation) && numel(spec.DefaultRotation) == 1 && iscell(spec.DefaultRotation{1})
                actions = cellstr(string(spec.DefaultRotation{1}(:)));
            else
                actions = cellstr(string(spec.DefaultRotation(:)));
            end
        else
            actions = localInferFallbackRotation(spec);
        end
    end

    actions = localExpandActionTokens(actions);
end

function actions = localInferFallbackRotation(spec)
    actions = {};
    actionMap = getFieldOrDefault(spec, 'Actions', struct());
    preferredOrder = {'E', 'Q', 'N1'};
    for i = 1:numel(preferredOrder)
        if isstruct(actionMap) && isfield(actionMap, preferredOrder{i})
            actions{end + 1, 1} = preferredOrder{i}; %#ok<AGROW>
        end
    end

    if isempty(actions)
        fields = fieldnames(actionMap);
        for i = 1:min(numel(fields), 6)
            actions{end + 1, 1} = fields{i}; %#ok<AGROW>
        end
    end
end

function expanded = localExpandActionTokens(actions)
    expanded = cell(0, 1);
    for i = 1:numel(actions)
        token = string(actions{i});
        parts = regexp(char(token), '^([A-Za-z][A-Za-z0-9_]*)(?:[x\*](\d+))?$', 'tokens', 'once');
        if isempty(parts)
            expanded{end + 1, 1} = char(token); %#ok<AGROW>
            continue;
        end

        baseToken = string(parts{1});
        repeatCount = 1;
        if numel(parts) >= 2 && ~isempty(parts{2})
            repeatCount = max(1, str2double(parts{2}));
        end
        for repeatIndex = 1:repeatCount %#ok<NASGU>
            expanded{end + 1, 1} = char(baseToken); %#ok<AGROW>
        end
    end
end

function [scaleValue, critRate, critDMG, atkValue, hpValue, defValue, emValue] = localResolveCoreStats(base, build, teamContext, scalingMode)
    atkValue = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    hpValue = base.BaseHP(1) * (1 + getFieldOrDefault(build, 'HPBonus', 0)) + getFieldOrDefault(build, 'FlatHP', 0);
    defValue = base.BaseDEF(1) * (1 + getFieldOrDefault(build, 'DEFBonus', 0)) + getFieldOrDefault(build, 'FlatDEF', 0);
    emValue = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);

    switch localNormalizeScalingMode(scalingMode)
        case "hp"
            scaleValue = hpValue;
        case "def"
            scaleValue = defValue;
        case "em"
            scaleValue = emValue;
        otherwise
            scaleValue = atkValue;
    end

    critRate = getFieldOrDefault(build, 'CritRate', 0);
    critDMG = getFieldOrDefault(build, 'CritDMG', 0);
end

function paramName = localResolveTalentParamName(talent, skillName, requestedParam)
    paramName = requestedParam;
    if any(strcmp(talent.Param, requestedParam))
        return;
    end

    normRequested = localNormalizeLookupToken(requestedParam);
    stemRequested = localStemLookupToken(requestedParam);
    skillMask = strcmp(talent.Skill, string(skillName));
    if ~any(skillMask)
        return;
    end

    params = string(talent.Param(skillMask));
    scores = zeros(numel(params), 1);
    for i = 1:numel(params)
        normCandidate = localNormalizeLookupToken(params(i));
        if normCandidate == normRequested
            paramName = char(params(i));
            return;
        end

        stemCandidate = localStemLookupToken(params(i));
        if stemCandidate == stemRequested && strlength(stemCandidate) > 0
            paramName = char(params(i));
            return;
        end

        scores(i) = max(localOverlapScore(normRequested, normCandidate), ...
            localOverlapScore(stemRequested, stemCandidate));
    end

    [bestScore, idx] = max(scores);
    if bestScore > 0.45
        paramName = char(params(idx));
    end
end

function token = localNormalizeLookupToken(text)
    token = string(lower(regexprep(char(string(text)), '[^a-z0-9]', '')));
end

function token = localStemLookupToken(text)
    token = localNormalizeLookupToken(text);
    token = regexprep(char(token), '^n([0-9]+)', 'x$1');
    token = regexprep(token, '^([0-9]+)hit', 'x$1');
    token = strrep(token, 'fullycharged', 'charged');
    token = strrep(token, 'chargedattack', 'charged');
    token = strrep(token, 'aimedshotchargelevel1', 'chargedaimedshot');
    token = strrep(token, 'highplunge', 'plunge');
    token = strrep(token, 'lowhighplunge', 'plunge');
    token = strrep(token, 'hit', '');
    token = strrep(token, 'dmg', '');
    token = strrep(token, 'damage', '');
    token = strrep(token, 'atk', '');
    token = strrep(token, 'hp', '');
    token = strrep(token, 'def', '');
    token = strrep(token, 'em', '');
    token = string(token);
end

function score = localOverlapScore(a, b)
    if strlength(a) == 0 || strlength(b) == 0
        score = 0;
        return;
    end
    if contains(b, a) || contains(a, b)
        score = double(min(strlength(a), strlength(b)) / max(strlength(a), strlength(b)));
        return;
    end

    len = min(strlength(a), strlength(b));
    common = 0;
    for i = 1:len
        if extractBetween(a, i, i) == extractBetween(b, i, i)
            common = common + 1;
        end
    end
    score = common / double(max(strlength(a), strlength(b)));
end

function damage = localDirectElementDamage(element, scaleValue, mv, build, teamContext, enemy, extraBonus, critRate, critDMG, extraResShred)
    if nargin < 10 || isempty(extraResShred)
        extraResShred = 0;
    end
    critRate = critRate + localElementCritRateBonus(element, teamContext);
    critDMG = critDMG + localElementCritDMGBonus(element, teamContext);
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    dmgBonus = 1 + localBuildElementBonus(element, build, teamContext) + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
    resShred = localElementResShred(element, build, teamContext) + extraResShred;
    damage = scaleValue * mv * dmgBonus * critMult * calcDamageMultiplier(90, enemy, resShred);
end

function bonus = localBuildElementBonus(element, build, teamContext)
    switch lower(char(string(element)))
        case 'pyro'
            bonus = getFieldOrDefault(build, 'PyroDMGBonus', 0) + getFieldOrDefault(teamContext, 'PyroDMGBonus', 0);
        case 'hydro'
            bonus = getFieldOrDefault(build, 'HydroDMGBonus', 0) + getFieldOrDefault(teamContext, 'HydroDMGBonus', 0);
        case 'cryo'
            bonus = getFieldOrDefault(build, 'CryoDMGBonus', 0) + getFieldOrDefault(teamContext, 'CryoDMGBonus', 0);
        case 'electro'
            bonus = getFieldOrDefault(build, 'ElectroDMGBonus', 0) + getFieldOrDefault(teamContext, 'ElectroDMGBonus', 0);
        case 'anemo'
            bonus = getFieldOrDefault(build, 'AnemoDMGBonus', 0) + getFieldOrDefault(teamContext, 'AnemoDMGBonus', 0);
        case 'geo'
            bonus = getFieldOrDefault(build, 'GeoDMGBonus', 0) + getFieldOrDefault(teamContext, 'GeoDMGBonus', 0);
        case 'dendro'
            bonus = getFieldOrDefault(build, 'DendroDMGBonus', 0) + getFieldOrDefault(teamContext, 'DendroDMGBonus', 0);
        case 'physical'
            bonus = getFieldOrDefault(build, 'PhysicalDMGBonus', 0) + getFieldOrDefault(teamContext, 'PhysicalDMGBonus', 0);
        otherwise
            bonus = 0;
    end
end

function resShred = localElementResShred(element, build, teamContext)
    resShred = getFieldOrDefault(build, 'ResShred', 0);
    switch lower(char(string(element)))
        case 'pyro'
            resShred = resShred + getFieldOrDefault(teamContext, 'PyroResShred', 0);
        case 'hydro'
            resShred = resShred + getFieldOrDefault(teamContext, 'HydroResShred', 0);
        case 'cryo'
            resShred = resShred + getFieldOrDefault(teamContext, 'CryoResShred', 0);
        case 'electro'
            resShred = resShred + getFieldOrDefault(teamContext, 'ElectroResShred', 0);
        case 'anemo'
            resShred = resShred + getFieldOrDefault(teamContext, 'AnemoResShred', 0);
        case 'geo'
            resShred = resShred + getFieldOrDefault(teamContext, 'GeoResShred', 0);
        case 'dendro'
            resShred = resShred + getFieldOrDefault(teamContext, 'DendroResShred', 0);
        case 'physical'
            resShred = resShred + getFieldOrDefault(teamContext, 'PhysicalResShred', 0);
    end
end

function bonus = localResolveDamageFieldBonus(build, damageField)
    damageField = string(damageField);
    bonus = getFieldOrDefault(build, char(damageField), 0);

    switch lower(char(damageField))
        case 'chargeddmgbonus'
            bonus = bonus + getFieldOrDefault(build, 'ChargeDMGBonus', 0);
        case 'chargedmgbonus'
            bonus = bonus + getFieldOrDefault(build, 'ChargedDMGBonus', 0);
    end
end

function bonus = localElementCritRateBonus(element, teamContext)
    switch lower(char(string(element)))
        case 'physical'
            bonus = getFieldOrDefault(teamContext, 'PhysicalCritRateBonus', 0);
        otherwise
            bonus = 0;
    end
end

function bonus = localElementCritDMGBonus(element, teamContext)
    switch lower(char(string(element)))
        case 'anemo'
            bonus = getFieldOrDefault(teamContext, 'AnemoCritDMGBonus', 0);
        case 'cryo'
            bonus = getFieldOrDefault(teamContext, 'CryoCritDMGBonus', 0);
        case 'geo'
            bonus = getFieldOrDefault(teamContext, 'GeoCritDMGBonus', 0);
        case 'physical'
            bonus = getFieldOrDefault(teamContext, 'PhysicalCritDMGBonus', 0);
        otherwise
            bonus = 0;
    end
end

function [reactionMultiplier, enemyState, reaction] = localResolveAmplify(enemyState, element, preferredAura, build, teamContext, reactionBonus)
    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    triggerElement = string(element);
    if strlength(preferredAura) > 0
        enemyState.Auras = struct('Element', string(preferredAura), 'Gauge', 1.0);
    end
    [reactionMultiplier, enemyState, reaction] = getAmplifyingReactionMultiplier( ...
        enemyState, triggerElement, em, teamContext, 1.0, 0, reactionBonus);
end

function [damage, reactionName] = localResolveCatalyzeDamage( ...
        element, build, teamContext, enemy, extraBonus, critRate, critDMG, reactionBonus, actionSpec, extraResShred)
    if nargin < 10 || isempty(extraResShred)
        extraResShred = 0;
    end
    damage = 0;
    reactionName = "";

    switch lower(char(string(element)))
        case 'electro'
            if getFieldOrDefault(teamContext, 'DendroCount', 0) < 1
                return;
            end
            reactionName = "Aggravate";
            baseDamage = getFieldOrDefault(actionSpec, 'CatalyzeBaseDamage', 1663.88);
        case 'dendro'
            if getFieldOrDefault(teamContext, 'ElectroCount', 0) < 1
                return;
            end
            reactionName = "Spread";
            baseDamage = getFieldOrDefault(actionSpec, 'CatalyzeBaseDamage', 1808.56);
        otherwise
            return;
    end

    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    additiveFlat = baseDamage * (1 + 5 * em / (em + 1200) + reactionBonus);
    damage = localDirectElementDamage( ...
        element, 1, additiveFlat, build, teamContext, enemy, extraBonus, critRate, critDMG, extraResShred);
end

function actionTime = localResolveActionTime(action, spec)
    timeMap = getFieldOrDefault(spec, 'ActionTimeMap', struct());
    key = matlab.lang.makeValidName(char(string(action)));
    if isstruct(timeMap) && isfield(timeMap, key)
        actionTime = timeMap.(key);
    else
        actionSpec = localGetActionSpec(spec, action);
        actionTime = getFieldOrDefault(actionSpec, 'ActionTime', getFieldOrDefault(spec, 'DefaultActionTime', 0.8));
    end
end

function key = localResolveActionKey(action, spec)
    aliases = getFieldOrDefault(spec, 'ActionAliases', struct());
    validName = matlab.lang.makeValidName(char(string(action)));
    if isstruct(aliases) && isfield(aliases, validName)
        key = string(aliases.(validName));
    else
        key = string(action);
    end
end

function actionSpec = localGetActionSpec(spec, actionKey)
    actionSpec = struct();
    actionMap = getFieldOrDefault(spec, 'Actions', struct());
    fieldName = matlab.lang.makeValidName(char(string(actionKey)));
    if isstruct(actionMap) && isfield(actionMap, fieldName)
        actionSpec = actionMap.(fieldName);
    end
end

function level = localResolveTalentLevel(talentLevel, constellation, talentGroup)
    switch lower(char(string(talentGroup)))
        case 'skill'
            level = talentLevel + 3 * double(constellation >= 3);
        case 'burst'
            level = talentLevel + 3 * double(constellation >= 5);
        otherwise
            level = talentLevel;
    end
end

function state = localApplyPreState(state, actionSpec, constellation)
    state = localApplyStateDelta(state, actionSpec, 'Pre', constellation);
end

function state = localApplyPostState(state, actionSpec, constellation)
    state = localApplyStateDelta(state, actionSpec, 'Post', constellation);
end

function state = localApplyStateDelta(state, actionSpec, prefix, constellation)
    stateFields = {'SkillActiveTime', 'BurstActiveTime', 'Stacks', 'Marks', 'AuxCounter', 'CustomValue'};
    for i = 1:numel(stateFields)
        fieldName = stateFields{i};
        setField = sprintf('%sSet%s', prefix, fieldName);
        addField = sprintf('%sAdd%s', prefix, fieldName);
        maxField = sprintf('%sMax%s', prefix, fieldName);
        c1Field = sprintf('%sC1Add%s', prefix, fieldName);
        c2Field = sprintf('%sC2Add%s', prefix, fieldName);
        c6Field = sprintf('%sC6Add%s', prefix, fieldName);

        if isfield(actionSpec, setField)
            state.(fieldName) = getFieldOrDefault(actionSpec, setField, state.(fieldName));
        end

        delta = getFieldOrDefault(actionSpec, addField, 0) ...
            + localConstellationGate(getFieldOrDefault(actionSpec, c1Field, 0), constellation, 1) ...
            + localConstellationGate(getFieldOrDefault(actionSpec, c2Field, 0), constellation, 2) ...
            + localConstellationGate(getFieldOrDefault(actionSpec, c6Field, 0), constellation, 6);
        if delta ~= 0
            state.(fieldName) = state.(fieldName) + delta;
        end
        if isfield(actionSpec, maxField)
            state.(fieldName) = min(getFieldOrDefault(actionSpec, maxField, state.(fieldName)), state.(fieldName));
        end
    end
end

function multiplier = localResolveDynamicMultiplier(state, actionSpec, constellation)
    multiplier = getFieldOrDefault(actionSpec, 'BaseMultiplier', 1.0);
    multiplier = multiplier ...
        + getFieldOrDefault(actionSpec, 'PerStackMultiplier', 0) * state.Stacks ...
        + getFieldOrDefault(actionSpec, 'PerMarkMultiplier', 0) * state.Marks ...
        + getFieldOrDefault(actionSpec, 'PerAuxMultiplier', 0) * state.AuxCounter ...
        + getFieldOrDefault(actionSpec, 'PerCustomMultiplier', 0) * state.CustomValue ...
        + getFieldOrDefault(actionSpec, 'BurstWindowMultiplier', 0) * double(state.BurstActiveTime > 0) ...
        + getFieldOrDefault(actionSpec, 'SkillWindowMultiplier', 0) * double(state.SkillActiveTime > 0);

    multiplier = multiplier ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C1MultiplierBonus', 0), constellation, 1) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C2MultiplierBonus', 0), constellation, 2) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C6MultiplierBonus', 0), constellation, 6);
end

function state = localAdvanceSimpleState(state, actionTime)
    state.SkillActiveTime = max(0, state.SkillActiveTime - actionTime);
    state.BurstActiveTime = max(0, state.BurstActiveTime - actionTime);
end

function value = localConstellationGate(value, constellation, requiredConstellation)
    value = value * double(constellation >= requiredConstellation);
end

function note = localAppendNote(baseNote, suffix)
    if strlength(string(baseNote)) == 0
        note = string(suffix);
    else
        note = string(baseNote) + ", " + string(suffix);
    end
end

function actionScalingMode = localResolveActionScalingMode(actionSpec, talent, skillName, paramName, fallbackScalingMode)
    actionScalingMode = localNormalizeScalingMode(getFieldOrDefault(actionSpec, 'ActionScalingMode', ""));
    if strlength(actionScalingMode) > 0
        return;
    end

    if strlength(string(paramName)) > 0 && any(strcmp(talent.Properties.VariableNames, 'ScalingType'))
        rowMask = strcmp(talent.Skill, string(skillName)) & strcmp(talent.Param, string(paramName));
        if any(rowMask)
            actionScalingMode = localNormalizeScalingMode(talent.ScalingType(find(rowMask, 1, 'first')));
            if strlength(actionScalingMode) > 0
                return;
            end
        end
    end

    actionScalingMode = localNormalizeScalingMode(fallbackScalingMode);
end

function scaleComponent = localResolveScaleComponent(actionScalingMode, defaultScaleValue, atkValue, hpValue, defValue, emValue, actionSpec)
    switch localNormalizeScalingMode(actionScalingMode)
        case "hp"
            scaleComponent = hpValue;
        case "def"
            scaleComponent = defValue;
        case "em"
            scaleComponent = emValue;
        otherwise
            scaleComponent = defaultScaleValue;
    end

    scaleComponent = scaleComponent ...
        + getFieldOrDefault(actionSpec, 'ATKWeight', 0) * atkValue ...
        + getFieldOrDefault(actionSpec, 'HPWeight', 0) * hpValue ...
        + getFieldOrDefault(actionSpec, 'DEFWeight', 0) * defValue ...
        + getFieldOrDefault(actionSpec, 'EMWeight', 0) * emValue ...
        + getFieldOrDefault(actionSpec, 'ScaleFlatATK', 0) ...
        + getFieldOrDefault(actionSpec, 'ScaleFlatHP', 0) ...
        + getFieldOrDefault(actionSpec, 'ScaleFlatDEF', 0) ...
        + getFieldOrDefault(actionSpec, 'ScaleFlatEM', 0) ...
        + getFieldOrDefault(actionSpec, 'ScaleFlatValue', 0);
end

function flatDirectBase = localResolveFlatDirectBase(atkValue, hpValue, defValue, emValue, actionSpec)
    flatDirectBase = getFieldOrDefault(actionSpec, 'FlatDirectDamage', 0) ...
        + getFieldOrDefault(actionSpec, 'FlatDirectATKWeight', 0) * atkValue ...
        + getFieldOrDefault(actionSpec, 'FlatDirectHPWeight', 0) * hpValue ...
        + getFieldOrDefault(actionSpec, 'FlatDirectDEFWeight', 0) * defValue ...
        + getFieldOrDefault(actionSpec, 'FlatDirectEMWeight', 0) * emValue;
end

function mode = localNormalizeScalingMode(rawMode)
    token = lower(char(string(rawMode)));
    switch token
        case {'maxhp', 'hp', 'hpbonus'}
            mode = "hp";
        case {'def', 'defbonus'}
            mode = "def";
        case {'em', 'elementalmastery'}
            mode = "em";
        otherwise
            mode = "atk";
    end
end

function bonus = localResolveStateDamageBonus(state, actionSpec, constellation)
    bonus = getFieldOrDefault(actionSpec, 'BaseActionDamageBonus', 0) ...
        + getFieldOrDefault(actionSpec, 'PerStackDamageBonus', 0) * state.Stacks ...
        + getFieldOrDefault(actionSpec, 'PerMarkDamageBonus', 0) * state.Marks ...
        + getFieldOrDefault(actionSpec, 'PerAuxDamageBonus', 0) * state.AuxCounter ...
        + getFieldOrDefault(actionSpec, 'PerCustomDamageBonus', 0) * state.CustomValue ...
        + getFieldOrDefault(actionSpec, 'SkillWindowDamageBonus', 0) * double(state.SkillActiveTime > 0) ...
        + getFieldOrDefault(actionSpec, 'BurstWindowDamageBonus', 0) * double(state.BurstActiveTime > 0);
    bonus = bonus ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C1ActionDamageBonus', 0), constellation, 1) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C2ActionDamageBonus', 0), constellation, 2) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C6ActionDamageBonus', 0), constellation, 6);
end

function extraResShred = localResolveActionExtraResShred(state, actionSpec, constellation)
    extraResShred = getFieldOrDefault(actionSpec, 'ExtraResShred', 0) ...
        + getFieldOrDefault(actionSpec, 'PerStackExtraResShred', 0) * state.Stacks ...
        + getFieldOrDefault(actionSpec, 'PerMarkExtraResShred', 0) * state.Marks ...
        + getFieldOrDefault(actionSpec, 'PerAuxExtraResShred', 0) * state.AuxCounter ...
        + getFieldOrDefault(actionSpec, 'PerCustomExtraResShred', 0) * state.CustomValue ...
        + getFieldOrDefault(actionSpec, 'SkillWindowExtraResShred', 0) * double(state.SkillActiveTime > 0) ...
        + getFieldOrDefault(actionSpec, 'BurstWindowExtraResShred', 0) * double(state.BurstActiveTime > 0);
    extraResShred = extraResShred ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C1ExtraResShred', 0), constellation, 1) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C2ExtraResShred', 0), constellation, 2) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C6ExtraResShred', 0), constellation, 6);
end

function localEnemy = localResolveActionEnemy(enemy, state, actionSpec, constellation)
    localEnemy = enemy;
    localEnemy.DefIgnore = getFieldOrDefault(enemy, 'DefIgnore', 0) ...
        + getFieldOrDefault(actionSpec, 'EnemyDefIgnore', 0) ...
        + getFieldOrDefault(actionSpec, 'PerStackEnemyDefIgnore', 0) * state.Stacks ...
        + getFieldOrDefault(actionSpec, 'PerMarkEnemyDefIgnore', 0) * state.Marks ...
        + getFieldOrDefault(actionSpec, 'PerAuxEnemyDefIgnore', 0) * state.AuxCounter ...
        + getFieldOrDefault(actionSpec, 'PerCustomEnemyDefIgnore', 0) * state.CustomValue ...
        + getFieldOrDefault(actionSpec, 'SkillWindowEnemyDefIgnore', 0) * double(state.SkillActiveTime > 0) ...
        + getFieldOrDefault(actionSpec, 'BurstWindowEnemyDefIgnore', 0) * double(state.BurstActiveTime > 0) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C1EnemyDefIgnore', 0), constellation, 1) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C2EnemyDefIgnore', 0), constellation, 2) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C6EnemyDefIgnore', 0), constellation, 6);
    localEnemy.DefReduct = getFieldOrDefault(enemy, 'DefReduct', 0) ...
        + getFieldOrDefault(actionSpec, 'EnemyDefReduct', 0) ...
        + getFieldOrDefault(actionSpec, 'PerStackEnemyDefReduct', 0) * state.Stacks ...
        + getFieldOrDefault(actionSpec, 'PerMarkEnemyDefReduct', 0) * state.Marks ...
        + getFieldOrDefault(actionSpec, 'PerAuxEnemyDefReduct', 0) * state.AuxCounter ...
        + getFieldOrDefault(actionSpec, 'PerCustomEnemyDefReduct', 0) * state.CustomValue ...
        + getFieldOrDefault(actionSpec, 'SkillWindowEnemyDefReduct', 0) * double(state.SkillActiveTime > 0) ...
        + getFieldOrDefault(actionSpec, 'BurstWindowEnemyDefReduct', 0) * double(state.BurstActiveTime > 0) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C1EnemyDefReduct', 0), constellation, 1) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C2EnemyDefReduct', 0), constellation, 2) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, 'C6EnemyDefReduct', 0), constellation, 6);
end
