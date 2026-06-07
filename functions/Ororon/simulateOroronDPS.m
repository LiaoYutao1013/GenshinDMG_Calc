function [totalDMG, dps, breakdown, rotationTime, audit] = simulateOroronDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Ororon high-detail simulator.
    % Focus:
    % - target-aware Spirit Orb bounce count.
    % - burst pulse cadence with C4 faster-rotation handling.
    % - A1 Hypersense proc estimation from team timeline signals with
    %   archetype fallback when no team timeline is available.
    % - constellation-aware Nighttide, Spiritual Supersense, and C6 echo damage.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Ororon', 'rotation_Ororon.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Ororon', 'Constellation', constellation, 'Build', build)}, 20, struct(), enemy);
    end

    aggravateReady = getFieldOrDefault(teamContext, 'DendroCount', 0) >= 1;
    electroChargedReady = logical(getFieldOrDefault(teamContext, 'ElectroChargedReady', false) ...
        || getFieldOrDefault(teamContext, 'LunarChargedEnabled', false));
    natlanSupportReady = localCountNightsoulAllies(teamContext) >= 1;
    electroReactionReady = aggravateReady || electroChargedReady || natlanSupportReady ...
        || getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1 ...
        || getFieldOrDefault(teamContext, 'CryoCount', 0) >= 1;

    % Ororon is one of the characters whose C3 / C5 talent upgrades are reversed
    % relative to the most common pattern.
    skillLevel = localClampTalentLevel(talentLevel + 3 * double(constellation >= 5));
    burstLevel = localClampTalentLevel(talentLevel + 3 * double(constellation >= 3));

    enemyTargetCount = max(1, round(getFieldOrDefault(enemy, 'TargetCount', ...
        getFieldOrDefault(enemy, 'EnemyCount', 1))));
    spiritOrbHitCount = min(enemyTargetCount, 4 + 2 * double(constellation >= 1));
    bounceHitCount = max(0, spiritOrbHitCount - 1);
    bounceTimeline = 0.18 * ones(1, bounceHitCount);

    waveTimeline = localBuildWaveTimeline(constellation);
    waveHitCount = numel(waveTimeline);
    c2ElectroBonus = localResolveC2ElectroBonus(constellation, enemyTargetCount);

    hypersenseProcCount = localEstimateHypersenseProcCount( ...
        teamContext, electroChargedReady, natlanSupportReady, enemyTargetCount);
    hypersenseTargetCount = min(4, enemyTargetCount);
    [hypersenseHitCount, hypersenseTimeline] = localBuildTriggeredHitTimeline( ...
        hypersenseProcCount, hypersenseTargetCount, 1.80, 0.60);
    c6EchoTargetCount = min(4, enemyTargetCount);

    c1NighttideBonus = 0.50 * double(constellation >= 1);
    hypersenseActive = hypersenseProcCount > 0;

    actions = struct();
    actions.E = struct( ...
        'TalentGroup', "Skill", ...
        'TalentLevelOverride', skillLevel, ...
        'Param', "SpiritOrbDMG", ...
        'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", ...
        'BaseMultiplier', 1.00, ...
        'AllowCatalyze', double(aggravateReady), ...
        'AllowTransformative', double(electroReactionReady), ...
        'ApplyGauge', 1.0, ...
        'ICDRule', "Standard (3h/2.5s)", ...
        'PostSetSkillActiveTime', 15.0, ...
        'LunarisAttackName', "Bullet_ElementalArt", ...
        'LunarisDamageParam', "ElementalArt_Damage", ...
        'Note', "Night's Sling");
    actions.Bounce = struct( ...
        'TalentGroup', "Skill", ...
        'TalentLevelOverride', skillLevel, ...
        'Param', "SpiritOrbDMG", ...
        'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", ...
        'BaseMultiplier', 1.00, ...
        'HitCount', max(1, bounceHitCount), ...
        'HitTimeline', bounceTimeline, ...
        'AllowCatalyze', double(aggravateReady), ...
        'AllowTransformative', double(electroReactionReady), ...
        'ApplyGauge', 1.0, ...
        'ICDGroup', "Ororon_SpiritOrb", ...
        'ICDRule', "Standard (3h/2.5s)", ...
        'LunarisAttackName', "Bullet_ElementalArt", ...
        'LunarisDamageParam', "ElementalArt_Damage", ...
        'Note', "Spirit Orb bounces");
    actions.Q = struct( ...
        'TalentGroup', "Burst", ...
        'TalentLevelOverride', burstLevel, ...
        'Param', "RitualDMG", ...
        'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Electro", ...
        'BaseMultiplier', 1.00, ...
        'AllowCatalyze', double(aggravateReady), ...
        'AllowTransformative', double(electroReactionReady), ...
        'ApplyGauge', 1.0, ...
        'ICDRule', "Independent", ...
        'PostSetBurstActiveTime', 9.0, ...
        'LunarisAttackName', "ElementalBurst", ...
        'LunarisDamageParam', "ElementalBurst_ReleaseDamage", ...
        'Note', "Dark Voices Echo");
    actions.Wave = struct( ...
        'TalentGroup', "Burst", ...
        'TalentLevelOverride', burstLevel, ...
        'Param', "SoundwaveCollisionDMG", ...
        'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Electro", ...
        'BaseMultiplier', 1.00, ...
        'HitCount', waveHitCount, ...
        'HitTimeline', waveTimeline, ...
        'AllowCatalyze', double(aggravateReady), ...
        'AllowTransformative', double(electroReactionReady), ...
        'ApplyGauge', 1.0, ...
        'ICDGroup', "Ororon_Oculus", ...
        'ICDRule', "7 hits / 3s", ...
        'BaseActionDamageBonus', c2ElectroBonus, ...
        'LunarisAttackName', localWaveAttackName(constellation), ...
        'LunarisDamageParam', "ElementalBurst_RotateDamage|ElementalBurst_RotateDamage|Nyx_BurstAdd|MUL|NyxValue_BurstCache|MUL|ADD", ...
        'Note', "Supersonic Oculus pulses");
    actions.Hypersense = struct( ...
        'TalentGroup', "Skill", ...
        'TalentLevelOverride', skillLevel, ...
        'Param', "SpiritOrbDMG", ...
        'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", ...
        'MVOverride', 0, ...
        'FlatDirectATKWeight', 1.60 * double(hypersenseActive), ...
        'HitCount', max(1, hypersenseHitCount), ...
        'HitTimeline', hypersenseTimeline, ...
        'AllowCatalyze', double(aggravateReady && hypersenseActive), ...
        'AllowTransformative', double(electroReactionReady && hypersenseActive), ...
        'ApplyGauge', double(hypersenseActive), ...
        'ICDGroup', "Ororon_Hypersense", ...
        'ICDRule', "Standard (3h/2.5s)", ...
        'BaseActionDamageBonus', c2ElectroBonus, ...
        'LunarisAttackName', "NyxState", ...
        'LunarisDamageParam', "Damage_ExpendNyx", ...
        'Note', localBuildHypersenseNote(hypersenseProcCount));
    actions.C6Echo = struct( ...
        'TalentGroup', "Skill", ...
        'TalentLevelOverride', skillLevel, ...
        'Param', "SpiritOrbDMG", ...
        'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", ...
        'MVOverride', 0, ...
        'FlatDirectATKWeight', 3.20, ...
        'HitCount', max(1, c6EchoTargetCount), ...
        'HitTimeline', zeros(1, max(1, c6EchoTargetCount)), ...
        'AllowCatalyze', double(aggravateReady), ...
        'AllowTransformative', double(electroReactionReady), ...
        'ApplyGauge', 1.0, ...
        'ICDGroup', "Ororon_Hypersense", ...
        'ICDRule', "Standard (3h/2.5s)", ...
        'BaseActionDamageBonus', c2ElectroBonus, ...
        'LunarisAttackName', "Constellation_AttackUp", ...
        'LunarisDamageParam', "Damage_Constellation6|Damage_ExpendNyx|MUL", ...
        'Note', "C6 burst-triggered Hypersense");

    defaultRotation = {'E'};
    if bounceHitCount > 0
        defaultRotation{end + 1} = 'Bounce'; %#ok<AGROW>
    end
    defaultRotation{end + 1} = 'Q'; %#ok<AGROW>
    if constellation >= 6
        defaultRotation{end + 1} = 'C6Echo'; %#ok<AGROW>
    end
    defaultRotation{end + 1} = 'Wave'; %#ok<AGROW>
    if hypersenseProcCount > 0
        defaultRotation{end + 1} = 'Hypersense'; %#ok<AGROW>
    end

    spec = struct( ...
        'Element', "Electro", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.8, ...
        'InitializeStateFn', @localInitializeState, ...
        'BeforeActionFn', @localBeforeAction, ...
        'AfterHitFn', @localAfterHit, ...
        'AdvanceStateFn', @localAdvanceState, ...
        'DefaultRotation', {defaultRotation}, ...
        'ActionTimeMap', struct( ...
            'E', 0.60, ...
            'Bounce', max(0.20, sum(bounceTimeline)), ...
            'Q', 0.95, ...
            'Wave', 9.0, ...
            'Hypersense', 0.20, ...
            'C6Echo', 0.20), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS( ...
        'Ororon', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

function attackName = localWaveAttackName(constellation)
    if constellation >= 4
        attackName = "SkillObj_ElementalBurst_Rotate_Constellation";
    else
        attackName = "SkillObj_ElementalBurst_Rotate";
    end
end

function bonus = localResolveC2ElectroBonus(constellation, enemyTargetCount)
    if constellation < 2
        bonus = 0;
        return;
    end
    bonus = min(0.32, 0.08 * max(1, min(enemyTargetCount, 4)));
end

function waveTimeline = localBuildWaveTimeline(constellation)
    if constellation >= 4
        waveTimeline = [0.60, 1.20 * ones(1, 7)];
    else
        waveTimeline = 1.50 * ones(1, 6);
    end
end

function [hitCount, timeline] = localBuildTriggeredHitTimeline(procCount, targetCount, interval, firstDelay)
    if procCount <= 0 || targetCount <= 0
        hitCount = 0;
        timeline = [];
        return;
    end

    hitCount = procCount * targetCount;
    timeline = zeros(1, hitCount);
    writeIndex = 1;
    for procIndex = 1:procCount
        if procIndex == 1
            timeline(writeIndex) = firstDelay;
        else
            timeline(writeIndex) = interval;
        end
        writeIndex = writeIndex + targetCount;
    end
end

function procCount = localEstimateHypersenseProcCount(teamContext, electroChargedReady, natlanSupportReady, enemyTargetCount)
    [timelineProcCount, usedTimeline] = localEstimateHypersenseProcCountFromTimeline( ...
        teamContext, electroChargedReady, natlanSupportReady);
    if usedTimeline
        procCount = min(8, max(0, timelineProcCount));
        return;
    end

    procCount = 0;
    if ~(electroChargedReady || natlanSupportReady)
        return;
    end

    archetypeInfo = localResolveArchetypeInfo(teamContext);
    memberNames = string(getFieldOrDefault(teamContext, 'MemberNames', strings(1, 0)));
    memberElements = string(getFieldOrDefault(teamContext, 'MemberElements', strings(1, 0)));
    preferredJobs = string(getFieldOrDefault(archetypeInfo, 'PreferredJobs', repmat("", size(memberNames))));
    if numel(memberElements) ~= numel(memberNames)
        memberElements = repmat("", size(memberNames));
    end
    if numel(preferredJobs) ~= numel(memberNames)
        preferredJobs = repmat("", size(memberNames));
    end

    normalizedNames = lower(memberNames);
    ororonMask = normalizedNames == "ororon";
    driverMask = preferredJobs == "Driver" | preferredJobs == "Carry";
    triggerMask = preferredJobs == "Trigger";
    hydroElectroMask = (memberElements == "Hydro" | memberElements == "Electro") & ~ororonMask;

    otherHydroElectroCount = sum(hydroElectroMask);
    driverHydroElectroCount = sum(hydroElectroMask & driverMask);
    triggerHydroElectroCount = sum(hydroElectroMask & triggerMask);
    otherNightsoulCount = localCountNightsoulAllies(teamContext);
    otherDriverCount = sum(driverMask & ~ororonMask);
    otherTriggerCount = sum(triggerMask & ~ororonMask);

    pointGainEvents = localEstimateHypersensePointGainEvents( ...
        electroChargedReady, otherHydroElectroCount, driverHydroElectroCount, triggerHydroElectroCount);
    pointBudgetProcCount = floor((40 * double(natlanSupportReady) + 5 * pointGainEvents) / 10);
    triggerOpportunityCount = localEstimateHypersenseTriggerOpportunityCount( ...
        electroChargedReady, natlanSupportReady, enemyTargetCount, ...
        otherHydroElectroCount, driverHydroElectroCount, triggerHydroElectroCount, ...
        otherNightsoulCount, otherDriverCount, otherTriggerCount);

    procCount = min([8, pointBudgetProcCount, triggerOpportunityCount]);
    procCount = max(0, procCount);
end

function [procCount, usedTimeline] = localEstimateHypersenseProcCountFromTimeline( ...
        teamContext, electroChargedReady, natlanSupportReady)
    procCount = 0;
    usedTimeline = false;

    timelineTable = getFieldOrDefault(teamContext, 'TimelineTable', table());
    if isempty(timelineTable) || ~istable(timelineTable) || height(timelineTable) == 0
        return;
    end
    if ~all(ismember({'Character', 'StartTime'}, timelineTable.Properties.VariableNames))
        return;
    end

    usedTimeline = true;
    if ~(electroChargedReady || natlanSupportReady)
        return;
    end

    triggerStartTime = localResolveOroronTriggerStartTime(timelineTable);
    pointGainTimes = zeros(0, 1);
    if electroChargedReady
        pointGainTimes = localCollectHypersenseReactionTimes(timelineTable, triggerStartTime);
    end

    opportunityTimes = pointGainTimes;
    if natlanSupportReady
        opportunityTimes = [opportunityTimes; ... %#ok<AGROW>
            localCollectHypersenseNightsoulOpportunityTimes(timelineTable, triggerStartTime)];
    end

    pointGainEventCount = min(10, numel(localUniqueTimelineTimes(pointGainTimes)));
    pointBudgetProcCount = floor((40 * double(natlanSupportReady) + 5 * pointGainEventCount) / 10);
    triggerOpportunityCount = localCountTimelineCooldownOpportunities(opportunityTimes, 1.80);

    procCount = min([8, pointBudgetProcCount, triggerOpportunityCount]);
    procCount = max(0, procCount);
end

function startTime = localResolveOroronTriggerStartTime(timelineTable)
    startTime = 0;
    rowCharacters = string(timelineTable.Character);
    ororonMask = strcmpi(rowCharacters, "Ororon");
    if ~any(ororonMask)
        return;
    end

    ororonRows = timelineTable(ororonMask, :);
    candidateTimes = double(ororonRows.StartTime);
    if ismember('Action', ororonRows.Properties.VariableNames)
        actionNames = string(ororonRows.Action);
        skillMask = strcmpi(actionNames, "E") | strcmpi(actionNames, "Q");
        if any(skillMask)
            candidateTimes = double(ororonRows.StartTime(skillMask));
        end
    end
    candidateTimes = candidateTimes(isfinite(candidateTimes));
    if isempty(candidateTimes)
        return;
    end
    startTime = min(candidateTimes);
end

function times = localCollectHypersenseReactionTimes(timelineTable, triggerStartTime)
    times = zeros(0, 1);
    if ~ismember('Reaction', timelineTable.Properties.VariableNames)
        return;
    end

    rowCharacters = string(timelineTable.Character);
    reactionText = lower(strtrim(string(timelineTable.Reaction)));
    timeMask = double(timelineTable.StartTime) >= triggerStartTime - 1e-9;
    reactionMask = contains(reactionText, "electro-charged") | contains(reactionText, "lunar-charged");
    allyMask = ~strcmpi(rowCharacters, "Ororon") & ~strcmpi(rowCharacters, "Team");

    times = localUniqueTimelineTimes(double(timelineTable.StartTime(timeMask & reactionMask & allyMask)));
end

function times = localCollectHypersenseNightsoulOpportunityTimes(timelineTable, triggerStartTime)
    rowCount = height(timelineTable);
    if rowCount == 0
        times = zeros(0, 1);
        return;
    end

    rowCharacters = string(timelineTable.Character);
    hitElements = repmat("", rowCount, 1);
    if ismember('HitElement', timelineTable.Properties.VariableNames)
        hitElements = string(timelineTable.HitElement);
    end

    applyGauge = zeros(rowCount, 1);
    if ismember('ApplyGauge', timelineTable.Properties.VariableNames)
        applyGauge = double(timelineTable.ApplyGauge);
    end

    sourceTypes = repmat("", rowCount, 1);
    if ismember('SourceType', timelineTable.Properties.VariableNames)
        sourceTypes = string(timelineTable.SourceType);
    end

    actionClasses = repmat("", rowCount, 1);
    if ismember('ActionClass', timelineTable.Properties.VariableNames)
        actionClasses = string(timelineTable.ActionClass);
    end

    allyMask = arrayfun(@localIsOroronNightsoulAlly, rowCharacters);
    elementalMask = applyGauge > 0 | strlength(strtrim(hitElements)) > 0;
    timeMask = double(timelineTable.StartTime) >= triggerStartTime - 1e-9;
    sourceMask = ~strcmpi(sourceTypes, "TimedReaction") & ~strcmpi(actionClasses, "Utility");

    times = localUniqueTimelineTimes(double(timelineTable.StartTime( ...
        allyMask & elementalMask & timeMask & sourceMask)));
end

function tf = localIsOroronNightsoulAlly(characterName)
    tf = false;
    if strlength(strtrim(string(characterName))) == 0
        return;
    end

    nightsoulRoster = [ ...
        "Chasca", "Citlali", "Iansan", "Ifa", "Kachina", ...
        "Kinich", "Mavuika", "Ororon", "Xilonen"];
    tf = any(strcmpi(string(characterName), nightsoulRoster)) ...
        && ~strcmpi(string(characterName), "Ororon");
end

function times = localUniqueTimelineTimes(times)
    times = double(times(:));
    times = times(isfinite(times));
    if isempty(times)
        times = zeros(0, 1);
        return;
    end
    times = unique(times, 'stable');
end

function count = localCountTimelineCooldownOpportunities(times, cooldown)
    count = 0;
    times = sort(localUniqueTimelineTimes(times));
    if isempty(times)
        return;
    end

    lastAccepted = -inf;
    for timeIndex = 1:numel(times)
        if times(timeIndex) < lastAccepted + cooldown - 1e-9
            continue;
        end
        count = count + 1;
        lastAccepted = times(timeIndex);
    end
end

function events = localEstimateHypersensePointGainEvents( ...
        electroChargedReady, otherHydroElectroCount, driverHydroElectroCount, triggerHydroElectroCount)
    events = 0;
    if ~electroChargedReady || otherHydroElectroCount <= 0
        return;
    end

    events = 5 ...
        + 2 * min(otherHydroElectroCount, 2) ...
        + driverHydroElectroCount ...
        + triggerHydroElectroCount;
    events = min(10, events);
end

function opportunityCount = localEstimateHypersenseTriggerOpportunityCount( ...
        electroChargedReady, natlanSupportReady, enemyTargetCount, ...
        otherHydroElectroCount, driverHydroElectroCount, triggerHydroElectroCount, ...
        otherNightsoulCount, otherDriverCount, otherTriggerCount)
    opportunityCount = 0;
    if electroChargedReady
        opportunityCount = max(opportunityCount, 4 ...
            + double(otherHydroElectroCount >= 2) ...
            + double(driverHydroElectroCount >= 1) ...
            + double(triggerHydroElectroCount >= 1) ...
            + double(enemyTargetCount >= 2));
    end

    if natlanSupportReady
        opportunityCount = max(opportunityCount, 3 ...
            + double(otherNightsoulCount >= 2) ...
            + double(otherDriverCount >= 1) ...
            + double(otherTriggerCount >= 1) ...
            + double(enemyTargetCount >= 2));
    end

    opportunityCount = min(8, opportunityCount);
end

function archetypeInfo = localResolveArchetypeInfo(teamContext)
    archetypeInfo = getFieldOrDefault(teamContext, 'ArchetypeInfo', struct());
    if isstruct(archetypeInfo) && ~isempty(fieldnames(archetypeInfo))
        return;
    end

    memberNames = string(getFieldOrDefault(teamContext, 'MemberNames', strings(1, 0)));
    if isempty(memberNames)
        archetypeInfo = struct();
        return;
    end

    members = cell(1, numel(memberNames));
    for i = 1:numel(memberNames)
        members{i} = struct('Name', char(memberNames(i)));
    end
    archetypeInfo = identifyTeamArchetype(members, struct());
end

function note = localBuildHypersenseNote(procCount)
    note = sprintf('Nightshade Synesthesia (est. %d procs)', procCount);
end

function count = localCountNightsoulAllies(teamContext)
    memberNames = string(getFieldOrDefault(teamContext, 'MemberNames', strings(0, 1)));
    if isempty(memberNames)
        count = 0;
        return;
    end

    nightsoulRoster = [ ...
        "Chasca", "Citlali", "Iansan", "Ifa", "Kachina", ...
        "Kinich", "Mavuika", "Ororon", "Xilonen"];
    count = sum(ismember(memberNames, nightsoulRoster)) - double(any(memberNames == "Ororon"));
    count = max(0, count);
end

function state = localInitializeState(state, hookContext)
    %#ok<INUSD>
    state.NighttideTimers = zeros(1, 0);
    state.C6EchoReady = true;
end

function [state, actionSpec, actionTime, note] = localBeforeAction(state, actionKey, actionSpec, actionTime, note, hookContext)
    %#ok<INUSD>
    if ~isfield(state, 'NighttideTimers')
        state = localInitializeState(state, hookContext);
    end
    if strcmp(actionKey, "Hypersense")
        coverage = localNighttideCoverage(state, getFieldOrDefault(hookContext.Enemy, 'TargetCount', 1));
        if coverage > 0
            actionSpec.BaseActionDamageBonus = getFieldOrDefault(actionSpec, 'BaseActionDamageBonus', 0) + 0.50 * double(coverage >= 1);
            note = localAppendNote(note, "Nighttide");
        end
    elseif strcmp(actionKey, "C6Echo")
        if ~state.C6EchoReady
            actionSpec.MVOverride = 0;
            actionSpec.ApplyGauge = 0;
            actionSpec.CanApplyAura = false;
            actionSpec.CanTriggerReaction = false;
        else
            state.C6EchoReady = false;
        end
    end
    actionTime = max(0, actionTime);
end

function [state, note] = localAfterHit(state, actionKey, actionSpec, hitIndex, reactionResult, note, hookContext) %#ok<INUSD>
    if any(strcmp(actionKey, ["E", "Bounce"]))
        state.NighttideTimers(end + 1) = 12.0; %#ok<AGROW>
        if numel(state.NighttideTimers) > 4
            state.NighttideTimers = state.NighttideTimers(end-3:end);
        end
        note = localAppendNote(note, "Nighttide+1");
    end
end

function state = localAdvanceState(state, actionTime, hookContext) %#ok<INUSD>
    if ~isfield(state, 'NighttideTimers')
        state = localInitializeState(state, hookContext);
    end
    state.NighttideTimers = max(0, state.NighttideTimers - actionTime);
    state.NighttideTimers = state.NighttideTimers(state.NighttideTimers > 1e-6);
end

function note = localAppendNote(baseNote, suffix)
    if strlength(string(baseNote)) == 0
        note = string(suffix);
    else
        note = string(baseNote) + ", " + string(suffix);
    end
end

function coverage = localNighttideCoverage(state, targetCount)
    if nargin < 2 || isempty(targetCount)
        targetCount = 1;
    end
    coverage = min(1.0, numel(getFieldOrDefault(state, 'NighttideTimers', zeros(1, 0))) / max(1, targetCount));
end

function level = localClampTalentLevel(level)
    level = max(1, min(15, round(level)));
end
