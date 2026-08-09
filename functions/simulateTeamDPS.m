function [teamResult, memberResults] = simulateTeamDPS(teamSpec, enemy)
    % 统一的配队伤害模拟入口。
    %
    % 支持三类输入：
    % 1. string / char 数组：仅给出角色名；
    % 2. cell：每项可为角色名或带覆盖项的成员 struct；
    % 3. struct：需包含 Members，并可额外指定 RotationDuration / SharedBuffs / PlanOptions。
    %
    % 当前实现策略：
    % 1. 先解析成员配置；
    % 2. 再调用 planTeamRotation 即时生成本轮排轴；
    % 3. 用计划生成的临时 rotation 文件覆盖各成员 RotationFile；
    % 4. 构造一次共享 teamContext；
    % 5. 逐成员复用现有单人模拟器并汇总结果。
    if nargin < 2 || isempty(enemy)
        enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
    end

    [members, rotationDuration, simulationHorizon, sharedBuffs, planOptions] = localResolveTeamSpec(teamSpec);
    if isempty(members)
        error('Team simulation requires at least one member.');
    end

    % 队伍模拟入口默认总是启用即时排轴；如后续需要做对比实验，
    % 仍可通过 teamSpec.PlanOptions.DisableAutoPlan 显式关闭。
    customActions = getFieldOrDefault(planOptions, 'CustomRotationActions', struct([]));
    disableAutoPlan = logical(getFieldOrDefault(planOptions, 'DisableAutoPlan', false));
    optimizerResult = struct('Enabled', false);
    if ~isempty(customActions)
        rotationPlan = buildCustomTeamRotationPlan(members, customActions, rotationDuration);
    elseif disableAutoPlan
        rotationPlan = localBuildPassthroughPlan(members, rotationDuration);
    else
        rotationPlan = planTeamRotation(members, rotationDuration, enemy, sharedBuffs, planOptions);
        if logical(getFieldOrDefault(planOptions, 'EnableDPSOptimizer', false))
            optimizerResult = optimizeTeamRotation( ...
                members, rotationPlan, rotationDuration, enemy, sharedBuffs, planOptions);
            if optimizerResult.BestIndex > 0
                rotationPlan = optimizerResult.BestPlan;
            end
        end
    end
    [rotationPlan, cutoffSummary] = localTruncateRotationPlan(rotationPlan, members, rotationDuration);
    members = localApplyPlannedRotationFiles(members, rotationPlan);

    % 先在不递归推导 Furina 共享增伤的上下文下构造真实队伍时间线，
    % 再把时间线摘要回填到最终 teamContext，避免 Furina 队伍二次排轴/二次时间线。
    planningSharedBuffs = localBuildPlanningSharedBuffs(sharedBuffs, members);
    teamContext = buildTeamContext(members, rotationDuration, planningSharedBuffs, enemy);
    teamContext.ArchetypeInfo = getFieldOrDefault(rotationPlan, 'ArchetypeInfo', identifyTeamArchetype(members, sharedBuffs));
    timelineResult = simulateTeamTimeline(members, rotationPlan, teamContext, enemy, planOptions);

    finalSharedBuffs = localAttachTimelineSharedBuffs(sharedBuffs, timelineResult);
    teamContext = buildTeamContext(members, rotationDuration, finalSharedBuffs, enemy);
    teamContext.ArchetypeInfo = getFieldOrDefault(rotationPlan, 'ArchetypeInfo', identifyTeamArchetype(members, sharedBuffs));
    teamContext.TimelineSummary = getFieldOrDefault(timelineResult, 'TimelineSummary', struct());
    teamContext.MemberTimelineSummary = getFieldOrDefault(timelineResult, 'MemberTimelineSummary', table());
    teamContext.EnergySummary = getFieldOrDefault(timelineResult, 'EnergySummary', table());

    memberCells = cell(1, numel(members));
    combinedBreakdown = table();

    for i = 1:numel(members)
        if ~isfield(members{i}, 'EnemyState') || isempty(members{i}.EnemyState)
            members{i}.EnemyState = createEnemyState(enemy, teamContext, getCharacterElement(members{i}.Name));
        end

        memberCells{i} = simulateCharacterDPS(members{i}, enemy, teamContext);
        if ~isempty(memberCells{i}.Breakdown)
            currentBreakdown = memberCells{i}.Breakdown;
            currentBreakdown.Character = repmat(memberCells{i}.DisplayName, height(currentBreakdown), 1);
            [plannedRole, plannedStart] = localLookupMemberPlan(rotationPlan, members{i}.Name);
            currentBreakdown.PlannedRole = repmat(plannedRole, height(currentBreakdown), 1);
            currentBreakdown.PlannedStartTime = repmat(plannedStart, height(currentBreakdown), 1);
            combinedBreakdown = [combinedBreakdown; currentBreakdown]; %#ok<AGROW>
        end
    end

    memberResults = [memberCells{:}];
    totalDMG = sum([memberResults.TotalDMG]);
    cycleDPS = totalDMG / rotationDuration;
    memberDPSSum = sum([memberResults.DPS]);
    % The primary team DPS follows the same per-character time basis shown in the UI.
    teamDPS = memberDPSSum;

    [plannedRoles, plannedJobs, plannedStarts, plannedEnds, plannedDurations] = localCollectPlanSummary(rotationPlan, members);
    memberSummary = table( ...
        [memberResults.DisplayName].', ...
        plannedRoles(:), ...
        plannedJobs(:), ...
        plannedStarts(:), ...
        plannedEnds(:), ...
        plannedDurations(:), ...
        [memberResults.TotalDMG].', ...
        ([memberResults.TotalDMG].' ./ rotationDuration), ...
        [memberResults.RotationTime].', ...
        [memberResults.DPS].', ...
        'VariableNames', {'Character', 'PlannedRole', 'PlannedJob', 'PlannedStartTime', 'PlannedEndTime', 'ReservedTime', ...
        'TotalDMG', 'TeamCycleDPS', 'ActionTime', 'StandaloneDPS'});
    memberSummary = localAttachEnergySummary(memberSummary, timelineResult);
    memberSummary = localAttachTimelineSummary(memberSummary, timelineResult);
    planningWarnings = localBuildPlanningWarnings(rotationPlan, timelineResult, rotationDuration);
    if cutoffSummary.TruncatedActionCount > 0
        planningWarnings(end + 1, 1) = sprintf( ...
            '模拟在 %.0f 秒截止，截去 %d 个未完成动作：%s。', ...
            rotationDuration, cutoffSummary.TruncatedActionCount, char(strjoin(cutoffSummary.Characters, ', '))); %#ok<AGROW>
    end

    teamResult = struct( ...
        'RotationDuration', rotationDuration, ...
        'SimulationHorizon', simulationHorizon, ...
        'TotalDMG', totalDMG, ...
        'DPS', teamDPS, ...
        'CycleDPS', cycleDPS, ...
        'MemberDPSSum', memberDPSSum, ...
        'DPSRule', "MemberStandaloneDPSSum", ...
        'Summary', memberSummary, ...
        'Breakdown', combinedBreakdown, ...
        'TeamContext', teamContext, ...
        'PlannedRotation', rotationPlan, ...
        'ArchetypeInfo', getFieldOrDefault(rotationPlan, 'ArchetypeInfo', struct()), ...
        'ExecutionTable', getFieldOrDefault(rotationPlan, 'ExecutionTable', table()), ...
        'TimelineTable', getFieldOrDefault(timelineResult, 'TimelineTable', table()), ...
        'TimelineSummary', getFieldOrDefault(timelineResult, 'TimelineSummary', struct()), ...
        'MemberTimelineSummary', getFieldOrDefault(timelineResult, 'MemberTimelineSummary', table()), ...
        'EnergySummary', getFieldOrDefault(timelineResult, 'EnergySummary', table()), ...
        'EnergyTimeline', getFieldOrDefault(timelineResult, 'EnergyTimeline', table()), ...
        'ActiveEffectsTable', getFieldOrDefault(timelineResult, 'ActiveEffectsTable', table()), ...
        'HealthEventTable', getFieldOrDefault(timelineResult, 'HealthEventTable', table()), ...
        'FinalEnemyState', getFieldOrDefault(timelineResult, 'FinalEnemyState', struct()), ...
        'CanLoopNextCycle', logical(getFieldOrDefault(timelineResult, 'CanLoopNextCycle', false)), ...
        'LoopReadiness', double(getFieldOrDefault(timelineResult, 'LoopReadiness', 0)), ...
        'Cutoff', cutoffSummary, ...
        'Optimization', optimizerResult, ...
        'PlanningWarnings', planningWarnings, ...
        'MemberRotationFiles', localCollectPlanFiles(rotationPlan, members), ...
        'MemberRotationTexts', localCollectPlanTexts(rotationPlan, members));
end

function planningSharedBuffs = localBuildPlanningSharedBuffs(sharedBuffs, members)
    planningSharedBuffs = sharedBuffs;
    hasFurina = false;
    for i = 1:numel(members)
        if strcmpi(char(string(getFieldOrDefault(members{i}, 'Name', ""))), 'Furina')
            hasFurina = true;
            break;
        end
    end

    if hasFurina && isempty(getFieldOrDefault(sharedBuffs, 'ApproxFurinaBonus', []))
        planningSharedBuffs.ApproxFurinaBonus = 0;
    end
end

function sharedBuffs = localAttachTimelineSharedBuffs(sharedBuffs, timelineResult)
    sharedBuffs.TimelineTable = getFieldOrDefault(timelineResult, 'TimelineTable', table());
    sharedBuffs.TimelineSummary = getFieldOrDefault(timelineResult, 'TimelineSummary', struct());
    sharedBuffs.MemberTimelineSummary = getFieldOrDefault(timelineResult, 'MemberTimelineSummary', table());
    sharedBuffs.EnergySummary = getFieldOrDefault(timelineResult, 'EnergySummary', table());
    sharedBuffs.EnergyTimeline = getFieldOrDefault(timelineResult, 'EnergyTimeline', table());
    sharedBuffs.ActiveEffectsTable = getFieldOrDefault(timelineResult, 'ActiveEffectsTable', table());
    sharedBuffs.HealthEventTable = getFieldOrDefault(timelineResult, 'HealthEventTable', table());
    sharedBuffs.FinalEnemyState = getFieldOrDefault(timelineResult, 'FinalEnemyState', struct());
    sharedBuffs.LoopReadiness = double(getFieldOrDefault(timelineResult, 'LoopReadiness', 0));
    sharedBuffs.CanLoopNextCycle = logical(getFieldOrDefault(timelineResult, 'CanLoopNextCycle', false));
end

function [members, rotationDuration, simulationHorizon, sharedBuffs, planOptions] = localResolveTeamSpec(teamSpec)
    % Keep one combat cycle separate from an optional report horizon.
    rotationDuration = getDefaultTeamCycleDuration();
    simulationHorizon = getFixedSimulationDuration();
    sharedBuffs = struct();
    planOptions = struct();

    if isstring(teamSpec)
        memberSpecs = cellstr(teamSpec);
        members = cell(1, numel(memberSpecs));
        for i = 1:numel(memberSpecs)
            members{i} = localResolveMemberSpec(memberSpecs{i});
        end
        return;
    end

    if ischar(teamSpec)
        members = {localResolveMemberSpec(teamSpec)};
        return;
    end

    if iscell(teamSpec)
        memberSpecs = teamSpec;
        members = cell(1, numel(memberSpecs));
        for i = 1:numel(memberSpecs)
            members{i} = localResolveMemberSpec(memberSpecs{i});
        end
        return;
    end

    if isstruct(teamSpec) && isfield(teamSpec, 'Members')
        rawMembers = teamSpec.Members;
        members = cell(1, numel(rawMembers));
        for i = 1:numel(rawMembers)
            members{i} = localResolveMemberSpec(rawMembers{i});
        end
        sharedBuffs = getFieldOrDefault(teamSpec, 'SharedBuffs', sharedBuffs);
        planOptions = getFieldOrDefault(teamSpec, 'PlanOptions', planOptions);
        rotationDuration = double(getFieldOrDefault(teamSpec, 'CycleDuration', ...
            getFieldOrDefault(teamSpec, 'RotationDuration', rotationDuration)));
        simulationHorizon = double(getFieldOrDefault(teamSpec, 'SimulationHorizon', simulationHorizon));
        if ~isscalar(rotationDuration) || ~isfinite(rotationDuration) || rotationDuration <= 0
            rotationDuration = getDefaultTeamCycleDuration();
        end
        if ~isscalar(simulationHorizon) || ~isfinite(simulationHorizon) || simulationHorizon < rotationDuration
            simulationHorizon = rotationDuration;
        end
        return;
    end

    error('teamSpec must be a list of members or a struct with a Members field.');
end

function member = localResolveMemberSpec(spec)
    % 将各种成员输入形式统一解析为完整角色配置结构。
    if isstring(spec) || ischar(spec)
        member = getDefaultCharacterConfig(spec);
        return;
    end

    if isstruct(spec)
        if ~isfield(spec, 'Name')
            error('Member override structs must include a Name field.');
        end
        member = getDefaultCharacterConfig(spec.Name, spec);
        return;
    end

    error('Unsupported member specification in unified team entry.');
end

function members = localApplyPlannedRotationFiles(members, rotationPlan)
    if ~isfield(rotationPlan, 'MemberPlans') || isempty(rotationPlan.MemberPlans)
        return;
    end

    for i = 1:min(numel(members), numel(rotationPlan.MemberPlans))
        currentPlan = rotationPlan.MemberPlans(i);
        if strlength(string(getFieldOrDefault(currentPlan, 'TempRotationFile', ""))) > 0
            members{i}.OriginalRotationFile = getFieldOrDefault(members{i}, 'RotationFile', "");
            members{i}.PlannedRole = string(getFieldOrDefault(currentPlan, 'Role', ""));
            members{i}.PlannedStartTime = getFieldOrDefault(currentPlan, 'StartTime', 0);
            members{i}.PlannedReservedTime = getFieldOrDefault(currentPlan, 'EstimatedDuration', 0);
            members{i}.RotationFile = char(string(currentPlan.TempRotationFile));
        end
    end
end

function [rotationPlan, summary] = localTruncateRotationPlan(rotationPlan, members, rotationDuration)
    summary = struct( ...
        'Duration', rotationDuration, ...
        'TruncatedActionCount', 0, ...
        'Characters', strings(0, 1));

    memberPlans = getFieldOrDefault(rotationPlan, 'MemberPlans', struct([]));
    if isempty(memberPlans)
        return;
    end

    planRoot = string(getFieldOrDefault(rotationPlan, 'PlanDirectory', ""));
    if strlength(planRoot) == 0 || exist(char(planRoot), 'dir') ~= 7
        planRoot = fullfile(tempdir, 'genshin_dmg_calc_team_rotations');
    end
    if exist(char(planRoot), 'dir') ~= 7
        mkdir(char(planRoot));
    end

    for i = 1:min(numel(memberPlans), numel(members))
        plan = memberPlans(i);
        tokens = localResolvePlanTokens(plan);
        startTime = min(rotationDuration, max(0, double(getFieldOrDefault(plan, 'StartTime', 0))));
        [keptTokens, truncatedCount] = localKeepCompletedTokens( ...
            tokens, members{i}.Name, max(0, rotationDuration - startTime));

        if truncatedCount > 0
            summary.TruncatedActionCount = summary.TruncatedActionCount + truncatedCount;
            summary.Characters(end + 1, 1) = string(getFieldOrDefault(members{i}, 'DisplayName', members{i}.Name)); %#ok<AGROW>
        end

        actualDuration = localEstimatePassthroughRotationDuration(keptTokens, members{i}.Name);
        plan.StartTime = startTime;
        plan.EndTime = startTime + actualDuration;
        plan.EstimatedDuration = actualDuration;
        plan.RotationTokens = keptTokens;
        plan.RotationText = string(strjoin(string(keptTokens(:)), newline));
        plan.Preview = strjoin(string(keptTokens(:)).', " > ");
        plan.TempRotationFile = localWriteCutoffRotationFile(planRoot, i, members{i}.Name, plan.RotationText);
        memberPlans(i) = plan;
    end

    rotationPlan.MemberPlans = memberPlans;
    rotationPlan.RotationDuration = rotationDuration;
    summary.Characters = unique(summary.Characters, 'stable');
    rotationPlan.ExecutionTable = localBuildCutoffExecutionTable(memberPlans, members);
end

function tokens = localResolvePlanTokens(plan)
    tokens = getFieldOrDefault(plan, 'RotationTokens', cell(0, 1));
    if isempty(tokens)
        rotationFile = string(getFieldOrDefault(plan, 'TempRotationFile', ""));
        if strlength(rotationFile) > 0 && exist(char(rotationFile), 'file') == 2
            tokens = readRotationTokens(char(rotationFile));
        end
    end
    tokens = cellstr(string(tokens(:)));
end

function [keptTokens, truncatedCount] = localKeepCompletedTokens(tokens, characterName, timeBudget)
    keptTokens = cell(0, 1);
    truncatedCount = 0;
    elapsed = 0;

    for i = 1:numel(tokens)
        token = tokens{i};
        duration = estimateActionDuration(characterName, token, 0.60);
        if ~isfinite(duration) || duration <= 0
            duration = 0.60;
        end
        if elapsed + duration > timeBudget + 1e-9
            truncatedCount = numel(tokens) - i + 1;
            break;
        end
        keptTokens(end + 1, 1) = tokens(i); %#ok<AGROW>
        elapsed = elapsed + duration;
    end
end

function filePath = localWriteCutoffRotationFile(planRoot, memberIndex, characterName, rotationText)
    safeName = regexprep(char(string(characterName)), '[^A-Za-z0-9_-]', '_');
    filePath = fullfile(char(planRoot), sprintf('cutoff_%02d_%s.txt', memberIndex, safeName));
    fid = fopen(filePath, 'w');
    if fid == -1
        error('Unable to create cutoff rotation file: %s', filePath);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', char(rotationText));
end

function executionTable = localBuildCutoffExecutionTable(memberPlans, members)
    executionRows = cell(0, 8);
    order = zeros(numel(memberPlans), 1);
    for i = 1:numel(memberPlans)
        order(i) = double(getFieldOrDefault(memberPlans(i), 'Order', i));
    end
    [~, indices] = sort(order);
    for i = 1:numel(indices)
        memberIndex = indices(i);
        plan = memberPlans(memberIndex);
        executionRows(end + 1, :) = { ... %#ok<AGROW>
            i, ...
            string(getFieldOrDefault(members{memberIndex}, 'DisplayName', members{memberIndex}.Name)), ...
            string(getFieldOrDefault(plan, 'Role', "")), ...
            string(getFieldOrDefault(plan, 'Job', "")), ...
            double(getFieldOrDefault(plan, 'StartTime', 0)), ...
            double(getFieldOrDefault(plan, 'EndTime', 0)), ...
            double(getFieldOrDefault(plan, 'EstimatedDuration', 0)), ...
            string(getFieldOrDefault(plan, 'Preview', ""))};
    end
    executionTable = cell2table(executionRows, 'VariableNames', { ...
        'Order', 'Character', 'Role', 'Job', 'StartTime', 'EndTime', 'ReservedTime', 'RotationPreview'});
end

function [role, startTime] = localLookupMemberPlan(rotationPlan, memberName)
    role = "";
    startTime = NaN;
    if ~isfield(rotationPlan, 'MemberPlans') || isempty(rotationPlan.MemberPlans)
        return;
    end

    target = lower(char(string(memberName)));
    for i = 1:numel(rotationPlan.MemberPlans)
        current = rotationPlan.MemberPlans(i);
        if strcmpi(char(string(getFieldOrDefault(current, 'Name', ""))), target) ...
                || strcmpi(char(string(getFieldOrDefault(current, 'Name', ""))), char(string(memberName)))
            role = string(getFieldOrDefault(current, 'Role', ""));
            startTime = getFieldOrDefault(current, 'StartTime', NaN);
            return;
        end
    end
end

function [roles, jobs, starts, ends, reservedTimes] = localCollectPlanSummary(rotationPlan, members)
    memberCount = numel(members);
    roles = repmat("", memberCount, 1);
    jobs = repmat("", memberCount, 1);
    starts = nan(memberCount, 1);
    ends = nan(memberCount, 1);
    reservedTimes = zeros(memberCount, 1);

    if ~isfield(rotationPlan, 'MemberPlans') || isempty(rotationPlan.MemberPlans)
        return;
    end

    for i = 1:min(memberCount, numel(rotationPlan.MemberPlans))
        roles(i) = string(getFieldOrDefault(rotationPlan.MemberPlans(i), 'Role', ""));
        jobs(i) = string(getFieldOrDefault(rotationPlan.MemberPlans(i), 'Job', ""));
        starts(i) = getFieldOrDefault(rotationPlan.MemberPlans(i), 'StartTime', NaN);
        ends(i) = getFieldOrDefault(rotationPlan.MemberPlans(i), 'EndTime', NaN);
        reservedTimes(i) = getFieldOrDefault(rotationPlan.MemberPlans(i), 'EstimatedDuration', 0);
    end
end

function files = localCollectPlanFiles(rotationPlan, members)
    files = strings(numel(members), 1);
    if ~isfield(rotationPlan, 'MemberPlans') || isempty(rotationPlan.MemberPlans)
        return;
    end

    for i = 1:min(numel(members), numel(rotationPlan.MemberPlans))
        files(i) = string(getFieldOrDefault(rotationPlan.MemberPlans(i), 'TempRotationFile', ""));
    end
end

function texts = localCollectPlanTexts(rotationPlan, members)
    texts = strings(numel(members), 1);
    if ~isfield(rotationPlan, 'MemberPlans') || isempty(rotationPlan.MemberPlans)
        return;
    end

    for i = 1:min(numel(members), numel(rotationPlan.MemberPlans))
        texts(i) = string(getFieldOrDefault(rotationPlan.MemberPlans(i), 'RotationText', ""));
    end
end

function rotationPlan = localBuildPassthroughPlan(members, rotationDuration)
    memberPlans = repmat(struct( ...
        'Name', "", ...
        'DisplayName', "", ...
        'Role', "Manual", ...
        'Order', 0, ...
        'TargetBudget', 0, ...
        'EstimatedDuration', 0, ...
        'StartTime', 0, ...
        'EndTime', 0, ...
        'RotationTokens', {cell(0, 1)}, ...
        'RotationText', "", ...
        'Preview', "", ...
        'PlanningSource', "manual", ...
        'SeedSource', "member", ...
        'TempRotationFile', ""), 1, numel(members));

    for i = 1:numel(members)
        currentFile = string(getFieldOrDefault(members{i}, 'RotationFile', ""));
        currentText = "";
        tokens = cell(0, 1);
        if strlength(currentFile) > 0 && exist(char(currentFile), 'file') == 2
            currentText = string(fileread(char(currentFile)));
            tokens = readRotationTokens(char(currentFile));
        end
        startTime = getFieldOrDefault(members{i}, 'StartTime', 0);
        estimatedDuration = localEstimatePassthroughRotationDuration(tokens, members{i}.Name);
        memberPlans(i).Name = string(members{i}.Name);
        memberPlans(i).DisplayName = string(getFieldOrDefault(members{i}, 'DisplayName', members{i}.Name));
        memberPlans(i).StartTime = startTime;
        memberPlans(i).EndTime = startTime + estimatedDuration;
        memberPlans(i).RotationTokens = tokens;
        memberPlans(i).RotationText = currentText;
        memberPlans(i).Preview = localPreviewPassthroughRotation(tokens, currentText);
        memberPlans(i).EstimatedDuration = estimatedDuration;
        memberPlans(i).TempRotationFile = currentFile;
    end

    sortRows = [(1:numel(members)).', [memberPlans.StartTime].'];
    sortedMembers = sortrows(sortRows, [2 1]);
    executionOrder = sortedMembers(:, 1).';
    executionRows = cell(0, 8);
    for orderPos = 1:numel(executionOrder)
        memberIndex = executionOrder(orderPos);
        memberPlans(memberIndex).Order = orderPos;
        executionRows(end + 1, :) = { ... %#ok<AGROW>
            orderPos, ...
            memberPlans(memberIndex).DisplayName, ...
            memberPlans(memberIndex).Role, ...
            "", ...
            memberPlans(memberIndex).StartTime, ...
            memberPlans(memberIndex).EndTime, ...
            memberPlans(memberIndex).EstimatedDuration, ...
            memberPlans(memberIndex).Preview};
    end

    executionTable = cell2table(executionRows, 'VariableNames', { ...
        'Order', 'Character', 'Role', 'Job', 'StartTime', 'EndTime', 'ReservedTime', 'RotationPreview'});

    rotationPlan = struct( ...
        'RotationDuration', rotationDuration, ...
        'CarryIndex', 0, ...
        'ExecutionOrder', executionOrder, ...
        'PlanDirectory', "", ...
        'MemberPlans', memberPlans, ...
        'ArchetypeInfo', identifyTeamArchetype(members, struct()), ...
        'ExecutionTable', executionTable);
end

function duration = localEstimatePassthroughRotationDuration(tokens, characterName)
    if nargin < 1 || isempty(tokens)
        duration = 0;
        return;
    end

    duration = 0;
    for i = 1:numel(tokens)
        duration = duration + estimateActionDuration(characterName, tokens{i}, 0.60);
    end
end

function preview = localPreviewPassthroughRotation(tokens, rawText)
    if nargin < 1 || isempty(tokens)
        preview = strtrim(string(rawText));
        return;
    end

    preview = join(string(tokens(:)).', " > ");
    if strlength(preview) > 160
        preview = extractBefore(preview, 158) + "…";
    end
end

function memberSummary = localAttachEnergySummary(memberSummary, timelineResult)
    energySummary = getFieldOrDefault(timelineResult, 'EnergySummary', table());
    if isempty(energySummary) || ~istable(energySummary) || height(energySummary) == 0
        return;
    end

    endEnergy = nan(height(memberSummary), 1);
    burstCost = nan(height(memberSummary), 1);
    canLoop = false(height(memberSummary), 1);
    missingEnergy = nan(height(memberSummary), 1);
    nextBurstWindowTime = nan(height(memberSummary), 1);
    earliestReadyTime = nan(height(memberSummary), 1);
    canBurstOnNextWindow = false(height(memberSummary), 1);
    nextWindowReadiness = nan(height(memberSummary), 1);

    for i = 1:height(memberSummary)
        idx = find(strcmpi(string(memberSummary.Character(i)), string(energySummary.Character)), 1, 'first');
        if isempty(idx)
            continue;
        end
        endEnergy(i) = energySummary.EndEnergy(idx);
        burstCost(i) = energySummary.BurstCost(idx);
        canLoop(i) = energySummary.CanBurstNextCycle(idx);
        missingEnergy(i) = energySummary.MissingEnergy(idx);
        if ismember('NextBurstWindowTime', energySummary.Properties.VariableNames)
            nextBurstWindowTime(i) = energySummary.NextBurstWindowTime(idx);
        end
        if ismember('EarliestBurstReadyTime', energySummary.Properties.VariableNames)
            earliestReadyTime(i) = energySummary.EarliestBurstReadyTime(idx);
        end
        if ismember('CanBurstOnNextWindow', energySummary.Properties.VariableNames)
            canBurstOnNextWindow(i) = energySummary.CanBurstOnNextWindow(idx);
        end
        if ismember('NextWindowReadiness', energySummary.Properties.VariableNames)
            nextWindowReadiness(i) = energySummary.NextWindowReadiness(idx);
        end
    end

    memberSummary.EndEnergy = endEnergy;
    memberSummary.BurstCost = burstCost;
    memberSummary.CanBurstNextCycle = canLoop;
    memberSummary.MissingEnergy = missingEnergy;
    memberSummary.NextBurstWindowTime = nextBurstWindowTime;
    memberSummary.EarliestBurstReadyTime = earliestReadyTime;
    memberSummary.CanBurstOnNextWindow = canBurstOnNextWindow;
    memberSummary.NextWindowReadiness = nextWindowReadiness;
end

function memberSummary = localAttachTimelineSummary(memberSummary, timelineResult)
    memberTimeline = getFieldOrDefault(timelineResult, 'MemberTimelineSummary', table());
    if isempty(memberTimeline) || ~istable(memberTimeline) || height(memberTimeline) == 0
        return;
    end

    scheduledActionCount = zeros(height(memberSummary), 1);
    scheduledActionTime = zeros(height(memberSummary), 1);
    backgroundEventCount = zeros(height(memberSummary), 1);
    backgroundEventTime = zeros(height(memberSummary), 1);
    autonomousBackgroundCount = zeros(height(memberSummary), 1);
    autonomousBackgroundTime = zeros(height(memberSummary), 1);
    actionTriggeredBackgroundCount = zeros(height(memberSummary), 1);
    actionTriggeredBackgroundTime = zeros(height(memberSummary), 1);
    reactionTriggeredBackgroundCount = zeros(height(memberSummary), 1);
    reactionTriggeredBackgroundTime = zeros(height(memberSummary), 1);
    firstActionTime = nan(height(memberSummary), 1);
    lastActionTime = nan(height(memberSummary), 1);

    for i = 1:height(memberSummary)
        idx = find(strcmpi(string(memberSummary.Character(i)), string(memberTimeline.Character)), 1, 'first');
        if isempty(idx)
            continue;
        end
        scheduledActionCount(i) = memberTimeline.ScheduledActionCount(idx);
        scheduledActionTime(i) = memberTimeline.ScheduledActionTime(idx);
        if ismember('BackgroundEventCount', memberTimeline.Properties.VariableNames)
            backgroundEventCount(i) = memberTimeline.BackgroundEventCount(idx);
        end
        if ismember('BackgroundEventTime', memberTimeline.Properties.VariableNames)
            backgroundEventTime(i) = memberTimeline.BackgroundEventTime(idx);
        end
        if ismember('AutonomousBackgroundCount', memberTimeline.Properties.VariableNames)
            autonomousBackgroundCount(i) = memberTimeline.AutonomousBackgroundCount(idx);
        end
        if ismember('AutonomousBackgroundTime', memberTimeline.Properties.VariableNames)
            autonomousBackgroundTime(i) = memberTimeline.AutonomousBackgroundTime(idx);
        end
        if ismember('ActionTriggeredBackgroundCount', memberTimeline.Properties.VariableNames)
            actionTriggeredBackgroundCount(i) = memberTimeline.ActionTriggeredBackgroundCount(idx);
        end
        if ismember('ActionTriggeredBackgroundTime', memberTimeline.Properties.VariableNames)
            actionTriggeredBackgroundTime(i) = memberTimeline.ActionTriggeredBackgroundTime(idx);
        end
        if ismember('ReactionTriggeredBackgroundCount', memberTimeline.Properties.VariableNames)
            reactionTriggeredBackgroundCount(i) = memberTimeline.ReactionTriggeredBackgroundCount(idx);
        end
        if ismember('ReactionTriggeredBackgroundTime', memberTimeline.Properties.VariableNames)
            reactionTriggeredBackgroundTime(i) = memberTimeline.ReactionTriggeredBackgroundTime(idx);
        end
        firstActionTime(i) = memberTimeline.FirstActionTime(idx);
        lastActionTime(i) = memberTimeline.LastActionTime(idx);
    end

    memberSummary.ScheduledActionCount = scheduledActionCount;
    memberSummary.ScheduledActionTime = scheduledActionTime;
    memberSummary.BackgroundEventCount = backgroundEventCount;
    memberSummary.BackgroundEventTime = backgroundEventTime;
    memberSummary.AutonomousBackgroundCount = autonomousBackgroundCount;
    memberSummary.AutonomousBackgroundTime = autonomousBackgroundTime;
    memberSummary.ActionTriggeredBackgroundCount = actionTriggeredBackgroundCount;
    memberSummary.ActionTriggeredBackgroundTime = actionTriggeredBackgroundTime;
    memberSummary.ReactionTriggeredBackgroundCount = reactionTriggeredBackgroundCount;
    memberSummary.ReactionTriggeredBackgroundTime = reactionTriggeredBackgroundTime;
    memberSummary.FirstActionTime = firstActionTime;
    memberSummary.LastActionTime = lastActionTime;
end

function warnings = localBuildPlanningWarnings(rotationPlan, timelineResult, rotationDuration)
    warnings = strings(0, 1);

    timelineSummary = getFieldOrDefault(timelineResult, 'TimelineSummary', struct());
    if ~isempty(fieldnames(timelineSummary))
        overlapTime = double(getFieldOrDefault(timelineSummary, 'OverlapTime', 0));
        idleTime = double(getFieldOrDefault(timelineSummary, 'IdleTime', 0));
        maxConcurrent = double(getFieldOrDefault(timelineSummary, 'MaxConcurrentActions', 0));

        if overlapTime > max(0.40, 0.05 * rotationDuration)
            warnings(end + 1, 1) = sprintf( ...
                '排轴存在 %.2f 秒重叠（最大并行动作 %.0f）。', ...
                overlapTime, maxConcurrent); %#ok<AGROW>
        end
        if idleTime > max(2.00, 0.12 * rotationDuration)
            warnings(end + 1, 1) = sprintf( ...
                '排轴在本轮留下 %.2f 秒空闲。', ...
                idleTime); %#ok<AGROW>
        end
    end

    energySummary = getFieldOrDefault(timelineResult, 'EnergySummary', table());
    if ~isempty(energySummary) && istable(energySummary) && height(energySummary) > 0
        if ismember('CanBurstOnNextWindow', energySummary.Properties.VariableNames)
            loopMask = logical(energySummary.UsedBurst) & ~logical(energySummary.CanBurstOnNextWindow);
        else
            loopMask = logical(energySummary.UsedBurst) & ~logical(energySummary.CanBurstNextCycle);
        end
        if any(loopMask)
            deficitRows = energySummary(loopMask, :);
            deficitText = strings(height(deficitRows), 1);
            for i = 1:height(deficitRows)
                if ismember('NextBurstWindowTime', deficitRows.Properties.VariableNames) ...
                        && ismember('EarliestBurstReadyTime', deficitRows.Properties.VariableNames) ...
                        && isfinite(double(deficitRows.NextBurstWindowTime(i))) ...
                        && isfinite(double(deficitRows.EarliestBurstReadyTime(i)))
                    deficitText(i) = sprintf('%s %.1fs late', ...
                        char(string(deficitRows.Character(i))), ...
                        double(deficitRows.EarliestBurstReadyTime(i) - deficitRows.NextBurstWindowTime(i)));
                else
                    deficitText(i) = sprintf('%s %.1f', ...
                        char(string(deficitRows.Character(i))), double(deficitRows.MissingEnergy(i)));
                end
            end
            warnings(end + 1, 1) = "循环能量不足：" + join(deficitText, "、");
        end
    end

    executionTable = getFieldOrDefault(rotationPlan, 'ExecutionTable', table());
    if ~isempty(executionTable) && istable(executionTable) && height(executionTable) > 0 ...
            && any(executionTable.EndTime > rotationDuration + 1e-9)
        warnings(end + 1, 1) = "部分角色排轴超过循环时长。";
    end
end
