function timelineResult = simulateTeamTimeline(members, rotationPlan, teamContext, enemy, options)
    % Unified team timeline and energy simulator.
    % Merges member actions into one shared timeline, advances enemy state,
    % estimates team energy flow, and records active background windows.
    %
    % Outputs timeline, energy, and active-effect tables for team analysis.
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
    actionEvents = localExpandActionEventsWithBackgroundDrivers( ...
        actionEvents, rotationPlan, archetypeInfo, teamContext, rotationDuration);
    actionQueue = localSortActionEvents(actionEvents);
    energyState = localInitializeEnergyState(members);
    pendingEnergyDrops = repmat(localEmptyPendingEnergyDrop(), 1, 0);
    compiledBuilds = localCompileBuilds(members, teamContext);
    runtimeTriggeredWindows = repmat(localEmptyActiveWindow(), 1, 0);
    runtimeTriggeredLastTriggerTimes = containers.Map('KeyType', 'char', 'ValueType', 'double');
    auraICDStates = struct();

    triggerElement = localResolveInitialTriggerElement(members, archetypeInfo);
    enemyState = createEnemyState(enemy, teamContext, triggerElement);
    currentTime = 0;
    activeForegroundCharacter = "";

    timelineRows = cell(0, 30);
    energyRows = cell(0, 6);
    effectRows = cell(0, 11);
    actionOrder = 0;

    previousForegroundCharacter = "";
    previousForegroundEndTime = 0;
    previousForegroundKnown = false;

    while ~isempty(actionQueue) || currentTime < rotationDuration - 1e-9
        if isempty(actionQueue)
            nextEvent = localEmptyEvent();
            nextMeta = struct();
            nextEventTime = rotationDuration;
        else
            nextEvent = actionQueue(1);
            nextMeta = localResolveEventMeta(nextEvent, archetypeInfo, teamContext);
            nextEventTime = min(rotationDuration, double(nextEvent.StartTime));
        end

        intervalEndTime = min(rotationDuration, nextEventTime);
        [intervalEndTime, hasMidIntervalTimedReaction] = localResolveNextIntervalStopTime( ...
            enemyState, currentTime, intervalEndTime, triggerElement, teamContext);
        if intervalEndTime > currentTime + 1e-9
            runtimeTriggeredWindows = localPruneExpiredActiveWindows(runtimeTriggeredWindows, intervalEndTime);
            boundaryCatchCharacter = localResolveBoundaryCatchCharacter( ...
                activeForegroundCharacter, nextEvent, nextMeta, actionQueue, ...
                archetypeInfo, teamContext, intervalEndTime);
            [energyState, pendingEnergyDrops, pendingEnergyRows] = localResolvePendingEnergyDrops( ...
                energyState, pendingEnergyDrops, activeForegroundCharacter, intervalEndTime, boundaryCatchCharacter);
            if ~isempty(pendingEnergyRows)
                energyRows = [energyRows; pendingEnergyRows]; %#ok<AGROW>
            end

            [gapWindow, gapLabel] = localResolveIntervalGapWindow( ...
                currentTime, intervalEndTime, nextEvent, nextMeta, previousForegroundKnown, ...
                previousForegroundCharacter, previousForegroundEndTime, rotationDuration);
            intervalTriggerElement = triggerElement;
            if ~isempty(actionQueue)
                intervalTriggerElement = string(getFieldOrDefault(nextMeta, 'HitElement', nextEvent.HitElement));
            end

            [enemyState, intervalRows, timedPackets, actionOrder] = localAdvanceIntervalRows( ...
                enemyState, currentTime, intervalEndTime, intervalTriggerElement, ...
                teamContext, activeForegroundCharacter, actionOrder, gapWindow, gapLabel);
            if ~isempty(intervalRows)
                timelineRows = [timelineRows; intervalRows]; %#ok<AGROW>
            end

            [runtimeReactionEvents, runtimeTriggeredWindows, runtimeTriggeredLastTriggerTimes] = ...
                localResolveBackgroundReactionTriggeredEvents( ...
                timedPackets, intervalEndTime, runtimeTriggeredWindows, ...
                runtimeTriggeredLastTriggerTimes, rotationDuration);
            if ~isempty(runtimeReactionEvents)
                actionQueue = localSortActionEvents([runtimeReactionEvents, actionQueue]);
            end
            currentTime = intervalEndTime;
            if hasMidIntervalTimedReaction
                continue;
            end
        end

        if isempty(actionQueue)
            continue;
        end

        event = actionQueue(1);
        meta = localResolveEventMeta(event, archetypeInfo, teamContext);
        boundaryCatchCharacter = localResolveBoundaryCatchCharacter( ...
            activeForegroundCharacter, event, meta, actionQueue(2:end), ...
            archetypeInfo, teamContext, event.StartTime);
        actionQueue(1) = [];
        eventTriggerElement = string(getFieldOrDefault(meta, 'HitElement', event.HitElement));
        runtimeTriggeredWindows = localPruneExpiredActiveWindows(runtimeTriggeredWindows, event.StartTime);
        [energyState, pendingEnergyDrops, pendingEnergyRows] = localResolvePendingEnergyDrops( ...
            energyState, pendingEnergyDrops, activeForegroundCharacter, event.StartTime, boundaryCatchCharacter);
        if ~isempty(pendingEnergyRows)
            energyRows = [energyRows; pendingEnergyRows]; %#ok<AGROW>
        end
        deltaTime = max(0, event.StartTime - currentTime);

        hitDescriptor = struct( ...
            'HitElement', meta.HitElement, ...
            'ApplyElement', meta.ApplyElement, ...
            'ApplyGauge', meta.ApplyGauge, ...
            'ApplyGaugeSource', string(getFieldOrDefault(meta, 'ApplyGaugeSource', "")), ...
            'CanApplyAura', meta.CanApplyAura, ...
            'AllowAmplify', meta.AllowAmplify, ...
            'AllowCatalyze', meta.AllowCatalyze, ...
            'PreferredAura', meta.PreferredAura, ...
            'CanTriggerReaction', logical(getFieldOrDefault(meta, 'CanTriggerReaction', true)), ...
            'ResolveReactionAsDamage', logical(getFieldOrDefault(meta, 'ResolveReactionAsDamage', false)), ...
            'ForceReactionName', string(getFieldOrDefault(meta, 'ForceReactionName', "")), ...
            'ReactionElement', string(getFieldOrDefault(meta, 'ReactionElement', "")), ...
            'StrikeType', string(getFieldOrDefault(meta, 'StrikeType', "")), ...
            'ICDGroup', string(getFieldOrDefault(meta, 'ICDGroup', "")), ...
            'ICDRule', string(getFieldOrDefault(meta, 'ICDRule', "")), ...
            'ICDSource', string(getFieldOrDefault(meta, 'ICDSource', "")), ...
            'LunarisAttackName', string(getFieldOrDefault(meta, 'LunarisAttackName', "")), ...
            'LunarisDamageParam', string(getFieldOrDefault(meta, 'LunarisDamageParam', "")), ...
            'SourceType', string(getFieldOrDefault(event, 'SourceType', "MemberAction")), ...
            'SourceCharacter', string(getFieldOrDefault(event, 'Character', "")), ...
            'SourceAction', string(getFieldOrDefault(event, 'Action', "")));

        [hitDescriptor.CanApplyAura, auraICDStates, icdSnapshot] = localResolveTimelineAuraICD( ...
            auraICDStates, event, meta, deltaTime);
        hitDescriptor.StrikeType = string(getFieldOrDefault(icdSnapshot, 'StrikeType', hitDescriptor.StrikeType));
        hitDescriptor.ICDGroup = string(getFieldOrDefault(icdSnapshot, 'ICDGroup', hitDescriptor.ICDGroup));
        hitDescriptor.ICDRule = string(getFieldOrDefault(icdSnapshot, 'ICDRule', hitDescriptor.ICDRule));
        hitDescriptor.ICDSource = string(getFieldOrDefault(icdSnapshot, 'ICDSource', hitDescriptor.ICDSource));

        build = compiledBuilds{event.MemberIndex};
        reactionResult = resolveReactionForHit(enemyState, hitDescriptor, build, teamContext, enemy, 0);
        enemyState = reactionResult.EnemyState;

        [runtimeActionEvents, runtimeTriggeredWindows, runtimeTriggeredLastTriggerTimes] = ...
            localResolveBackgroundTriggeredEvents( ...
            event, meta, runtimeTriggeredWindows, ...
            runtimeTriggeredLastTriggerTimes, rotationDuration);
        if ~isempty(runtimeActionEvents)
            actionQueue = localSortActionEvents([actionQueue, runtimeActionEvents]);
        end

        directReactionPackets = localBuildDirectReactionTriggerPackets(reactionResult, event.EndTime, event, meta);
        [runtimeReactionEvents, runtimeTriggeredWindows, runtimeTriggeredLastTriggerTimes] = ...
            localResolveBackgroundReactionTriggeredEvents( ...
            directReactionPackets, event.EndTime, runtimeTriggeredWindows, ...
            runtimeTriggeredLastTriggerTimes, rotationDuration);
        if ~isempty(runtimeReactionEvents)
            actionQueue = localSortActionEvents([actionQueue, runtimeReactionEvents]);
        end

        if localShouldExpandBackgroundDrivers(meta, event)
            currentWindows = localBuildBackgroundDriverWindows(event, meta, rotationDuration);
            for windowIndex = 1:numel(currentWindows)
                currentWindow = currentWindows(windowIndex);
                if string(getFieldOrDefault(currentWindow, 'DriverKind', "")) == "Triggered"
                    runtimeTriggeredWindows(end + 1) = currentWindow; %#ok<AGROW>
                end
            end
        end

        [energyState, pendingEnergyDrops, currentEnergyRows, ownerEnergyDelta] = localApplyEnergyEvent( ...
            energyState, pendingEnergyDrops, event.MemberIndex, meta, event.EndTime, event.StartTime);
        if ~isempty(currentEnergyRows)
            energyRows = [energyRows; currentEnergyRows]; %#ok<AGROW>
        end

        if logical(getFieldOrDefault(meta, 'ConsumesActiveWindow', true))
            activeForegroundCharacter = event.Character;
        end

        [effectKind, effectMode, effectAction, effectInterval, effectCount] = ...
            localDescribeBackgroundDrivers(meta);
        displayDriverKind = string(getFieldOrDefault(meta, 'BackgroundDriverKind', ""));
        displayDriverMode = string(getFieldOrDefault(meta, 'BackgroundDriverMode', ""));
        if strlength(displayDriverKind) == 0
            displayDriverKind = effectKind;
        end
        if strlength(displayDriverMode) == 0
            displayDriverMode = effectMode;
        end

        if meta.EffectDuration > 0 && strlength(string(meta.EffectTag)) > 0
            effectRows(end + 1, :) = { ... %#ok<AGROW>
                event.Character, event.Action, meta.EffectTag, ...
                event.StartTime, min(rotationDuration, event.StartTime + meta.EffectDuration), ...
                event.MemberRole, effectKind, effectMode, effectAction, effectInterval, effectCount};
        end

        actionOrder = actionOrder + 1;
        timelineRows(end + 1, :) = { ... %#ok<AGROW>
            actionOrder, event.StartTime, event.EndTime, event.Character, activeForegroundCharacter, ...
            event.MemberRole, event.Action, string(getFieldOrDefault(event, 'SourceType', "MemberAction")), ...
            meta.ActionClass, meta.HitElement, meta.ApplyGauge, ...
            hitDescriptor.CanApplyAura, ...
            string(getFieldOrDefault(hitDescriptor, 'ApplyGaugeSource', "")), ...
            string(getFieldOrDefault(hitDescriptor, 'ICDRule', "")), ...
            string(getFieldOrDefault(hitDescriptor, 'ICDGroup', "")), ...
            string(getFieldOrDefault(hitDescriptor, 'ICDSource', "")), ...
            localJoinReactions(reactionResult.PrimaryReaction, reactionResult.TriggeredReactions), ...
            localAuraSummary(enemyState), localQuickenGauge(enemyState), ...
            localFrozenGauge(enemyState), localCoreCount(enemyState), ...
            ownerEnergyDelta, meta.EffectTag, logical(getFieldOrDefault(meta, 'ConsumesActiveWindow', true)), ...
            displayDriverKind, displayDriverMode, ...
            string(getFieldOrDefault(event, 'TriggerSourceType', "")), ...
            string(getFieldOrDefault(event, 'TriggerSourceCharacter', "")), ...
            string(getFieldOrDefault(event, 'TriggerSourceAction', "")), ...
            string(getFieldOrDefault(event, 'TriggerPacketSource', ""))};

        currentTime = max(currentTime, event.StartTime);
        if logical(getFieldOrDefault(meta, 'ConsumesActiveWindow', true))
            previousForegroundCharacter = event.Character;
            previousForegroundEndTime = event.EndTime;
            previousForegroundKnown = true;
        end
    end

    [energyState, pendingEnergyDrops, pendingEnergyRows] = localResolvePendingEnergyDrops( ...
        energyState, pendingEnergyDrops, activeForegroundCharacter, rotationDuration, "");
    if ~isempty(pendingEnergyRows)
        energyRows = [energyRows; pendingEnergyRows]; %#ok<AGROW>
    end
    rotationEndEnergyState = energyState;
    [~, projectedEnergyRows] = localResolvePostCyclePendingEnergyDrops( ...
        energyState, pendingEnergyDrops, activeForegroundCharacter, ...
        members, rotationPlan, archetypeInfo, teamContext, rotationDuration);
    if ~isempty(projectedEnergyRows)
        energyRows = [energyRows; projectedEnergyRows]; %#ok<AGROW>
    end

    timelineTable = localTimelineTable(timelineRows);
    energyTable = localBuildEnergySummaryTable(rotationEndEnergyState, energyRows, rotationPlan, rotationDuration);
    energyTimeline = localBuildEnergyTimelineTable(energyRows);
    activeEffectsTable = localBuildEffectTable(effectRows);
    timelineSummary = localBuildTimelineSummary(timelineTable, rotationDuration);
    memberTimelineTable = localBuildMemberTimelineTable(timelineTable, members);

    burstMask = energyTable.UsedBurst;
    if any(burstMask)
        canLoop = all(energyTable.CanBurstOnNextWindow(burstMask));
        loopReadiness = min(energyTable.NextWindowReadiness(burstMask));
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
        tokens = localExpandCharacterActionTokens(tokens, members{i});
        disableRuntimeExpansion = localPlanHasExplicitFollowUpTokens(tokens);

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
            event.DisableRuntimeBackgroundExpansion = disableRuntimeExpansion;
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

function tokens = localExpandCharacterActionTokens(tokens, member)
    if nargin < 1 || isempty(tokens)
        tokens = cell(0, 1);
        return;
    end
    if nargin < 2
        member = struct();
    end

    characterName = lower(char(string(getFieldOrDefault(member, 'Name', ""))));
    constellation = double(getFieldOrDefault(member, 'Constellation', 0));
    expanded = cell(0, 1);
    for tokenIndex = 1:numel(tokens)
        token = string(tokens{tokenIndex});
        appendList = {char(token)};
        switch characterName
            case 'varka'
                appendList = localExpandVarkaTimelineToken(token, constellation);
        end
        expanded = [expanded; appendList(:)]; %#ok<AGROW>
    end
    tokens = expanded;
end

function appendList = localExpandVarkaTimelineToken(token, constellation)
    normalized = upper(strtrim(char(string(token))));
    switch normalized
        case {'ASCEND', 'FWA'}
            appendList = {'FourWindsRight', 'FourWindsAnemo'};
            if constellation >= 2
                appendList{end + 1} = 'FourWindsC2'; %#ok<AGROW>
            end
        case {'DEVOUR', 'AD'}
            appendList = {'AzureDevourRight1', 'AzureDevourAnemo1', 'AzureDevourRight2', 'AzureDevourAnemo2'};
            if constellation >= 2
                appendList{end + 1} = 'AzureDevourC2'; %#ok<AGROW>
            end
        case {'Q', 'BURST'}
            appendList = {'Q1', 'Q2'};
        otherwise
            appendList = {char(token)};
    end
end

function actionEvents = localExpandActionEventsWithBackgroundDrivers(actionEvents, rotationPlan, archetypeInfo, teamContext, rotationDuration)
    if isempty(actionEvents)
        return;
    end

    expandedEvents = repmat(localEmptyEvent(), 1, 0);

    for i = 1:numel(actionEvents)
        event = actionEvents(i);
        meta = localResolveEventMeta(event, archetypeInfo, teamContext);
        event.CombatMeta = meta;

        expandedEvents(end + 1) = event; %#ok<AGROW>

        if ~localShouldExpandBackgroundDrivers(meta, event)
            continue;
        end

        windows = localBuildBackgroundDriverWindows(event, meta, rotationDuration);
        for j = 1:numel(windows)
            window = windows(j);
            if string(getFieldOrDefault(window, 'DriverKind', "")) ~= "Triggered"
                driverEvents = localBuildAutonomousBackgroundEvents(window, rotationDuration);
                for k = 1:numel(driverEvents)
                    expandedEvents(end + 1) = driverEvents(k); %#ok<AGROW>
                end
            end
        end
    end

    actionEvents = localSortActionEvents(expandedEvents);
end

function meta = localResolveEventMeta(event, archetypeInfo, teamContext)
    meta = getFieldOrDefault(event, 'CombatMeta', struct());
    if isstruct(meta) && ~isempty(fieldnames(meta))
        return;
    end
    meta = inferActionCombatMetadata(event.Member, event.Action, archetypeInfo, teamContext);
end

function [stopTime, hasMidIntervalTimedReaction] = localResolveNextIntervalStopTime( ...
        enemyState, startTime, targetTime, triggerElement, teamContext)
    stopTime = double(targetTime);
    hasMidIntervalTimedReaction = false;
    if stopTime <= double(startTime) + 1e-9
        return;
    end

    [~, probePackets] = advanceEnemyStateTime(enemyState, stopTime - double(startTime), triggerElement, teamContext);
    if isempty(probePackets)
        return;
    end

    triggerTimes = arrayfun(@(packet) double(getFieldOrDefault(packet, 'TriggerTime', NaN)), probePackets);
    triggerTimes = triggerTimes(isfinite(triggerTimes) ...
        & triggerTimes > double(startTime) + 1e-9 ...
        & triggerTimes < double(targetTime) - 1e-9);
    if isempty(triggerTimes)
        return;
    end

    stopTime = min(triggerTimes);
    hasMidIntervalTimedReaction = true;
end

function [gapWindow, gapLabel] = localResolveIntervalGapWindow( ...
        currentTime, intervalEndTime, nextEvent, nextMeta, previousForegroundKnown, ...
        previousForegroundCharacter, previousForegroundEndTime, rotationDuration)
    gapWindow = [NaN, NaN];
    gapLabel = "";
    if strlength(string(getFieldOrDefault(nextEvent, 'Character', ""))) == 0
        tailStart = currentTime;
        if previousForegroundKnown
            tailStart = max(tailStart, previousForegroundEndTime);
        end
        gapWindow = [tailStart, min(rotationDuration, intervalEndTime)];
        gapLabel = "Tail";
        return;
    end

    if previousForegroundKnown && logical(getFieldOrDefault(nextMeta, 'ConsumesActiveWindow', true)) ...
            && previousForegroundCharacter ~= "" ...
            && string(getFieldOrDefault(nextEvent, 'Character', "")) ~= previousForegroundCharacter ...
            && double(getFieldOrDefault(nextEvent, 'StartTime', intervalEndTime)) - previousForegroundEndTime > 1e-9
        gapWindow = [max(currentTime, previousForegroundEndTime), double(getFieldOrDefault(nextEvent, 'StartTime', intervalEndTime))];
        gapLabel = "Swap";
    end
end

function [canApplyAura, icdStates, snapshot] = localResolveTimelineAuraICD(icdStates, event, meta, deltaTime)
    if nargin < 4 || isempty(deltaTime)
        deltaTime = 0;
    end

    snapshot = struct( ...
        'ICDGroup', string(getFieldOrDefault(meta, 'ICDGroup', "")), ...
        'ICDRule', string(getFieldOrDefault(meta, 'ICDRule', "")), ...
        'ICDHits', 1, ...
        'ICDWindow', 0, ...
        'StrikeType', string(getFieldOrDefault(meta, 'StrikeType', "")), ...
        'ICDSource', string(getFieldOrDefault(meta, 'ICDSource', "")));
    canApplyAura = logical(getFieldOrDefault(meta, 'CanApplyAura', false)) ...
        && double(getFieldOrDefault(meta, 'ApplyGauge', 0)) > 0 ...
        && localIsElementalDamageElement(string(getFieldOrDefault(meta, 'ApplyElement', "")));

    if ~canApplyAura
        return;
    end

    icdRule = string(getFieldOrDefault(meta, 'ICDRule', ""));
    if strlength(icdRule) == 0 || strcmpi(char(icdRule), 'independent')
        if strlength(snapshot.ICDSource) == 0
            snapshot.ICDSource = "not_applicable";
        end
        return;
    end

    [icdHits, icdWindow, isWindowed] = localParseICDRuleText(icdRule);
    snapshot.ICDHits = icdHits;
    snapshot.ICDWindow = icdWindow;
    if ~isWindowed
        return;
    end

    icdGroup = string(getFieldOrDefault(meta, 'ICDGroup', ""));
    if strlength(icdGroup) == 0
        icdGroup = string(getFieldOrDefault(meta, 'LunarisAttackName', ""));
    end
    if strlength(icdGroup) == 0
        icdGroup = string(getFieldOrDefault(event, 'Character', "")) + "_" + string(getFieldOrDefault(event, 'Action', ""));
    end
    snapshot.ICDGroup = icdGroup;

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

function [hits, window, isWindowed] = localParseICDRuleText(ruleText)
    ruleText = lower(char(string(ruleText)));
    hits = 1;
    window = 0;
    isWindowed = false;
    if isempty(ruleText) || strcmp(ruleText, '-') || contains(ruleText, 'independent')
        return;
    end
    if contains(ruleText, 'standard')
        hits = 3;
        window = 2.5;
        isWindowed = true;
        return;
    end
    tokens = regexp(ruleText, '(\d+)\s*hits?\s*/\s*([\d\.]+)\s*s', 'tokens', 'once');
    if isempty(tokens)
        return;
    end
    hits = max(1, str2double(tokens{1}));
    window = max(0, str2double(tokens{2}));
    isWindowed = true;
end

function tf = localIsElementalDamageElement(element)
    switch lower(char(string(element)))
        case {'pyro', 'hydro', 'cryo', 'electro', 'anemo', 'geo', 'dendro'}
            tf = true;
        otherwise
            tf = false;
    end
end

function tf = localShouldExpandBackgroundDrivers(meta, sourceInfo)
    specs = localCollectBackgroundDriverSpecs(meta);
    if isempty(specs)
        tf = false;
        return;
    end
    if nargin >= 2 && logical(getFieldOrDefault(sourceInfo, 'DisableRuntimeBackgroundExpansion', false))
        tf = false;
        return;
    end
    % Expand runtime background windows unless the rotation already lists explicit follow-up tokens.
    tf = true;
end

function tf = localPlanHasExplicitFollowUpTokens(tokens)
    explicitActions = ["duckywaterball", "duckywaterballc2", ...
        "meowball", "meowbounce", "robot", "robotstrike"];
    patterns = {'rain', 'throw', 'chain', 'radish', 'spirit', 'pyronado', 'doll', ...
        'projection', 'phantom', 'pathfinder', 'moon', 'star', 'skull', 'usher', ...
        'cheval', 'crab', 'loop', 'field', 'wave', 'slash', 'connector', 'spring', ...
        'song', 'bolt', 'arkhe', 'summon', 'mark', 'dice', 'spore', 'blossom', 'debt', ...
        'sanctuary', 'phantasm', 'herald', 'stellar', 'icicle', 'blade', 'drill', ...
        'oz', 'eye', 'pillar', 'ring', 'source', 'trikarma', 'starwicker', ...
        'casehit', 'thorn', 'scenteddew', 'lumidoucecase', 'aromaticexplication', ...
        'collapse', 'geowave', 'qdot', 'qinfuse', 'qoz', 'mirror'};
    tf = false;
    for tokenIndex = 1:numel(tokens)
        action = lower(char(string(tokens{tokenIndex})));
        if any(strcmp(action, explicitActions))
            tf = true;
            return;
        end
        for patternIndex = 1:numel(patterns)
            if contains(action, patterns{patternIndex})
                tf = true;
                return;
            end
        end
    end
end

function specs = localCollectBackgroundDriverSpecs(meta)
    specs = repmat(localEmptyBackgroundDriverSpec(), 1, 0);

    followUpAction = string(getFieldOrDefault(meta, 'TriggeredFollowUpAction', ""));
    tickAction = string(getFieldOrDefault(meta, 'EffectTickAction', ""));
    tickCount = double(getFieldOrDefault(meta, 'EffectTickCount', 0));
    tickInterval = double(getFieldOrDefault(meta, 'EffectTickInterval', 0));
    effectDuration = double(getFieldOrDefault(meta, 'EffectDuration', 0));
    if strlength(tickAction) > 0 && tickCount > 0 && tickInterval > 0 && effectDuration > 0 ...
            && ~localShouldSkipAutonomousTickSpec(meta)
        autonomousMode = localResolveAutonomousBackgroundDriverMode(meta);
        spec = localEmptyBackgroundDriverSpec();
        spec.DriverKind = "Autonomous";
        spec.DriverMode = autonomousMode;
        spec.Action = tickAction;
        spec.Element = string(getFieldOrDefault(meta, 'EffectTickElement', ""));
        spec.PreferredAura = string(getFieldOrDefault(meta, 'EffectTickPreferredAura', ""));
        spec.FirstDelay = double(getFieldOrDefault(meta, 'EffectFirstTickDelay', 0));
        spec.Interval = tickInterval;
        spec.Count = tickCount;
        spec.Gauge = double(getFieldOrDefault(meta, 'EffectTickGauge', 0));
        specs(end + 1) = spec; %#ok<AGROW>
    end

    followUpMode = localResolveTriggeredBackgroundDriverMode(meta);
    if strlength(followUpAction) > 0 && effectDuration > 0
        spec = localEmptyBackgroundDriverSpec();
        spec.DriverKind = "Triggered";
        spec.DriverMode = followUpMode;
        spec.Action = followUpAction;
        spec.Element = string(getFieldOrDefault(meta, 'TriggeredFollowUpElement', ""));
        spec.PreferredAura = string(getFieldOrDefault(meta, 'TriggeredFollowUpPreferredAura', ""));
        spec.FirstDelay = double(getFieldOrDefault(meta, 'TriggeredFollowUpDelay', 0));
        spec.Gauge = double(getFieldOrDefault(meta, 'TriggeredFollowUpGauge', 0));
        spec.InternalCooldown = double(getFieldOrDefault(meta, 'TriggeredFollowUpInternalCooldown', 0));
        spec.EligibleClasses = string(getFieldOrDefault(meta, 'TriggeredFollowUpEligibleClasses', strings(1, 0)));
        spec.ForegroundOnly = logical(getFieldOrDefault(meta, 'TriggeredFollowUpForegroundOnly', true));
        spec.MaxTriggers = double(getFieldOrDefault(meta, 'TriggeredFollowUpMaxCount', inf));
        specs(end + 1) = spec; %#ok<AGROW>
    end

    additionalProfiles = getFieldOrDefault(meta, 'AdditionalTriggeredFollowUpProfiles', repmat(localEmptyTriggeredFollowUpProfile(), 1, 0));
    for profileIndex = 1:numel(additionalProfiles)
        profile = additionalProfiles(profileIndex);
        if strlength(string(getFieldOrDefault(profile, 'Action', ""))) == 0 || effectDuration <= 0
            continue;
        end
        spec = localEmptyBackgroundDriverSpec();
        spec.DriverKind = "Triggered";
        spec.DriverMode = string(getFieldOrDefault(profile, 'DriverMode', localResolveTriggeredBackgroundDriverMode(meta)));
        spec.Action = string(getFieldOrDefault(profile, 'Action', ""));
        spec.Element = string(getFieldOrDefault(profile, 'Element', ""));
        spec.PreferredAura = string(getFieldOrDefault(profile, 'PreferredAura', ""));
        spec.FirstDelay = double(getFieldOrDefault(profile, 'Delay', 0));
        spec.Gauge = double(getFieldOrDefault(profile, 'Gauge', 0));
        spec.InternalCooldown = double(getFieldOrDefault(profile, 'InternalCooldown', 0));
        spec.EligibleClasses = string(getFieldOrDefault(profile, 'EligibleClasses', strings(1, 0)));
        spec.ForegroundOnly = logical(getFieldOrDefault(profile, 'ForegroundOnly', true));
        spec.MaxTriggers = double(getFieldOrDefault(profile, 'MaxCount', inf));
        spec.AllowedReactionNames = string(getFieldOrDefault(profile, 'AllowedReactionNames', strings(1, 0)));
        spec.AllowedPacketSources = string(getFieldOrDefault(profile, 'AllowedPacketSources', strings(1, 0)));
        spec.RequireForegroundTrigger = logical(getFieldOrDefault(profile, 'RequireForegroundTrigger', false));
        specs(end + 1) = spec; %#ok<AGROW>
    end
end

function tf = localShouldSkipAutonomousTickSpec(meta)
    tag = lower(char(string(getFieldOrDefault(meta, 'EffectTag', ""))));
    switch tag
        case 'seedofskandha'
            tf = true;
        otherwise
            tf = false;
    end
end

function mode = localResolveAutonomousBackgroundDriverMode(meta)
    tag = lower(char(string(getFieldOrDefault(meta, 'EffectTag', ""))));
    switch tag
        case {'stonestele', 'autumnwhirlwind'}
            mode = "FieldPulse";
        case {'sesshousakura', 'oz', 'kurage', 'guoba', 'cuileinanbar', ...
                'lumidoucecase', 'aromaticexplication', 'yuegui', 'adeptallegacy', 'turbotwirly'}
            mode = "SummonPeriodic";
        case {'salonmembers', 'tamoto'}
            mode = "CompanionPeriodic";
        case {'pyronado', 'heraldoffrost', 'sanctifyingring', 'seamlessshield', 'glacialwaltz'}
            mode = "OrbitingPeriodic";
        otherwise
            mode = "AutonomousTick";
    end
end

function mode = localResolveTriggeredBackgroundDriverMode(meta)
    tag = lower(char(string(getFieldOrDefault(meta, 'EffectTag', ""))));
    eligibleClasses = string(getFieldOrDefault(meta, 'TriggeredFollowUpEligibleClasses', strings(1, 0)));
    if any(strcmpi(cellstr(eligibleClasses(:)), 'Reaction'))
        mode = "ReactionEventTrigger";
        return;
    end
    switch tag
        case {'rainswords', 'exquisitethrow'}
            mode = "ForegroundNormalTrigger";
        case {'stormbreaker'}
            mode = "ForegroundNormalChargedTrigger";
        case {'eyeofstormyjudgment'}
            mode = "ForegroundAnyActionTrigger";
        case {'seedofskandha'}
            mode = "ReactionEventTrigger";
        otherwise
            eligibleClasses = string(getFieldOrDefault(meta, 'TriggeredFollowUpEligibleClasses', strings(1, 0)));
            eligibleCells = cellstr(eligibleClasses(:));
            hasNormal = any(strcmpi(eligibleCells, 'Normal'));
            hasCharged = any(strcmpi(eligibleCells, 'Charged'));
            hasPlunge = any(strcmpi(eligibleCells, 'Plunge'));
            hasSkill = any(strcmpi(eligibleCells, 'Skill'));
            hasBurst = any(strcmpi(eligibleCells, 'Burst'));
            if hasNormal && ~(hasCharged || hasPlunge || hasSkill || hasBurst)
                mode = "ForegroundNormalTrigger";
            elseif hasCharged && ~(hasNormal || hasPlunge || hasSkill || hasBurst)
                mode = "ForegroundChargedTrigger";
            elseif hasPlunge && ~(hasNormal || hasCharged || hasSkill || hasBurst)
                mode = "ForegroundPlungeTrigger";
            elseif hasNormal && hasCharged && ~(hasPlunge || hasSkill || hasBurst)
                mode = "ForegroundNormalChargedTrigger";
            elseif (hasNormal || hasCharged || hasPlunge) && ~(hasSkill || hasBurst)
                mode = "ForegroundAttackTrigger";
            else
                mode = "ForegroundAnyActionTrigger";
            end
    end
end

function windows = localBuildBackgroundDriverWindows(baseEvent, baseMeta, rotationDuration)
    windows = repmat(localEmptyActiveWindow(), 1, 0);
    specs = localCollectBackgroundDriverSpecs(baseMeta);
    if isempty(specs)
        return;
    end

    duration = double(getFieldOrDefault(baseMeta, 'EffectDuration', 0));
    if duration <= 0
        return;
    end

    effectEndTime = min(rotationDuration, baseEvent.StartTime + duration);
    for i = 1:numel(specs)
        window = localEmptyActiveWindow();
        window.MemberIndex = baseEvent.MemberIndex;
        window.Member = baseEvent.Member;
        window.Character = baseEvent.Character;
        window.MemberRole = baseEvent.MemberRole;
        window.EffectTag = string(getFieldOrDefault(baseMeta, 'EffectTag', ""));
        window.StartTime = baseEvent.StartTime;
        window.EndTime = effectEndTime;
        window.Meta = baseMeta;
        window.DriverKind = string(specs(i).DriverKind);
        window.DriverMode = string(specs(i).DriverMode);
        window.DriverSpec = specs(i);
        window.RemainingTriggers = double(getFieldOrDefault(specs(i), 'MaxTriggers', inf));
        windows(end + 1) = window; %#ok<AGROW>
    end
end

function [driverEvents, activeWindows, lastTriggerTimes] = localResolveBackgroundTriggeredEvents( ...
        driverEvent, driverMeta, activeWindows, lastTriggerTimes, rotationDuration)
    driverEvents = repmat(localEmptyEvent(), 1, 0);
    driverClass = string(getFieldOrDefault(driverMeta, 'ActionClass', ""));
    if strlength(driverClass) == 0
        return;
    end

    for i = 1:numel(activeWindows)
        window = activeWindows(i);
        if string(getFieldOrDefault(window, 'DriverKind', "")) ~= "Triggered"
            continue;
        end
        driverSpec = getFieldOrDefault(window, 'DriverSpec', localEmptyBackgroundDriverSpec());
        driverMode = string(getFieldOrDefault(driverSpec, 'DriverMode', ""));
        if driverMode == "ReactionEventTrigger"
            continue;
        end
        remainingTriggers = double(getFieldOrDefault(window, 'RemainingTriggers', inf));
        if isfinite(remainingTriggers) && remainingTriggers <= 0
            continue;
        end

        % Filter by driver mode first, then apply any driver-specific eligible classes.
        if driverMode == "ForegroundNormalTrigger" && driverClass ~= "Normal"
            continue;
        elseif driverMode == "ForegroundChargedTrigger" && driverClass ~= "Charged"
            continue;
        elseif driverMode == "ForegroundPlungeTrigger" && driverClass ~= "Plunge"
            continue;
        elseif driverMode == "ForegroundNormalChargedTrigger" ...
                && ~any(strcmpi(char(driverClass), {'Normal', 'Charged'}))
            continue;
        elseif driverMode == "ForegroundAttackTrigger" ...
                && ~any(strcmpi(char(driverClass), {'Normal', 'Charged', 'Plunge'}))
            continue;
        elseif driverMode == "ForegroundActionTrigger" ...
                && ~any(strcmpi(char(driverClass), {'Normal', 'Charged', 'Plunge', 'Skill', 'Burst'}))
            continue;
        elseif any(driverMode == ["ForegroundAnyActionTrigger", "ForegroundAnyHitTrigger"]) ...
                && any(strcmpi(char(driverClass), {'Utility', 'Reaction'}))
            continue;
        end

        if driverEvent.StartTime + 1e-9 < window.StartTime || driverEvent.StartTime > window.EndTime + 1e-9
            continue;
        end

        eligibleClasses = string(getFieldOrDefault(driverSpec, 'EligibleClasses', strings(1, 0)));
        if ~isempty(eligibleClasses) && ~any(strcmpi(char(driverClass), cellstr(eligibleClasses(:))))
            continue;
        end
        if logical(getFieldOrDefault(driverSpec, 'ForegroundOnly', true)) ...
                && ~logical(getFieldOrDefault(driverMeta, 'ConsumesActiveWindow', true))
            continue;
        end

        key = localBuildBackgroundTriggerKey(window, driverSpec);
        icd = double(getFieldOrDefault(driverSpec, 'InternalCooldown', 0));
        lastTime = -inf;
        if isKey(lastTriggerTimes, key)
            lastTime = lastTriggerTimes(key);
        end
        if driverEvent.StartTime - lastTime < icd - 1e-9
            continue;
        end

        driverEvents(end + 1) = localBuildTriggeredFollowUpEvent( ... %#ok<AGROW>
            window, window.Meta, driverEvent, rotationDuration, driverSpec);
        lastTriggerTimes(key) = driverEvent.StartTime;
        if isfinite(remainingTriggers)
            activeWindows(i).RemainingTriggers = max(0, remainingTriggers - 1);
        end
    end
end

function [driverEvents, activeWindows, lastTriggerTimes] = localResolveBackgroundReactionTriggeredEvents( ...
        reactionPackets, fallbackTriggerTime, activeWindows, lastTriggerTimes, rotationDuration)
    driverEvents = repmat(localEmptyEvent(), 1, 0);
    if isempty(reactionPackets) || isempty(activeWindows)
        return;
    end

    for packetIndex = 1:numel(reactionPackets)
        packet = reactionPackets(packetIndex);
        reactionName = string(getFieldOrDefault(packet, 'ReactionName', ""));
        if strlength(reactionName) == 0
            continue;
        end

        triggerTime = double(getFieldOrDefault(packet, 'TriggerTime', fallbackTriggerTime));
        if ~isfinite(triggerTime)
            triggerTime = fallbackTriggerTime;
        end
        triggerTime = min(rotationDuration, max(0, triggerTime));

        for windowIndex = 1:numel(activeWindows)
            window = activeWindows(windowIndex);
            if ~localWindowNeedsRuntimeReactionResolution(window)
                continue;
            end
            if triggerTime + 1e-9 < window.StartTime || triggerTime > window.EndTime + 1e-9
                continue;
            end

            driverSpec = getFieldOrDefault(window, 'DriverSpec', localEmptyBackgroundDriverSpec());
            remainingTriggers = double(getFieldOrDefault(window, 'RemainingTriggers', inf));
            if isfinite(remainingTriggers) && remainingTriggers <= 0
                continue;
            end
            if logical(getFieldOrDefault(driverSpec, 'RequireForegroundTrigger', false)) ...
                    && ~logical(getFieldOrDefault(packet, 'SourceConsumesActiveWindow', false))
                continue;
            end
            allowedReactionNames = string(getFieldOrDefault(driverSpec, 'AllowedReactionNames', strings(1, 0)));
            if ~isempty(allowedReactionNames) && ~any(strcmpi(char(reactionName), cellstr(allowedReactionNames(:))))
                continue;
            end
            allowedPacketSources = string(getFieldOrDefault(driverSpec, 'AllowedPacketSources', strings(1, 0)));
            packetSource = string(getFieldOrDefault(packet, 'PacketSource', ""));
            if ~isempty(allowedPacketSources) && ~any(strcmpi(char(packetSource), cellstr(allowedPacketSources(:))))
                continue;
            end
            key = localBuildBackgroundTriggerKey(window, driverSpec);
            icd = double(getFieldOrDefault(driverSpec, 'InternalCooldown', 0));
            lastTime = -inf;
            if isKey(lastTriggerTimes, key)
                lastTime = lastTriggerTimes(key);
            end
            if triggerTime - lastTime < icd - 1e-9
                continue;
            end

            triggerEvent = localEmptyEvent();
            triggerEvent.Action = reactionName;
            triggerEvent.SourceType = "ReactionTrigger";
            triggerEvent.StartTime = triggerTime;
            triggerEvent.EndTime = triggerTime;
            triggerEvent.TriggerSourceType = string(getFieldOrDefault(packet, 'SourceType', "ReactionPacket"));
            triggerEvent.TriggerSourceCharacter = string(getFieldOrDefault(packet, 'SourceCharacter', ""));
            triggerEvent.TriggerSourceAction = string(getFieldOrDefault(packet, 'SourceAction', reactionName));
            triggerEvent.TriggerPacketSource = string(getFieldOrDefault(packet, 'PacketSource', ""));
            driverEvents(end + 1) = localBuildTriggeredFollowUpEvent( ... %#ok<AGROW>
                window, window.Meta, triggerEvent, rotationDuration, driverSpec);
            lastTriggerTimes(key) = triggerTime;
            if isfinite(remainingTriggers)
                activeWindows(windowIndex).RemainingTriggers = max(0, remainingTriggers - 1);
            end
        end
    end
end

function driverEvents = localBuildAutonomousBackgroundEvents(window, rotationDuration)
    driverEvents = repmat(localEmptyEvent(), 1, 0);
    driverSpec = getFieldOrDefault(window, 'DriverSpec', localEmptyBackgroundDriverSpec());
    tickCount = double(getFieldOrDefault(driverSpec, 'Count', 0));
    tickInterval = double(getFieldOrDefault(driverSpec, 'Interval', 0));
    firstTickDelay = double(getFieldOrDefault(driverSpec, 'FirstDelay', 0));
    if tickCount <= 0 || tickInterval <= 0
        return;
    end

    for tickIndex = 1:tickCount
        tickTime = window.StartTime + firstTickDelay + (tickIndex - 1) * tickInterval;
        if tickTime > window.EndTime + 1e-9 || tickTime >= rotationDuration - 1e-9
            break;
        end
        driverEvents(end + 1) = localBuildSyntheticEffectTickEvent( ... %#ok<AGROW>
            window, window.Meta, tickIndex, tickTime, rotationDuration, driverSpec);
    end
end

function tf = localWindowNeedsRuntimeReactionResolution(window)
    tf = string(getFieldOrDefault(window, 'DriverKind', "")) == "Triggered" ...
        && string(getFieldOrDefault(window, 'DriverMode', "")) == "ReactionEventTrigger";
end

function tf = localIsReactionTriggeredBackgroundEvent(row)
    tf = false;
    if ~isfield(row, 'SourceType')
        return;
    end
    if string(getFieldOrDefault(row, 'SourceType', "")) ~= "TriggeredFollowUp"
        return;
    end
    if isfield(row, 'BackgroundDriverMode') && string(getFieldOrDefault(row, 'BackgroundDriverMode', "")) == "ReactionEventTrigger"
        tf = true;
        return;
    end
    if isfield(row, 'TriggerSourceType') && string(getFieldOrDefault(row, 'TriggerSourceType', "")) == "ReactionPacket"
        tf = true;
    end
end

function key = localBuildBackgroundTriggerKey(window, driverSpec)
    % Build a per-window trigger key so different background windows do not share ICD state.
    key = char(lower(string(getFieldOrDefault(window, 'Character', "")) + ":" ...
        + string(getFieldOrDefault(window, 'StartTime', 0)) + ":" ...
        + string(getFieldOrDefault(window, 'EndTime', 0)) + ":" ...
        + string(getFieldOrDefault(window, 'EffectTag', "")) + ":" ...
        + string(getFieldOrDefault(driverSpec, 'Action', "")) + ":" ...
        + string(getFieldOrDefault(driverSpec, 'DriverMode', ""))));
end

function [driverKind, driverMode, driverAction, driverInterval, driverCount] = localDescribeBackgroundDrivers(meta)
    specs = localCollectBackgroundDriverSpecs(meta);
    if isempty(specs)
        driverKind = "";
        driverMode = "";
        driverAction = "";
        driverInterval = 0;
        driverCount = 0;
        return;
    end

    driverKind = join(unique(string({specs.DriverKind}), 'stable'), ", ");
    driverMode = join(unique(string({specs.DriverMode}), 'stable'), ", ");
    driverAction = join(unique(string({specs.Action}), 'stable'), ", ");
    if numel(specs) == 1
        spec = specs(1);
        if string(spec.DriverKind) == "Autonomous"
            driverInterval = double(getFieldOrDefault(spec, 'Interval', 0));
            driverCount = double(getFieldOrDefault(spec, 'Count', 0));
        else
            driverInterval = double(getFieldOrDefault(spec, 'InternalCooldown', 0));
            if isfinite(double(getFieldOrDefault(spec, 'MaxTriggers', inf)))
                driverCount = double(getFieldOrDefault(spec, 'MaxTriggers', inf));
            else
                driverCount = NaN;
            end
        end
    else
        driverInterval = NaN;
        driverCount = NaN;
    end
end

function activeWindows = localPruneExpiredActiveWindows(activeWindows, currentTime)
    if isempty(activeWindows)
        return;
    end
    keepMask = false(1, numel(activeWindows));
    for i = 1:numel(activeWindows)
        remainingTriggers = double(getFieldOrDefault(activeWindows(i), 'RemainingTriggers', inf));
        keepMask(i) = currentTime <= activeWindows(i).EndTime + 1e-9 ...
            && (~isfinite(remainingTriggers) || remainingTriggers > 0);
    end
    activeWindows = activeWindows(keepMask);
end

function packets = localBuildDirectReactionTriggerPackets(reactionResult, triggerTime, sourceEvent, sourceMeta)
    packets = repmat(localEmptyReactionPacket(), 1, 0);
    if nargin < 2 || isempty(triggerTime) || ~isfinite(triggerTime)
        triggerTime = NaN;
    end
    if nargin < 3 || isempty(sourceEvent)
        sourceEvent = struct();
    end
    if nargin < 4 || isempty(sourceMeta)
        sourceMeta = struct();
    end

    reactionNames = strings(0, 1);
    primaryReaction = string(getFieldOrDefault(reactionResult, 'PrimaryReaction', ""));
    if strlength(primaryReaction) > 0
        reactionNames(end + 1, 1) = primaryReaction; %#ok<AGROW>
    end
    triggered = string(getFieldOrDefault(reactionResult, 'TriggeredReactions', strings(0, 1)));
    if ~isempty(triggered)
        reactionNames = [reactionNames; triggered(:)]; %#ok<AGROW>
    end
    reactionNames = localUniqueReactionNames(reactionNames);
    if isempty(reactionNames)
        return;
    end

    for i = 1:numel(reactionNames)
        packet = localEmptyReactionPacket();
        packet.ReactionName = reactionNames(i);
        packet.TriggerTime = triggerTime;
        packet.PacketSource = "DirectHitReaction";
        packet.SourceType = string(getFieldOrDefault(sourceEvent, 'SourceType', "MemberAction"));
        packet.SourceCharacter = string(getFieldOrDefault(sourceEvent, 'Character', ""));
        packet.SourceAction = string(getFieldOrDefault(sourceEvent, 'Action', ""));
        packet.SourceConsumesActiveWindow = logical(getFieldOrDefault(sourceMeta, 'ConsumesActiveWindow', true));
        packets(end + 1) = packet; %#ok<AGROW>
    end
end

function event = localBuildTriggeredFollowUpEvent(window, sourceMeta, driverEvent, rotationDuration, driverSpec)
    if nargin < 5 || isempty(driverSpec)
        driverSpec = localEmptyBackgroundDriverSpec();
    end
    event = localEmptyEvent();
    event.MemberIndex = window.MemberIndex;
    event.Member = window.Member;
    event.Character = window.Character;
    event.MemberRole = window.MemberRole;
    event.SourceType = "TriggeredFollowUp";
    event.Action = string(getFieldOrDefault(driverSpec, 'Action', getFieldOrDefault(sourceMeta, 'TriggeredFollowUpAction', "")));
    event.StartTime = min(rotationDuration, driverEvent.EndTime + double(getFieldOrDefault(driverSpec, 'FirstDelay', getFieldOrDefault(sourceMeta, 'TriggeredFollowUpDelay', 0.08))));
    event.EndTime = min(rotationDuration, event.StartTime + 0.02);
    event.Duration = max(0, event.EndTime - event.StartTime);
    event.HitElement = string(getFieldOrDefault(driverSpec, 'Element', ...
        getFieldOrDefault(sourceMeta, 'TriggeredFollowUpElement', ...
        getFieldOrDefault(sourceMeta, 'ApplyElement', getFieldOrDefault(sourceMeta, 'HitElement', "")))));
    event.TriggerSourceType = string(getFieldOrDefault(driverEvent, 'TriggerSourceType', getFieldOrDefault(driverEvent, 'SourceType', "")));
    event.TriggerSourceCharacter = string(getFieldOrDefault(driverEvent, 'TriggerSourceCharacter', getFieldOrDefault(driverEvent, 'Character', "")));
    event.TriggerSourceAction = string(getFieldOrDefault(driverEvent, 'TriggerSourceAction', getFieldOrDefault(driverEvent, 'Action', "")));
    event.TriggerPacketSource = string(getFieldOrDefault(driverEvent, 'TriggerPacketSource', getFieldOrDefault(driverEvent, 'PacketSource', "")));

    followUpMeta = sourceMeta;
    followUpMeta.Action = event.Action;
    followUpMeta.ActionClass = "FollowUp";
    followUpMeta.ConsumesActiveWindow = false;
    if strlength(string(getFieldOrDefault(driverSpec, 'Element', ""))) > 0
        followUpMeta.HitElement = string(getFieldOrDefault(driverSpec, 'Element', followUpMeta.HitElement));
        followUpMeta.ApplyElement = followUpMeta.HitElement;
    end
    followUpMeta.ApplyGauge = double(getFieldOrDefault(driverSpec, 'Gauge', getFieldOrDefault(sourceMeta, 'TriggeredFollowUpGauge', getFieldOrDefault(sourceMeta, 'EffectTickGauge', 0))));
    followUpMeta.CanApplyAura = followUpMeta.ApplyGauge > 0 && strlength(string(followUpMeta.ApplyElement)) > 0;
    followUpMeta.PreferredAura = string(getFieldOrDefault(driverSpec, 'PreferredAura', getFieldOrDefault(sourceMeta, 'TriggeredFollowUpPreferredAura', getFieldOrDefault(sourceMeta, 'PreferredAura', ""))));
    followUpMeta.EstimatedParticles = 0;
    followUpMeta.EstimatedOrbs = 0;
    followUpMeta.FlatEnergySelf = 0;
    followUpMeta.FlatEnergyTeam = 0;
    followUpMeta.ConsumesBurstEnergy = false;
    followUpMeta.BurstCost = 0;
    followUpMeta.EffectDuration = 0;
    followUpMeta.EffectFirstTickDelay = 0;
    followUpMeta.EffectTickInterval = 0;
    followUpMeta.EffectTickCount = 0;
    followUpMeta.EffectTickAction = "";
    followUpMeta.EffectTickGauge = 0;
    followUpMeta.TriggeredFollowUpAction = "";
    followUpMeta.TriggeredFollowUpDelay = 0;
    followUpMeta.TriggeredFollowUpGauge = 0;
    followUpMeta.TriggeredFollowUpInternalCooldown = 0;
    followUpMeta.TriggeredFollowUpEligibleClasses = strings(1, 0);
    followUpMeta.TriggeredFollowUpForegroundOnly = false;
    followUpMeta.TriggeredFollowUpMaxCount = inf;
    followUpMeta.AdditionalTriggeredFollowUpProfiles = repmat(localEmptyTriggeredFollowUpProfile(), 1, 0);
    followUpMeta.BackgroundDriverKind = string(getFieldOrDefault(driverSpec, 'DriverKind', "Triggered"));
    followUpMeta.BackgroundDriverMode = string(getFieldOrDefault(driverSpec, 'DriverMode', "ForegroundAnyActionTrigger"));
    followUpMeta.EffectTag = string(getFieldOrDefault(sourceMeta, 'EffectTag', ""));
    followUpMeta = resolveInferredAuraMetadata(window.Member, event.Action, followUpMeta);
    event.CombatMeta = followUpMeta;
end

function event = localBuildSyntheticEffectTickEvent(baseEvent, baseMeta, tickIndex, tickTime, rotationDuration, driverSpec)
    if nargin < 6 || isempty(driverSpec)
        driverSpec = localEmptyBackgroundDriverSpec();
    end
    event = localEmptyEvent();
    event.MemberIndex = baseEvent.MemberIndex;
    event.Member = baseEvent.Member;
    event.Character = baseEvent.Character;
    event.MemberRole = baseEvent.MemberRole;
    event.SourceType = "EffectTick";
    event.Action = string(getFieldOrDefault(driverSpec, 'Action', getFieldOrDefault(baseMeta, 'EffectTickAction', "EffectTick"))) + "#" + string(tickIndex);
    event.StartTime = tickTime;
    event.EndTime = min(rotationDuration, tickTime + 0.01);
    event.Duration = max(0, event.EndTime - event.StartTime);
    event.HitElement = string(getFieldOrDefault(driverSpec, 'Element', ...
        getFieldOrDefault(baseMeta, 'EffectTickElement', ...
        getFieldOrDefault(baseMeta, 'ApplyElement', getFieldOrDefault(baseMeta, 'HitElement', "")))));
    event.TriggerSourceType = "EffectWindow";
    event.TriggerSourceCharacter = string(getFieldOrDefault(baseEvent, 'Character', ""));
    event.TriggerSourceAction = string(getFieldOrDefault(baseMeta, 'Action', getFieldOrDefault(baseEvent, 'Action', "")));
    event.TriggerPacketSource = "";

    tickMeta = baseMeta;
    tickMeta.Action = event.Action;
    tickMeta.ActionClass = "FollowUp";
    tickMeta.ConsumesActiveWindow = false;
    if strlength(string(getFieldOrDefault(driverSpec, 'Element', ""))) > 0
        tickMeta.HitElement = string(getFieldOrDefault(driverSpec, 'Element', tickMeta.HitElement));
        tickMeta.ApplyElement = tickMeta.HitElement;
    end
    tickMeta.ApplyGauge = double(getFieldOrDefault(driverSpec, 'Gauge', getFieldOrDefault(baseMeta, 'EffectTickGauge', 0)));
    tickMeta.CanApplyAura = tickMeta.ApplyGauge > 0 && strlength(string(tickMeta.ApplyElement)) > 0;
    tickMeta.PreferredAura = string(getFieldOrDefault(driverSpec, 'PreferredAura', getFieldOrDefault(baseMeta, 'EffectTickPreferredAura', getFieldOrDefault(baseMeta, 'PreferredAura', ""))));
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
    tickMeta.EffectTickGauge = 0;
    tickMeta.TriggeredFollowUpAction = "";
    tickMeta.TriggeredFollowUpDelay = 0;
    tickMeta.TriggeredFollowUpGauge = 0;
    tickMeta.TriggeredFollowUpInternalCooldown = 0;
    tickMeta.TriggeredFollowUpEligibleClasses = strings(1, 0);
    tickMeta.TriggeredFollowUpForegroundOnly = false;
    tickMeta.TriggeredFollowUpMaxCount = inf;
    tickMeta.AdditionalTriggeredFollowUpProfiles = repmat(localEmptyTriggeredFollowUpProfile(), 1, 0);
    tickMeta.BackgroundDriverKind = string(getFieldOrDefault(driverSpec, 'DriverKind', "Autonomous"));
    tickMeta.BackgroundDriverMode = string(getFieldOrDefault(driverSpec, 'DriverMode', "AutonomousTick"));
    tickMeta.EffectTag = string(getFieldOrDefault(baseMeta, 'EffectTag', ""));
    tickMeta = resolveInferredAuraMetadata(baseEvent.Member, event.Action, tickMeta);
    event.CombatMeta = tickMeta;
end

function spec = localEmptyBackgroundDriverSpec()
    spec = struct( ...
        'DriverKind', "", ...
        'DriverMode', "", ...
        'Action', "", ...
        'Element', "", ...
        'PreferredAura', "", ...
        'FirstDelay', 0, ...
        'Interval', 0, ...
        'Count', 0, ...
        'Gauge', 0, ...
        'InternalCooldown', 0, ...
        'EligibleClasses', strings(1, 0), ...
        'ForegroundOnly', true, ...
        'MaxTriggers', inf, ...
        'AllowedReactionNames', strings(1, 0), ...
        'AllowedPacketSources', strings(1, 0), ...
        'RequireForegroundTrigger', false);
end

function packet = localEmptyReactionPacket()
    packet = struct( ...
        'ReactionName', "", ...
        'TriggerTime', NaN, ...
        'PacketSource', "", ...
        'SourceType', "", ...
        'SourceCharacter', "", ...
        'SourceAction', "", ...
        'SourceConsumesActiveWindow', false);
end

function profile = localEmptyTriggeredFollowUpProfile()
    profile = struct( ...
        'Action', "", ...
        'Delay', 0.0, ...
        'Gauge', 0.0, ...
        'Element', "", ...
        'PreferredAura', "", ...
        'InternalCooldown', 0.0, ...
        'EligibleClasses', strings(1, 0), ...
        'ForegroundOnly', true, ...
        'MaxCount', inf, ...
        'DriverMode', "", ...
        'AllowedReactionNames', strings(1, 0), ...
        'AllowedPacketSources', strings(1, 0), ...
        'RequireForegroundTrigger', false);
end

function priority = localEventSourcePriority(event)
    sourceType = string(getFieldOrDefault(event, 'SourceType', "MemberAction"));
    switch char(sourceType)
        case 'EffectTick'
            priority = 1;
        case 'MemberAction'
            priority = 2;
        case 'TriggeredFollowUp'
            priority = 3;
        otherwise
            priority = 4;
    end
end

function actionEvents = localSortActionEvents(actionEvents)
    if isempty(actionEvents)
        return;
    end

    sortRows = zeros(numel(actionEvents), 3);
    for eventIndex = 1:numel(actionEvents)
        sortRows(eventIndex, :) = [ ...
            actionEvents(eventIndex).StartTime, ...
            localEventSourcePriority(actionEvents(eventIndex)), ...
            eventIndex];
    end
    order = sortrows(sortRows, [1 2 3]);
    actionEvents = actionEvents(order(:, 3).');
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
        startEnergy = localResolveStartingEnergy(members{i}, burstCost);
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
        energyState(i).StartEnergy = startEnergy;
        energyState(i).CurrentEnergy = startEnergy;
    end
end

function [energyState, pendingDrops, rows, ownerDelta] = localApplyEnergyEvent(energyState, pendingDrops, ownerIndex, meta, eventTime, eventStartTime)
    if nargin < 5 || isempty(eventTime)
        eventTime = 0;
    end
    if nargin < 6 || isempty(eventStartTime)
        eventStartTime = eventTime;
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

    if particles > 1e-9
        spawnTime = localResolveEnergyDropSpawnTime(meta, eventStartTime, eventTime, "Particle");
        arrivalTime = spawnTime + localResolveEnergyDropDelay(meta, "Particle");
        pendingDrops(end + 1) = localMakePendingEnergyDrop( ... %#ok<AGROW>
            ownerIndex, energyState(ownerIndex).DisplayName, string(meta.Action), ownerElement, ...
            particles, arrivalTime, "ParticleCatch");
        rows(end + 1, :) = { ... %#ok<AGROW>
            spawnTime, energyState(ownerIndex).DisplayName, string(meta.Action), ...
            energyState(ownerIndex).DisplayName, 0, energyState(ownerIndex).CurrentEnergy, "ParticleSpawn"};
    end
    if orbs > 1e-9
        spawnTime = localResolveEnergyDropSpawnTime(meta, eventStartTime, eventTime, "Orb");
        arrivalTime = spawnTime + localResolveEnergyDropDelay(meta, "Orb");
        pendingDrops(end + 1) = localMakePendingEnergyDrop( ... %#ok<AGROW>
            ownerIndex, energyState(ownerIndex).DisplayName, string(meta.Action), ownerElement, ...
            orbs, arrivalTime, "OrbCatch");
        rows(end + 1, :) = { ... %#ok<AGROW>
            spawnTime, energyState(ownerIndex).DisplayName, string(meta.Action), ...
            energyState(ownerIndex).DisplayName, 0, energyState(ownerIndex).CurrentEnergy, "OrbSpawn"};
    end

    if abs(flatSelf) <= 1e-9 && abs(flatTeam) <= 1e-9
        return;
    end

    for i = 1:numel(energyState)
        deltaEnergy = flatTeam / max(numel(energyState), 1);
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
            energyState(i).DisplayName, deltaEnergy, energyState(i).CurrentEnergy, "FlatEnergyGain"};
        if i == ownerIndex
            ownerDelta = ownerDelta + deltaEnergy;
        end
    end
end

function startEnergy = localResolveStartingEnergy(member, burstCost)
    build = getFieldOrDefault(member, 'Build', struct());
    startEnergy = getFieldOrDefault(member, 'StartEnergy', []);
    if isempty(startEnergy)
        startEnergy = getFieldOrDefault(member, 'InitialEnergy', []);
    end
    if isempty(startEnergy)
        startEnergy = getFieldOrDefault(build, 'StartEnergy', []);
    end
    if isempty(startEnergy)
        startEnergy = getFieldOrDefault(build, 'InitialEnergy', []);
    end
    if isempty(startEnergy)
        startEnergy = burstCost;
    end

    startEnergy = double(startEnergy);
    if ~isscalar(startEnergy) || ~isfinite(startEnergy)
        startEnergy = burstCost;
    end
    startEnergy = min(max(0, startEnergy), burstCost);
end

function [energyState, pendingDrops, rows] = localResolvePendingEnergyDrops( ...
        energyState, pendingDrops, activeCharacter, upToTime, boundaryCharacter)
    rows = cell(0, 7);
    if nargin < 4 || isempty(upToTime) || ~isfinite(upToTime)
        upToTime = inf;
    end
    if nargin < 5
        boundaryCharacter = "";
    end
    if isempty(pendingDrops)
        return;
    end

    arrivalRows = zeros(numel(pendingDrops), 2);
    for dropIndex = 1:numel(pendingDrops)
        arrivalRows(dropIndex, :) = [double(getFieldOrDefault(pendingDrops(dropIndex), 'ArrivalTime', inf)), dropIndex];
    end
    arrivalRows = sortrows(arrivalRows, [1 2]);

    kept = repmat(localEmptyPendingEnergyDrop(), 1, 0);
    for rowIndex = 1:size(arrivalRows, 1)
        drop = pendingDrops(arrivalRows(rowIndex, 2));
        if double(getFieldOrDefault(drop, 'ArrivalTime', inf)) > upToTime + 1e-9
            kept(end + 1) = drop; %#ok<AGROW>
            continue;
        end

        recipientCharacter = string(activeCharacter);
        if strlength(string(boundaryCharacter)) > 0 ...
                && abs(double(getFieldOrDefault(drop, 'ArrivalTime', inf)) - double(upToTime)) <= 1e-9
            recipientCharacter = string(boundaryCharacter);
        end

        recipientIndex = localResolveEnergyRecipientIndex( ...
            energyState, recipientCharacter, getFieldOrDefault(drop, 'OwnerIndex', 0));
        [energyState, catchRows] = localApplyPendingEnergyDrop(energyState, drop, recipientIndex);
        if ~isempty(catchRows)
            rows = [rows; catchRows]; %#ok<AGROW>
        end
    end
    pendingDrops = kept;
end

function [energyState, rows] = localResolvePostCyclePendingEnergyDrops( ...
        energyState, pendingDrops, activeCharacter, members, rotationPlan, ...
        archetypeInfo, teamContext, rotationDuration)
    rows = cell(0, 7);
    if isempty(pendingDrops) || ~isfinite(rotationDuration) || rotationDuration <= 0
        return;
    end

    maxArrivalTime = localMaxPendingEnergyArrivalTime(pendingDrops);
    if ~isfinite(maxArrivalTime) || maxArrivalTime <= rotationDuration + 1e-9
        return;
    end

    futureEvents = localBuildRepeatedFutureActionEvents( ...
        members, rotationPlan, rotationDuration, maxArrivalTime);
    currentActiveCharacter = string(activeCharacter);

    while ~isempty(pendingDrops)
        nextArrivalTime = localMinPendingEnergyArrivalTime(pendingDrops);
        if ~isfinite(nextArrivalTime)
            break;
        end

        nextEventTime = inf;
        nextEvent = localEmptyEvent();
        nextMeta = struct();
        if ~isempty(futureEvents)
            nextEvent = futureEvents(1);
            nextMeta = getFieldOrDefault(nextEvent, 'CombatMeta', struct());
            if isempty(fieldnames(nextMeta))
                nextMeta = localResolveEventMeta(nextEvent, archetypeInfo, teamContext);
            end
            nextEventTime = double(getFieldOrDefault(nextEvent, 'StartTime', inf));
        end

        if nextEventTime <= nextArrivalTime + 1e-9
            boundaryCatchCharacter = localResolveBoundaryCatchCharacter( ...
                currentActiveCharacter, nextEvent, nextMeta, futureEvents(2:end), ...
                archetypeInfo, teamContext, nextEventTime);
            [energyState, pendingDrops, catchRows] = localResolvePendingEnergyDrops( ...
                energyState, pendingDrops, currentActiveCharacter, ...
                nextEventTime, boundaryCatchCharacter);
            if ~isempty(catchRows)
                rows = [rows; catchRows]; %#ok<AGROW>
            end

            futureEvents(1) = [];
            if logical(getFieldOrDefault(nextMeta, 'ConsumesActiveWindow', true))
                currentActiveCharacter = string(getFieldOrDefault(nextEvent, 'Character', currentActiveCharacter));
            end
            continue;
        end

        [energyState, pendingDrops, catchRows] = localResolvePendingEnergyDrops( ...
            energyState, pendingDrops, currentActiveCharacter, nextArrivalTime, "");
        if ~isempty(catchRows)
            rows = [rows; catchRows]; %#ok<AGROW>
        end
    end
end

function futureEvents = localBuildRepeatedFutureActionEvents( ...
        members, rotationPlan, rotationDuration, maxArrivalTime)
    futureEvents = repmat(localEmptyEvent(), 1, 0);
    if ~isfinite(rotationDuration) || rotationDuration <= 0 ...
            || ~isfinite(maxArrivalTime) || maxArrivalTime <= rotationDuration + 1e-9
        return;
    end

    baseEvents = localBuildActionEvents(members, rotationPlan, rotationDuration);
    if isempty(baseEvents)
        return;
    end

    cycleCount = max(1, ceil(max(0, maxArrivalTime - rotationDuration) / max(rotationDuration, 1e-9)));
    for cycleIndex = 1:cycleCount
        shiftedEvents = baseEvents;
        timeShift = cycleIndex * rotationDuration;
        for eventIndex = 1:numel(shiftedEvents)
            shiftedEvents(eventIndex).StartTime = double(shiftedEvents(eventIndex).StartTime) + timeShift;
            shiftedEvents(eventIndex).EndTime = double(shiftedEvents(eventIndex).EndTime) + timeShift;
        end
        futureEvents = [futureEvents, shiftedEvents]; %#ok<AGROW>
    end
    futureEvents = localSortActionEvents(futureEvents);
end

function arrivalTime = localMinPendingEnergyArrivalTime(pendingDrops)
    arrivalTime = inf;
    if isempty(pendingDrops)
        return;
    end

    for dropIndex = 1:numel(pendingDrops)
        currentArrival = double(getFieldOrDefault(pendingDrops(dropIndex), 'ArrivalTime', inf));
        if currentArrival < arrivalTime
            arrivalTime = currentArrival;
        end
    end
end

function arrivalTime = localMaxPendingEnergyArrivalTime(pendingDrops)
    arrivalTime = -inf;
    if isempty(pendingDrops)
        arrivalTime = inf;
        return;
    end

    for dropIndex = 1:numel(pendingDrops)
        currentArrival = double(getFieldOrDefault(pendingDrops(dropIndex), 'ArrivalTime', -inf));
        if currentArrival > arrivalTime
            arrivalTime = currentArrival;
        end
    end
end

function boundaryCharacter = localResolveBoundaryCatchCharacter( ...
        activeCharacter, primaryEvent, primaryMeta, siblingEvents, archetypeInfo, teamContext, targetTime)
    boundaryCharacter = "";
    targetTime = double(targetTime);

    if localEventStartsAtTime(primaryEvent, targetTime) ...
            && logical(getFieldOrDefault(primaryMeta, 'ConsumesActiveWindow', true))
        candidate = string(getFieldOrDefault(primaryEvent, 'Character', ""));
        if strlength(candidate) > 0
            boundaryCharacter = candidate;
            return;
        end
    end

    for eventIndex = 1:numel(siblingEvents)
        currentEvent = siblingEvents(eventIndex);
        if ~localEventStartsAtTime(currentEvent, targetTime)
            if double(getFieldOrDefault(currentEvent, 'StartTime', inf)) > targetTime + 1e-9
                break;
            end
            continue;
        end

        currentMeta = getFieldOrDefault(currentEvent, 'CombatMeta', struct());
        if isempty(fieldnames(currentMeta))
            currentMeta = localResolveEventMeta(currentEvent, archetypeInfo, teamContext);
        end
        if ~logical(getFieldOrDefault(currentMeta, 'ConsumesActiveWindow', true))
            continue;
        end

        candidate = string(getFieldOrDefault(currentEvent, 'Character', ""));
        if strlength(candidate) > 0
            boundaryCharacter = candidate;
            return;
        end
    end
end

function tf = localEventStartsAtTime(event, targetTime)
    eventTime = double(getFieldOrDefault(event, 'StartTime', inf));
    tf = isfinite(eventTime) && abs(eventTime - double(targetTime)) <= 1e-9;
end

function recipientIndex = localResolveEnergyRecipientIndex(energyState, activeCharacter, fallbackIndex)
    recipientIndex = 0;
    activeCharacter = string(activeCharacter);
    if strlength(activeCharacter) > 0
        for i = 1:numel(energyState)
            if strcmpi(char(energyState(i).DisplayName), char(activeCharacter)) ...
                    || strcmpi(char(energyState(i).Name), char(activeCharacter))
                recipientIndex = i;
                break;
            end
        end
    end

    if recipientIndex < 1 || recipientIndex > numel(energyState)
        recipientIndex = max(1, min(numel(energyState), round(double(fallbackIndex))));
    end
end

function [energyState, rows] = localApplyPendingEnergyDrop(energyState, drop, recipientIndex)
    rows = cell(0, 7);
    if isempty(energyState)
        return;
    end

    sourceElement = string(getFieldOrDefault(drop, 'SourceElement', ""));
    amount = double(getFieldOrDefault(drop, 'Amount', 0));
    arrivalTime = double(getFieldOrDefault(drop, 'ArrivalTime', 0));
    sourceCharacter = string(getFieldOrDefault(drop, 'SourceCharacter', ""));
    action = string(getFieldOrDefault(drop, 'Action', ""));
    eventType = string(getFieldOrDefault(drop, 'EventType', "ParticleCatch"));
    if amount <= 1e-9
        return;
    end

    isOrb = strcmpi(char(eventType), 'OrbCatch');
    for i = 1:numel(energyState)
        sameElement = strcmpi(char(energyState(i).Element), char(sourceElement));
        if i == recipientIndex
            if isOrb
                unitEnergy = 9.0 * double(sameElement) + 3.0 * double(~sameElement);
            else
                unitEnergy = 3.0 * double(sameElement) + 1.0 * double(~sameElement);
            end
        else
            if isOrb
                unitEnergy = 5.4 * double(sameElement) + 1.8 * double(~sameElement);
            else
                unitEnergy = 1.8 * double(sameElement) + 0.6 * double(~sameElement);
            end
        end

        deltaEnergy = amount * unitEnergy * energyState(i).ER;
        if abs(deltaEnergy) <= 1e-9
            continue;
        end

        energyState(i).CurrentEnergy = min(energyState(i).BurstCost, ...
            energyState(i).CurrentEnergy + deltaEnergy);
        rows(end + 1, :) = { ... %#ok<AGROW>
            arrivalTime, sourceCharacter, action, ...
            energyState(i).DisplayName, deltaEnergy, energyState(i).CurrentEnergy, char(eventType)};
    end
end

function delay = localResolveEnergyDropDelay(meta, dropKind)
    if nargin < 2
        dropKind = "Particle";
    end
    switch lower(char(string(dropKind)))
        case 'orb'
            delay = double(getFieldOrDefault(meta, 'EstimatedOrbTravelDelay', 1.08));
        otherwise
            delay = double(getFieldOrDefault(meta, 'EstimatedParticleTravelDelay', 0.90));
    end
    if ~isscalar(delay) || ~isfinite(delay) || delay < 0
        if strcmpi(char(string(dropKind)), 'orb')
            delay = 1.08;
        else
            delay = 0.90;
        end
    end
end

function spawnTime = localResolveEnergyDropSpawnTime(meta, eventStartTime, eventEndTime, dropKind)
    if nargin < 4
        dropKind = "Particle";
    end

    actionWindow = max(0, double(eventEndTime) - double(eventStartTime));
    spawnDelay = double(getFieldOrDefault(meta, 'EstimatedEnergySpawnDelay', NaN));
    if ~isscalar(spawnDelay) || ~isfinite(spawnDelay)
        switch lower(char(string(dropKind)))
            case 'orb'
                spawnDelay = min(actionWindow, max(0.12, 0.45 * actionWindow));
            otherwise
                spawnDelay = min(actionWindow, max(0.08, 0.35 * actionWindow));
        end
    end
    spawnDelay = max(0, min(actionWindow, spawnDelay));
    spawnTime = double(eventStartTime) + spawnDelay;
end

function drop = localMakePendingEnergyDrop(ownerIndex, sourceCharacter, action, sourceElement, amount, arrivalTime, eventType)
    drop = struct( ...
        'OwnerIndex', double(ownerIndex), ...
        'SourceCharacter', string(sourceCharacter), ...
        'Action', string(action), ...
        'SourceElement', string(sourceElement), ...
        'Amount', double(amount), ...
        'ArrivalTime', double(arrivalTime), ...
        'EventType', string(eventType));
end

function tableOut = localTimelineTable(rows)
    if isempty(rows)
        tableOut = table();
        return;
    end

    tableOut = cell2table(rows, 'VariableNames', { ...
        'Order', 'StartTime', 'EndTime', 'Character', 'ActiveCharacter', 'Role', 'Action', ...
        'SourceType', 'ActionClass', 'HitElement', 'ApplyGauge', 'CanApplyAura', ...
        'ApplyGaugeSource', 'ICDRule', 'ICDGroup', 'ICDSource', 'Reaction', 'AuraState', ...
        'QuickenGauge', 'FrozenGauge', 'DendroCoreCount', 'OwnerEnergyDelta', 'EffectTag', ...
        'ConsumesActiveWindow', 'BackgroundDriverKind', 'BackgroundDriverMode', ...
        'TriggerSourceType', 'TriggerSourceCharacter', 'TriggerSourceAction', 'TriggerPacketSource'});
    tableOut = localSortTimelineTable(tableOut);
end

function tableOut = localSortTimelineTable(tableOut)
    if isempty(tableOut) || height(tableOut) <= 1
        return;
    end

    sourcePriority = zeros(height(tableOut), 1);
    for rowIndex = 1:height(tableOut)
        sourcePriority(rowIndex) = localTimelineRowPriority(tableOut(rowIndex, :));
    end
    sortTable = table( ...
        double(tableOut.StartTime), ...
        sourcePriority, ...
        double(tableOut.EndTime), ...
        double(tableOut.Order), ...
        'VariableNames', {'StartTime', 'Priority', 'EndTime', 'Order'});
    [~, order] = sortrows(sortTable, {'StartTime', 'Priority', 'EndTime', 'Order'});
    tableOut = tableOut(order, :);
    tableOut.Order = (1:height(tableOut)).';
end

function priority = localTimelineRowPriority(row)
    sourceType = string(getFieldOrDefault(row, 'SourceType', "MemberAction"));
    action = string(getFieldOrDefault(row, 'Action', ""));
    switch char(sourceType)
        case 'EffectTick'
            priority = 1;
        case 'MemberAction'
            priority = 2;
        case 'TriggeredFollowUp'
            priority = 3;
        case 'TimedReaction'
            priority = 4;
        case 'Team'
            if strcmpi(char(action), 'Swap')
                priority = 5;
            else
                priority = 6;
            end
        otherwise
            priority = 7;
    end
end

function tableOut = localBuildEnergySummaryTable(energyState, energyRows, rotationPlan, rotationDuration)
    if isempty(energyState)
        tableOut = table();
        return;
    end
    if nargin < 2 || isempty(energyRows)
        energyRows = cell(0, 7);
    end
    if nargin < 3 || isempty(rotationPlan)
        rotationPlan = struct();
    end
    if nargin < 4 || isempty(rotationDuration)
        rotationDuration = inf;
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
    nextBurstWindowTime = nan(numel(energyState), 1);
    earliestReadyTime = nan(numel(energyState), 1);
    canBurstOnNextWindow = false(numel(energyState), 1);
    nextWindowReadiness = zeros(numel(energyState), 1);
    energyTimeline = localBuildEnergyTimelineTable(energyRows);

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
        nextBurstWindowTime(i) = localResolveNextBurstWindowTime(rotationPlan, i, names(i), rotationDuration);
        earliestReadyTime(i) = localResolveEarliestBurstReadyTime( ...
            energyTimeline, names(i), burstCost(i), startEnergy(i), usedBurst(i));
        if usedBurst(i)
            canBurstOnNextWindow(i) = isfinite(nextBurstWindowTime(i)) ...
                && isfinite(earliestReadyTime(i)) ...
                && earliestReadyTime(i) <= nextBurstWindowTime(i) + 1e-9;
        else
            canBurstOnNextWindow(i) = canBurst(i);
        end
        if ~isfinite(nextBurstWindowTime(i))
            nextWindowReadiness(i) = min(1, endEnergy(i) / max(burstCost(i), 1));
        elseif ~isfinite(earliestReadyTime(i))
            nextWindowReadiness(i) = 0;
        elseif nextBurstWindowTime(i) <= 1e-9
            nextWindowReadiness(i) = double(canBurstOnNextWindow(i));
        else
            nextWindowReadiness(i) = min(1, nextBurstWindowTime(i) / max(earliestReadyTime(i), 1e-9));
            if canBurstOnNextWindow(i)
                nextWindowReadiness(i) = 1;
            end
        end
    end

    tableOut = table(names, elements, burstCost, startEnergy, endEnergy, er, usedBurst, canBurst, missingEnergy, ...
        nextBurstWindowTime, earliestReadyTime, canBurstOnNextWindow, nextWindowReadiness, ...
        'VariableNames', {'Character', 'Element', 'BurstCost', 'StartEnergy', 'EndEnergy', ...
        'ER', 'UsedBurst', 'CanBurstNextCycle', 'MissingEnergy', ...
        'NextBurstWindowTime', 'EarliestBurstReadyTime', 'CanBurstOnNextWindow', 'NextWindowReadiness'});
end

function nextTime = localResolveNextBurstWindowTime(rotationPlan, memberIndex, characterName, rotationDuration)
    nextTime = inf;
    memberPlans = getFieldOrDefault(rotationPlan, 'MemberPlans', struct([]));
    if isempty(memberPlans)
        return;
    end

    planIndices = memberIndex;
    if memberIndex < 1 || memberIndex > numel(memberPlans)
        planIndices = 1:numel(memberPlans);
    end

    for i = planIndices
        currentName = string(getFieldOrDefault(memberPlans(i), 'DisplayName', getFieldOrDefault(memberPlans(i), 'Name', "")));
        if memberIndex < 1 || memberIndex > numel(memberPlans)
            if ~strcmpi(char(currentName), char(string(characterName))) ...
                    && ~strcmpi(char(string(getFieldOrDefault(memberPlans(i), 'Name', ""))), char(string(characterName)))
                continue;
            end
        end

        if i < 1 || i > numel(memberPlans)
            continue;
        end

        tokens = localNormalizeTimelineTokens(getFieldOrDefault(memberPlans(i), 'RotationTokens', {}));
        cursor = double(getFieldOrDefault(memberPlans(i), 'StartTime', 0));
        for tokenIndex = 1:numel(tokens)
            token = string(tokens{tokenIndex});
            if localIsTimelineBurstToken(token)
                nextTime = rotationDuration + cursor;
                return;
            end
            cursor = cursor + estimateActionDuration(char(string(getFieldOrDefault(memberPlans(i), 'Name', currentName))), char(token), 0.60);
        end
        return;
    end
end

function readyTime = localResolveEarliestBurstReadyTime(energyTimeline, characterName, burstCost, startEnergy, usedBurst)
    if nargin < 5
        usedBurst = false;
    end

    if ~usedBurst && startEnergy >= burstCost - 1e-6
        readyTime = 0;
        return;
    end

    readyTime = inf;
    if isempty(energyTimeline) || ~istable(energyTimeline) || height(energyTimeline) == 0
        return;
    end

    relevantRows = energyTimeline(strcmpi(string(energyTimeline.Recipient), string(characterName)), :);
    if isempty(relevantRows)
        return;
    end
    relevantRows = sortrows(relevantRows, 'Time');
    searchStartTime = -inf;
    if usedBurst
        burstRows = relevantRows(strcmpi(string(relevantRows.EventType), 'BurstCost'), :);
        if isempty(burstRows)
            return;
        end
        searchStartTime = max(double(burstRows.Time));
    end
    for rowIndex = 1:height(relevantRows)
        if double(relevantRows.Time(rowIndex)) < searchStartTime - 1e-9
            continue;
        end
        if double(relevantRows.RecipientEnergy(rowIndex)) >= burstCost - 1e-6
            readyTime = double(relevantRows.Time(rowIndex));
            return;
        end
    end
end

function tf = localIsTimelineBurstToken(token)
    token = lower(strtrim(char(string(token))));
    tf = strcmp(token, 'q') || strcmp(token, 'burst') || ~isempty(regexp(token, '^q\d+$', 'once')) ...
        || any(strcmp(token, {'qphysical', 'qpyro'}));
end

function tokens = localNormalizeTimelineTokens(tokens)
    if isempty(tokens)
        tokens = {};
        return;
    end
    if isstring(tokens)
        tokens = cellstr(tokens(:));
        return;
    end
    if ischar(tokens)
        tokens = cellstr(string(tokens(:)));
        return;
    end
    if ~iscell(tokens)
        tokens = cellstr(string(tokens(:)));
        return;
    end
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
        'DriverKind', 'DriverMode', 'DriverAction', 'DriverInterval', 'DriverCount'});
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
    parts = localUniqueReactionNames(parts);
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
    names = localUniqueReactionNames(names);
    if isempty(names)
        text = "";
    else
        text = join(names, ", ");
    end
end

function names = localUniqueReactionNames(names)
    names = string(names(:));
    names = names(strlength(names) > 0);
    if isempty(names)
        return;
    end

    seenKeys = strings(0, 1);
    keepMask = false(size(names));
    for nameIndex = 1:numel(names)
        key = lower(strtrim(names(nameIndex)));
        if ~any(seenKeys == key)
            seenKeys(end + 1, 1) = key; %#ok<AGROW>
            keepMask(nameIndex) = true;
        end
    end
    names = names(keepMask);
end

function [enemyState, rows, packets, actionOrder] = localAdvanceIntervalRows( ...
        enemyState, startTime, endTime, triggerElement, teamContext, activeCharacter, actionOrder, gapWindow, gapAction)
    rows = cell(0, 30);
    packets = struct([]);
    if nargin < 8 || isempty(gapWindow)
        gapWindow = [NaN, NaN];
    end
    if nargin < 9
        gapAction = "";
    end
    if endTime <= startTime + 1e-9
        return;
    end

    cursor = startTime;
    while cursor < endTime - 1e-9
        [~, probePackets] = advanceEnemyStateTime(enemyState, endTime - cursor, triggerElement, teamContext);
        segmentEnd = endTime;
        if ~isempty(probePackets)
            triggerTimes = arrayfun(@(packet) double(getFieldOrDefault(packet, 'TriggerTime', NaN)), probePackets);
            triggerTimes = triggerTimes(isfinite(triggerTimes) & triggerTimes > cursor + 1e-9);
            if ~isempty(triggerTimes)
                segmentEnd = min(endTime, min(triggerTimes));
            end
        end

        [enemyState, segmentPackets] = advanceEnemyStateTime(enemyState, segmentEnd - cursor, triggerElement, teamContext);
        if ~isempty(segmentPackets)
            if isempty(packets)
                packets = segmentPackets;
            else
                packets = [packets, segmentPackets]; %#ok<AGROW>
            end
        end

        gapStart = max(cursor, double(gapWindow(1)));
        gapEnd = min(segmentEnd, double(gapWindow(2)));
        if strlength(string(gapAction)) > 0 && gapEnd > gapStart + 1e-9
            actionOrder = actionOrder + 1;
            rows(end + 1, :) = { ... %#ok<AGROW>
                actionOrder, gapStart, gapEnd, "Team", activeCharacter, ...
                gapAction, gapAction, "Team", "Utility", "", 0, ...
                false, "", "", "", "", ...
                "", localAuraSummary(enemyState), localQuickenGauge(enemyState), ...
                localFrozenGauge(enemyState), localCoreCount(enemyState), ...
                0, "", false, "", "", "", "", "", ""};
        end
        if ~isempty(segmentPackets)
            [timedReactionRows, actionOrder] = localBuildTimedReactionTimelineRows( ...
                segmentPackets, enemyState, activeCharacter, actionOrder);
            if ~isempty(timedReactionRows)
                rows = [rows; timedReactionRows]; %#ok<AGROW>
            end
        end
        cursor = segmentEnd;
    end
end

function [rows, actionOrder] = localBuildTimedReactionTimelineRows(packets, enemyState, activeCharacter, actionOrder)
    rows = cell(0, 30);
    if isempty(packets)
        return;
    end

    orderedPackets = localSortReactionPackets(packets);
    for packetIndex = 1:numel(orderedPackets)
        packet = orderedPackets(packetIndex);
        reactionName = string(getFieldOrDefault(packet, 'ReactionName', ""));
        if strlength(reactionName) == 0
            continue;
        end
        triggerTime = double(getFieldOrDefault(packet, 'TriggerTime', NaN));
        if ~isfinite(triggerTime)
            triggerTime = 0;
        end

        actionOrder = actionOrder + 1;
        rows(end + 1, :) = { ... %#ok<AGROW>
            actionOrder, triggerTime, triggerTime, ...
            localResolveTimedReactionCharacter(packet), activeCharacter, ...
            "Reaction", reactionName, "TimedReaction", "Reaction", ...
            string(getFieldOrDefault(packet, 'ReactionElement', "")), ...
            0, false, "not_applicable", "", "", "not_applicable", ...
            reactionName, localAuraSummary(enemyState), localQuickenGauge(enemyState), ...
            localFrozenGauge(enemyState), localCoreCount(enemyState), ...
            0, "", false, "", "", ...
            string(getFieldOrDefault(packet, 'SourceType', "")), ...
            string(getFieldOrDefault(packet, 'SourceCharacter', "")), ...
            string(getFieldOrDefault(packet, 'SourceAction', "")), ...
            string(getFieldOrDefault(packet, 'PacketSource', ""))};
    end
end

function packets = localSortReactionPackets(packets)
    if isempty(packets)
        return;
    end

    sortRows = zeros(numel(packets), 3);
    for packetIndex = 1:numel(packets)
        triggerTime = double(getFieldOrDefault(packets(packetIndex), 'TriggerTime', inf));
        if ~isfinite(triggerTime)
            triggerTime = inf;
        end
        sortRows(packetIndex, :) = [triggerTime, packetIndex, packetIndex];
    end
    order = sortrows(sortRows, [1 2 3]);
    packets = packets(order(:, 3).');
end

function characterName = localResolveTimedReactionCharacter(packet)
    characterName = string(getFieldOrDefault(packet, 'SourceCharacter', ""));
    if strlength(characterName) > 0
        return;
    end

    sourceType = string(getFieldOrDefault(packet, 'SourceType', ""));
    if sourceType == "ReactionTrigger"
        characterName = "Team";
    else
        characterName = "Enemy";
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
        'AutonomousBackgroundCount', 0, ...
        'ActionTriggeredBackgroundCount', 0, ...
        'ReactionTriggeredBackgroundCount', 0, ...
        'SwapCount', 0, ...
        'TailCount', 0, ...
        'MemberScheduledActionTime', 0, ...
        'MemberOccupiedTime', 0, ...
        'AutonomousBackgroundTime', 0, ...
        'ActionTriggeredBackgroundTime', 0, ...
        'ReactionTriggeredBackgroundTime', 0, ...
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
    sourceTypes = strings(height(timelineTable), 1);
    if ismember('SourceType', timelineTable.Properties.VariableNames)
        sourceTypes = string(timelineTable.SourceType);
    end
    foregroundMask = memberMask & (sourceTypes == "MemberAction");
    if ismember('ConsumesActiveWindow', timelineTable.Properties.VariableNames)
        foregroundMask = foregroundMask & logical(timelineTable.ConsumesActiveWindow);
    end
    backgroundMask = memberMask & (sourceTypes ~= "MemberAction");
    autonomousMask = backgroundMask & (sourceTypes == "EffectTick");
    triggeredMask = backgroundMask & (sourceTypes == "TriggeredFollowUp");
    reactionTriggeredMask = false(height(timelineTable), 1);
    for rowIndex = find(triggeredMask(:)).'
        reactionTriggeredMask(rowIndex) = localIsReactionTriggeredBackgroundEvent(table2struct(timelineTable(rowIndex, :)));
    end
    actionTriggeredMask = triggeredMask & ~reactionTriggeredMask;
    swapMask = characterNames == "Team" & strcmpi(actionNames, "Swap");
    tailMask = characterNames == "Team" & strcmpi(actionNames, "Tail");

    summary.ActionCount = height(timelineTable);
    summary.MemberEventCount = sum(memberMask);
    summary.BackgroundEventCount = sum(backgroundMask);
    summary.AutonomousBackgroundCount = sum(autonomousMask);
    summary.ActionTriggeredBackgroundCount = sum(actionTriggeredMask);
    summary.ReactionTriggeredBackgroundCount = sum(reactionTriggeredMask);
    summary.SwapCount = sum(swapMask);
    summary.TailCount = sum(tailMask);
    summary.MemberScheduledActionTime = sum(durations(foregroundMask));
    summary.MemberOccupiedTime = localUnionDuration( ...
        timelineTable.StartTime(foregroundMask), timelineTable.EndTime(foregroundMask));
    summary.AutonomousBackgroundTime = sum(durations(autonomousMask));
    summary.ActionTriggeredBackgroundTime = sum(durations(actionTriggeredMask));
    summary.ReactionTriggeredBackgroundTime = sum(durations(reactionTriggeredMask));
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
    autonomousCounts = zeros(numel(members), 1);
    autonomousTimes = zeros(numel(members), 1);
    actionTriggeredCounts = zeros(numel(members), 1);
    actionTriggeredTimes = zeros(numel(members), 1);
    reactionTriggeredCounts = zeros(numel(members), 1);
    reactionTriggeredTimes = zeros(numel(members), 1);
    firstStarts = nan(numel(members), 1);
    lastEnds = nan(numel(members), 1);

    for i = 1:numel(members)
        names(i) = string(getFieldOrDefault(members{i}, 'DisplayName', members{i}.Name));
    end

    if isempty(timelineTable) || ~istable(timelineTable) || height(timelineTable) == 0
        memberTable = table(names, actionCounts, scheduledTimes, backgroundCounts, backgroundTimes, ...
            autonomousCounts, autonomousTimes, actionTriggeredCounts, actionTriggeredTimes, ...
            reactionTriggeredCounts, reactionTriggeredTimes, firstStarts, lastEnds, ...
            'VariableNames', {'Character', 'ScheduledActionCount', 'ScheduledActionTime', ...
            'BackgroundEventCount', 'BackgroundEventTime', ...
            'AutonomousBackgroundCount', 'AutonomousBackgroundTime', ...
            'ActionTriggeredBackgroundCount', 'ActionTriggeredBackgroundTime', ...
            'ReactionTriggeredBackgroundCount', 'ReactionTriggeredBackgroundTime', ...
            'FirstActionTime', 'LastActionTime'});
        return;
    end

    rowNames = string(timelineTable.Character);
    rowDurations = max(0, timelineTable.EndTime - timelineTable.StartTime);
    rowSourceTypes = strings(height(timelineTable), 1);
    if ismember('SourceType', timelineTable.Properties.VariableNames)
        rowSourceTypes = string(timelineTable.SourceType);
    end
    reactionTriggeredGlobalMask = false(height(timelineTable), 1);
    triggerRows = find(rowSourceTypes == "TriggeredFollowUp");
    for rowIndex = triggerRows(:).'
        reactionTriggeredGlobalMask(rowIndex) = localIsReactionTriggeredBackgroundEvent(table2struct(timelineTable(rowIndex, :)));
    end
    consumeMask = true(height(timelineTable), 1);
    if ismember('ConsumesActiveWindow', timelineTable.Properties.VariableNames)
        consumeMask = logical(timelineTable.ConsumesActiveWindow);
    end
    for i = 1:numel(names)
        memberMask = strcmpi(rowNames, names(i));
        if ~any(memberMask)
            continue;
        end
        foregroundMask = memberMask & (rowSourceTypes == "MemberAction") & consumeMask;
        backgroundMask = memberMask & (rowSourceTypes ~= "MemberAction");
        autonomousMask = backgroundMask & (rowSourceTypes == "EffectTick");
        triggeredMask = backgroundMask & (rowSourceTypes == "TriggeredFollowUp");
        reactionTriggeredMask = backgroundMask & reactionTriggeredGlobalMask;
        actionTriggeredMask = triggeredMask & ~reactionTriggeredMask;
        actionCounts(i) = sum(foregroundMask);
        scheduledTimes(i) = sum(rowDurations(foregroundMask));
        backgroundCounts(i) = sum(backgroundMask);
        backgroundTimes(i) = sum(rowDurations(backgroundMask));
        autonomousCounts(i) = sum(autonomousMask);
        autonomousTimes(i) = sum(rowDurations(autonomousMask));
        actionTriggeredCounts(i) = sum(actionTriggeredMask);
        actionTriggeredTimes(i) = sum(rowDurations(actionTriggeredMask));
        reactionTriggeredCounts(i) = sum(reactionTriggeredMask);
        reactionTriggeredTimes(i) = sum(rowDurations(reactionTriggeredMask));
        firstStarts(i) = min(timelineTable.StartTime(memberMask));
        lastEnds(i) = max(timelineTable.EndTime(memberMask));
    end

    memberTable = table(names, actionCounts, scheduledTimes, backgroundCounts, backgroundTimes, ...
        autonomousCounts, autonomousTimes, actionTriggeredCounts, actionTriggeredTimes, ...
        reactionTriggeredCounts, reactionTriggeredTimes, firstStarts, lastEnds, ...
        'VariableNames', {'Character', 'ScheduledActionCount', 'ScheduledActionTime', ...
        'BackgroundEventCount', 'BackgroundEventTime', ...
        'AutonomousBackgroundCount', 'AutonomousBackgroundTime', ...
        'ActionTriggeredBackgroundCount', 'ActionTriggeredBackgroundTime', ...
        'ReactionTriggeredBackgroundCount', 'ReactionTriggeredBackgroundTime', ...
        'FirstActionTime', 'LastActionTime'});
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
        'TriggerSourceType', "", ...
        'TriggerSourceCharacter', "", ...
        'TriggerSourceAction', "", ...
        'TriggerPacketSource', "", ...
        'DisableRuntimeBackgroundExpansion', false, ...
        'Action', "", ...
        'StartTime', 0, ...
        'EndTime', 0, ...
        'Duration', 0, ...
        'HitElement', "", ...
        'CombatMeta', struct());
end

function drop = localEmptyPendingEnergyDrop()
    drop = struct( ...
        'OwnerIndex', 0, ...
        'SourceCharacter', "", ...
        'Action', "", ...
        'SourceElement', "", ...
        'Amount', 0, ...
        'ArrivalTime', inf, ...
        'EventType', "ParticleCatch");
end

function window = localEmptyActiveWindow()
    window = struct( ...
        'MemberIndex', 0, ...
        'Member', struct(), ...
        'Character', "", ...
        'MemberRole', "", ...
        'EffectTag', "", ...
        'StartTime', 0, ...
        'EndTime', 0, ...
        'Meta', struct(), ...
        'DriverKind', "", ...
        'DriverMode', "", ...
        'DriverSpec', localEmptyBackgroundDriverSpec(), ...
        'RemainingTriggers', inf);
end
