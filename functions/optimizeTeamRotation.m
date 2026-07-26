function result = optimizeTeamRotation(members, basePlan, rotationDuration, enemy, sharedBuffs, options)
    % Search feasible variations of an auto-generated team rotation for maximum DPS.
    if nargin < 6 || isempty(options)
        options = struct();
    end
    if nargin < 5 || isempty(sharedBuffs)
        sharedBuffs = struct();
    end
    if nargin < 4 || isempty(enemy)
        enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
    end
    if nargin < 3 || isempty(rotationDuration)
        rotationDuration = getFieldOrDefault(basePlan, 'RotationDuration', 20);
    end

    maxCandidates = max(1, round(double(getFieldOrDefault(options, 'OptimizerMaxCandidates', 24))));
    swapBuffer = max(0, double(getFieldOrDefault(options, 'SwapBuffer', 0.20)));
    candidates = localBuildCandidates(basePlan, members, rotationDuration, swapBuffer, maxCandidates);
    teamContext = buildTeamContext(members, rotationDuration, sharedBuffs, enemy);
    evaluated = repmat(localEmptyEvaluation(), 1, 0);

    for candidateIndex = 1:numel(candidates)
        candidate = candidates(candidateIndex);
        loopReport = validateTeamRotationLoop(members, candidate.Plan, teamContext, enemy, options);
        evaluation = localEmptyEvaluation();
        evaluation.Label = candidate.Label;
        evaluation.Plan = candidate.Plan;
        evaluation.LoopReport = loopReport;
        if ~loopReport.IsFeasible
            evaluated(end + 1) = evaluation; %#ok<AGROW>
            continue;
        end

        simulation = localEvaluateCandidateDPS(members, candidate.Plan, rotationDuration, enemy, sharedBuffs);
        evaluation.DPS = double(simulation.DPS);
        evaluation.TotalDMG = double(simulation.TotalDMG);
        evaluation.IsFeasible = true;
        evaluated(end + 1) = evaluation; %#ok<AGROW>
    end

    feasibleMask = [evaluated.IsFeasible];
    if any(feasibleMask)
        feasibleIndices = find(feasibleMask);
        [~, localBest] = max([evaluated(feasibleIndices).DPS]);
        bestIndex = feasibleIndices(localBest);
    else
        bestIndex = 0;
    end

    result = struct( ...
        'Enabled', true, ...
        'CandidateCount', numel(evaluated), ...
        'FeasibleCandidateCount', sum(feasibleMask), ...
        'BestIndex', bestIndex, ...
        'BestPlan', basePlan, ...
        'BestDPS', NaN, ...
        'BestLoopReport', struct(), ...
        'Evaluations', evaluated);
    if bestIndex > 0
        result.BestPlan = localMaterializePlan(evaluated(bestIndex).Plan, members);
        result.BestDPS = evaluated(bestIndex).DPS;
        result.BestLoopReport = evaluated(bestIndex).LoopReport;
        result.BestPlan.SelectionMode = "dps-optimized " + evaluated(bestIndex).Label;
        result.BestPlan.SelectionSummary = sprintf('stable DPS=%.0f; feasible candidates=%d/%d', ...
            result.BestDPS, result.FeasibleCandidateCount, result.CandidateCount);
        result.BestPlan.SelectionMetrics = struct( ...
            'StableDPS', result.BestDPS, ...
            'FeasibleCandidateCount', result.FeasibleCandidateCount, ...
            'CandidateCount', result.CandidateCount, ...
            'MinimumCooldownMargin', result.BestLoopReport.MinimumCooldownMargin);
    end
end

function candidates = localBuildCandidates(basePlan, members, rotationDuration, swapBuffer, maxCandidates)
    candidates = repmat(struct('Label', "", 'Plan', struct()), 1, 0);
    candidates(end + 1) = struct('Label', "base", 'Plan', basePlan); %#ok<AGROW>
    memberCount = numel(members);
    baseOrder = double(getFieldOrDefault(basePlan, 'ExecutionOrder', 1:memberCount));
    if isempty(baseOrder)
        baseOrder = 1:memberCount;
    end
    orders = localPermute(baseOrder);
    for orderIndex = 1:numel(orders)
        if numel(candidates) >= maxCandidates
            break;
        end
        if ~localOrderRespectsCarryWindow(orders{orderIndex}, basePlan)
            continue;
        end
        candidatePlan = localReschedule(basePlan, members, orders{orderIndex}, rotationDuration, swapBuffer);
        candidates(end + 1) = struct('Label', "order-" + join(string(orders{orderIndex}), "-"), 'Plan', candidatePlan); %#ok<AGROW>
    end

    basePlans = getFieldOrDefault(basePlan, 'MemberPlans', struct([]));
    for memberIndex = 1:numel(basePlans)
        if numel(candidates) >= maxCandidates
            break;
        end
        tokens = localNormalizeTokens(getFieldOrDefault(basePlans(memberIndex), 'RotationTokens', {}));
        burstIndex = localFindBurstToken(tokens);
        if isempty(burstIndex)
            continue;
        end
        candidatePlan = basePlan;
        tokens(burstIndex) = [];
        candidatePlan.MemberPlans(memberIndex).RotationTokens = tokens;
        candidatePlan.MemberPlans(memberIndex).RotationText = localTokensToText(tokens);
        candidatePlan = localReschedule(candidatePlan, members, baseOrder, rotationDuration, swapBuffer);
        candidates(end + 1) = struct('Label', "drop-burst-" + string(memberIndex), 'Plan', candidatePlan); %#ok<AGROW>
    end

    carryIndex = double(getFieldOrDefault(basePlan, 'CarryIndex', 0));
    if carryIndex >= 1 && carryIndex <= numel(basePlans) && numel(candidates) < maxCandidates
        candidatePlan = basePlan;
        tokens = localNormalizeTokens(getFieldOrDefault(candidatePlan.MemberPlans(carryIndex), 'RotationTokens', {}));
        tokens{end + 1, 1} = 'N1';
        candidatePlan.MemberPlans(carryIndex).RotationTokens = tokens;
        candidatePlan.MemberPlans(carryIndex).RotationText = localTokensToText(tokens);
        candidatePlan = localReschedule(candidatePlan, members, baseOrder, rotationDuration, swapBuffer);
        candidates(end + 1) = struct('Label', "carry-n1", 'Plan', candidatePlan); %#ok<AGROW>
    end
end

function tf = localOrderRespectsCarryWindow(order, basePlan)
    carryIndex = double(getFieldOrDefault(basePlan, 'CarryIndex', 0));
    tf = carryIndex < 1 || (numel(order) >= 1 && order(end) == carryIndex);
end

function plan = localReschedule(plan, members, order, rotationDuration, swapBuffer)
    cursor = 0;
    for orderIndex = 1:numel(order)
        memberIndex = order(orderIndex);
        tokens = localNormalizeTokens(getFieldOrDefault(plan.MemberPlans(memberIndex), 'RotationTokens', {}));
        duration = 0;
        for tokenIndex = 1:numel(tokens)
            duration = duration + estimateActionDuration(members{memberIndex}.Name, tokens{tokenIndex}, 0.60);
        end
        duration = min(duration, max(0, rotationDuration - cursor));
        plan.MemberPlans(memberIndex).Order = orderIndex;
        plan.MemberPlans(memberIndex).StartTime = cursor;
        plan.MemberPlans(memberIndex).EndTime = cursor + duration;
        plan.MemberPlans(memberIndex).EstimatedDuration = duration;
        cursor = min(rotationDuration, cursor + duration + swapBuffer);
    end
    plan.ExecutionOrder = order;
    plan.RotationDuration = rotationDuration;
end

function simulation = localEvaluateCandidateDPS(members, plan, rotationDuration, enemy, sharedBuffs)
    tempDir = tempname;
    mkdir(tempDir);
    cleanup = onCleanup(@() localCleanupDirectory(tempDir)); %#ok<NASGU>
    candidateMembers = members;
    for memberIndex = 1:numel(candidateMembers)
        tokens = localNormalizeTokens(getFieldOrDefault(plan.MemberPlans(memberIndex), 'RotationTokens', {}));
        candidateMembers{memberIndex}.RotationFile = writeTempRotationFile( ...
            tempDir, candidateMembers{memberIndex}.Name, memberIndex, localTokensToText(tokens));
        candidateMembers{memberIndex}.StartTime = getFieldOrDefault(plan.MemberPlans(memberIndex), 'StartTime', 0);
    end
    spec = struct( ...
        'Members', {candidateMembers}, ...
        'RotationDuration', rotationDuration, ...
        'SharedBuffs', sharedBuffs, ...
        'PlanOptions', struct('DisableAutoPlan', true));
    simulation = simulateTeamDPS(spec, enemy);
end

function plan = localMaterializePlan(plan, members)
    planRoot = fullfile(tempdir, 'genshin_dmg_calc_optimized_rotations', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS')));
    if exist(planRoot, 'dir') ~= 7
        mkdir(planRoot);
    end
    executionRows = cell(0, 8);
    order = double(getFieldOrDefault(plan, 'ExecutionOrder', 1:numel(members)));
    for orderIndex = 1:numel(order)
        memberIndex = order(orderIndex);
        tokens = localNormalizeTokens(getFieldOrDefault(plan.MemberPlans(memberIndex), 'RotationTokens', {}));
        plan.MemberPlans(memberIndex).RotationText = localTokensToText(tokens);
        plan.MemberPlans(memberIndex).TempRotationFile = writeTempRotationFile( ...
            planRoot, members{memberIndex}.Name, orderIndex, plan.MemberPlans(memberIndex).RotationText);
        plan.MemberPlans(memberIndex).Preview = join(string(tokens(:)).', " > ");
        executionRows(end + 1, :) = { ... %#ok<AGROW>
            orderIndex, ...
            string(getFieldOrDefault(members{memberIndex}, 'DisplayName', members{memberIndex}.Name)), ...
            string(getFieldOrDefault(plan.MemberPlans(memberIndex), 'Role', "")), ...
            string(getFieldOrDefault(plan.MemberPlans(memberIndex), 'Job', "")), ...
            double(getFieldOrDefault(plan.MemberPlans(memberIndex), 'StartTime', 0)), ...
            double(getFieldOrDefault(plan.MemberPlans(memberIndex), 'EndTime', 0)), ...
            double(getFieldOrDefault(plan.MemberPlans(memberIndex), 'EstimatedDuration', 0)), ...
            plan.MemberPlans(memberIndex).Preview};
    end
    plan.PlanDirectory = string(planRoot);
    plan.ExecutionTable = cell2table(executionRows, 'VariableNames', { ...
        'Order', 'Character', 'Role', 'Job', 'StartTime', 'EndTime', 'ReservedTime', 'RotationPreview'});
end

function localCleanupDirectory(path)
    if exist(path, 'dir') == 7
        rmdir(path, 's');
    end
end

function evaluation = localEmptyEvaluation()
    evaluation = struct('Label', "", 'Plan', struct(), 'LoopReport', struct(), ...
        'IsFeasible', false, 'DPS', NaN, 'TotalDMG', NaN);
end

function permutations = localPermute(values)
    values = reshape(values, 1, []);
    if isempty(values)
        permutations = {values};
    elseif numel(values) == 1
        permutations = {values};
    else
        permutations = cell(0, 1);
        for i = 1:numel(values)
            remaining = values([1:i - 1, i + 1:end]);
            children = localPermute(remaining);
            for childIndex = 1:numel(children)
                permutations{end + 1, 1} = [values(i), children{childIndex}]; %#ok<AGROW>
            end
        end
    end
end

function index = localFindBurstToken(tokens)
    index = [];
    for i = 1:numel(tokens)
        token = lower(strtrim(char(string(tokens{i}))));
        if strcmp(token, 'q') || strcmp(token, 'burst') || ~isempty(regexp(token, '^q\d+$', 'once')) ...
                || any(strcmp(token, {'qphysical', 'qpyro'}))
            index = i;
            return;
        end
    end
end

function text = localTokensToText(tokens)
    tokens = localNormalizeTokens(tokens);
    if isempty(tokens)
        text = "AUTO";
    else
        text = join(string(tokens(:)), newline);
    end
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
