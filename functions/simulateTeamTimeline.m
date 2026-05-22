function timelineResult = simulateTeamTimeline(members, rotationPlan, teamContext, enemy, options)
    % 统一队伍时间线与能量近似模拟器。
    %
    % 这一层不直接替代各角色单体高精度伤害模拟，而是补齐队伍级主干能力：
    % 1. 把各成员的 StartTime / 切人空档 / action token 合并成一条共享时间线；
    % 2. 在这条时间线上推进共享敌人元素状态；
    % 3. 按动作近似估算粒子、返能与下一轮循环衔接情况；
    % 4. 产出可视化友好的时间线表、能量表和效果窗口表。
    if nargin < 1 || isempty(members)
        members = {};
    end
    if nargin < 2 || isempty(rotationPlan)
        rotationPlan = struct();
    end
    if nargin < 3 || isempty(teamContext)
        teamContext = struct('RotationDuration', 20);
    end
    if nargin < 4 || isempty(enemy)
        enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
    end
    if nargin < 5 || isempty(options)
        options = struct();
    end

    memberCount = numel(members);
    archetypeInfo = getFieldOrDefault(rotationPlan, 'ArchetypeInfo', struct());
    if isempty(fieldnames(archetypeInfo))
        archetypeInfo = identifyTeamArchetype(members, struct());
    end
    rotationDuration = getFieldOrDefault(rotationPlan, 'RotationDuration', ...
        getFieldOrDefault(teamContext, 'RotationDuration', 20));

    if memberCount == 0
        timelineResult = struct( ...
            'TimelineTable', table(), ...
            'EnergySummary', table(), ...
            'EnergyTimeline', table(), ...
            'ActiveEffectsTable', table(), ...
            'FinalEnemyState', createEnemyState(enemy, teamContext, ""), ...
            'CanLoopNextCycle', false, ...
            'LoopReadiness', 0);
        return;
    end

    actionEvents = localBuildActionEvents(members, rotationPlan, rotationDuration);
    actionEvents = localExpandActionEventsWithEffectTicks( ...
        actionEvents, rotationPlan, archetypeInfo, teamContext, rotationDuration);
    energyState = localInitializeEnergyState(members);
    compiledBuilds = localCompileBuilds(members, teamContext);

    triggerElement = localResolveInitialTriggerElement(members, archetypeInfo);
    enemyState = createEnemyState(enemy, teamContext, triggerElement);
    currentTime = 0;
    activeForegroundCharacter = "";

    timelineRows = cell(0, 19);
    energyRows = cell(0, 6);
    effectRows = cell(0, 9);
    actionOrder = 0;

    previousForegroundCharacter = "";
    previousForegroundEndTime = 0;
    previousForegroundKnown = false;

    for i = 1:numel(actionEvents)
        event = actionEvents(i);
        meta = localResolveEventMeta(event, archetypeInfo, teamContext);
        eventTriggerElement = string(getFieldOrDefault(meta, 'HitElement', event.HitElement));
        deltaTime = max(0, event.StartTime - currentTime);
        if deltaTime > 1e-9
            [enemyState, timedPackets] = advanceEnemyStateTime( ...
                enemyState, deltaTime, eventTriggerElement, teamContext);
            if previousForegroundKnown && logical(getFieldOrDefault(meta, 'ConsumesActiveWindow', true)) ...
                    && previousForegroundCharacter ~= "" && event.Character ~= previousForegroundCharacter ...
                    && event.StartTime - previousForegroundEndTime > 1e-9
                actionOrder = actionOrder + 1;
                timelineRows(end + 1, :) = { ... %#ok<AGROW>
                    actionOrder, previousForegroundEndTime, event.StartTime, "Team", activeForegroundCharacter, ...
                    "Swap", "Swap", "Team", "Utility", "", 0, ...
                    localJoinReactionNames(timedPackets), localAuraSummary(enemyState), ...
                    localQuickenGauge(enemyState), localFrozenGauge(enemyState), localCoreCount(enemyState), ...
                    0, "", false};
            end
            currentTime = event.StartTime;
        end

        hitDescriptor = struct( ...
            'HitElement', meta.HitElement, ...
            'ApplyElement', meta.ApplyElement, ...
            'ApplyGauge', meta.ApplyGauge, ...
            'CanApplyAura', meta.CanApplyAura, ...
            'AllowAmplify', meta.AllowAmplify, ...
            'AllowCatalyze', meta.AllowCatalyze, ...
            'PreferredAura', meta.PreferredAura, ...
            'ResolveReactionAsDamage', logical(getFieldOrDefault(meta, 'ResolveReactionAsDamage', false)), ...
            'ForceReactionName', string(getFieldOrDefault(meta, 'ForceReactionName', "")), ...
            'ReactionElement', string(getFieldOrDefault(meta, 'ReactionElement', "")));

        build = compiledBuilds{event.MemberIndex};
        reactionResult = resolveReactionForHit(enemyState, hitDescriptor, build, teamContext, enemy, 0);
        enemyState = reactionResult.EnemyState;

        [energyState, currentEnergyRows, ownerEnergyDelta] = localApplyEnergyEvent( ...
            energyState, event.MemberIndex, meta, event.EndTime);
        if ~isempty(currentEnergyRows)
            energyRows = [energyRows; currentEnergyRows]; %#ok<AGROW>
        end

        if logical(getFieldOrDefault(meta, 'ConsumesActiveWindow', true))
            activeForegroundCharacter = event.Character;
        end

        if meta.EffectDuration > 0 && strlength(string(meta.EffectTag)) > 0
            effectRows(end + 1, :) = { ... %#ok<AGROW>
                event.Character, event.Action, meta.EffectTag, ...
                event.StartTime, min(rotationDuration, event.StartTime + meta.EffectDuration), ...
                event.MemberRole, string(getFieldOrDefault(meta, 'EffectTickAction', "")), ...
                double(getFieldOrDefault(meta, 'EffectTickInterval', 0)), ...
                double(getFieldOrDefault(meta, 'EffectTickCount', 0))};
        end

        actionOrder = actionOrder + 1;
        timelineRows(end + 1, :) = { ... %#ok<AGROW>
            actionOrder, event.StartTime, event.EndTime, event.Character, activeForegroundCharacter, ...
            event.MemberRole, event.Action, string(getFieldOrDefault(event, 'SourceType', "MemberAction")), ...
            meta.ActionClass, meta.HitElement, meta.ApplyGauge, ...
            localJoinReactions(reactionResult.PrimaryReaction, reactionResult.TriggeredReactions), ...
            localAuraSummary(enemyState), localQuickenGauge(enemyState), ...
            localFrozenGauge(enemyState), localCoreCount(enemyState), ...
            ownerEnergyDelta, meta.EffectTag, logical(getFieldOrDefault(meta, 'ConsumesActiveWindow', true))};

        currentTime = max(currentTime, event.StartTime);
        if logical(getFieldOrDefault(meta, 'ConsumesActiveWindow', true))
            previousForegroundCharacter = event.Character;
            previousForegroundEndTime = event.EndTime;
            previousForegroundKnown = true;
        end
    end

    if currentTime < rotationDuration
        [enemyState, timedPackets] = advanceEnemyStateTime( ...
            enemyState, rotationDuration - currentTime, triggerElement, teamContext);
        if ~isempty(timedPackets)
            actionOrder = actionOrder + 1;
            timelineRows(end + 1, :) = { ... %#ok<AGROW>
                actionOrder, currentTime, rotationDuration, "Team", activeForegroundCharacter, "Tail", "Tail", ...
                "Team", "Utility", "", 0, localJoinReactionNames(timedPackets), localAuraSummary(enemyState), ...
                localQuickenGauge(enemyState), localFrozenGauge(enemyState), localCoreCount(enemyState), 0, "", false};
        end
    end

    timelineTable = localTimelineTable(timelineRows);
    energyTable = localBuildEnergySummaryTable(energyState);
    energyTimeline = localBuildEnergyTimelineTable(energyRows);
    activeEffectsTable = localBuildEffectTable(effectRows);
    timelineSummary = localBuildTimelineSummary(timelineTable, rotationDuration);
    memberTimelineTable = localBuildMemberTimelineTable(timelineTable, members);

    burstMask = energyTable.UsedBurst;
    if any(burstMask)
        canLoop = all(energyTable.CanBurstNextCycle(burstMask));
        loopReadiness = min(energyTable.EndEnergy(burstMask) ./ max(energyTable.BurstCost(burstMask), 1));
    else
        canLoop = true;
        loopReadiness = 1;
    end

    timelineResult = struct( ...
        'TimelineTable', timelineTable, ...
        'EnergySummary', energyTable, ...
        'EnergyTimeline', energyTimeline, ...
        'ActiveEffectsTable', activeEffectsTable, ...
        'TimelineSummary', timelineSummary, ...
        'MemberTimelineSummary', memberTimelineTable, ...
        'FinalEnemyState', enemyState, ...
        'CanLoopNextCycle', canLoop, ...
        'LoopReadiness', loopReadiness);
end

function actionEvents = localBuildActionEvents(members, rotationPlan, rotationDuration)
    if nargin < 3 || isempty(rotationDuration)
        rotationDuration = inf;
    end

    actionEvents = repmat(localEmptyEvent(), 1, 0);
    memberPlans = getFieldOrDefault(rotationPlan, 'MemberPlans', struct([]));

    for i = 1:min(numel(members), numel(memberPlans))
        plan = memberPlans(i);
        tokens = getFieldOrDefault(plan, 'RotationTokens', cell(0, 1));
        if isempty(tokens)
            rotationFile = string(getFieldOrDefault(plan, 'TempRotationFile', ""));
            if strlength(rotationFile) > 0 && exist(char(rotationFile), 'file') == 2
                tokens = readRotationTokens(char(rotationFile));
            end
        end
        if isempty(tokens)
            continue;
        end

        cursor = getFieldOrDefault(plan, 'StartTime', 0);
        for tokenIndex = 1:numel(tokens)
            if cursor >= rotationDuration - 1e-9
                break;
            end

            action = string(tokens{tokenIndex});
            duration = estimateActionDuration(members{i}.Name, action, 0.60);
            if ~isfinite(duration) || duration <= 0
                duration = 0.60;
            end

            event = localEmptyEvent();
            event.MemberIndex = i;
            event.Member = members{i};
            event.Character = string(getFieldOrDefault(members{i}, 'DisplayName', members{i}.Name));
            event.MemberRole = string(getFieldOrDefault(plan, 'Role', ""));
            event.Action = action;
            event.StartTime = cursor;
            event.EndTime = min(rotationDuration, cursor + duration);
            event.Duration = max(0, event.EndTime - event.StartTime);
            event.HitElement = string(getCharacterElement(members{i}.Name));
            actionEvents(end + 1) = event; %#ok<AGROW>

            cursor = cursor + duration;
        end
    end

    if isempty(actionEvents)
        return;
    end
    [~, order] = sort([actionEvents.StartTime]);
    actionEvents = actionEvents(order);
end

function actionEvents = localExpandActionEventsWithEffectTicks(actionEvents, rotationPlan, archetypeInfo, teamContext, rotationDuration)
    if isempty(actionEvents)
        return;
    end

    expandedEvents = repmat(localEmptyEvent(), 1, 0);
    memberPlans = getFieldOrDefault(rotationPlan, 'MemberPlans', struct([]));

    for i = 1:numel(actionEvents)
        event = actionEvents(i);
        meta = inferActionCombatMetadata(event.Member, event.Action, archetypeInfo, teamContext);
        event.CombatMeta = meta;
        expandedEvents(end + 1) = event; %#ok<AGROW>

        memberPlan = struct();
        if event.MemberIndex >= 1 && event.MemberIndex <= numel(memberPlans)
            memberPlan = memberPlans(event.MemberIndex);
        end
        if ~localShouldExpandEffectTicks(memberPlan)
            continue;
        end

        tickCount = double(getFieldOrDefault(meta, 'EffectTickCount', 0));
        tickInterval = double(getFieldOrDefault(meta, 'EffectTickInterval', 0));
        firstTickDelay = double(getFieldOrDefault(meta, 'EffectFirstTickDelay', 0));
        tickAction = string(getFieldOrDefault(meta, 'EffectTickAction', ""));
        effectDuration = double(getFieldOrDefault(meta, 'EffectDuration', 0));
        if tickCount <= 0 || tickInterval <= 0 || effectDuration <= 0 || strlength(tickAction) == 0
            continue;
        end

        effectEndTime = min(rotationDuration, event.StartTime + effectDuration);
        for tickIndex = 1:tickCount
            tickTime = event.StartTime + firstTickDelay + (tickIndex - 1) * tickInterval;
            if tickTime > effectEndTime + 1e-9 || tickTime >= rotationDuration - 1e-9
                break;
            end
            expandedEvents(end + 1) = localBuildSyntheticEffectTickEvent( ... %#ok<AGROW>
                event, meta, tickIndex, tickTime, rotationDuration);
        end
    end

    sortRows = zeros(numel(expandedEvents), 3);
    for i = 1:numel(expandedEvents)
        sortRows(i, :) = [expandedEvents(i).StartTime, localEventSourcePriority(expandedEvents(i)), i];
    end
    order = sortrows(sortRows, [1 2 3]);
    actionEvents = expandedEvents(order(:, 3).');
end

function meta = localResolveEventMeta(event, archetypeInfo, teamContext)
    meta = getFieldOrDefault(event, 'CombatMeta', struct());
    if isstruct(meta) && ~isempty(fieldnames(meta))
        return;
    end
    meta = inferActionCombatMetadata(event.Member, event.Action, archetypeInfo, teamContext);
end

function tf = localShouldExpandEffectTicks(memberPlan)
    planningSource = lower(char(string(getFieldOrDefault(memberPlan, 'PlanningSource', ""))));
    if strlength(string(planningSource)) == 0
        tf = true;
        return;
    end
    if contains(planningSource, 'seed') || contains(planningSource, 'manual')
        tf = false;
        return;
    end
    tf = contains(planningSource, 'named') || contains(planningSource, 'generic') ...
        || contains(planningSource, 'auto') || contains(planningSource, 'fallback');
end

function event = localBuildSyntheticEffectTickEvent(baseEvent, baseMeta, tickIndex, tickTime, rotationDuration)
    event = localEmptyEvent();
    event.MemberIndex = baseEvent.MemberIndex;
    event.Member = baseEvent.Member;
    event.Character = baseEvent.Character;
    event.MemberRole = baseEvent.MemberRole;
    event.SourceType = "EffectTick";
    event.Action = string(getFieldOrDefault(baseMeta, 'EffectTickAction', "EffectTick")) + "#" + string(tickIndex);
    event.StartTime = tickTime;
    event.EndTime = min(rotationDuration, tickTime + 0.01);
    event.Duration = max(0, event.EndTime - event.StartTime);
    event.HitElement = string(getFieldOrDefault(baseMeta, 'ApplyElement', getFieldOrDefault(baseMeta, 'HitElement', "")));

    tickMeta = baseMeta;
    tickMeta.Action = event.Action;
    tickMeta.ActionClass = "FollowUp";
    tickMeta.ConsumesActiveWindow = false;
    tickMeta.HitElement = event.HitElement;
    tickMeta.ApplyElement = event.HitElement;
    tickMeta.ApplyGauge = double(getFieldOrDefault(baseMeta, 'EffectTickGauge', 0));
    tickMeta.CanApplyAura = tickMeta.ApplyGauge > 0 && strlength(string(tickMeta.ApplyElement)) > 0;
    tickMeta.EstimatedParticles = 0;
    tickMeta.EstimatedOrbs = 0;
    tickMeta.FlatEnergySelf = 0;
    tickMeta.FlatEnergyTeam = 0;
    tickMeta.ConsumesBurstEnergy = false;
    tickMeta.BurstCost = 0;
    tickMeta.EffectDuration = 0;
    tickMeta.EffectFirstTickDelay = 0;
    tickMeta.EffectTickInterval = 0;
    tickMeta.EffectTickCount = 0;
    tickMeta.EffectTickAction = "";
    tickMeta.EffectTag = string(getFieldOrDefault(baseMeta, 'EffectTag', ""));
    event.CombatMeta = tickMeta;
end

function priority = localEventSourcePriority(event)
    sourceType = string(getFieldOrDefault(event, 'SourceType', "MemberAction"));
    if sourceType == "EffectTick"
        priority = 2;
    else
        priority = 1;
    end
end

function builds = localCompileBuilds(members, teamContext)
    builds = cell(1, numel(members));
    for i = 1:numel(members)
        memberBuild = getFieldOrDefault(members{i}, 'Build', struct());
        builds{i} = compileArtifactSetBonuses(members{i}.Name, memberBuild, teamContext);
    end
end

function energyState = localInitializeEnergyState(members)
    energyState = repmat(struct( ...
        'Name', "", ...
        'DisplayName', "", ...
        'Element', "", ...
        'ER', 1.0, ...
        'BurstCost', 60, ...
        'StartEnergy', 60, ...
        'CurrentEnergy', 60, ...
        'UsedBurst', false), 1, numel(members));

    for i = 1:numel(members)
        burstCost = getCharacterBurstCost( ...
            members{i}.Name, ...
            getFieldOrDefault(members{i}, 'TalentLevel', 10), ...
            getFieldOrDefault(members{i}, 'Constellation', 0));
        build = getFieldOrDefault(members{i}, 'Build', struct());
        er = double(getFieldOrDefault(build, 'ER', 1.0));
        if er <= 0
            er = 1.0;
        end
        if er > 10
            er = er / 100;
        end

        energyState(i).Name = string(members{i}.Name);
        energyState(i).DisplayName = string(getFieldOrDefault(members{i}, 'DisplayName', members{i}.Name));
        energyState(i).Element = string(getCharacterElement(members{i}.Name));
        energyState(i).ER = er;
        energyState(i).BurstCost = burstCost;
        energyState(i).StartEnergy = burstCost;
        energyState(i).CurrentEnergy = burstCost;
    end
end

function [energyState, rows, ownerDelta] = localApplyEnergyEvent(energyState, ownerIndex, meta, eventTime)
    if nargin < 4 || isempty(eventTime)
        eventTime = 0;
    end

    rows = cell(0, 7);
    ownerDelta = 0;

    if ownerIndex < 1 || ownerIndex > numel(energyState)
        return;
    end

    if logical(getFieldOrDefault(meta, 'ConsumesBurstEnergy', false))
        burstCost = double(getFieldOrDefault(meta, 'BurstCost', energyState(ownerIndex).BurstCost));
        ownerDelta = ownerDelta - burstCost;
        energyState(ownerIndex).CurrentEnergy = max(0, energyState(ownerIndex).CurrentEnergy - burstCost);
        energyState(ownerIndex).UsedBurst = true;
        rows(end + 1, :) = { ... %#ok<AGROW>
            eventTime, energyState(ownerIndex).DisplayName, string(meta.Action), ...
            energyState(ownerIndex).DisplayName, -burstCost, energyState(ownerIndex).CurrentEnergy, "BurstCost"};
    end

    extraSelfEnergy = double(getFieldOrDefault(meta, 'PostAddEnergySelf', 0));
    if extraSelfEnergy > 0
        energyState(ownerIndex).CurrentEnergy = min(energyState(ownerIndex).BurstCost, ...
            energyState(ownerIndex).CurrentEnergy + extraSelfEnergy);
        ownerDelta = ownerDelta + extraSelfEnergy;
        rows(end + 1, :) = { ...
            eventTime, energyState(ownerIndex).DisplayName, string(meta.Action), ...
            energyState(ownerIndex).DisplayName, extraSelfEnergy, energyState(ownerIndex).CurrentEnergy, "ExtraSelfEnergy"};
    end

    ownerElement = string(getFieldOrDefault(meta, 'ApplyElement', energyState(ownerIndex).Element));
    particles = double(getFieldOrDefault(meta, 'EstimatedParticles', 0));
    orbs = double(getFieldOrDefault(meta, 'EstimatedOrbs', 0));
    flatSelf = double(getFieldOrDefault(meta, 'FlatEnergySelf', 0));
    flatTeam = double(getFieldOrDefault(meta, 'FlatEnergyTeam', 0));

    for i = 1:numel(energyState)
        sameElement = strcmpi(char(energyState(i).Element), char(ownerElement));
        if i == ownerIndex
            particleEnergy = particles * (3.0 * double(sameElement) + 1.0 * double(~sameElement));
            orbEnergy = orbs * (9.0 * double(sameElement) + 3.0 * double(~sameElement));
        else
            particleEnergy = particles * (1.8 * double(sameElement) + 0.6 * double(~sameElement));
            orbEnergy = orbs * (5.4 * double(sameElement) + 1.8 * double(~sameElement));
        end

        deltaEnergy = (particleEnergy + orbEnergy) * energyState(i).ER ...
            + flatTeam / max(numel(energyState), 1);
        if i == ownerIndex
            deltaEnergy = deltaEnergy + flatSelf;
        end

        if abs(deltaEnergy) <= 1e-9
            continue;
        end

        energyState(i).CurrentEnergy = min(energyState(i).BurstCost, ...
            energyState(i).CurrentEnergy + deltaEnergy);
        rows(end + 1, :) = { ... %#ok<AGROW>
            eventTime, energyState(ownerIndex).DisplayName, string(meta.Action), ...
            energyState(i).DisplayName, deltaEnergy, energyState(i).CurrentEnergy, "EnergyGain"};
        if i == ownerIndex
            ownerDelta = ownerDelta + deltaEnergy;
        end
    end
end

function tableOut = localTimelineTable(rows)
    if isempty(rows)
        tableOut = table();
        return;
    end

    tableOut = cell2table(rows, 'VariableNames', { ...
        'Order', 'StartTime', 'EndTime', 'Character', 'ActiveCharacter', 'Role', 'Action', ...
        'SourceType', 'ActionClass', 'HitElement', 'ApplyGauge', 'Reaction', 'AuraState', ...
        'QuickenGauge', 'FrozenGauge', 'DendroCoreCount', 'OwnerEnergyDelta', 'EffectTag', ...
        'ConsumesActiveWindow'});
end

function tableOut = localBuildEnergySummaryTable(energyState)
    if isempty(energyState)
        tableOut = table();
        return;
    end

    names = strings(numel(energyState), 1);
    elements = strings(numel(energyState), 1);
    startEnergy = zeros(numel(energyState), 1);
    endEnergy = zeros(numel(energyState), 1);
    burstCost = zeros(numel(energyState), 1);
    er = zeros(numel(energyState), 1);
    usedBurst = false(numel(energyState), 1);
    canBurst = false(numel(energyState), 1);
    missingEnergy = zeros(numel(energyState), 1);

    for i = 1:numel(energyState)
        names(i) = energyState(i).DisplayName;
        elements(i) = energyState(i).Element;
        startEnergy(i) = energyState(i).StartEnergy;
        endEnergy(i) = energyState(i).CurrentEnergy;
        burstCost(i) = energyState(i).BurstCost;
        er(i) = energyState(i).ER;
        usedBurst(i) = energyState(i).UsedBurst;
        canBurst(i) = endEnergy(i) >= burstCost(i) - 1e-6;
        missingEnergy(i) = max(0, burstCost(i) - endEnergy(i));
    end

    tableOut = table(names, elements, burstCost, startEnergy, endEnergy, er, usedBurst, canBurst, missingEnergy, ...
        'VariableNames', {'Character', 'Element', 'BurstCost', 'StartEnergy', 'EndEnergy', ...
        'ER', 'UsedBurst', 'CanBurstNextCycle', 'MissingEnergy'});
end

function tableOut = localBuildEnergyTimelineTable(rows)
    if isempty(rows)
        tableOut = table();
        return;
    end
    tableOut = cell2table(rows, 'VariableNames', { ...
        'Time', 'SourceCharacter', 'Action', 'Recipient', 'DeltaEnergy', 'RecipientEnergy', 'EventType'});
end

function tableOut = localBuildEffectTable(rows)
    if isempty(rows)
        tableOut = table();
        return;
    end
    tableOut = cell2table(rows, 'VariableNames', { ...
        'Character', 'Action', 'EffectTag', 'StartTime', 'EndTime', 'Role', ...
        'TickAction', 'TickInterval', 'TickCount'});
end

function summary = localAuraSummary(enemyState)
    summary = "";
    auraParts = strings(0, 1);
    auras = getFieldOrDefault(enemyState, 'Auras', []);
    for i = 1:numel(auras)
        auraParts(end + 1, 1) = string(auras(i).Element) + ":" + sprintf('%.2fU', double(auras(i).Gauge)); %#ok<AGROW>
    end
    if getFieldOrDefault(getFieldOrDefault(enemyState, 'Quicken', struct()), 'Active', false)
        auraParts(end + 1, 1) = "Quicken"; %#ok<AGROW>
    end
    if getFieldOrDefault(getFieldOrDefault(enemyState, 'Frozen', struct()), 'Active', false)
        auraParts(end + 1, 1) = "Frozen"; %#ok<AGROW>
    end
    if isempty(auraParts)
        summary = "None";
    else
        summary = join(auraParts, " | ");
    end
end

function gauge = localQuickenGauge(enemyState)
    gauge = double(getFieldOrDefault(getFieldOrDefault(enemyState, 'Quicken', struct()), 'Gauge', 0));
end

function gauge = localFrozenGauge(enemyState)
    gauge = double(getFieldOrDefault(getFieldOrDefault(enemyState, 'Frozen', struct()), 'Gauge', 0));
end

function count = localCoreCount(enemyState)
    count = numel(getFieldOrDefault(enemyState, 'DendroCores', repmat(struct(), 1, 0)));
end

function text = localJoinReactions(primaryReaction, triggeredReactions)
    parts = strings(0, 1);
    if strlength(string(primaryReaction)) > 0
        parts(end + 1, 1) = string(primaryReaction); %#ok<AGROW>
    end
    if ~isempty(triggeredReactions)
        parts = [parts; string(triggeredReactions(:))]; %#ok<AGROW>
    end
    parts = unique(parts(strlength(parts) > 0), 'stable');
    if isempty(parts)
        text = "";
    else
        text = join(parts, ", ");
    end
end

function text = localJoinReactionNames(packets)
    names = strings(0, 1);
    for i = 1:numel(packets)
        names(end + 1, 1) = string(getFieldOrDefault(packets(i), 'ReactionName', "")); %#ok<AGROW>
    end
    names = unique(names(strlength(names) > 0), 'stable');
    if isempty(names)
        text = "";
    else
        text = join(names, ", ");
    end
end

function summary = localBuildTimelineSummary(timelineTable, rotationDuration)
    if nargin < 2 || isempty(rotationDuration) || ~isfinite(rotationDuration)
        rotationDuration = 0;
    end

    summary = struct( ...
        'RotationDuration', rotationDuration, ...
        'ActionCount', 0, ...
        'MemberEventCount', 0, ...
        'BackgroundEventCount', 0, ...
        'SwapCount', 0, ...
        'TailCount', 0, ...
        'MemberScheduledActionTime', 0, ...
        'MemberOccupiedTime', 0, ...
        'SwapTime', 0, ...
        'TailTime', 0, ...
        'OverlapTime', 0, ...
        'IdleTime', max(0, rotationDuration), ...
        'MaxConcurrentActions', 0);

    if isempty(timelineTable) || ~istable(timelineTable) || height(timelineTable) == 0
        return;
    end

    durations = max(0, timelineTable.EndTime - timelineTable.StartTime);
    actionNames = string(timelineTable.Action);
    characterNames = string(timelineTable.Character);
    memberMask = characterNames ~= "Team";
    foregroundMask = memberMask;
    if ismember('ConsumesActiveWindow', timelineTable.Properties.VariableNames)
        foregroundMask = foregroundMask & logical(timelineTable.ConsumesActiveWindow);
    end
    swapMask = characterNames == "Team" & strcmpi(actionNames, "Swap");
    tailMask = characterNames == "Team" & strcmpi(actionNames, "Tail");

    summary.ActionCount = height(timelineTable);
    summary.MemberEventCount = sum(memberMask);
    summary.BackgroundEventCount = max(0, summary.MemberEventCount - sum(foregroundMask));
    summary.SwapCount = sum(swapMask);
    summary.TailCount = sum(tailMask);
    summary.MemberScheduledActionTime = sum(durations(foregroundMask));
    summary.MemberOccupiedTime = localUnionDuration( ...
        timelineTable.StartTime(foregroundMask), timelineTable.EndTime(foregroundMask));
    summary.SwapTime = sum(durations(swapMask));
    summary.TailTime = sum(durations(tailMask));
    summary.OverlapTime = max(0, summary.MemberScheduledActionTime - summary.MemberOccupiedTime);
    summary.IdleTime = max(0, rotationDuration - summary.MemberOccupiedTime - summary.SwapTime);
    summary.MaxConcurrentActions = localMaxConcurrentActions( ...
        timelineTable.StartTime(foregroundMask), timelineTable.EndTime(foregroundMask));
end

function memberTable = localBuildMemberTimelineTable(timelineTable, members)
    if nargin < 2 || isempty(members)
        members = {};
    end

    names = strings(numel(members), 1);
    actionCounts = zeros(numel(members), 1);
    scheduledTimes = zeros(numel(members), 1);
    backgroundCounts = zeros(numel(members), 1);
    backgroundTimes = zeros(numel(members), 1);
    firstStarts = nan(numel(members), 1);
    lastEnds = nan(numel(members), 1);

    for i = 1:numel(members)
        names(i) = string(getFieldOrDefault(members{i}, 'DisplayName', members{i}.Name));
    end

    if isempty(timelineTable) || ~istable(timelineTable) || height(timelineTable) == 0
        memberTable = table(names, actionCounts, scheduledTimes, backgroundCounts, backgroundTimes, firstStarts, lastEnds, ...
            'VariableNames', {'Character', 'ScheduledActionCount', 'ScheduledActionTime', ...
            'BackgroundEventCount', 'BackgroundEventTime', 'FirstActionTime', 'LastActionTime'});
        return;
    end

    rowNames = string(timelineTable.Character);
    rowDurations = max(0, timelineTable.EndTime - timelineTable.StartTime);
    consumeMask = true(height(timelineTable), 1);
    if ismember('ConsumesActiveWindow', timelineTable.Properties.VariableNames)
        consumeMask = logical(timelineTable.ConsumesActiveWindow);
    end
    for i = 1:numel(names)
        memberMask = strcmpi(rowNames, names(i));
        if ~any(memberMask)
            continue;
        end
        foregroundMask = memberMask & consumeMask;
        backgroundMask = memberMask & ~consumeMask;
        actionCounts(i) = sum(foregroundMask);
        scheduledTimes(i) = sum(rowDurations(foregroundMask));
        backgroundCounts(i) = sum(backgroundMask);
        backgroundTimes(i) = sum(rowDurations(backgroundMask));
        firstStarts(i) = min(timelineTable.StartTime(memberMask));
        lastEnds(i) = max(timelineTable.EndTime(memberMask));
    end

    memberTable = table(names, actionCounts, scheduledTimes, backgroundCounts, backgroundTimes, firstStarts, lastEnds, ...
        'VariableNames', {'Character', 'ScheduledActionCount', 'ScheduledActionTime', ...
        'BackgroundEventCount', 'BackgroundEventTime', 'FirstActionTime', 'LastActionTime'});
end

function duration = localUnionDuration(starts, ends)
    duration = 0;
    if isempty(starts) || isempty(ends)
        return;
    end

    intervals = [double(starts(:)), double(ends(:))];
    intervals = intervals(isfinite(intervals(:, 1)) & isfinite(intervals(:, 2)) ...
        & intervals(:, 2) > intervals(:, 1), :);
    if isempty(intervals)
        return;
    end

    intervals = sortrows(intervals, [1 2]);
    currentStart = intervals(1, 1);
    currentEnd = intervals(1, 2);
    for i = 2:size(intervals, 1)
        nextStart = intervals(i, 1);
        nextEnd = intervals(i, 2);
        if nextStart <= currentEnd + 1e-9
            currentEnd = max(currentEnd, nextEnd);
        else
            duration = duration + (currentEnd - currentStart);
            currentStart = nextStart;
            currentEnd = nextEnd;
        end
    end
    duration = duration + (currentEnd - currentStart);
end

function maxConcurrent = localMaxConcurrentActions(starts, ends)
    maxConcurrent = 0;
    if isempty(starts) || isempty(ends)
        return;
    end

    starts = double(starts(:));
    ends = double(ends(:));
    validMask = isfinite(starts) & isfinite(ends) & ends > starts;
    starts = starts(validMask);
    ends = ends(validMask);
    if isempty(starts)
        return;
    end

    points = [starts, ones(numel(starts), 1); ends, -ones(numel(ends), 1)];
    points = sortrows(points, [1 2]);
    current = 0;
    for i = 1:size(points, 1)
        delta = points(i, 2);
        if delta > 0
            current = current + 1;
            maxConcurrent = max(maxConcurrent, current);
        else
            current = max(0, current - 1);
        end
    end
end

function triggerElement = localResolveInitialTriggerElement(members, archetypeInfo)
    carryIndices = getFieldOrDefault(archetypeInfo, 'RecommendedCarryIndices', []);
    if ~isempty(carryIndices)
        carryIndex = carryIndices(1);
        if carryIndex >= 1 && carryIndex <= numel(members)
            triggerElement = string(getCharacterElement(members{carryIndex}.Name));
            return;
        end
    end
    triggerElement = string(getCharacterElement(members{1}.Name));
end

function event = localEmptyEvent()
    event = struct( ...
        'MemberIndex', 0, ...
        'Member', struct(), ...
        'Character', "", ...
        'MemberRole', "", ...
        'SourceType', "MemberAction", ...
        'Action', "", ...
        'StartTime', 0, ...
        'EndTime', 0, ...
        'Duration', 0, ...
        'HitElement', "", ...
        'CombatMeta', struct());
end
