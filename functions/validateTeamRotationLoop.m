function report = validateTeamRotationLoop(members, rotationPlan, teamContext, enemy, options)
    % Validate a repeated team rotation against energy, cooldown, and overlap constraints.
    if nargin < 5 || isempty(options)
        options = struct();
    end
    if nargin < 4 || isempty(enemy)
        enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
    end
    if nargin < 3 || isempty(teamContext)
        teamContext = buildTeamContext(members, getFieldOrDefault(rotationPlan, 'RotationDuration', 20), struct(), enemy);
    end

    cycleCount = max(2, round(double(getFieldOrDefault(options, 'ValidationCycles', 6))));
    warmupCycles = max(0, min(cycleCount - 1, round(double(getFieldOrDefault(options, 'WarmupCycles', 1)))));
    tolerance = max(1e-9, double(getFieldOrDefault(options, 'EnergyTolerance', 1e-6)));
    rotationDuration = double(getFieldOrDefault(rotationPlan, 'RotationDuration', getFieldOrDefault(teamContext, 'RotationDuration', 20)));

    [cooldownViolations, cooldownMargins] = localValidateCooldowns(members, rotationPlan, teamContext, rotationDuration, tolerance);
    violationRows = cooldownViolations;
    cycleRows = cell(0, 7);
    energyState = localResolveInitialEnergy(members);
    previousEndEnergy = nan(1, numel(members));
    stableCycle = NaN;
    allCycleEnergy = cell(cycleCount, 1);

    for cycleIndex = 1:cycleCount
        cycleMembers = members;
        for memberIndex = 1:numel(cycleMembers)
            cycleMembers{memberIndex}.StartEnergy = energyState(memberIndex);
        end

        timelineResult = simulateTeamTimeline(cycleMembers, rotationPlan, teamContext, enemy, struct());
        [energyViolations, minEnergyMargin] = localFindBurstEnergyViolations( ...
            timelineResult, cycleIndex, warmupCycles, tolerance);
        violationRows = [violationRows; energyViolations]; %#ok<AGROW>

        endEnergy = localResolveProjectedEndEnergy(timelineResult, cycleMembers);
        allCycleEnergy{cycleIndex} = endEnergy;
        overlapTime = double(getFieldOrDefault(getFieldOrDefault(timelineResult, 'TimelineSummary', struct()), 'OverlapTime', 0));
        if overlapTime > tolerance
            violationRows(end + 1, :) = {cycleIndex, 0, "Team", "Timeline", "Overlap", 0, overlapTime, overlapTime}; %#ok<AGROW>
        end

        energyDelta = inf;
        if all(isfinite(previousEndEnergy))
            energyDelta = max(abs(endEnergy - previousEndEnergy));
            if energyDelta <= tolerance && isnan(stableCycle)
                stableCycle = cycleIndex;
            end
        end
        cycleRows(end + 1, :) = {cycleIndex, minEnergyMargin, min(cooldownMargins), overlapTime, energyDelta, ...
            logical(getFieldOrDefault(timelineResult, 'CanLoopNextCycle', false)), ...
            double(getFieldOrDefault(timelineResult, 'LoopReadiness', 0))}; %#ok<AGROW>
        previousEndEnergy = endEnergy;
        energyState = endEnergy;
    end

    violationTable = localBuildViolationTable(violationRows);
    cycleTable = cell2table(cycleRows, 'VariableNames', { ...
        'Cycle', 'MinimumEnergyMargin', 'MinimumCooldownMargin', 'OverlapTime', ...
        'EnergyStateDelta', 'TimelineLoopReady', 'TimelineReadiness'});
    relevantViolations = violationTable(violationTable.Cycle > warmupCycles | violationTable.Type == "Cooldown", :);
    report = struct( ...
        'IsFeasible', isempty(relevantViolations), ...
        'IsStable', ~isnan(stableCycle), ...
        'FirstStableCycle', stableCycle, ...
        'RotationDuration', rotationDuration, ...
        'ValidationCycles', cycleCount, ...
        'WarmupCycles', warmupCycles, ...
        'FinalEnergy', energyState(:), ...
        'CycleEnergy', {allCycleEnergy}, ...
        'MinimumCooldownMargin', min(cooldownMargins), ...
        'Violations', violationTable, ...
        'CycleSummaries', cycleTable);
end

function energy = localResolveInitialEnergy(members)
    energy = zeros(1, numel(members));
    for i = 1:numel(members)
        cost = getCharacterBurstCost(members{i}.Name, getFieldOrDefault(members{i}, 'TalentLevel', 10), getFieldOrDefault(members{i}, 'Constellation', 0));
        configured = getFieldOrDefault(members{i}, 'StartEnergy', []);
        if isempty(configured)
            configured = cost;
        end
        energy(i) = min(cost, max(0, double(configured)));
    end
end

function [rows, margins] = localValidateCooldowns(members, rotationPlan, teamContext, rotationDuration, tolerance)
    rows = cell(0, 8);
    margins = inf;
    memberPlans = getFieldOrDefault(rotationPlan, 'MemberPlans', struct([]));
    for memberIndex = 1:min(numel(members), numel(memberPlans))
        tokens = localNormalizeTokens(getFieldOrDefault(memberPlans(memberIndex), 'RotationTokens', {}));
        cursor = double(getFieldOrDefault(memberPlans(memberIndex), 'StartTime', 0));
        actionTimes = struct('Skill', zeros(1, 0), 'Burst', zeros(1, 0));
        actionCooldowns = struct('Skill', zeros(1, 0), 'Burst', zeros(1, 0));
        for tokenIndex = 1:numel(tokens)
            token = string(tokens{tokenIndex});
            meta = inferActionCombatMetadata(members{memberIndex}, token, getFieldOrDefault(rotationPlan, 'ArchetypeInfo', struct()), teamContext);
            actionClass = string(getFieldOrDefault(meta, 'ActionClass', ""));
            if actionClass == "Skill" || actionClass == "Burst"
                cooldown = localResolveCooldown(members{memberIndex}, token, actionClass);
                if isfinite(cooldown) && cooldown > tolerance
                    key = char(actionClass);
                    actionTimes.(key)(end + 1) = cursor; %#ok<AGROW>
                    actionCooldowns.(key)(end + 1) = cooldown; %#ok<AGROW>
                end
            end
            cursor = cursor + estimateActionDuration(members{memberIndex}.Name, token, 0.60);
        end
        for className = ["Skill", "Burst"]
            key = char(className);
            times = actionTimes.(key);
            cooldowns = actionCooldowns.(key);
            if isempty(times)
                continue;
            end
            for i = 1:numel(times)
                nextIndex = mod(i, numel(times)) + 1;
                nextTime = times(nextIndex) + rotationDuration * double(nextIndex == 1);
                required = cooldowns(i);
                margin = nextTime - times(i) - required;
                margins(end + 1) = margin; %#ok<AGROW>
                if margin < -tolerance
                    rows(end + 1, :) = {0, times(i), string(getFieldOrDefault(members{memberIndex}, 'DisplayName', members{memberIndex}.Name)), ...
                        className, "Cooldown", required, nextTime - times(i), -margin}; %#ok<AGROW>
                end
            end
        end
    end
    if isempty(margins)
        margins = inf;
    end
end

function cooldown = localResolveCooldown(member, token, actionClass)
    cooldown = NaN;
    path = resolveCharacterDataFile(member.Name, 'talents');
    if strlength(path) == 0 || exist(char(path), 'file') ~= 2
        return;
    end
    try
        talents = readtable(char(path));
    catch
        return;
    end
    level = getFieldOrDefault(member, 'TalentLevel', 10);
    lowerToken = lower(char(string(token)));
    if actionClass == "Burst"
        names = {'CD'};
        skill = 'Burst';
    elseif contains(lowerToken, 'hold')
        names = {'HoldCD', 'CD', 'SkillCD'};
        skill = 'Skill';
    elseif contains(lowerToken, 'press') || contains(lowerToken, 'tap')
        names = {'PressCD', 'CD', 'SkillCD'};
        skill = 'Skill';
    else
        names = {'CD', 'SkillCD', 'PressCD', 'HoldCD'};
        skill = 'Skill';
    end
    for i = 1:numel(names)
        mask = strcmp(string(talents.Skill), skill) & strcmp(string(talents.Param), names{i});
        if any(mask)
            try
                cooldown = double(getTalentValue(talents, skill, names{i}, level));
            catch
                cooldown = NaN;
            end
            return;
        end
    end
end

function [rows, minMargin] = localFindBurstEnergyViolations(timelineResult, cycleIndex, warmupCycles, tolerance)
    rows = cell(0, 8);
    minMargin = inf;
    energyTimeline = getFieldOrDefault(timelineResult, 'EnergyTimeline', table());
    if isempty(energyTimeline) || ~istable(energyTimeline) || height(energyTimeline) == 0
        return;
    end
    burstRows = energyTimeline(string(energyTimeline.EventType) == "BurstCost", :);
    for i = 1:height(burstRows)
        cost = -double(burstRows.DeltaEnergy(i));
        before = double(burstRows.RecipientEnergy(i)) + cost;
        margin = before - cost;
        minMargin = min(minMargin, margin);
        if cycleIndex > warmupCycles && margin < -tolerance
            rows(end + 1, :) = {cycleIndex, double(burstRows.Time(i)), string(burstRows.Recipient(i)), ...
                string(burstRows.Action(i)), "Energy", cost, before, -margin}; %#ok<AGROW>
        end
    end
end

function endEnergy = localResolveProjectedEndEnergy(timelineResult, members)
    summary = getFieldOrDefault(timelineResult, 'EnergySummary', table());
    energyTimeline = getFieldOrDefault(timelineResult, 'EnergyTimeline', table());
    endEnergy = zeros(1, numel(members));
    for memberIndex = 1:numel(members)
        name = string(getFieldOrDefault(members{memberIndex}, 'DisplayName', members{memberIndex}.Name));
        value = NaN;
        if ~isempty(summary) && istable(summary)
            summaryRow = summary(string(summary.Character) == name, :);
            if ~isempty(summaryRow)
                value = double(summaryRow.EndEnergy(1));
            end
        end
        if ~isempty(energyTimeline) && istable(energyTimeline)
            rows = energyTimeline(string(energyTimeline.Recipient) == name & double(energyTimeline.DeltaEnergy) ~= 0, :);
            if ~isempty(rows)
                [~, lastIndex] = max(double(rows.Time));
                value = double(rows.RecipientEnergy(lastIndex));
            end
        end
        if ~isfinite(value)
            value = 0;
        end
        cost = getCharacterBurstCost(members{memberIndex}.Name, getFieldOrDefault(members{memberIndex}, 'TalentLevel', 10), getFieldOrDefault(members{memberIndex}, 'Constellation', 0));
        endEnergy(memberIndex) = min(cost, max(0, value));
    end
end

function tableOut = localBuildViolationTable(rows)
    if isempty(rows)
        tableOut = table(zeros(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
            'VariableNames', {'Cycle', 'Time', 'Character', 'Action', 'Type', 'Required', 'Actual', 'Shortfall'});
        return;
    end
    tableOut = cell2table(rows, 'VariableNames', {'Cycle', 'Time', 'Character', 'Action', 'Type', 'Required', 'Actual', 'Shortfall'});
end

function tokens = localNormalizeTokens(tokens)
    if isempty(tokens)
        tokens = {};
    elseif isstring(tokens)
        tokens = cellstr(tokens(:));
    elseif ischar(tokens)
        tokens = {tokens};
    elseif ~iscell(tokens)
        tokens = cellstr(string(tokens(:)));
    end
end
