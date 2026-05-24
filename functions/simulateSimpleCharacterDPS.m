function [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS( ...
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

    base = readtable(char(resolveCharacterDataFile(characterName, 'characters')));
    talent = readtable(char(resolveCharacterDataFile(characterName, 'talents')));
    actions = localReadActionSequence(seqFile, spec);
    attackMetadata = loadLunarisAttackMetadata(characterName);
    icdStates = struct();

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
    state = localRunInitializeStateHook(spec, state, struct( ...
        'Character', string(characterName), ...
        'Build', build, ...
        'Enemy', enemy, ...
        'TalentLevel', talentLevel, ...
        'Constellation', constellation, ...
        'TeamContext', teamContext, ...
        'EnemyState', enemyState, ...
        'TalentTable', talent));

    totalDMG = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});
    auditRows = {};

    for i = 1:numel(actions)
        action = string(actions{i});
        actionTime = localResolveActionTime(action, spec);

        actionKey = localResolveActionKey(action, spec);
        actionSpec = localGetActionSpec(spec, actionKey);
        note = string(getFieldOrDefault(actionSpec, 'Note', ""));
        dmg = 0;
        auditApplyGauge = NaN;
        auditApplyGaugeSource = "";
        auditICDRule = "";
        auditICDSource = "";
        auditLunarisAttackName = "";
        auditLunarisDamageParam = "";

        if ~isstruct(actionSpec) || isempty(fieldnames(actionSpec))
            note = "Unknown action";
        else
            [state, actionSpec, actionTime, note] = localRunBeforeActionHook( ...
                spec, state, actionKey, actionSpec, actionTime, note, struct( ...
                'Character', string(characterName), ...
                'Build', build, ...
                'Enemy', enemy, ...
                'TalentLevel', talentLevel, ...
                'Constellation', constellation, ...
                'TeamContext', teamContext, ...
                'EnemyState', enemyState, ...
                'ActionIndex', i, ...
                'ActionToken', action, ...
                'TalentTable', talent));
            if isfield(actionSpec, 'PreSetCustomValue')
                state.CustomValue = getFieldOrDefault(actionSpec, 'PreSetCustomValue', state.CustomValue);
            end
            state = localApplyPreState(state, actionSpec, constellation);
            actionElement = string(getFieldOrDefault(actionSpec, 'ActionElement', element));
            reactionElement = string(getFieldOrDefault(actionSpec, 'ReactionElement', actionElement));

            talentGroup = char(string(getFieldOrDefault(actionSpec, 'TalentGroup', "Normal")));
            level = localResolveConfiguredTalentLevel(actionSpec, talentLevel, constellation, talentGroup);
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
                + getFieldOrDefault(actionSpec, 'SkillWindowCritRateBonus', 0) * double(state.SkillActiveTime > 0) ...
                + getFieldOrDefault(actionSpec, 'BurstWindowCritRateBonus', 0) * double(state.BurstActiveTime > 0) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1CritRateBonus', 0), constellation, 1) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2CritRateBonus', 0), constellation, 2) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6CritRateBonus', 0), constellation, 6));
            effectiveCritDMG = baseCritDMG ...
                + getFieldOrDefault(actionSpec, 'CritDMGBonus', 0) ...
                + getFieldOrDefault(actionSpec, 'SkillWindowCritDMGBonus', 0) * double(state.SkillActiveTime > 0) ...
                + getFieldOrDefault(actionSpec, 'BurstWindowCritDMGBonus', 0) * double(state.BurstActiveTime > 0) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1CritDMGBonus', 0), constellation, 1) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2CritDMGBonus', 0), constellation, 2) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6CritDMGBonus', 0), constellation, 6);

            dynamicMultiplier = localResolveDynamicMultiplier(state, actionSpec, constellation);
            scaleComponent = localResolveScaleComponent( ...
                actionScalingMode, scaleValue, atkValue, hpValue, defValue, emValue, ...
                actionSpec, state, constellation);
            flatDirectBase = localResolveFlatDirectBase( ...
                atkValue, hpValue, defValue, emValue, actionSpec, state, constellation);
            extraBonus = localResolveDamageFieldBonus( ...
                build, string(getFieldOrDefault(actionSpec, 'DamageField', defaultDamageField))) ...
                + localResolveStateDamageBonus(state, actionSpec, constellation) ...
                + getFieldOrDefault(actionSpec, 'FlatDamageBonus', 0) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1DamageBonus', 0), constellation, 1) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2DamageBonus', 0), constellation, 2) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6DamageBonus', 0), constellation, 6);
            buildReactionBonus = getFieldOrDefault(build, char(reactionBonusField), 0);
            actionReactionBonus = getFieldOrDefault(actionSpec, 'ReactionBonus', 0);
            extraResShred = localResolveActionExtraResShred(state, actionSpec, constellation);
            localEnemy = localResolveActionEnemy(enemy, state, actionSpec, constellation);
            [hitTimeline, postActionDeltaTime] = localResolveHitTimeline(actionSpec, actionTime);
            hitCount = numel(hitTimeline);
            reactionTags = strings(0, 1);

            for hitIndex = 1:hitCount
                hitDeltaTime = hitTimeline(hitIndex);
                attackMeta = localResolveLunarisAttackMetadata( ...
                    characterName, actionSpec, actionKey, paramName, actionElement, attackMetadata);
                [applyGauge, applyGaugeSource] = localResolveActionApplyGauge(actionSpec, attackMeta);
                [canApplyAura, icdStates, icdSnapshot] = localResolveActionICDGate( ...
                    icdStates, actionKey, actionSpec, attackMeta, hitDeltaTime);
                auditApplyGauge = applyGauge;
                auditApplyGaugeSource = applyGaugeSource;
                auditICDRule = string(getFieldOrDefault(icdSnapshot, 'ICDRule', ""));
                auditICDSource = string(getFieldOrDefault(icdSnapshot, 'ICDSource', ""));
                applyElement = string(getFieldOrDefault(actionSpec, 'ApplyElement', actionElement));
                canApplyAura = canApplyAura && localIsElementalDamageElement(applyElement) ...
                    && applyGauge > 0;

                hitDMG = localDirectElementDamage( ...
                    actionElement, scaleComponent, mv * dynamicMultiplier, build, teamContext, localEnemy, ...
                    extraBonus + localResolveEnemyAuraDamageBonus(enemyState, actionSpec), ...
                    effectiveCritRate, effectiveCritDMG, extraResShred);
                if abs(flatDirectBase) > 1e-9
                    hitDMG = hitDMG + localDirectElementDamage( ...
                        actionElement, 1, flatDirectBase, build, teamContext, localEnemy, ...
                        extraBonus + localResolveEnemyAuraDamageBonus(enemyState, actionSpec), ...
                        effectiveCritRate, effectiveCritDMG, extraResShred);
                end

                hitDescriptor = localBuildHitDescriptor( ...
                    actionSpec, actionElement, reactionElement, preferredAura, ...
                    actionReactionBonus, buildReactionBonus, atkValue, hpValue, defValue, emValue, ...
                    constellation, extraResShred);
                hitDescriptor.ApplyElement = applyElement;
                hitDescriptor.ApplyGauge = applyGauge;
                hitDescriptor.ApplyGaugeSource = applyGaugeSource;
                hitDescriptor.CanApplyAura = canApplyAura;
                hitDescriptor.StrikeType = string(getFieldOrDefault(icdSnapshot, 'StrikeType', ""));
                hitDescriptor.ICDGroup = string(getFieldOrDefault(icdSnapshot, 'ICDGroup', ""));
                hitDescriptor.ICDRule = string(getFieldOrDefault(icdSnapshot, 'ICDRule', ""));
                hitDescriptor.ICDSource = string(getFieldOrDefault(icdSnapshot, 'ICDSource', ""));
                if isstruct(attackMeta) && ~isempty(fieldnames(attackMeta))
                    hitDescriptor.LunarisDamageParam = string(getFieldOrDefault(attackMeta, 'DamageParam', ""));
                    hitDescriptor.LunarisAttackName = string(getFieldOrDefault(attackMeta, 'Name', ""));
                    auditLunarisDamageParam = string(getFieldOrDefault(attackMeta, 'DamageParam', ""));
                    auditLunarisAttackName = string(getFieldOrDefault(attackMeta, 'Name', ""));
                    if strlength(string(getFieldOrDefault(attackMeta, 'Element', ""))) > 0
                        hitDescriptor.ApplyElement = string(getFieldOrDefault(actionSpec, 'ApplyElement', applyElement));
                    end
                end
                if strcmpi(char(string(actionElement)), 'physical') || strcmpi(char(string(actionElement)), 'none')
                    hitDescriptor.CanApplyAura = logical(getFieldOrDefault(actionSpec, 'CanApplyAura', false)) && canApplyAura;
                end

                reactionResult = resolveReactionForHit( ...
                    enemyState, ...
                    hitDescriptor, ...
                    build, teamContext, localEnemy, hitDeltaTime);
                enemyState = reactionResult.EnemyState;

                hitDMG = hitDMG * reactionResult.AmplifyMultiplier;
                if reactionResult.CatalyzeFlatDamage > 0
                    hitDMG = hitDMG + localDirectElementDamage( ...
                        actionElement, 1, reactionResult.CatalyzeFlatDamage, build, teamContext, localEnemy, ...
                        extraBonus, effectiveCritRate, effectiveCritDMG, extraResShred);
                end
                hitDMG = hitDMG + reactionResult.ReactionDamage;
                if ~isempty(reactionResult.TriggeredReactions)
                    reactionTags = [reactionTags; reactionResult.TriggeredReactions(:)]; %#ok<AGROW>
                end
                [state, note] = localRunAfterHitHook( ...
                    spec, state, actionKey, actionSpec, hitIndex, reactionResult, note, struct( ...
                    'Character', string(characterName), ...
                    'Build', build, ...
                    'Enemy', localEnemy, ...
                    'TalentLevel', talentLevel, ...
                    'Constellation', constellation, ...
                    'TeamContext', teamContext, ...
                    'EnemyState', enemyState, ...
                    'ActionElement', actionElement, ...
                    'ReactionElement', reactionElement, ...
                    'HitDamage', hitDMG, ...
                    'HitDeltaTime', hitDeltaTime, ...
                    'ActionIndex', i, ...
                    'ActionToken', action));

                dmg = dmg + hitDMG;
            end

            if postActionDeltaTime > 1e-9
                [enemyState, timedPackets] = advanceEnemyStateTime( ...
                    enemyState, postActionDeltaTime, actionElement, teamContext);
                for packetIndex = 1:numel(timedPackets)
                    packet = timedPackets(packetIndex);
                    dmg = dmg + localResolveTimedPacketDamage(packet, build, teamContext, localEnemy, enemyState);
                    reactionTags = [reactionTags; lower(string(packet.ReactionName))]; %#ok<AGROW>
                end
            end

            reactionTags = unique(reactionTags(strlength(reactionTags) > 0), 'stable');
            for tagIndex = 1:numel(reactionTags)
                note = localAppendNote(note, reactionTags(tagIndex));
            end
            if hitCount > 1
                note = localAppendNote(note, "x" + string(hitCount));
            end

            [state, note] = localRunAfterActionHook( ...
                spec, state, actionKey, actionSpec, dmg, reactionTags, note, struct( ...
                'Character', string(characterName), ...
                'Build', build, ...
                'Enemy', localEnemy, ...
                'TalentLevel', talentLevel, ...
                'Constellation', constellation, ...
                'TeamContext', teamContext, ...
                'EnemyState', enemyState, ...
                'ActionIndex', i, ...
                'ActionToken', action, ...
                'ActionTime', actionTime));
            state = localApplyPostState(state, actionSpec, constellation);
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {action, dmg, note}]; %#ok<AGROW>
        auditRows = [auditRows; {action, actionKey, auditApplyGauge, auditApplyGaugeSource, ...
            auditICDRule, auditICDSource, auditLunarisAttackName, auditLunarisDamageParam, ...
            strcmpi(char(auditApplyGaugeSource), 'fallback'), ...
            strcmpi(char(auditICDSource), 'fallback')}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;
        state = localAdvanceSimpleState(state, actionTime);
        state = localRunAdvanceStateHook(spec, state, actionTime, struct( ...
            'Character', string(characterName), ...
            'Build', build, ...
            'Enemy', enemy, ...
            'TalentLevel', talentLevel, ...
            'Constellation', constellation, ...
            'TeamContext', teamContext, ...
            'EnemyState', enemyState, ...
            'ActionIndex', i, ...
            'ActionToken', action));
    end

    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    dps = totalDMG / rotationTime;

    if nargout > 4
        auditTable = table();
        if ~isempty(auditRows)
            auditTable = cell2table(auditRows, 'VariableNames', { ...
                'Action', 'ActionKey', 'ApplyGauge', 'ApplyGaugeSource', 'ICDRule', 'ICDSource', ...
                'LunarisAttackName', 'LunarisDamageParam', 'ApplyGaugeFallback', 'ICDFallback'});
        end
        audit = struct( ...
            'Character', string(characterName), ...
            'RotationFile', string(seqFile), ...
            'Rows', auditTable);
    else
        audit = struct();
    end
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

function state = localRunInitializeStateHook(spec, state, hookContext)
    fn = getFieldOrDefault(spec, 'InitializeStateFn', []);
    if isa(fn, 'function_handle')
        state = fn(state, hookContext);
    end
end

function [state, actionSpec, actionTime, note] = localRunBeforeActionHook( ...
        spec, state, actionKey, actionSpec, actionTime, note, hookContext)
    fn = getFieldOrDefault(spec, 'BeforeActionFn', []);
    if isa(fn, 'function_handle')
        [state, actionSpec, actionTime, note] = fn( ...
            state, string(actionKey), actionSpec, actionTime, note, hookContext);
    end
end

function [state, note] = localRunAfterHitHook( ...
        spec, state, actionKey, actionSpec, hitIndex, reactionResult, note, hookContext)
    fn = getFieldOrDefault(spec, 'AfterHitFn', []);
    if isa(fn, 'function_handle')
        [state, note] = fn( ...
            state, string(actionKey), actionSpec, hitIndex, reactionResult, note, hookContext);
    end
end

function [state, note] = localRunAfterActionHook( ...
        spec, state, actionKey, actionSpec, actionDamage, reactionTags, note, hookContext)
    fn = getFieldOrDefault(spec, 'AfterActionFn', []);
    if isa(fn, 'function_handle')
        [state, note] = fn( ...
            state, string(actionKey), actionSpec, actionDamage, reactionTags, note, hookContext);
    end
end

function state = localRunAdvanceStateHook(spec, state, actionTime, hookContext)
    fn = getFieldOrDefault(spec, 'AdvanceStateFn', []);
    if isa(fn, 'function_handle')
        state = fn(state, actionTime, hookContext);
    end
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

function damage = localResolveTimedPacketDamage(packet, build, teamContext, enemy, enemyState)
    reactionName = string(getFieldOrDefault(packet, 'ReactionName', ""));
    if strlength(reactionName) == 0
        damage = 0;
        return;
    end
    hitDescriptor = struct( ...
        'ReactionElement', string(getFieldOrDefault(packet, 'ReactionElement', localReactionElement(reactionName))), ...
        'ReactionCritRate', getFieldOrDefault(packet, 'CritRate', []), ...
        'ReactionCritDMG', getFieldOrDefault(packet, 'CritDMG', []), ...
        'ReactionEMOverride', getFieldOrDefault(packet, 'SourceEM', []), ...
        'ReactionResShredOverride', getFieldOrDefault(packet, 'SourceResShred', []), ...
        'UseReactionBonusSnapshot', logical(getFieldOrDefault(packet, 'UseSnapshot', false)));
    damage = localResolveTransformativeDamage( ...
        reactionName, build, teamContext, enemy, enemyState, 0, ...
        getFieldOrDefault(packet, 'ReactionBonus', 0), hitDescriptor);
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

function [hitTimeline, postActionDeltaTime] = localResolveHitTimeline(actionSpec, actionTime)
    hitCount = max(1, round(double(getFieldOrDefault(actionSpec, 'HitCount', 1))));
    hitTimeline = zeros(1, hitCount);
    postActionDeltaTime = 0;

    explicitTimeline = getFieldOrDefault(actionSpec, 'HitTimeline', []);
    if isnumeric(explicitTimeline) && ~isempty(explicitTimeline)
        hitTimeline = double(explicitTimeline(:).');
        hitTimeline = max(0, hitTimeline);
        if numel(hitTimeline) < hitCount
            hitTimeline(end + 1:hitCount) = 0; %#ok<AGROW>
        elseif numel(hitTimeline) > hitCount
            hitTimeline = hitTimeline(1:hitCount);
        end
        postActionDeltaTime = max(0, double(actionTime) - sum(hitTimeline));
        return;
    end

    hitIntervals = getFieldOrDefault(actionSpec, 'HitIntervals', []);
    if isnumeric(hitIntervals) && ~isempty(hitIntervals)
        hitIntervals = double(hitIntervals(:).');
        hitIntervals = max(0, hitIntervals);
        usableCount = min(numel(hitIntervals), hitCount - 1);
        if usableCount > 0
            hitTimeline(2:usableCount + 1) = hitIntervals(1:usableCount);
        end
        postActionDeltaTime = max(0, double(actionTime) - sum(hitTimeline));
        return;
    end

    perHitDeltaTime = double(actionTime) / hitCount;
    hitTimeline(:) = perHitDeltaTime;
    postActionDeltaTime = 0;
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

function level = localResolveConfiguredTalentLevel(actionSpec, talentLevel, constellation, talentGroup)
    level = localResolveTalentLevel(talentLevel, constellation, talentGroup);
    if isfield(actionSpec, 'TalentLevelOverride')
        override = getFieldOrDefault(actionSpec, 'TalentLevelOverride', level);
        if ~isempty(override) && isnumeric(override) && isscalar(override) && ~isnan(override)
            level = double(override);
        end
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
    if state.Stacks >= getFieldOrDefault(actionSpec, 'MinStacksMultiplierThreshold', 0)
        multiplier = multiplier + getFieldOrDefault(actionSpec, 'MinStacksMultiplierBonus', 0);
    end

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

function scaleComponent = localResolveScaleComponent( ...
        actionScalingMode, defaultScaleValue, atkValue, hpValue, defValue, emValue, ...
        actionSpec, state, constellation)
    atkValue = localResolveStateStatValue(atkValue, "ATK", actionSpec, state, constellation);
    hpValue = localResolveStateStatValue(hpValue, "HP", actionSpec, state, constellation);
    defValue = localResolveStateStatValue(defValue, "DEF", actionSpec, state, constellation);
    emValue = localResolveStateStatValue(emValue, "EM", actionSpec, state, constellation);

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

function value = localResolveStateStatValue(baseValue, statKey, actionSpec, state, constellation)
    statKey = upper(char(string(statKey)));
    bonus = getFieldOrDefault(actionSpec, sprintf('%sBonus', statKey), 0) ...
        + getFieldOrDefault(actionSpec, sprintf('PerStack%sBonus', statKey), 0) * state.Stacks ...
        + getFieldOrDefault(actionSpec, sprintf('PerMark%sBonus', statKey), 0) * state.Marks ...
        + getFieldOrDefault(actionSpec, sprintf('PerAux%sBonus', statKey), 0) * state.AuxCounter ...
        + getFieldOrDefault(actionSpec, sprintf('PerCustom%sBonus', statKey), 0) * state.CustomValue ...
        + getFieldOrDefault(actionSpec, sprintf('SkillWindow%sBonus', statKey), 0) * double(state.SkillActiveTime > 0) ...
        + getFieldOrDefault(actionSpec, sprintf('BurstWindow%sBonus', statKey), 0) * double(state.BurstActiveTime > 0) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, sprintf('C1%sBonus', statKey), 0), constellation, 1) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, sprintf('C2%sBonus', statKey), 0), constellation, 2) ...
        + localConstellationGate(getFieldOrDefault(actionSpec, sprintf('C6%sBonus', statKey), 0), constellation, 6);
    thresholdField = sprintf('MinStacks%sThreshold', statKey);
    bonusField = sprintf('MinStacks%sBonus', statKey);
    if state.Stacks >= getFieldOrDefault(actionSpec, thresholdField, 0)
        bonus = bonus + getFieldOrDefault(actionSpec, bonusField, 0);
    end
    value = baseValue * (1 + bonus);
    if strcmp(statKey, 'EM')
        value = value + getFieldOrDefault(state, 'TempEMBonus', 0);
    end
end

function flatDirectBase = localResolveFlatDirectBase(atkValue, hpValue, defValue, emValue, actionSpec, state, constellation)
    if nargin < 6 || isempty(state)
        state = struct();
    end
    if nargin < 7
        constellation = 0;
    end
    emValue = localResolveStateStatValue(emValue, "EM", actionSpec, state, constellation);
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
    if state.Stacks >= getFieldOrDefault(actionSpec, 'MinStacksDamageThreshold', 0)
        bonus = bonus + getFieldOrDefault(actionSpec, 'MinStacksDamageBonus', 0);
    end
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

function bonus = localResolveEnemyAuraDamageBonus(enemyState, actionSpec)
    bonus = 0;
    auraElement = string(getFieldOrDefault(actionSpec, 'EnemyAuraDamageBonusElement', ""));
    if strlength(auraElement) == 0
        return;
    end

    auras = getFieldOrDefault(enemyState, 'Auras', repmat(struct(), 1, 0));
    for i = 1:numel(auras)
        if strcmpi(char(string(getFieldOrDefault(auras(i), 'Element', ""))), char(auraElement)) ...
                && double(getFieldOrDefault(auras(i), 'Gauge', 0)) > 1e-6
            bonus = getFieldOrDefault(actionSpec, 'EnemyAuraDamageBonus', 0);
            return;
        end
    end
end

function hitDescriptor = localBuildHitDescriptor( ...
        actionSpec, actionElement, reactionElement, preferredAura, ...
        actionReactionBonus, buildReactionBonus, atkValue, hpValue, defValue, emValue, ...
        constellation, extraResShred)
    resolveReactionAsDamage = logical(getFieldOrDefault(actionSpec, 'ResolveReactionAsDamage', ...
        localShouldResolveReactionAsDamage(actionSpec)));
    hitDescriptor = struct( ...
        'HitElement', string(actionElement), ...
        'ApplyElement', string(getFieldOrDefault(actionSpec, 'ApplyElement', actionElement)), ...
        'ApplyGauge', getFieldOrDefault(actionSpec, 'ApplyGauge', 1.0), ...
        'CanApplyAura', logical(getFieldOrDefault(actionSpec, 'CanApplyAura', strlength(string(actionElement)) > 0)), ...
        'CanTriggerReaction', logical(getFieldOrDefault(actionSpec, 'CanTriggerReaction', true)), ...
        'AllowAmplify', logical(getFieldOrDefault(actionSpec, 'AllowAmplify', 0)), ...
        'AllowCatalyze', logical(getFieldOrDefault(actionSpec, 'AllowCatalyze', 0)), ...
        'AllowTransformative', logical(getFieldOrDefault(actionSpec, 'AllowTransformative', 0)), ...
        'PreferredAura', string(getFieldOrDefault(actionSpec, 'PreferredAmplifyAura', preferredAura)), ...
        'ForceReactionName', string(getFieldOrDefault(actionSpec, 'ForceReactionName', "")), ...
        'ReactionElement', string(getFieldOrDefault(actionSpec, 'ReactionElement', reactionElement)), ...
        'ReactionBonus', buildReactionBonus + actionReactionBonus, ...
        'ReactionBaseDamage', getFieldOrDefault(actionSpec, 'ReactionBaseDamage', 0), ...
        'ReactionATKWeight', getFieldOrDefault(actionSpec, 'ReactionATKWeight', 0), ...
        'ReactionHPWeight', getFieldOrDefault(actionSpec, 'ReactionHPWeight', 0), ...
        'ReactionDEFWeight', getFieldOrDefault(actionSpec, 'ReactionDEFWeight', 0), ...
        'ReactionEMWeight', getFieldOrDefault(actionSpec, 'ReactionEMWeight', 0), ...
        'ResolveReactionAsDamage', resolveReactionAsDamage, ...
        'ATKValue', atkValue, ...
        'HPValue', hpValue, ...
        'DEFValue', defValue, ...
        'EMValue', emValue, ...
        'ExtraResShred', extraResShred, ...
        'ReactionEMOverride', getFieldOrDefault(actionSpec, 'ReactionEMOverride', []), ...
        'ReactionResShredOverride', getFieldOrDefault(actionSpec, 'ReactionResShredOverride', []), ...
        'UseReactionBonusSnapshot', logical(getFieldOrDefault(actionSpec, 'UseReactionBonusSnapshot', false)));

    if isfield(actionSpec, 'ReactionCritRate') || isfield(actionSpec, 'ReactionCritDMG') ...
            || isfield(actionSpec, 'C1ReactionCritRate') || isfield(actionSpec, 'C2ReactionCritRate') ...
            || isfield(actionSpec, 'C6ReactionCritRate') || isfield(actionSpec, 'C1ReactionCritDMG') ...
            || isfield(actionSpec, 'C2ReactionCritDMG') || isfield(actionSpec, 'C6ReactionCritDMG')
        hitDescriptor.ReactionCritRate = getFieldOrDefault(actionSpec, 'ReactionCritRate', []) ...
            + localConstellationGate(getFieldOrDefault(actionSpec, 'C1ReactionCritRate', 0), constellation, 1) ...
            + localConstellationGate(getFieldOrDefault(actionSpec, 'C2ReactionCritRate', 0), constellation, 2) ...
            + localConstellationGate(getFieldOrDefault(actionSpec, 'C6ReactionCritRate', 0), constellation, 6);
        hitDescriptor.ReactionCritDMG = getFieldOrDefault(actionSpec, 'ReactionCritDMG', []) ...
            + localConstellationGate(getFieldOrDefault(actionSpec, 'C1ReactionCritDMG', 0), constellation, 1) ...
            + localConstellationGate(getFieldOrDefault(actionSpec, 'C2ReactionCritDMG', 0), constellation, 2) ...
            + localConstellationGate(getFieldOrDefault(actionSpec, 'C6ReactionCritDMG', 0), constellation, 6);
    end
end

function tf = localShouldResolveReactionAsDamage(actionSpec)
    if ~logical(getFieldOrDefault(actionSpec, 'AllowTransformative', 0))
        tf = false;
        return;
    end

    hasCustomReactionPayload = abs(getFieldOrDefault(actionSpec, 'ReactionBaseDamage', 0)) > 1e-9 ...
        || abs(getFieldOrDefault(actionSpec, 'ReactionATKWeight', 0)) > 1e-9 ...
        || abs(getFieldOrDefault(actionSpec, 'ReactionHPWeight', 0)) > 1e-9 ...
        || abs(getFieldOrDefault(actionSpec, 'ReactionDEFWeight', 0)) > 1e-9 ...
        || abs(getFieldOrDefault(actionSpec, 'ReactionEMWeight', 0)) > 1e-9;
    if ~hasCustomReactionPayload
        tf = false;
        return;
    end

    mvOverride = getFieldOrDefault(actionSpec, 'MVOverride', nan);
    tf = (isnumeric(mvOverride) && isscalar(mvOverride) && abs(mvOverride) <= 1e-9);
end

function attackMeta = localResolveLunarisAttackMetadata(characterName, actionSpec, actionKey, paramName, actionElement, attackMetadata)
    attackMeta = struct();
    if isempty(attackMetadata)
        return;
    end

    explicitDamageParam = string(getFieldOrDefault(actionSpec, 'LunarisDamageParam', ""));
    explicitAttackName = string(getFieldOrDefault(actionSpec, 'LunarisAttackName', ""));
    candidates = attackMetadata;

    if strlength(explicitDamageParam) > 0
        attackMeta = localFindAttackMetadata(candidates, explicitAttackName, explicitDamageParam, string(actionElement));
        if ~isempty(fieldnames(attackMeta))
            return;
        end
        attackMeta = localFindAttackMetadata(candidates, explicitAttackName, explicitDamageParam, "");
        if ~isempty(fieldnames(attackMeta))
            return;
        end
    end

    attackMeta = localFindAttackMetadata( ...
        candidates, string(actionKey), string(paramName), string(actionElement));
    if isempty(fieldnames(attackMeta))
        [aliasName, aliasParam] = localResolveAttackLookupAliases(actionKey, paramName, actionSpec);
        attackMeta = localFindAttackMetadata(candidates, aliasName, aliasParam, string(actionElement));
    end
    if isempty(fieldnames(attackMeta))
        attackMeta = localFindAttackMetadata(candidates, string(actionKey), string(paramName), "");
    end
    if isempty(fieldnames(attackMeta))
        [aliasName, aliasParam] = localResolveAttackLookupAliases(actionKey, paramName, actionSpec);
        attackMeta = localFindAttackMetadata(candidates, aliasName, aliasParam, "");
    end
    if isempty(fieldnames(attackMeta))
        [alternateNames, alternateParams] = localResolveSecondaryLookupAliases(actionKey, paramName, actionSpec);
        for idx = 1:numel(alternateNames)
            attackMeta = localFindAttackMetadata(candidates, alternateNames(idx), alternateParams(idx), string(actionElement));
            if ~isempty(fieldnames(attackMeta))
                break;
            end
            attackMeta = localFindAttackMetadata(candidates, alternateNames(idx), alternateParams(idx), "");
            if ~isempty(fieldnames(attackMeta))
                break;
            end
        end
    end
    if isempty(fieldnames(attackMeta)) && strlength(explicitAttackName) > 0
        attackMeta = localFindAttackMetadata(candidates, explicitAttackName, "", "");
    end
    if isempty(fieldnames(attackMeta))
        attackMeta = struct();
    end
end

function attackMeta = localFindAttackMetadata(candidates, attackName, damageParam, actionElement)
    attackMeta = struct();
    if isempty(candidates)
        return;
    end

    normalizedName = localNormalizeLookupToken(attackName);
    normalizedParam = localNormalizeLookupToken(damageParam);
    normalizedElement = localNormalizeLookupToken(actionElement);

    bestScore = -inf;
    bestIndex = 0;
    for i = 1:numel(candidates)
        score = 0;
        if strlength(normalizedParam) > 0
            if candidates(i).NormalizedDamageParam == normalizedParam
                score = score + 6;
            elseif candidates(i).NormalizedDamageParam == localStripReactionSuffix(normalizedParam)
                score = score + 5;
            end
        end
        if strlength(normalizedName) > 0
            if candidates(i).NormalizedName == normalizedName
                score = score + 4;
            elseif contains(candidates(i).NormalizedName, normalizedName) || contains(normalizedName, candidates(i).NormalizedName)
                score = score + 2;
            end
        end
        if strlength(normalizedElement) > 0 && strlength(candidates(i).Element) > 0
            if localNormalizeLookupToken(candidates(i).Element) == normalizedElement
                score = score + 1;
            end
        end

        if score > bestScore
            bestScore = score;
            bestIndex = i;
        end
    end

    if bestIndex > 0 && bestScore > 0
        attackMeta = candidates(bestIndex);
    end
end

function token = localStripReactionSuffix(token)
    token = string(token);
    token = regexprep(char(token), '(damage|dmg|hit|strike|art|attack|bullet|loop|loopdamage)$', '');
    token = string(token);
end

function [applyGauge, source] = localResolveActionApplyGauge(actionSpec, attackMeta)
    applyGauge = getFieldOrDefault(actionSpec, 'ApplyGauge', []);
    if ~isempty(applyGauge)
        applyGauge = double(applyGauge);
        source = "explicit";
        return;
    end

    if isstruct(attackMeta) && isfield(attackMeta, 'GaugeUnits')
        applyGauge = double(getFieldOrDefault(attackMeta, 'GaugeUnits', 0));
        source = "metadata";
        return;
    end

    applyGauge = 1.0;
    source = "fallback";
end

function tf = localIsElementalDamageElement(element)
    switch lower(char(string(element)))
        case {'pyro', 'hydro', 'cryo', 'electro', 'anemo', 'geo', 'dendro'}
            tf = true;
        otherwise
            tf = false;
    end
end

function [canApplyAura, icdStates, snapshot] = localResolveActionICDGate(icdStates, actionKey, actionSpec, attackMeta, deltaTime)
    snapshot = struct('ICDGroup', "", 'ICDRule', "", 'ICDHits', 1, 'ICDWindow', 0, 'StrikeType', "", 'ICDSource', "");
    canApplyAura = true;

    explicitICDRule = string(getFieldOrDefault(actionSpec, 'ICDRule', ""));
    if strlength(explicitICDRule) > 0
        snapshot.ICDRule = explicitICDRule;
        snapshot.ICDGroup = localResolveICDGroupKey(actionSpec, actionKey, struct());
        snapshot.StrikeType = string(getFieldOrDefault(actionSpec, 'StrikeType', ""));
        snapshot.ICDSource = "explicit";
        snapshotConfig = localParseExplicitICDRule(explicitICDRule);
        snapshot.ICDHits = getFieldOrDefault(snapshotConfig, 'Hits', 1);
        snapshot.ICDWindow = getFieldOrDefault(snapshotConfig, 'Window', 0);
        if double(getFieldOrDefault(actionSpec, 'ApplyGauge', 1.0)) <= 0
            canApplyAura = false;
            return;
        end
        if strcmpi(char(string(getFieldOrDefault(snapshotConfig, 'Kind', "Independent"))), 'Independent') ...
                || strlength(snapshot.ICDGroup) == 0
            return;
        end

        fieldName = matlab.lang.makeValidName(char(snapshot.ICDGroup));
        if ~isfield(icdStates, fieldName)
            icdStates.(fieldName) = struct( ...
                'HitsSinceApply', max(0, double(snapshot.ICDHits) - 1), ...
                'Elapsed', max(0, double(snapshot.ICDWindow)), ...
                'HitsThreshold', max(1, double(snapshot.ICDHits)), ...
                'Window', max(0, double(snapshot.ICDWindow)));
        end

        state = icdStates.(fieldName);
        state.Elapsed = state.Elapsed + max(0, double(deltaTime));
        if state.HitsThreshold <= 1 && state.Window > 0
            canApplyAura = state.Elapsed >= state.Window;
            if canApplyAura
                state.Elapsed = 0;
            end
            icdStates.(fieldName) = state;
            return;
        end
        if state.Window > 0 && state.Elapsed >= state.Window
            state.HitsSinceApply = max(0, state.HitsThreshold - 1);
            state.Elapsed = 0;
        end

        if state.HitsSinceApply >= max(0, state.HitsThreshold - 1)
            canApplyAura = true;
            state.HitsSinceApply = 0;
            state.Elapsed = 0;
        else
            canApplyAura = false;
            state.HitsSinceApply = state.HitsSinceApply + 1;
        end

        icdStates.(fieldName) = state;
        return;
    end

    if ~isstruct(attackMeta) || isempty(fieldnames(attackMeta))
        return;
    end

    snapshot.ICDRule = string(getFieldOrDefault(attackMeta, 'ICDRule', ""));
    snapshot.ICDGroup = localResolveICDGroupKey(actionSpec, actionKey, attackMeta);
    snapshot.ICDHits = getFieldOrDefault(attackMeta.ICDConfig, 'Hits', 1);
    snapshot.ICDWindow = getFieldOrDefault(attackMeta.ICDConfig, 'Window', 0);
    snapshot.StrikeType = string(getFieldOrDefault(attackMeta, 'StrikeType', ""));
    if strlength(snapshot.ICDRule) > 0
        snapshot.ICDSource = "metadata";
    else
        snapshot.ICDSource = "fallback";
    end

    if isfield(attackMeta, 'GaugeUnits')
        if double(getFieldOrDefault(attackMeta, 'GaugeUnits', 0)) <= 0
            canApplyAura = false;
            return;
        end
    end

    if ~isfield(attackMeta, 'ICDConfig')
        snapshot.ICDSource = "fallback";
        return;
    end

    ruleKind = string(getFieldOrDefault(attackMeta.ICDConfig, 'Kind', "Independent"));
    if strcmpi(char(ruleKind), 'Independent')
        snapshot.ICDSource = "metadata";
        return;
    end

    if strlength(snapshot.ICDGroup) == 0
        snapshot.ICDSource = "fallback";
        return;
    end

    fieldName = matlab.lang.makeValidName(char(snapshot.ICDGroup));
    if ~isfield(icdStates, fieldName)
        icdStates.(fieldName) = struct( ...
            'HitsSinceApply', max(0, double(snapshot.ICDHits) - 1), ...
            'Elapsed', max(0, double(snapshot.ICDWindow)), ...
            'HitsThreshold', max(1, double(snapshot.ICDHits)), ...
            'Window', max(0, double(snapshot.ICDWindow)));
    end

    state = icdStates.(fieldName);
    state.Elapsed = state.Elapsed + max(0, double(deltaTime));
    if state.HitsThreshold <= 1 && state.Window > 0
        canApplyAura = state.Elapsed >= state.Window;
        if canApplyAura
            state.Elapsed = 0;
        end
        icdStates.(fieldName) = state;
        return;
    end
    if state.Window > 0 && state.Elapsed >= state.Window
        state.HitsSinceApply = max(0, state.HitsThreshold - 1);
        state.Elapsed = 0;
    end

    if state.HitsSinceApply >= max(0, state.HitsThreshold - 1)
        canApplyAura = true;
        state.HitsSinceApply = 0;
        state.Elapsed = 0;
    else
        canApplyAura = false;
        state.HitsSinceApply = state.HitsSinceApply + 1;
    end

    icdStates.(fieldName) = state;
end

function groupKey = localResolveICDGroupKey(actionSpec, actionKey, attackMeta)
    explicitGroup = string(getFieldOrDefault(actionSpec, 'ICDGroup', ""));
    if strlength(explicitGroup) > 0
        groupKey = explicitGroup;
        return;
    end

    if isstruct(attackMeta) && isfield(attackMeta, 'NormalizedICDSource') && strlength(string(attackMeta.NormalizedICDSource)) > 0
        groupKey = string(attackMeta.NormalizedICDSource);
        return;
    end
    if isstruct(attackMeta) && isfield(attackMeta, 'NormalizedName') && strlength(string(attackMeta.NormalizedName)) > 0
        groupKey = string(attackMeta.NormalizedName);
        return;
    end
    groupKey = string(actionKey);
end

function [aliasName, aliasParam] = localResolveAttackLookupAliases(actionKey, paramName, actionSpec)
    aliasName = string(actionKey);
    aliasParam = string(paramName);

    key = lower(char(string(actionKey)));
    switch key
        case 'n1'
            aliasName = "Attack01";
        case 'n2'
            aliasName = "Attack02";
        case 'n3'
            aliasName = "Attack03";
        case 'n4'
            aliasName = "Attack04";
        case 'n5'
            aliasName = "Attack05";
        case 'n6'
            aliasName = "Attack06";
        case {'ca', 'charge', 'charged'}
            aliasName = "ChargedAttack";
        case {'plunge', 'plunging'}
            aliasName = "FallingAnthem";
    end

    if strlength(string(getFieldOrDefault(actionSpec, 'LunarisAttackName', ""))) > 0
        aliasName = string(getFieldOrDefault(actionSpec, 'LunarisAttackName', ""));
    end

    aliasParam = localResolveDamageParamAlias(aliasParam, actionSpec);
end

function [aliasNames, aliasParams] = localResolveSecondaryLookupAliases(actionKey, paramName, actionSpec)
    aliasNames = strings(0, 1);
    aliasParams = strings(0, 1);

    explicitAttackName = string(getFieldOrDefault(actionSpec, 'LunarisAttackName', ""));
    explicitDamageParam = string(getFieldOrDefault(actionSpec, 'LunarisDamageParam', ""));
    baseParam = string(paramName);
    key = lower(char(string(actionKey)));

    if strlength(explicitAttackName) > 0 && strlength(baseParam) > 0
        aliasNames(end + 1, 1) = explicitAttackName; %#ok<AGROW>
        aliasParams(end + 1, 1) = baseParam; %#ok<AGROW>
    end

    if strlength(explicitDamageParam) > 0
        aliasNames(end + 1, 1) = string(actionKey); %#ok<AGROW>
        aliasParams(end + 1, 1) = explicitDamageParam; %#ok<AGROW>
    end

    switch key
        case {'charged', 'ca'}
            aliasNames(end + 1, 1) = "ChargedAttack"; %#ok<AGROW>
            aliasParams(end + 1, 1) = "ChargedAttackDMG"; %#ok<AGROW>
            aliasNames(end + 1, 1) = "AimShot"; %#ok<AGROW>
            aliasParams(end + 1, 1) = "AimedShot"; %#ok<AGROW>
        case {'e', 'e2'}
            aliasNames(end + 1, 1) = "ElementalArt"; %#ok<AGROW>
            aliasParams(end + 1, 1) = baseParam; %#ok<AGROW>
        case {'q', 'qloop'}
            aliasNames(end + 1, 1) = "ElementalBurst"; %#ok<AGROW>
            aliasParams(end + 1, 1) = baseParam; %#ok<AGROW>
        case {'plunge', 'plunging'}
            aliasNames(end + 1, 1) = "FallingAnthem"; %#ok<AGROW>
            aliasParams(end + 1, 1) = baseParam; %#ok<AGROW>
    end
end

function aliasParam = localResolveDamageParamAlias(paramName, actionSpec)
    aliasParam = string(paramName);
    if strlength(string(getFieldOrDefault(actionSpec, 'LunarisDamageParam', ""))) > 0
        aliasParam = string(getFieldOrDefault(actionSpec, 'LunarisDamageParam', ""));
        return;
    end

    token = lower(char(string(paramName)));
    switch token
        case 'x1hitdmg'
            aliasParam = "NormalAttack_01_Damage";
        case 'x2hitdmg'
            aliasParam = "NormalAttack_02_Damage";
        case 'x3hitdmg'
            aliasParam = "NormalAttack_03_Damage";
        case 'x4hitdmg'
            aliasParam = "NormalAttack_04_Damage";
        case 'x5hitdmg'
            aliasParam = "NormalAttack_05_Damage";
        case 'x6hitdmg'
            aliasParam = "NormalAttack_06_Damage";
        case {'chargedattackdmg', 'chargedattack'}
            aliasParam = "ChargedAttackDMG";
    end
end

function config = localParseExplicitICDRule(ruleText)
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
