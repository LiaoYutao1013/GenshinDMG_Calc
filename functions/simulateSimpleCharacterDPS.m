function [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        characterName, build, enemy, seqFile, talentLevel, constellation, teamContext, spec)
    % Shared simulator for newly imported characters before they receive
    % bespoke high-detail modeling. It keeps the project's unified entry,
    % constellation switch, reaction support, and rotation-file workflow.
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
    actions = readRotationTokens(seqFile);

    scalingMode = lower(char(string(getFieldOrDefault(spec, 'ScalingMode', "ATK"))));
    element = string(getFieldOrDefault(spec, 'Element', getCharacterElement(characterName)));
    preferredAura = string(getFieldOrDefault(spec, 'PreferredAmplifyAura', ""));
    defaultDamageField = string(getFieldOrDefault(spec, 'DefaultDamageField', "SkillDMGBonus"));
    reactionBonusField = string(getFieldOrDefault(spec, 'ReactionBonusField', "ReactionDMGBonus"));

    [scaleValue, critRate, critDMG] = localResolveCoreStats(base, build, teamContext, scalingMode);
    baseCritRate = critRate;
    baseCritDMG = critDMG;
    enemyState = getFieldOrDefault(teamContext, 'EnemyState', createEnemyState(enemy, teamContext, element));

    state = struct( ...
        'SkillActiveTime', 0, ...
        'BurstActiveTime', 0, ...
        'Stacks', 0, ...
        'Marks', 0, ...
        'AuxCounter', 0);

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
            level = localResolveTalentLevel(talentLevel, constellation, string(getFieldOrDefault(actionSpec, 'TalentGroup', "Normal")));
            mv = getTalentValue(talent, char(string(getFieldOrDefault(actionSpec, 'TalentGroup', "Normal"))), ...
                char(string(getFieldOrDefault(actionSpec, 'Param', actionKey))), level);

            effectiveCritRate = min(1, baseCritRate + getFieldOrDefault(actionSpec, 'CritRateBonus', 0) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1CritRateBonus', 0), constellation, 1) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2CritRateBonus', 0), constellation, 2) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6CritRateBonus', 0), constellation, 6));
            effectiveCritDMG = baseCritDMG + getFieldOrDefault(actionSpec, 'CritDMGBonus', 0) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1CritDMGBonus', 0), constellation, 1) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2CritDMGBonus', 0), constellation, 2) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6CritDMGBonus', 0), constellation, 6);

            dynamicMultiplier = localResolveDynamicMultiplier(state, actionSpec, constellation);
            extraBonus = getFieldOrDefault(build, char(string(getFieldOrDefault(actionSpec, 'DamageField', defaultDamageField))), 0) ...
                + getFieldOrDefault(actionSpec, 'FlatDamageBonus', 0) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C1DamageBonus', 0), constellation, 1) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C2DamageBonus', 0), constellation, 2) ...
                + localConstellationGate(getFieldOrDefault(actionSpec, 'C6DamageBonus', 0), constellation, 6);

            baseDMG = localDirectElementDamage( ...
                element, scaleValue, mv * dynamicMultiplier, build, teamContext, enemy, extraBonus, effectiveCritRate, effectiveCritDMG);

            if logical(getFieldOrDefault(actionSpec, 'AllowAmplify', 0))
                reactionBonus = getFieldOrDefault(build, char(reactionBonusField), 0) ...
                    + getFieldOrDefault(actionSpec, 'ReactionBonus', 0);
                [reactionMult, enemyState, reaction] = localResolveAmplify(enemyState, element, preferredAura, build, teamContext, reactionBonus);
                dmg = baseDMG * reactionMult;
                if reaction.Name ~= ""
                    note = localAppendNote(note, lower(char(reaction.Name)));
                end
            else
                dmg = baseDMG;
            end

            if logical(getFieldOrDefault(actionSpec, 'AllowTransformative', 0))
                reactionBase = getFieldOrDefault(actionSpec, 'ReactionBaseDamage', 0);
                if reactionBase > 0
                    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
                    resShred = localElementResShred(element, build, teamContext);
                    transformativeDMG = calcReactionDamage( ...
                        reactionBase, em, enemy, resShred, ...
                        1 + getFieldOrDefault(build, char(reactionBonusField), 0) + getFieldOrDefault(actionSpec, 'ReactionBonus', 0), ...
                        [], []);
                    dmg = dmg + transformativeDMG;
                    note = localAppendNote(note, "reaction bonus");
                end
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

function [scaleValue, critRate, critDMG] = localResolveCoreStats(base, build, teamContext, scalingMode)
    switch scalingMode
        case 'hp'
            scaleValue = base.BaseHP(1) * (1 + getFieldOrDefault(build, 'HPBonus', 0)) + getFieldOrDefault(build, 'FlatHP', 0);
        case 'def'
            scaleValue = base.BaseDEF(1) * (1 + getFieldOrDefault(build, 'DEFBonus', 0)) + getFieldOrDefault(build, 'FlatDEF', 0);
        otherwise
            scaleValue = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
                * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
                + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    end

    critRate = getFieldOrDefault(build, 'CritRate', 0);
    critDMG = getFieldOrDefault(build, 'CritDMG', 0);
end

function damage = localDirectElementDamage(element, scaleValue, mv, build, teamContext, enemy, extraBonus, critRate, critDMG)
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    dmgBonus = 1 + localBuildElementBonus(element, build) + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
    resShred = localElementResShred(element, build, teamContext);
    damage = scaleValue * mv * dmgBonus * critMult * calcDamageMultiplier(90, enemy, resShred);
end

function bonus = localBuildElementBonus(element, build)
    switch lower(char(string(element)))
        case 'pyro'
            bonus = getFieldOrDefault(build, 'PyroDMGBonus', 0);
        case 'hydro'
            bonus = getFieldOrDefault(build, 'HydroDMGBonus', 0);
        case 'cryo'
            bonus = getFieldOrDefault(build, 'CryoDMGBonus', 0);
        case 'electro'
            bonus = getFieldOrDefault(build, 'ElectroDMGBonus', 0);
        case 'anemo'
            bonus = getFieldOrDefault(build, 'AnemoDMGBonus', 0);
        case 'geo'
            bonus = getFieldOrDefault(build, 'GeoDMGBonus', 0);
        case 'dendro'
            bonus = getFieldOrDefault(build, 'DendroDMGBonus', 0);
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
        case 'geo'
            resShred = resShred + getFieldOrDefault(teamContext, 'GeoResShred', 0);
        case 'dendro'
            resShred = resShred + getFieldOrDefault(teamContext, 'DendroResShred', 0);
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

function actionTime = localResolveActionTime(action, spec)
    timeMap = getFieldOrDefault(spec, 'ActionTimeMap', struct());
    key = matlab.lang.makeValidName(char(string(action)));
    if isstruct(timeMap) && isfield(timeMap, key)
        actionTime = timeMap.(key);
    else
        actionTime = getFieldOrDefault(spec, 'DefaultActionTime', 0.8);
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
    stateFields = {'SkillActiveTime', 'BurstActiveTime', 'Stacks', 'Marks', 'AuxCounter'};
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
