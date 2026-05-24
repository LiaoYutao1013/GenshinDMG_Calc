function [totalDMG, dps, breakdown, rotationTime, audit] = simulateNicoleDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Nicole 高精度近似模拟器。
    % 建模重点：
    % 1. 战技的护盾、Grace / Guidance 攻击加成与专武触发；
    % 2. 爆发的 4 次 3 秒间隔 Arcane Projection；
    % 3. Hexerei: Secret Rite、C1 / C4 / C6 与对应投影元素；
    % 4. 单人入口下剥离 teamContext 中为“团队近似”预先注入的 Nicole 自身增益，
    %    避免 Nicole 自己的模拟出现双重计算。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Nicole', 'rotation_Nicole.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext) || ~isfield(teamContext, 'NicoleProjectionOwnerElement')
        teamContext = buildTeamContext({struct('Name', 'Nicole', 'Constellation', constellation, 'TalentLevel', talentLevel, 'Build', build)}, 20, struct());
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Nicole');
    base = readtable(fullfile(dataFolder, 'characters_Nicole.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Nicole.csv'));
    actions = localResolveRotation(seqFile);

    localTeamContext = localRemoveNicoleSharedApprox(teamContext);
    atk = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(localTeamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(localTeamContext, 'FlatATK', 0);
    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(localTeamContext, 'EMBonus', 0);
    critRate = min(1, getFieldOrDefault(build, 'CritRate', 0));
    critDMG = getFieldOrDefault(build, 'CritDMG', 0);
    skillLevel = localSkillTalentLevel(talentLevel, constellation);
    burstLevel = localBurstTalentLevel(talentLevel, constellation);

    state = struct( ...
        'ShieldTime', 0, ...
        'ShieldValue', 0, ...
        'GraceTime', 0, ...
        'GraceFlatATK', 0, ...
        'GuidanceTime', 0, ...
        'GuidanceFlatATK', 0, ...
        'BurstTime', 0, ...
        'ProjectionCount', 0, ...
        'WeaponBuffTime', 0, ...
        'PathfinderTime', 0, ...
        'PathfinderHitsRemaining', 0, ...
        'EnergyRefundReady', 0, ...
        'ProjectionOwnerName', string(getFieldOrDefault(localTeamContext, 'NicoleProjectionOwnerName', "Nicole")), ...
        'ProjectionOwnerElement', string(getFieldOrDefault(localTeamContext, 'NicoleProjectionOwnerElement', "Pyro")), ...
        'ProjectionOwnerIsHexerei', getFieldOrDefault(localTeamContext, 'NicoleProjectionOwnerIsHexerei', false));

    totalDMG = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    for i = 1:numel(actions)
        action = actions{i};
        actionTime = localActionTime(action);
        dmg = 0;
        note = "";
        extraRows = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
            'VariableNames', {'Action', 'Damage', 'Note'});

        currentATK = atk + state.GraceFlatATK + state.GuidanceFlatATK * double(state.GuidanceTime > 0);
        currentDefIgnore = 0;
        if state.GuidanceTime > 0 && constellation >= 6
            currentDefIgnore = getTalentValue(talent, 'Constellation', 'C6DefIgnore', burstLevel);
        end
        currentWeaponBonus = getFieldOrDefault(localTeamContext, 'NicoleWeaponActiveDMGBonus', 0) ...
            * double(state.WeaponBuffTime > 0);

        switch action
            case 'E'
                castMV = getTalentValue(talent, 'Skill', 'CastATK', skillLevel);
                dmg = localElementDamage("Pyro", currentATK, castMV, build, localTeamContext, enemy, ...
                    getFieldOrDefault(build, 'SkillDMGBonus', 0), critRate, critDMG, currentDefIgnore);

                shieldRatio = getTalentValue(talent, 'Skill', 'ShieldATKRatio', skillLevel);
                shieldFlat = getTalentValue(talent, 'Skill', 'ShieldFlat', skillLevel);
                state.ShieldValue = currentATK * shieldRatio + shieldFlat;
                state.ShieldTime = getTalentValue(talent, 'Skill', 'ShieldDuration', skillLevel);
                state.GraceTime = getTalentValue(talent, 'Skill', 'GraceDuration', skillLevel);
                state.GraceFlatATK = min( ...
                    getTalentValue(talent, 'Skill', 'GraceATKCap', skillLevel), ...
                    currentATK * getTalentValue(talent, 'Skill', 'GraceATKRatio', skillLevel)) ...
                    + 300 * double(constellation >= 2);
                state.GuidanceTime = state.GraceTime;
                state.GuidanceFlatATK = getTalentValue(talent, 'Passive', 'GuidanceFlatATK', skillLevel);
                state.WeaponBuffTime = state.GraceTime;
                state.EnergyRefundReady = max(state.EnergyRefundReady, 14.0);
                if constellation >= 4
                    state.PathfinderTime = getTalentValue(talent, 'Constellation', 'C4PathfinderDuration', skillLevel);
                    state.PathfinderHitsRemaining = getTalentValue(talent, 'Constellation', 'C4PathfinderMaxHits', skillLevel);
                end
                note = sprintf('Shield=%.0f, Grace+Guidance active, weapon buff %.1fs', ...
                    state.ShieldValue, state.WeaponBuffTime);

            case 'Q'
                burstMV = getTalentValue(talent, 'Burst', 'CastATK', burstLevel);
                [pathfinderFlat, state] = localConsumePathfinderFlat(state, localTeamContext);
                dmg = localElementDamageWithFlat("Pyro", currentATK, burstMV, pathfinderFlat, build, localTeamContext, enemy, ...
                    getFieldOrDefault(build, 'BurstDMGBonus', 0) + currentWeaponBonus, critRate, critDMG, currentDefIgnore);
                state.BurstTime = getTalentValue(talent, 'Burst', 'ProjectionDuration', burstLevel);
                state.ProjectionCount = 0;
                note = sprintf('Silent Contemplation active, owner=%s/%s', ...
                    state.ProjectionOwnerName, state.ProjectionOwnerElement);
                if pathfinderFlat > 0
                    note = note + " + C4";
                end

            case 'Projection'
                if state.BurstTime > 0 && state.ProjectionCount < getTalentValue(talent, 'Burst', 'ProjectionCount', burstLevel)
                    state.ProjectionCount = state.ProjectionCount + 1;
                    [projectionDMG, projectionNote] = localProjectionDamage( ...
                        currentATK, build, localTeamContext, enemy, burstLevel, currentDefIgnore, state);
                    dmg = dmg + projectionDMG;
                    note = sprintf('Projection #%d, %s', state.ProjectionCount, projectionNote);
                else
                    note = "Projection inactive";
                end

            case 'Unity'
                if constellation >= 1 && state.BurstTime > 0
                    unityMV = getTalentValue(talent, 'Constellation', 'C1UnityATK', burstLevel);
                    [ownerATK, ownerBonus, ownerResShred, ownerCritRate, ownerCritDMG] = ...
                        localProjectionOwnerStats(currentATK, build, localTeamContext);
                    dmg = localOwnerElementDamage(state.ProjectionOwnerElement, ownerATK, unityMV, enemy, ...
                        ownerBonus, ownerResShred, ownerCritRate, ownerCritDMG, currentDefIgnore);
                    note = sprintf('Unity trigger, owner=%s', state.ProjectionOwnerName);
                else
                    note = "Unity unavailable";
                end

            case {'NA1', 'NA2', 'NA3', 'CA'}
                [dmg, state, note, extraRows] = localResolveNicoleAttack( ...
                    action, currentATK, build, localTeamContext, enemy, talent, skillLevel, currentDefIgnore, ...
                    critRate, critDMG, currentWeaponBonus, state, extraRows);

            otherwise
                note = "Unknown action";
        end

        totalDMG = totalDMG + dmg;
        if ~isempty(extraRows)
            breakdown = [breakdown; extraRows]; %#ok<AGROW>
        end
        breakdown = [breakdown; {string(action), dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;
        state = localAdvanceState(state, actionTime);
    end

    if state.ShieldValue > 0
        breakdown = [breakdown; {string("Shield"), state.ShieldValue, "Shield snapshot"}]; %#ok<AGROW>
    end

    if rotationTime <= 0
        rotationTime = getFieldOrDefault(localTeamContext, 'RotationDuration', 20);
    end
    dps = totalDMG / rotationTime;

    if nargout > 4
        audit = buildInferredReactionAudit( ...
            struct('Name', "Nicole", 'Constellation', constellation, 'TalentLevel', talentLevel), ...
            actions, localTeamContext, seqFile, struct(), struct('PrimaryArchetype', "Support"));
    else
        audit = struct();
    end
end

function actions = localResolveRotation(seqFile)
    rawTokens = readRotationTokens(seqFile);
    if isempty(rawTokens)
        rawTokens = {'AUTO'};
    end

    if numel(rawTokens) == 1 && strcmpi(rawTokens{1}, 'AUTO')
        tokens = {'E', 'Q', 'Projection', 'Unity', 'Projection', 'Projection', 'Unity', 'Projection'};
    else
        tokens = rawTokens;
    end
    actions = tokens;
end

function teamContext = localRemoveNicoleSharedApprox(teamContext)
    teamContext.AllDMGBonus = getFieldOrDefault(teamContext, 'AllDMGBonus', 0) ...
        - getFieldOrDefault(teamContext, 'NicoleApproxSharedAllDMGBonus', 0);
    teamContext.FlatATK = getFieldOrDefault(teamContext, 'FlatATK', 0) ...
        - getFieldOrDefault(teamContext, 'NicoleApproxSharedFlatATK', 0);
    teamContext.PyroResShred = getFieldOrDefault(teamContext, 'PyroResShred', 0) ...
        - getFieldOrDefault(teamContext, 'NicoleApproxSharedPyroResShred', 0);
    teamContext.HydroResShred = getFieldOrDefault(teamContext, 'HydroResShred', 0) ...
        - getFieldOrDefault(teamContext, 'NicoleApproxSharedHydroResShred', 0);
    teamContext.CryoResShred = getFieldOrDefault(teamContext, 'CryoResShred', 0) ...
        - getFieldOrDefault(teamContext, 'NicoleApproxSharedCryoResShred', 0);
    teamContext.ElectroResShred = getFieldOrDefault(teamContext, 'ElectroResShred', 0) ...
        - getFieldOrDefault(teamContext, 'NicoleApproxSharedElectroResShred', 0);
    teamContext.DendroResShred = getFieldOrDefault(teamContext, 'DendroResShred', 0) ...
        - getFieldOrDefault(teamContext, 'NicoleApproxSharedDendroResShred', 0);
    teamContext.GeoResShred = getFieldOrDefault(teamContext, 'GeoResShred', 0) ...
        - getFieldOrDefault(teamContext, 'NicoleApproxSharedGeoResShred', 0);
end

function level = localSkillTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 3);
end

function level = localBurstTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 5);
end

function [dmg, note] = localProjectionDamage(nicoleATK, build, teamContext, enemy, burstLevel, defIgnore, state)
    [ownerATK, ownerBonus, ownerResShred, ownerCritRate, ownerCritDMG] = ...
        localProjectionOwnerStats(nicoleATK, build, teamContext);
    projectionMV = getFieldOrDefault(teamContext, 'NicoleProjectionMultiplier', 0);
    if projectionMV <= 0
        projectionMV = 1.8;
    end
    dmg = localOwnerElementDamage(state.ProjectionOwnerElement, ownerATK, projectionMV, enemy, ...
        ownerBonus, ownerResShred, ownerCritRate, ownerCritDMG, defIgnore);

    if state.ProjectionOwnerIsHexerei && getFieldOrDefault(teamContext, 'NicoleHexereiProjectionFlatBase', 0) > 0
        hexereiFlatDMG = getFieldOrDefault(teamContext, 'NicoleHexereiProjectionFlatBase', 0);
        dmg = dmg + hexereiFlatDMG;
        note = sprintf('owner=%s, Hexerei bonus', state.ProjectionOwnerName);
    else
        note = sprintf('owner=%s', state.ProjectionOwnerName);
    end

    if state.ProjectionCount >= getFieldOrDefault(teamContext, 'NicoleProjectionMaxCount', 4)
        note = note + ", last trigger";
    end
end

function [ownerATK, dmgBonus, resShred, critRate, critDMG] = localProjectionOwnerStats(nicoleATK, build, teamContext)
    ownerConfig = getFieldOrDefault(teamContext, 'NicoleProjectionOwnerConfig', struct());
    ownerBuild = getFieldOrDefault(ownerConfig, 'Build', struct());
    ownerElement = string(getFieldOrDefault(teamContext, 'NicoleProjectionOwnerElement', "Pyro"));

    if isfield(ownerConfig, 'Name') && string(ownerConfig.Name) == "Nicole"
        ownerATK = nicoleATK;
        critRate = getFieldOrDefault(build, 'CritRate', 0);
        critDMG = getFieldOrDefault(build, 'CritDMG', 0);
        dmgBonus = getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + ...
            localElementBonusValue(ownerElement, build) + getFieldOrDefault(teamContext, 'NicoleWeaponActiveDMGBonus', 0);
        resShred = localElementResShred(ownerElement, build, teamContext);
        return;
    end

    fallbackBaseATK = localFallbackBaseATK(ownerConfig);
    ownerATK = (fallbackBaseATK + getFieldOrDefault(ownerBuild, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(ownerBuild, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(ownerBuild, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    critRate = getFieldOrDefault(ownerBuild, 'CritRate', getFieldOrDefault(build, 'CritRate', 0));
    critDMG = getFieldOrDefault(ownerBuild, 'CritDMG', getFieldOrDefault(build, 'CritDMG', 0));
    dmgBonus = getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + localElementBonusValue(ownerElement, ownerBuild);
    if getFieldOrDefault(teamContext, 'NicoleWeaponActiveDMGBonus', 0) > 0
        dmgBonus = dmgBonus + getFieldOrDefault(teamContext, 'NicoleWeaponActiveDMGBonus', 0);
    end
    resShred = localElementResShred(ownerElement, ownerBuild, teamContext);
end

function baseATK = localFallbackBaseATK(ownerConfig)
    resolvedATK = localResolveOwnerBaseATKFromData(ownerConfig);
    if resolvedATK > 0
        baseATK = resolvedATK;
        return;
    end

    name = lower(char(string(getFieldOrDefault(ownerConfig, 'Name', ""))));
    switch name
        case 'nicole'
            baseATK = 342;
        case 'furina'
            baseATK = 244;
        case 'neuvillette'
            baseATK = 208;
        case 'citlali'
            baseATK = 127;
        case 'skirk'
            baseATK = 359;
        case 'escoffier'
            baseATK = 332;
        otherwise
            baseATK = 300;
    end
end

function baseATK = localResolveOwnerBaseATKFromData(ownerConfig)
    baseATK = 0;
    ownerName = string(getFieldOrDefault(ownerConfig, 'Name', ""));
    if strlength(ownerName) == 0
        return;
    end

    filePath = resolveCharacterDataFile(ownerName, 'characters');
    if strlength(filePath) == 0 || exist(char(filePath), 'file') ~= 2
        return;
    end

    try
        tbl = readtable(char(filePath), 'TextType', 'string');
    catch
        return;
    end
    baseATK = double(getFieldOrDefault(tbl, 'BaseATK', 0));
end

function [dmg, state, note, extraRows] = localResolveNicoleAttack(action, atk, build, teamContext, enemy, talent, skillLevel, defIgnore, critRate, critDMG, currentWeaponBonus, state, extraRows)
    switch action
        case 'NA1'
            mv = getTalentValue(talent, 'Normal', 'NA1ATK', skillLevel);
            actionBonus = getFieldOrDefault(build, 'NormalDMGBonus', 0);
        case 'NA2'
            mv = getTalentValue(talent, 'Normal', 'NA2ATK', skillLevel);
            actionBonus = getFieldOrDefault(build, 'NormalDMGBonus', 0);
        case 'NA3'
            mv = getTalentValue(talent, 'Normal', 'NA3ATK', skillLevel);
            actionBonus = getFieldOrDefault(build, 'NormalDMGBonus', 0);
        otherwise
            mv = getTalentValue(talent, 'Normal', 'ChargedATK', skillLevel);
            actionBonus = getFieldOrDefault(build, 'NormalDMGBonus', 0);
    end

    [pathfinderFlat, state] = localConsumePathfinderFlat(state, teamContext);
    dmg = localElementDamageWithFlat("Pyro", atk, mv, pathfinderFlat, build, teamContext, enemy, ...
        actionBonus + currentWeaponBonus, critRate, critDMG, defIgnore);
    note = char(action);
    if pathfinderFlat > 0
        extraRows = [extraRows; {string(action + "C4"), pathfinderFlat, "Pathfinder's Blessing"}]; %#ok<AGROW>
        note = note + " + C4";
    end
end

function dmg = localElementDamage(element, atk, mv, build, teamContext, enemy, extraBonus, critRate, critDMG, extraDefIgnore)
    dmg = localElementDamageWithFlat(element, atk, mv, 0, build, teamContext, enemy, extraBonus, critRate, critDMG, extraDefIgnore);
end

function dmg = localElementDamageWithFlat(element, atk, mv, flatBase, build, teamContext, enemy, extraBonus, critRate, critDMG, extraDefIgnore)
    localEnemy = enemy;
    localEnemy.DefIgnore = getFieldOrDefault(enemy, 'DefIgnore', 0) + extraDefIgnore;
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    dmgBonus = 1 + localElementBonusValue(element, build) + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + extraBonus;
    resShred = localElementResShred(element, build, teamContext);
    dmg = (atk * mv + flatBase) * dmgBonus * critMult * calcDamageMultiplier(90, localEnemy, resShred);
end

function dmg = localOwnerElementDamage(element, atk, mv, enemy, dmgBonus, resShred, critRate, critDMG, extraDefIgnore)
    localEnemy = enemy;
    localEnemy.DefIgnore = getFieldOrDefault(enemy, 'DefIgnore', 0) + extraDefIgnore;
    critMult = calcExpectedCritMultiplier(critRate, critDMG);
    dmg = atk * mv * (1 + dmgBonus) * critMult * calcDamageMultiplier(90, localEnemy, resShred);
end

function bonus = localElementBonusValue(element, build)
    pyroFallback = getFieldOrDefault(build, 'PyroDMGBonus', 0);
    switch lower(char(element))
        case 'pyro'
            bonus = getFieldOrDefault(build, 'PyroDMGBonus', pyroFallback);
        case 'hydro'
            bonus = getFieldOrDefault(build, 'HydroDMGBonus', pyroFallback);
        case 'cryo'
            bonus = getFieldOrDefault(build, 'CryoDMGBonus', pyroFallback);
        case 'electro'
            bonus = getFieldOrDefault(build, 'ElectroDMGBonus', pyroFallback);
        case 'anemo'
            bonus = getFieldOrDefault(build, 'AnemoDMGBonus', pyroFallback);
        case 'geo'
            bonus = getFieldOrDefault(build, 'GeoDMGBonus', pyroFallback);
        case 'dendro'
            bonus = getFieldOrDefault(build, 'DendroDMGBonus', pyroFallback);
        otherwise
            bonus = pyroFallback;
    end
end

function resShred = localElementResShred(element, build, teamContext)
    resShred = getFieldOrDefault(build, 'ResShred', 0);
    switch lower(char(element))
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

function state = localAdvanceState(state, actionTime)
    state.ShieldTime = max(0, state.ShieldTime - actionTime);
    state.GraceTime = max(0, state.GraceTime - actionTime);
    state.GuidanceTime = max(0, state.GuidanceTime - actionTime);
    state.BurstTime = max(0, state.BurstTime - actionTime);
    state.WeaponBuffTime = max(0, state.WeaponBuffTime - actionTime);
    state.PathfinderTime = max(0, state.PathfinderTime - actionTime);
    state.EnergyRefundReady = max(0, state.EnergyRefundReady - actionTime);
    if state.GraceTime <= 0
        state.GraceFlatATK = 0;
        state.GuidanceTime = 0;
        state.GuidanceFlatATK = 0;
    end
    if state.PathfinderTime <= 0
        state.PathfinderHitsRemaining = 0;
    end
    if state.BurstTime <= 0
        state.ProjectionCount = 0;
    end
end

function [flatDamage, state] = localConsumePathfinderFlat(state, teamContext)
    flatDamage = 0;
    if state.PathfinderTime > 0 && state.PathfinderHitsRemaining > 0
        flatDamage = getFieldOrDefault(teamContext, 'NicolePathfinderFlatDamage', 0);
        if flatDamage > 0
            state.PathfinderHitsRemaining = state.PathfinderHitsRemaining - 1;
        end
    end
end

function actionTime = localActionTime(action)
    switch action
        case 'E'
            actionTime = 0.70;
        case 'Q'
            actionTime = 1.15;
        case 'Projection'
            actionTime = 3.00;
        case 'Unity'
            actionTime = 0.10;
        case {'NA1', 'NA2', 'NA3'}
            actionTime = 0.55;
        case 'CA'
            actionTime = 0.85;
        otherwise
            actionTime = 0.50;
    end
end
