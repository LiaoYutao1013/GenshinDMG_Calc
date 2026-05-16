function [totalDMG, dps, breakdown, rotationTime] = simulateColumbinaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Columbina simulator rewritten to match the project's unified entry.
    % The model keeps three independent damage channels:
    % 1. normal / charged / burst direct hydro damage,
    % 2. MoonCont sustained follow-up hits,
    % 3. lunar-reaction follow-up hits that consume teamContext bonuses.
    %
    % The legacy implementation used a different argument order
    %   (build, enemy, talentLevel, constellation, seqFile).
    % To avoid breaking old analysis scripts, this version detects that
    % layout and transparently remaps the inputs.
    if nargin >= 3 && (isnumeric(seqFile) || islogical(seqFile))
        legacyTalentLevel = seqFile;
        legacyConstellation = 0;
        legacySeqFile = [];
        if nargin >= 4
            legacyConstellation = talentLevel;
        end
        if nargin >= 5
            legacySeqFile = constellation;
        end
        talentLevel = legacyTalentLevel;
        constellation = legacyConstellation;
        seqFile = legacySeqFile;
    end

    thisFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(thisFolder, '..', '..', 'data', 'Columbina');

    if nargin < 3 || isempty(seqFile)
        seqFile = localResolveExistingFile(dataFolder, {'rotation_Columbina.txt', 'sequence_Columbina.txt'});
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct( ...
            'Name', 'Columbina', ...
            'Constellation', constellation, ...
            'TalentLevel', talentLevel, ...
            'Build', build)}, 20, struct());
    end

    basePath = localResolveExistingFile(dataFolder, {'characters_Columbina.csv', 'characters_哥伦比娅.csv'});
    base = readtable(basePath);
    talent = readtable(fullfile(dataFolder, 'talents_Columbina.csv'));
    actions = localResolveRotation(seqFile);

    maxHP = base.BaseHP(1) * (1 + getFieldOrDefault(build, 'HPBonus', 0)) + getFieldOrDefault(build, 'FlatHP', 5000);
    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    critRate = min(1, max(0, getFieldOrDefault(build, 'CritRate', 0)));
    critDMG = max(0, getFieldOrDefault(build, 'CritDMG', 0));
    hydroResShred = getFieldOrDefault(build, 'ResShred', 0) + getFieldOrDefault(teamContext, 'HydroResShred', 0);
    enemyState = getFieldOrDefault(teamContext, 'EnemyState', createEnemyState(enemy, teamContext, "Hydro"));

    state = struct( ...
        'SkillFieldTime', 0, ...
        'BurstTime', 0, ...
        'EnemyState', enemyState);

    totalDMG = 0;
    rotationTime = 0;
    breakdown = table('Size', [0 3], 'VariableTypes', {'string', 'double', 'string'}, ...
        'VariableNames', {'Action', 'Damage', 'Note'});

    normalLevel = talentLevel;
    skillLevel = localSkillTalentLevel(talentLevel, constellation);
    burstLevel = localBurstTalentLevel(talentLevel, constellation);

    for i = 1:numel(actions)
        actionToken = string(actions{i});
        actionKey = upper(char(actionToken));
        actionTime = localActionTime(actionKey);
        dmg = 0;
        note = "";
        advanceAfterAction = true;

        switch actionKey
            case {'E1', 'N1', 'A'}
                [dmg, state.EnemyState, reactionName] = localApplyHydroHit( ...
                    state.EnemyState, maxHP, localLevelValue(talent, 1, normalLevel), ...
                    build, teamContext, enemy, hydroResShred, em, ...
                    localHydroDamageBonus(build, teamContext, getFieldOrDefault(build, 'NormalDMGBonus', 0), constellation), ...
                    critRate, critDMG, 1.0, 0);
                note = localMergeReactionNote("一段直伤", reactionName);

            case {'E2', 'N2'}
                [dmg, state.EnemyState, reactionName] = localApplyHydroHit( ...
                    state.EnemyState, maxHP, localLevelValue(talent, 2, normalLevel), ...
                    build, teamContext, enemy, hydroResShred, em, ...
                    localHydroDamageBonus(build, teamContext, getFieldOrDefault(build, 'NormalDMGBonus', 0), constellation), ...
                    critRate, critDMG, 1.0, 0);
                note = localMergeReactionNote("二段直伤", reactionName);

            case {'E3', 'N3', 'SA3'}
                [dmg, state.EnemyState, reactionName] = localApplyHydroHit( ...
                    state.EnemyState, maxHP, localLevelValue(talent, 3, normalLevel), ...
                    build, teamContext, enemy, hydroResShred, em, ...
                    localHydroDamageBonus(build, teamContext, getFieldOrDefault(build, 'NormalDMGBonus', 0), constellation), ...
                    critRate, critDMG, 1.0, 0);
                note = localMergeReactionNote("三段 / 终结直伤", reactionName);

            case {'HEAVY', 'CA'}
                chargedBonus = max(getFieldOrDefault(build, 'ChargedDMGBonus', 0), getFieldOrDefault(build, 'ChargeDMGBonus', 0));
                [dmg, state.EnemyState, reactionName] = localApplyHydroHit( ...
                    state.EnemyState, maxHP, localLevelValue(talent, 4, normalLevel), ...
                    build, teamContext, enemy, hydroResShred, em, ...
                    localHydroDamageBonus(build, teamContext, chargedBonus, constellation), ...
                    critRate, critDMG, 1.2, 0);
                note = localMergeReactionNote("重击", reactionName);

            case {'PLUNGE'}
                plungeBonus = getFieldOrDefault(build, 'PlungeDMGBonus', 0) + getFieldOrDefault(teamContext, 'PlungeDMGBonus', 0);
                [dmg, state.EnemyState, reactionName] = localApplyHydroHit( ...
                    state.EnemyState, maxHP, localLevelValue(talent, 8, normalLevel), ...
                    build, teamContext, enemy, hydroResShred, em, ...
                    localHydroDamageBonus(build, teamContext, plungeBonus, constellation), ...
                    min(1, critRate + getFieldOrDefault(teamContext, 'PlungeCritRateBonus', 0)), critDMG, 1.5, 0);
                note = localMergeReactionNote("下落", reactionName);

            case {'E', 'SKILL'}
                [dmg, state.EnemyState, reactionName] = localApplyHydroHit( ...
                    state.EnemyState, maxHP, localLevelValue(talent, 9, skillLevel), ...
                    build, teamContext, enemy, hydroResShred, em, ...
                    localHydroDamageBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0), constellation), ...
                    critRate, critDMG, 1.0, 0);
                state.SkillFieldTime = max(state.SkillFieldTime, 10.0);
                note = localMergeReactionNote("战技施放", reactionName);

            case {'MOONCONT', 'SUMMON'}
                state.SkillFieldTime = max(state.SkillFieldTime, 10.0);
                [dmg, state.EnemyState, reactionCount] = localResolveMoonCont( ...
                    state.EnemyState, maxHP, talent, skillLevel, build, teamContext, enemy, hydroResShred, em, critRate, critDMG, constellation);
                note = sprintf('战技持续段 40 tick，触发增幅反应 %d 次', reactionCount);
                actionTime = 10.0;
                advanceAfterAction = false;

            case {'Q', 'BURST'}
                [dmg, state.EnemyState, reactionName] = localApplyHydroHit( ...
                    state.EnemyState, maxHP, localLevelValue(talent, 17, burstLevel), ...
                    build, teamContext, enemy, hydroResShred, em, ...
                    localHydroDamageBonus(build, teamContext, getFieldOrDefault(build, 'BurstDMGBonus', 0), constellation), ...
                    critRate, critDMG, 1.0, 0);
                state.BurstTime = max(state.BurstTime, 12.0);
                burstReactionBonus = localLevelValue(talent, 18, burstLevel);
                note = localMergeReactionNote(sprintf('爆发开启，月感反应额外增伤 %.0f%%', 100 * burstReactionBonus), reactionName);

            case {'MOONBLOOM', 'MOONCHARGED', 'MOONCRYSTALLIZE', 'INTERFERE', 'LUNARBLOOM', 'LUNARCHARGED', 'LUNARCRYSTALLIZE'}
                [reactionLabel, rowIndex, bonusField] = localResolveLunarReaction(actionKey, teamContext);
                if rowIndex <= 0
                    note = "当前配队未启用可用的月感反应";
                else
                    [dmg, state.EnemyState] = localResolveLunarField( ...
                        state.EnemyState, maxHP, talent, rowIndex, skillLevel, burstLevel, build, teamContext, enemy, hydroResShred, em, state, constellation);
                    note = sprintf('%s 16 tick', reactionLabel);
                    actionTime = 8.0;
                    advanceAfterAction = false;
                end

            otherwise
                note = "未识别动作";
        end

        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {actionToken, dmg, note}]; %#ok<AGROW>
        rotationTime = rotationTime + actionTime;

        if advanceAfterAction
            state.EnemyState = advanceEnemyStateTime(state.EnemyState, actionTime, "Hydro", teamContext);
        end
        state = localAdvanceState(state, actionTime);
    end

    if rotationTime <= 0
        rotationTime = getFieldOrDefault(teamContext, 'RotationDuration', 20);
    end
    dps = totalDMG / rotationTime;
end

function [dmg, enemyState, reactionName] = localApplyHydroHit(enemyState, maxHP, mv, build, teamContext, enemy, hydroResShred, em, dmgBonusMult, critRate, critDMG, gaugeUnits, reactionBonus)
    baseDMG = maxHP * mv * dmgBonusMult ...
        * calcExpectedCritMultiplier(critRate, critDMG) ...
        * calcDamageMultiplier(90, enemy, hydroResShred);
    [reactionMultiplier, enemyState, reaction] = getAmplifyingReactionMultiplier( ...
        enemyState, "Hydro", em, teamContext, gaugeUnits, 0, reactionBonus);
    dmg = baseDMG * reactionMultiplier;
    reactionName = reaction.Name;
end

function [totalDMG, enemyState, reactionCount] = localResolveMoonCont(enemyState, maxHP, talent, skillLevel, build, teamContext, enemy, hydroResShred, em, critRate, critDMG, constellation)
    totalDMG = 0;
    reactionCount = 0;

    [castDMG, enemyState, reactionName] = localApplyHydroHit( ...
        enemyState, maxHP, localLevelValue(talent, 9, skillLevel), ...
        build, teamContext, enemy, hydroResShred, em, ...
        localHydroDamageBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0), constellation), ...
        critRate, critDMG, 1.0, 0);
    totalDMG = totalDMG + castDMG;
    reactionCount = reactionCount + double(reactionName ~= "");

    tickMV = localLevelValue(talent, 10, skillLevel);
    for tickIndex = 1:40
        enemyState = advanceEnemyStateTime(enemyState, 0.25, "Hydro", teamContext);
        [tickDMG, enemyState, reactionName] = localApplyHydroHit( ...
            enemyState, maxHP, tickMV, build, teamContext, enemy, hydroResShred, em, ...
            localHydroDamageBonus(build, teamContext, getFieldOrDefault(build, 'SkillDMGBonus', 0), constellation), ...
            critRate, critDMG, 0.5, 0);
        totalDMG = totalDMG + tickDMG;
        reactionCount = reactionCount + double(reactionName ~= "");
    end
end

function [totalDMG, enemyState] = localResolveLunarField(enemyState, maxHP, talent, rowIndex, skillLevel, burstLevel, build, teamContext, enemy, hydroResShred, em, state, constellation)
    totalDMG = 0;
    bonusField = localLunarBonusField(rowIndex);
    reactionBonus = 1 ...
        + getFieldOrDefault(build, 'ReactionDMGBonus', 0) ...
        + getFieldOrDefault(build, 'Set4_MoonPromote', 0) ...
        + getFieldOrDefault(build, 'Set4_InterfereBonus', 0) ...
        + getFieldOrDefault(build, bonusField, 0) ...
        + getFieldOrDefault(teamContext, bonusField, 0);

    if state.BurstTime > 0
        reactionBonus = reactionBonus + localLevelValue(talent, 18, burstLevel);
    end
    if constellation >= 2
        reactionBonus = reactionBonus + 0.15;
    end
    if constellation >= 4
        reactionBonus = reactionBonus + 0.10;
    end
    if state.SkillFieldTime > 0
        reactionBonus = reactionBonus + 0.05;
    end

    reactionCritRate = getFieldOrDefault(teamContext, 'ReactionCritRate', 0);
    reactionCritDMG = getFieldOrDefault(teamContext, 'ReactionCritDMG', 0);
    if reactionCritRate <= 0 && reactionCritDMG <= 0
        reactionCritRate = 0.10;
        reactionCritDMG = 0.20;
    end
    if constellation >= 6
        reactionCritRate = reactionCritRate + 0.10;
        reactionCritDMG = reactionCritDMG + 0.30;
    end

    tickBase = maxHP * localLevelValue(talent, rowIndex, skillLevel);
    for tickIndex = 1:16
        enemyState = advanceEnemyStateTime(enemyState, 0.50, "Hydro", teamContext);
        totalDMG = totalDMG + calcReactionDamage( ...
            tickBase, em, enemy, hydroResShred, reactionBonus, reactionCritRate, reactionCritDMG);
    end
end

function bonusMult = localHydroDamageBonus(build, teamContext, extraBonus, constellation)
    totalBonus = getFieldOrDefault(build, 'HydroDMGBonus', 0) ...
        + getFieldOrDefault(teamContext, 'AllDMGBonus', 0) ...
        + getFieldOrDefault(build, 'PromoteBonus', 0) ...
        + getFieldOrDefault(build, 'TeamHPAbove50Mult', 0) ...
        + extraBonus;

    if constellation >= 1
        totalBonus = totalBonus + 0.03;
    end
    if constellation >= 4
        totalBonus = totalBonus + 0.125;
    end
    bonusMult = 1 + totalBonus;
end

function [reactionLabel, rowIndex, bonusField] = localResolveLunarReaction(actionKey, teamContext)
    reactionLabel = "";
    rowIndex = 0;
    bonusField = "";

    switch actionKey
        case {'MOONCHARGED', 'LUNARCHARGED'}
            reactionLabel = "月感电";
            rowIndex = 11;
            bonusField = "LunarChargedBonus";
        case {'MOONCRYSTALLIZE', 'LUNARCRYSTALLIZE'}
            reactionLabel = "月结晶";
            rowIndex = 13;
            bonusField = "LunarCrystallizeBonus";
        case {'MOONBLOOM', 'LUNARBLOOM'}
            reactionLabel = "月绽放";
            rowIndex = 12;
            bonusField = "LunarBloomBonus";
        otherwise
            preferred = string(getFieldOrDefault(teamContext, 'DominantLunarReaction', ""));
            switch lower(char(preferred))
                case 'lunarcharged'
                    reactionLabel = "月感电";
                    rowIndex = 11;
                    bonusField = "LunarChargedBonus";
                case 'lunarcrystallize'
                    reactionLabel = "月结晶";
                    rowIndex = 13;
                    bonusField = "LunarCrystallizeBonus";
                case 'lunarbloom'
                    reactionLabel = "月绽放";
                    rowIndex = 12;
                    bonusField = "LunarBloomBonus";
            end
    end

    if rowIndex == 0
        if getFieldOrDefault(teamContext, 'LunarBloomEnabled', false)
            reactionLabel = "月绽放";
            rowIndex = 12;
            bonusField = "LunarBloomBonus";
        elseif getFieldOrDefault(teamContext, 'LunarChargedEnabled', false)
            reactionLabel = "月感电";
            rowIndex = 11;
            bonusField = "LunarChargedBonus";
        elseif getFieldOrDefault(teamContext, 'LunarCrystallizeEnabled', false)
            reactionLabel = "月结晶";
            rowIndex = 13;
            bonusField = "LunarCrystallizeBonus";
        end
    end
end

function bonusField = localLunarBonusField(rowIndex)
    switch rowIndex
        case 11
            bonusField = "LunarChargedBonus";
        case 13
            bonusField = "LunarCrystallizeBonus";
        otherwise
            bonusField = "LunarBloomBonus";
    end
end

function state = localAdvanceState(state, deltaTime)
    state.SkillFieldTime = max(0, state.SkillFieldTime - deltaTime);
    state.BurstTime = max(0, state.BurstTime - deltaTime);
end

function actions = localResolveRotation(seqFile)
    actions = {};
    if ~isempty(seqFile) && isfile(seqFile)
        actions = readRotationTokens(seqFile);
    end
    if isempty(actions)
        actions = {'E1', 'E2', 'E3', 'SA3', 'Heavy', 'MoonCont', 'Q', 'MoonBloom'};
        return;
    end

    if numel(actions) == 1 && strcmpi(actions{1}, 'AUTO')
        actions = {'E1', 'E2', 'E3', 'SA3', 'Heavy', 'MoonCont', 'Q', 'MoonBloom'};
    end
end

function level = localSkillTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 3);
end

function level = localBurstTalentLevel(talentLevel, constellation)
    level = talentLevel + 3 * double(constellation >= 5);
end

function actionTime = localActionTime(actionKey)
    switch upper(char(string(actionKey)))
        case {'E1', 'N1', 'A'}
            actionTime = 0.45;
        case {'E2', 'N2'}
            actionTime = 0.52;
        case {'E3', 'N3', 'SA3'}
            actionTime = 0.72;
        case {'HEAVY', 'CA'}
            actionTime = 0.95;
        case {'PLUNGE'}
            actionTime = 0.85;
        case {'E', 'SKILL'}
            actionTime = 0.70;
        case {'MOONCONT', 'SUMMON'}
            actionTime = 10.0;
        case {'Q', 'BURST'}
            actionTime = 1.30;
        case {'MOONBLOOM', 'MOONCHARGED', 'MOONCRYSTALLIZE', 'INTERFERE', 'LUNARBLOOM', 'LUNARCHARGED', 'LUNARCRYSTALLIZE'}
            actionTime = 8.0;
        otherwise
            actionTime = 0.60;
    end
end

function note = localMergeReactionNote(baseNote, reactionName)
    if strlength(string(reactionName)) == 0
        note = string(baseNote);
    else
        note = sprintf('%s, %s', char(string(baseNote)), lower(char(string(reactionName))));
    end
end

function value = localLevelValue(talentTable, rowIndex, talentLevel)
    if rowIndex < 1 || rowIndex > height(talentTable)
        error('Invalid Columbina talent row index: %d', rowIndex);
    end

    targetLevel = min(max(round(talentLevel), 1), 15);
    value = NaN;
    for level = targetLevel:-1:1
        levelName = sprintf('Level%d', level);
        if ismember(levelName, talentTable.Properties.VariableNames)
            candidate = talentTable.(levelName)(rowIndex);
            if ~isnan(candidate)
                value = candidate;
                return;
            end
        end
    end

    error('No numeric Columbina talent value found for row %d.', rowIndex);
end

function filePath = localResolveExistingFile(folderPath, candidateNames)
    filePath = "";
    for i = 1:numel(candidateNames)
        currentPath = fullfile(folderPath, candidateNames{i});
        if isfile(currentPath)
            filePath = currentPath;
            return;
        end
    end
    error('Required Columbina data file is missing under %s.', folderPath);
end
