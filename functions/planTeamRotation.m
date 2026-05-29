function plan = planTeamRotation(members, rotationDuration, enemy, sharedBuffs, options)
    % 为统一队伍入口即时生成本轮排轴。
    %
    % 设计目标：
    % 1. 不重写现有角色模拟器，而是为每名角色动态生成本轮 rotation token；
    % 2. 支援位尽量压缩为“挂后台 / 开增益 / 放召唤物”的短轴；
    % 3. 主C保留更完整的站场连段，并尽量吃满本轮剩余站场时间；
    % 4. 最终落为临时 rotation 文件，继续复用现有 readRotationTokens 流程。
    initProjectPaths();

    if nargin < 2 || isempty(rotationDuration)
        rotationDuration = 20;
    end
    if nargin < 3 || isempty(enemy)
        enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0); %#ok<NASGU>
    end
    if nargin < 4 || isempty(sharedBuffs)
        sharedBuffs = struct(); %#ok<NASGU>
    end
    if nargin < 5 || isempty(options)
        options = struct();
    end

    memberCount = numel(members);
    if memberCount == 0
        plan = struct( ...
            'RotationDuration', rotationDuration, ...
            'CarryIndex', 0, ...
            'ExecutionOrder', zeros(1, 0), ...
            'PlanDirectory', "", ...
            'MemberPlans', struct([]), ...
            'ArchetypeInfo', struct(), ...
            'ExecutionTable', table());
        return;
    end

    teamInfo = localBuildTeamInfo(members, sharedBuffs);
    seeds = repmat(localEmptySeed(), 1, memberCount);
    scores = repmat(localEmptyScore(), 1, memberCount);

    for i = 1:memberCount
        seeds(i) = localBuildMemberSeed(members{i});
        scores(i) = localInferMemberScores(members{i}, seeds(i), teamInfo);
    end
    scores = localApplyTeamSynergyScores(scores, teamInfo);
    scores = localApplyArchetypeScores(scores, teamInfo);

    swapBuffer = getFieldOrDefault(options, 'SwapBuffer', 0.20);
    planningSharedBuffs = localBuildPlanningSharedBuffs(sharedBuffs, members);
    planningTeamContext = buildTeamContext(members, rotationDuration, planningSharedBuffs, enemy);
    planningTeamContext.ArchetypeInfo = teamInfo.Archetype;

    candidate = localSelectBestPlanCandidate( ...
        members, seeds, scores, teamInfo, rotationDuration, enemy, ...
        planningTeamContext, swapBuffer, options);
    planRoot = localCreatePlanDirectory();
    [plans, memberOrder, executionTable] = localScheduleMemberPlans( ...
        candidate.OrderSeed, members, candidate.MemberPlans, rotationDuration, swapBuffer, planRoot, true);

    plan = struct( ...
        'RotationDuration', rotationDuration, ...
        'CarryIndex', candidate.CarryIndex, ...
        'ExecutionOrder', memberOrder, ...
        'PlanDirectory', string(planRoot), ...
        'MemberPlans', plans, ...
        'ArchetypeInfo', teamInfo.Archetype, ...
        'ExecutionTable', executionTable, ...
        'CandidateCount', candidate.CandidateCount, ...
        'SelectionScore', candidate.Score, ...
        'SelectionMode', string(candidate.CandidateLabel), ...
        'SelectionSummary', string(candidate.Summary));
end

function teamInfo = localBuildTeamInfo(members, sharedBuffs)
    if nargin < 2 || isempty(sharedBuffs)
        sharedBuffs = struct();
    end
    memberCount = numel(members);
    names = strings(1, memberCount);
    elements = strings(1, memberCount);
    normalizedNames = strings(1, memberCount);
    for i = 1:memberCount
        names(i) = string(members{i}.Name);
        elements(i) = string(getCharacterElement(members{i}.Name));
        normalizedNames(i) = localNormalizeName(members{i}.Name);
    end

    hydroCount = sum(strcmpi(elements, "Hydro"));
    dendroCount = sum(strcmpi(elements, "Dendro"));
    pyroCount = sum(strcmpi(elements, "Pyro"));
    electroCount = sum(strcmpi(elements, "Electro"));
    cryoCount = sum(strcmpi(elements, "Cryo"));

    teamInfo = struct( ...
        'Count', memberCount, ...
        'Names', names, ...
        'Elements', elements, ...
        'NormalizedNames', normalizedNames, ...
        'Archetype', identifyTeamArchetype(members, sharedBuffs), ...
        'HasNilou', any(normalizedNames == "nilou"), ...
        'HasFurina', any(normalizedNames == "furina"), ...
        'HasEscoffier', any(normalizedNames == "escoffier"), ...
        'HasCitlali', any(normalizedNames == "citlali"), ...
        'HasChevreuse', any(normalizedNames == "chevreuse"), ...
        'HasFaruzan', any(normalizedNames == "faruzan"), ...
        'HasXianyun', any(normalizedNames == "xianyun"), ...
        'HydroCount', hydroCount, ...
        'DendroCount', dendroCount, ...
        'PyroCount', pyroCount, ...
        'ElectroCount', electroCount, ...
        'CryoCount', cryoCount, ...
        'NilouPureBloom', any(normalizedNames == "nilou") ...
            && hydroCount >= 1 && dendroCount >= 1 ...
            && hydroCount + dendroCount == memberCount, ...
        'ChevreuseOverloadTeam', any(normalizedNames == "chevreuse") ...
            && pyroCount >= 1 && electroCount >= 1 ...
            && pyroCount + electroCount == memberCount);
end

function requestedStart = localResolveRequestedStartTime(member)
    requestedStart = double(getFieldOrDefault(member, 'StartTime', NaN));
    if isempty(requestedStart) || ~isscalar(requestedStart) || ~isfinite(requestedStart)
        requestedStart = NaN;
    end
end

function planningSharedBuffs = localBuildPlanningSharedBuffs(sharedBuffs, members)
    planningSharedBuffs = sharedBuffs;
    if isfield(planningSharedBuffs, 'ApproxFurinaBonus')
        return;
    end

    for i = 1:numel(members)
        if strcmpi(char(string(getFieldOrDefault(members{i}, 'Name', ""))), 'Furina')
            planningSharedBuffs.ApproxFurinaBonus = 0;
            return;
        end
    end
end

function candidate = localSelectBestPlanCandidate( ...
        members, seeds, scores, teamInfo, rotationDuration, enemy, ...
        planningTeamContext, swapBuffer, options)
    carryCandidates = localBuildCarryCandidateIndices(scores, teamInfo.Archetype);
    scoredCandidates = repmat(localEmptyPlanCandidate(), 1, 0);

    for carryPos = 1:numel(carryCandidates)
        forcedCarryIndex = carryCandidates(carryPos);
        [roles, carryIndex, memberJobs] = localAssignMemberRoles( ...
            scores, teamInfo.Archetype, teamInfo, forcedCarryIndex);
        basePlans = localBuildRolePlans( ...
            members, seeds, scores, roles, memberJobs, carryIndex, ...
            rotationDuration, teamInfo.Archetype, swapBuffer);
        baseOrder = localBuildExecutionOrder(scores, roles, memberJobs, teamInfo.Archetype);
        orderCandidates = localBuildOrderCandidates(baseOrder, members, carryIndex);

        for orderPos = 1:numel(orderCandidates)
            currentOrder = orderCandidates{orderPos};
            candidatePlans = localCloneMemberPlans(basePlans);
            [candidatePlans, memberOrder, executionTable] = localScheduleMemberPlans( ...
                currentOrder, members, candidatePlans, rotationDuration, swapBuffer, "", false);
            label = sprintf('timeline-ranked carry=%s order=%d', ...
                char(string(getFieldOrDefault(members{carryIndex}, 'DisplayName', members{carryIndex}.Name))), ...
                orderPos);
            scoredCandidates(end + 1) = localEvaluatePlanCandidate( ... %#ok<AGROW>
                label, members, candidatePlans, currentOrder, memberOrder, executionTable, ...
                carryIndex, roles, memberJobs, teamInfo.Archetype, rotationDuration, ...
                planningTeamContext, enemy, options);
        end
    end

    assert(~isempty(scoredCandidates), 'Team rotation planner should always evaluate at least one candidate.');
    [~, bestIndex] = max([scoredCandidates.Score]);
    candidate = scoredCandidates(bestIndex);

    candidate.CandidateCount = numel(scoredCandidates);
end

function carryCandidates = localBuildCarryCandidateIndices(scores, archetypeInfo)
    carryScores = [scores.CarryScore];
    supportScores = [scores.SupportScore];
    [~, carryOrder] = sort(carryScores, 'descend');
    confidence = double(getFieldOrDefault(archetypeInfo, 'Confidence', 0));
    primary = string(getFieldOrDefault(archetypeInfo, 'PrimaryArchetype', ""));

    carryCandidates = zeros(1, 0);
    recommended = getFieldOrDefault(archetypeInfo, 'RecommendedCarryIndices', []);
    if ~isempty(recommended)
        recommended = recommended(recommended >= 1 & recommended <= numel(scores));
        for i = 1:numel(recommended)
            candidateIndex = recommended(i);
            if ~localIsViableCarryCandidate(scores(candidateIndex), primary, confidence)
                continue;
            end
            carryCandidates(end + 1) = candidateIndex; %#ok<AGROW>
        end
    end

    if ~isempty(carryOrder)
        if localIsViableCarryCandidate(scores(carryOrder(1)), primary, confidence)
            carryCandidates = [carryCandidates, carryOrder(1)]; %#ok<AGROW>
        end
        topScore = carryScores(carryOrder(1));
        for orderIndex = 2:numel(carryOrder)
            candidateIndex = carryOrder(orderIndex);
            carryLead = carryScores(candidateIndex) - supportScores(candidateIndex);
            if ~localIsViableCarryCandidate(scores(candidateIndex), primary, confidence)
                continue;
            end
            if carryScores(candidateIndex) < topScore - 0.75
                continue;
            end
            if carryLead < -0.25
                continue;
            end
            carryCandidates(end + 1) = candidateIndex; %#ok<AGROW>
            break;
        end
    end

    carryCandidates = unique(carryCandidates, 'stable');
    carryCandidates = carryCandidates(carryCandidates >= 1 & carryCandidates <= numel(scores));
    if isempty(carryCandidates)
        carryCandidates = 1;
    end
end

function tf = localIsViableCarryCandidate(score, primary, confidence)
    normalizedName = string(getFieldOrDefault(score, 'NormalizedName', ""));
    carryScore = double(getFieldOrDefault(score, 'CarryScore', 0));
    supportScore = double(getFieldOrDefault(score, 'SupportScore', 0));

    tf = true;
    if ~localShouldDefaultToSupport(normalizedName)
        return;
    end
    if confidence >= 0.85 && any(primary == ["Freeze", "Vaporize", "Melt", "Plunge", ...
            "GeoHypercarry", "AnemoHypercarry", "Mono", "Hyperbloom", ...
            "Bloom", "Burgeon", "Overload", "Aggravate", "Spread"])
        return;
    end

    tf = carryScore >= max(6.5, supportScore + 0.5);
end

function plans = localBuildRolePlans( ...
        members, seeds, scores, roles, memberJobs, carryIndex, ...
        rotationDuration, archetypeInfo, swapBuffer)
    plans = repmat(localEmptyMemberPlan(), 1, numel(members));
    order = localBuildExecutionOrder(scores, roles, memberJobs, archetypeInfo);
    otherReservedDuration = 0;

    for orderPos = 1:numel(order)
        memberIndex = order(orderPos);
        if memberIndex == carryIndex
            continue;
        end

        role = roles(memberIndex);
        targetBudget = localResolveMemberBudget( ...
            role, memberJobs(memberIndex), rotationDuration, archetypeInfo);
        plans(memberIndex) = localBuildMemberPlan( ...
            members{memberIndex}, seeds(memberIndex), scores(memberIndex), ...
            role, targetBudget, archetypeInfo, memberJobs(memberIndex));
        otherReservedDuration = otherReservedDuration + plans(memberIndex).EstimatedDuration;
    end

    reservedOther = otherReservedDuration + swapBuffer * max(0, numel(members) - 1);
    carryBudget = rotationDuration - min(reservedOther, 0.65 * rotationDuration);
    carryBudget = max(6.0, carryBudget);
    carryBudget = localResolveCarryBudget( ...
        carryBudget, scores(carryIndex), members{carryIndex}.Name, ...
        rotationDuration, archetypeInfo);
    plans(carryIndex) = localBuildMemberPlan( ...
        members{carryIndex}, seeds(carryIndex), scores(carryIndex), ...
        "Carry", carryBudget, archetypeInfo, memberJobs(carryIndex));
end

function orderCandidates = localBuildOrderCandidates(baseOrder, members, carryIndex)
    orderCandidates = {baseOrder};
    nonCarry = setdiff(baseOrder, carryIndex, 'stable');

    if ~isempty(nonCarry)
        orderCandidates{end + 1} = [nonCarry, carryIndex]; %#ok<AGROW>
        orderCandidates{end + 1} = [carryIndex, nonCarry]; %#ok<AGROW>
    end
    if numel(nonCarry) > 1
        orderCandidates{end + 1} = [nonCarry(end:-1:1), carryIndex]; %#ok<AGROW>
        orderCandidates{end + 1} = [[nonCarry(2:end), nonCarry(1)], carryIndex]; %#ok<AGROW>
    end

    requestedStarts = nan(1, numel(members));
    for i = 1:numel(members)
        requestedStarts(i) = localResolveRequestedStartTime(members{i});
    end
    explicitMembers = find(isfinite(requestedStarts));
    if ~isempty(explicitMembers)
        anchoredOrder = [explicitMembers(:).', setdiff(baseOrder, explicitMembers, 'stable')];
        orderCandidates{end + 1} = anchoredOrder; %#ok<AGROW>
    end

    signatures = strings(0, 1);
    uniqueCandidates = cell(0, 1);
    for orderIndex = 1:numel(orderCandidates)
        candidate = orderCandidates{orderIndex};
        signature = strjoin(string(candidate), '-');
        if any(signatures == signature)
            continue;
        end
        signatures(end + 1, 1) = signature; %#ok<AGROW>
        uniqueCandidates{end + 1, 1} = candidate; %#ok<AGROW>
    end
    orderCandidates = uniqueCandidates;
end

function candidate = localEvaluatePlanCandidate( ...
        label, members, memberPlans, orderSeed, memberOrder, executionTable, ...
        carryIndex, roles, memberJobs, archetypeInfo, rotationDuration, ...
        planningTeamContext, enemy, options)
    rotationPlan = struct( ...
        'RotationDuration', rotationDuration, ...
        'CarryIndex', carryIndex, ...
        'ExecutionOrder', memberOrder, ...
        'PlanDirectory', "", ...
        'MemberPlans', memberPlans, ...
        'ArchetypeInfo', archetypeInfo, ...
        'ExecutionTable', executionTable);
    timelineResult = simulateTeamTimeline(members, rotationPlan, planningTeamContext, enemy, options);
    [score, summary] = localScorePlanCandidate(rotationPlan, timelineResult, roles, memberJobs, rotationDuration);

    candidate = localEmptyPlanCandidate();
    candidate.CandidateLabel = string(label);
    candidate.Score = score;
    candidate.Summary = string(summary);
    candidate.CarryIndex = carryIndex;
    candidate.Roles = roles;
    candidate.MemberJobs = memberJobs;
    candidate.OrderSeed = orderSeed;
    candidate.MemberPlans = memberPlans;
    candidate.ExecutionOrder = memberOrder;
    candidate.ExecutionTable = executionTable;
    candidate.TimelineResult = timelineResult;
end

function [score, summary] = localScorePlanCandidate(rotationPlan, timelineResult, roles, memberJobs, rotationDuration)
    timelineSummary = getFieldOrDefault(timelineResult, 'TimelineSummary', struct());
    energySummary = getFieldOrDefault(timelineResult, 'EnergySummary', table());
    timelineTable = getFieldOrDefault(timelineResult, 'TimelineTable', table());

    idleFrac = max(0, double(getFieldOrDefault(timelineSummary, 'IdleTime', 0))) / max(rotationDuration, 1e-6);
    overlapFrac = max(0, double(getFieldOrDefault(timelineSummary, 'OverlapTime', 0))) / max(rotationDuration, 1e-6);
    occupiedTime = max(0, double(getFieldOrDefault(timelineSummary, 'MemberOccupiedTime', 0))) ...
        + max(0, double(getFieldOrDefault(timelineSummary, 'AutonomousBackgroundTime', 0))) ...
        + max(0, double(getFieldOrDefault(timelineSummary, 'ActionTriggeredBackgroundTime', 0))) ...
        + max(0, double(getFieldOrDefault(timelineSummary, 'ReactionTriggeredBackgroundTime', 0)));
    occupiedFrac = min(1.25, occupiedTime / max(rotationDuration, 1e-6));
    loopReadiness = min(1, max(0, double(getFieldOrDefault(timelineResult, 'LoopReadiness', 0))));

    reactionDensity = 0;
    if istable(timelineTable) && height(timelineTable) > 0 && ismember('Reactions', string(timelineTable.Properties.VariableNames))
        reactionRows = sum(strlength(strtrim(string(timelineTable.Reactions))) > 0);
        reactionDensity = min(1, reactionRows / max(height(timelineTable), 1));
    end

    missingRatio = 0;
    if istable(energySummary) && height(energySummary) > 0
        burstMask = logical(energySummary.UsedBurst);
        if any(burstMask)
            missingEnergy = sum(max(0, double(energySummary.MissingEnergy(burstMask))));
            burstCost = sum(max(1, double(energySummary.BurstCost(burstMask))));
            missingRatio = min(2.0, missingEnergy / max(burstCost, 1));
        end
    end

    setupCoverage = localComputeSetupCoverage(rotationPlan);
    orderPenalty = localComputeOrderPenalty(rotationPlan, roles, memberJobs);
    score = 4.0 * loopReadiness ...
        + 2.5 * occupiedFrac ...
        + 0.8 * reactionDensity ...
        + 1.0 * localComputeBurstCoverage(rotationPlan) ...
        + 1.2 * localComputeCarryWindowQuality(rotationPlan, rotationDuration) ...
        + 0.6 * setupCoverage ...
        - 3.0 * idleFrac ...
        - 5.0 * overlapFrac ...
        - 2.4 * missingRatio ...
        - 0.35 * orderPenalty;

    summary = sprintf('score=%.3f loop=%.2f idle=%.2fs overlap=%.2fs energy=%.2f', ...
        score, loopReadiness, ...
        double(getFieldOrDefault(timelineSummary, 'IdleTime', 0)), ...
        double(getFieldOrDefault(timelineSummary, 'OverlapTime', 0)), ...
        missingRatio);
end

function setupCoverage = localComputeSetupCoverage(rotationPlan)
    setupCoverage = 0.5;
    carryIndex = double(getFieldOrDefault(rotationPlan, 'CarryIndex', 0));
    memberPlans = getFieldOrDefault(rotationPlan, 'MemberPlans', struct([]));
    if carryIndex < 1 || carryIndex > numel(memberPlans)
        return;
    end

    carryStart = double(getFieldOrDefault(memberPlans(carryIndex), 'StartTime', 0));
    carryEnd = double(getFieldOrDefault(memberPlans(carryIndex), 'EndTime', carryStart));
    if carryEnd <= carryStart + 1e-9
        return;
    end

    setupTime = 0;
    for i = 1:numel(memberPlans)
        if i == carryIndex
            continue;
        end
        memberStart = double(getFieldOrDefault(memberPlans(i), 'StartTime', 0));
        memberEnd = double(getFieldOrDefault(memberPlans(i), 'EndTime', memberStart));
        setupTime = setupTime + max(0, min(carryStart, memberEnd) - memberStart);
    end

    setupCoverage = min(1, setupTime / max(carryStart, 0.6));
end

function penalty = localComputeOrderPenalty(rotationPlan, roles, memberJobs)
    penalty = 0;
    memberPlans = getFieldOrDefault(rotationPlan, 'MemberPlans', struct([]));
    carryIndex = double(getFieldOrDefault(rotationPlan, 'CarryIndex', 0));
    carryStart = inf;
    if carryIndex >= 1 && carryIndex <= numel(memberPlans)
        carryStart = double(getFieldOrDefault(memberPlans(carryIndex), 'StartTime', inf));
    end

    for i = 1:numel(memberPlans)
        memberStart = double(getFieldOrDefault(memberPlans(i), 'StartTime', 0));
        if i ~= carryIndex && string(memberJobs(i)) == "Opener" && memberStart > carryStart + 1e-9
            penalty = penalty + 1.0;
        end
        if i ~= carryIndex && string(roles(i)) == "Support" && memberStart > carryStart + 2.5
            penalty = penalty + 0.5;
        end
    end
end

function burstCoverage = localComputeBurstCoverage(rotationPlan)
    burstCoverage = 0;
    memberPlans = getFieldOrDefault(rotationPlan, 'MemberPlans', struct([]));
    if isempty(memberPlans)
        return;
    end
    burstCount = 0;
    for i = 1:numel(memberPlans)
        if localPlanContainsBurst(getFieldOrDefault(memberPlans(i), 'RotationTokens', {}))
            burstCount = burstCount + 1;
        end
    end
    burstCoverage = burstCount / max(numel(memberPlans), 1);
end

function quality = localComputeCarryWindowQuality(rotationPlan, rotationDuration)
    quality = 0;
    carryIndex = double(getFieldOrDefault(rotationPlan, 'CarryIndex', 0));
    memberPlans = getFieldOrDefault(rotationPlan, 'MemberPlans', struct([]));
    if carryIndex < 1 || carryIndex > numel(memberPlans)
        return;
    end

    carryDuration = double(getFieldOrDefault(memberPlans(carryIndex), 'EstimatedDuration', 0));
    if carryDuration <= 0
        return;
    end
    targetDuration = min(7.0, max(4.0, 0.28 * rotationDuration));
    quality = 1.0 - min(1.0, abs(carryDuration - targetDuration) / max(targetDuration, 1e-6));
    if carryDuration < 3.0
        quality = quality - 0.5;
    end
    quality = max(-1.0, quality);
end

function tf = localPlanContainsBurst(tokens)
    tokens = localNormalizeTokenList(tokens);
    tf = false;
    for i = 1:numel(tokens)
        if localIsBurstToken(tokens{i})
            tf = true;
            return;
        end
    end
end

function plans = localCloneMemberPlans(plans)
    for i = 1:numel(plans)
        plans(i).RotationTokens = localNormalizeTokenList(getFieldOrDefault(plans(i), 'RotationTokens', {}));
    end
end

function [plans, memberOrder, executionTable] = localScheduleMemberPlans( ...
        defaultOrder, members, plans, rotationDuration, swapBuffer, planRoot, writeFiles)
    if nargin < 7 || isempty(writeFiles)
        writeFiles = true;
    end
    memberCount = numel(members);
    requestedStarts = nan(1, memberCount);
    defaultPositions = zeros(1, memberCount);
    explicitMask = false(1, memberCount);

    for i = 1:numel(defaultOrder)
        defaultPositions(defaultOrder(i)) = i;
    end
    for i = 1:memberCount
        requestedStarts(i) = localResolveRequestedStartTime(members{i});
        explicitMask(i) = isfinite(requestedStarts(i));
        plans(i).StartTime = 0;
        plans(i).EndTime = 0;
    end

    explicitMembers = defaultOrder(explicitMask(defaultOrder));
    if ~isempty(explicitMembers)
        explicitSortMatrix = [requestedStarts(explicitMembers).', defaultPositions(explicitMembers).'];
        explicitSortRows = [(1:numel(explicitMembers)).', explicitSortMatrix];
        explicitSortRows = sortrows(explicitSortRows, [2 3]);
        explicitMembers = explicitMembers(explicitSortRows(:, 1).');
    end
    implicitMembers = defaultOrder(~explicitMask(defaultOrder));

    scheduledMembers = zeros(1, 0);
    implicitPtr = 1;
    cursor = 0;

    if isempty(explicitMembers)
        [plans, implicitPtr, cursor, scheduledWindowMembers] = localScheduleImplicitWindow( ...
            implicitMembers, implicitPtr, cursor, rotationDuration, plans, members, swapBuffer);
        scheduledMembers = [scheduledMembers, scheduledWindowMembers]; %#ok<AGROW>
    else
        for explicitPos = 1:numel(explicitMembers)
            memberIndex = explicitMembers(explicitPos);
            anchorStart = max(0, requestedStarts(memberIndex));
            anchorStart = min(anchorStart, rotationDuration);

            [plans, implicitPtr, cursor, scheduledWindowMembers] = localScheduleImplicitWindow( ...
                implicitMembers, implicitPtr, cursor, anchorStart, plans, members, swapBuffer);
            scheduledMembers = [scheduledMembers, scheduledWindowMembers]; %#ok<AGROW>

            anchorEndLimit = rotationDuration;
            if explicitPos < numel(explicitMembers)
                anchorEndLimit = min(anchorEndLimit, max(0, requestedStarts(explicitMembers(explicitPos + 1))));
            end
            plans(memberIndex) = localFitMemberPlanToBudget( ...
                plans(memberIndex), members{memberIndex}.Name, max(0, anchorEndLimit - anchorStart));
            plans(memberIndex).StartTime = anchorStart;
            plans(memberIndex).EndTime = anchorStart + plans(memberIndex).EstimatedDuration;
            scheduledMembers(end + 1) = memberIndex; %#ok<AGROW>
            cursor = min(rotationDuration, plans(memberIndex).EndTime + swapBuffer);
        end

        [plans, implicitPtr, cursor, scheduledWindowMembers] = localScheduleImplicitWindow( ...
            implicitMembers, implicitPtr, cursor, rotationDuration, plans, members, swapBuffer);
        scheduledMembers = [scheduledMembers, scheduledWindowMembers]; %#ok<AGROW>
    end

    while implicitPtr <= numel(implicitMembers)
        memberIndex = implicitMembers(implicitPtr);
        fallbackStart = min(rotationDuration, max(0, cursor));
        plans(memberIndex) = localFitMemberPlanToBudget( ...
            plans(memberIndex), members{memberIndex}.Name, max(0, rotationDuration - fallbackStart));
        plans(memberIndex).StartTime = fallbackStart;
        plans(memberIndex).EndTime = fallbackStart + plans(memberIndex).EstimatedDuration;
        scheduledMembers(end + 1) = memberIndex; %#ok<AGROW>
        cursor = min(rotationDuration, plans(memberIndex).EndTime + swapBuffer);
        implicitPtr = implicitPtr + 1;
    end

    if isempty(scheduledMembers)
        memberOrder = defaultOrder;
    else
        uniqueScheduled = unique(scheduledMembers(:), 'stable');
        sortMatrix = [ ...
            (1:memberCount).', ...
            [plans.StartTime].', ...
            [plans.EndTime].', ...
            defaultPositions(:)];
        sortedMembers = sortrows(sortMatrix(ismember(sortMatrix(:, 1), uniqueScheduled), :), [2 3 4]);
        memberOrder = sortedMembers(:, 1).';
        if numel(uniqueScheduled) < memberCount
            missingMembers = setdiff(defaultOrder, uniqueScheduled, 'stable');
            memberOrder = [memberOrder, missingMembers];
        end
    end

    executionRows = cell(0, 8);
    for orderPos = 1:numel(memberOrder)
        memberIndex = memberOrder(orderPos);
        plans(memberIndex).Order = orderPos;
        if writeFiles
            plans(memberIndex).TempRotationFile = localWritePlanFile( ...
                planRoot, orderPos, members{memberIndex}.Name, plans(memberIndex).RotationText);
        else
            plans(memberIndex).TempRotationFile = "";
        end

        executionRows(end + 1, :) = { ... %#ok<AGROW>
            orderPos, ...
            string(getFieldOrDefault(members{memberIndex}, 'DisplayName', members{memberIndex}.Name)), ...
            string(plans(memberIndex).Role), ...
            string(getFieldOrDefault(plans(memberIndex), 'Job', "")), ...
            plans(memberIndex).StartTime, ...
            plans(memberIndex).EndTime, ...
            plans(memberIndex).EstimatedDuration, ...
            plans(memberIndex).Preview};
    end

    executionTable = cell2table(executionRows, 'VariableNames', { ...
        'Order', 'Character', 'Role', 'Job', 'StartTime', 'EndTime', 'ReservedTime', 'RotationPreview'});
end

function [plans, ptr, cursor, scheduledMembers] = localScheduleImplicitWindow( ...
        implicitMembers, ptr, windowStart, windowEnd, plans, members, swapBuffer)
    cursor = max(0, windowStart);
    scheduledMembers = zeros(1, 0);
    hardWindowEnd = max(cursor, windowEnd);

    while ptr <= numel(implicitMembers)
        if cursor >= hardWindowEnd - 1e-9
            break;
        end

        memberIndex = implicitMembers(ptr);
        availableBudget = max(0, hardWindowEnd - cursor);
        fittedPlan = localFitMemberPlanToBudget(plans(memberIndex), members{memberIndex}.Name, availableBudget);
        if fittedPlan.EstimatedDuration <= 0
            break;
        end

        plans(memberIndex) = fittedPlan;
        plans(memberIndex).StartTime = cursor;
        plans(memberIndex).EndTime = cursor + plans(memberIndex).EstimatedDuration;
        scheduledMembers(end + 1) = memberIndex; %#ok<AGROW>
        ptr = ptr + 1;
        cursor = min(hardWindowEnd, plans(memberIndex).EndTime + swapBuffer);
    end
end

function seed = localBuildMemberSeed(member)
    seed = localEmptySeed();
    seed.Name = string(member.Name);
    seed.DisplayName = string(getFieldOrDefault(member, 'DisplayName', member.Name));

    [rotationFile, rotationText, tokens, source] = localReadSeedRotation(member);
    seed.SeedRotationFile = string(rotationFile);
    seed.SeedRotationText = string(rotationText);
    seed.Source = string(source);
    seed.Tokens = tokens;
    seed.ReferenceTokens = localDropAutoToken(tokens);
    seed.IsExplicit = logical(localResolveSeedExplicitness(member, rotationFile));
    if seed.IsExplicit
        seed.HasAuto = isempty(tokens) || (numel(tokens) == 1 && strcmpi(tokens{1}, 'AUTO'));
        seed.ExplicitTokens = localDropAutoToken(tokens);
    else
        seed.HasAuto = true;
        seed.ExplicitTokens = {};
    end
    seed.EstimatedDuration = localEstimateRotationDuration(seed.ReferenceTokens, member.Name);
end

function [rotationFile, rotationText, tokens, source] = localReadSeedRotation(member)
    defaultCfg = getDefaultCharacterConfig(member.Name);
    defaultRotationFile = string(getFieldOrDefault(defaultCfg, 'RotationFile', ""));
    memberRotationFile = string(getFieldOrDefault(member, 'RotationFile', ""));
    rotationText = "";
    tokens = {};
    isExplicit = localResolveSeedExplicitness(member, memberRotationFile);

    if isExplicit && strlength(memberRotationFile) > 0 && exist(char(memberRotationFile), 'file') == 2
        rotationFile = memberRotationFile;
        source = "member-explicit";
        rotationText = string(fileread(char(rotationFile)));
        tokens = readRotationTokens(char(rotationFile));
    else
        rotationFile = defaultRotationFile;
        source = "default";
        if strlength(rotationFile) > 0 && exist(char(rotationFile), 'file') == 2
            rotationText = string(fileread(char(rotationFile)));
            tokens = readRotationTokens(char(rotationFile));
        elseif strlength(memberRotationFile) > 0 && exist(char(memberRotationFile), 'file') == 2
            rotationFile = memberRotationFile;
            source = "member-fallback";
            rotationText = string(fileread(char(rotationFile)));
            tokens = readRotationTokens(char(rotationFile));
        end
    end

    if strlength(strtrim(rotationText)) == 0
        rotationText = "AUTO";
    end
    if isempty(tokens)
        tokens = {'AUTO'};
    end
end

function isExplicit = localResolveSeedExplicitness(member, rotationFile)
    explicitValue = getFieldOrDefault(member, 'HasExplicitRotationSeed', []);
    if ~isempty(explicitValue)
        isExplicit = logical(explicitValue);
        return;
    end

    rotationFile = string(rotationFile);
    if strlength(rotationFile) == 0
        isExplicit = false;
        return;
    end

    defaultCfg = getDefaultCharacterConfig(member.Name);
    defaultRotationFile = string(getFieldOrDefault(defaultCfg, 'RotationFile', ""));
    if strlength(defaultRotationFile) == 0
        isExplicit = true;
        return;
    end

    isExplicit = ~strcmpi(char(rotationFile), char(defaultRotationFile));
end

function score = localInferMemberScores(member, seed, teamInfo) %#ok<INUSD>
    score = localEmptyScore();
    score.Name = string(member.Name);
    score.NormalizedName = localNormalizeName(member.Name);
    score.CarryScore = localBaseCarryScore(score.NormalizedName);
    score.SupportScore = localBaseSupportScore(score.NormalizedName);

    explicitTokens = seed.ExplicitTokens;
    if ~isempty(explicitTokens)
        onFieldCount = 0;
        persistentCount = 0;
        hasSkill = false;
        hasBurst = false;
        for i = 1:numel(explicitTokens)
            token = string(explicitTokens{i});
            if localIsOnFieldToken(token)
                onFieldCount = onFieldCount + 1;
            end
            if localIsPersistentSupportToken(token)
                persistentCount = persistentCount + 1;
            end
            if localIsElementalSkillToken(token)
                hasSkill = true;
            end
            if localIsBurstToken(token)
                hasBurst = true;
            end
        end

        score.CarryScore = score.CarryScore + 1.20 * onFieldCount ...
            + 0.60 * double(numel(explicitTokens) >= 6);
        score.SupportScore = score.SupportScore + 0.90 * persistentCount ...
            + 0.45 * double(hasSkill) + 0.45 * double(hasBurst) ...
            + 0.60 * double(numel(explicitTokens) <= 3 && (hasSkill || hasBurst));
    else
        score.SupportScore = score.SupportScore + 0.50 * double(seed.HasAuto);
        score.CarryScore = score.CarryScore + 0.50 * double(seed.HasAuto);
    end
end

function scores = localApplyTeamSynergyScores(scores, teamInfo)
    for i = 1:numel(scores)
        name = scores(i).NormalizedName;
        element = lower(char(teamInfo.Elements(i)));

        if teamInfo.NilouPureBloom
            if name == "nilou"
                scores(i).SupportScore = scores(i).SupportScore + 4.0;
                scores(i).CarryScore = scores(i).CarryScore - 1.5;
            end
            if strcmp(element, 'dendro')
                scores(i).CarryScore = scores(i).CarryScore + 2.0;
            end
        end

        if teamInfo.HasFaruzan && strcmp(element, 'anemo') && name ~= "faruzan"
            scores(i).CarryScore = scores(i).CarryScore + 2.0;
        end

        if teamInfo.HasXianyun && any(name == ["xiao", "gaming", "hutao", "diluc", "navia"])
            scores(i).CarryScore = scores(i).CarryScore + 2.0;
        end

        if teamInfo.HasEscoffier && any(strcmp(element, {'hydro', 'cryo'})) && name ~= "escoffier"
            scores(i).CarryScore = scores(i).CarryScore + 1.5;
        end

        if teamInfo.HasCitlali && any(strcmp(element, {'pyro', 'hydro'})) && name ~= "citlali"
            scores(i).CarryScore = scores(i).CarryScore + 1.0;
        end

        if teamInfo.ChevreuseOverloadTeam && any(strcmp(element, {'pyro', 'electro'})) && name ~= "chevreuse"
            scores(i).CarryScore = scores(i).CarryScore + 1.5;
        end

        if teamInfo.HasFurina && strcmp(element, 'hydro') && name ~= "furina"
            scores(i).CarryScore = scores(i).CarryScore + 0.5;
        end
    end
end

function scores = localApplyArchetypeScores(scores, teamInfo)
    archetype = getFieldOrDefault(teamInfo, 'Archetype', struct());
    carryWeights = getFieldOrDefault(archetype, 'CarryWeights', zeros(1, numel(scores)));
    supportWeights = getFieldOrDefault(archetype, 'SupportWeights', zeros(1, numel(scores)));
    openerWeights = getFieldOrDefault(archetype, 'OpenerWeights', zeros(1, numel(scores)));

    for i = 1:numel(scores)
        if i <= numel(carryWeights)
            scores(i).CarryScore = scores(i).CarryScore + carryWeights(i);
        end
        if i <= numel(supportWeights)
            scores(i).SupportScore = scores(i).SupportScore + supportWeights(i);
        end
        if i <= numel(openerWeights)
            scores(i).OpenerScore = openerWeights(i);
        else
            scores(i).OpenerScore = 0;
        end
    end
end

function [roles, carryIndex, memberJobs] = localAssignMemberRoles(scores, archetypeInfo, teamInfo, forcedCarryIndex)
    if nargin >= 4 && ~isempty(forcedCarryIndex) ...
            && isfinite(forcedCarryIndex) && forcedCarryIndex >= 1 && forcedCarryIndex <= numel(scores)
        carryIndex = double(forcedCarryIndex);
    else
        carryIndex = localChooseCarryIndex(scores, archetypeInfo);
    end
    roles = repmat("Support", 1, numel(scores));
    memberJobs = repmat("Sustain", 1, numel(scores));
    preferredJobs = string(getFieldOrDefault(archetypeInfo, 'PreferredJobs', strings(1, numel(scores))));
    if numel(preferredJobs) < numel(scores)
        preferredJobs(numel(scores)) = "";
    end

    for i = 1:numel(scores)
        if i == carryIndex
            roles(i) = "Carry";
            preferredJob = localPreferredJobAtIndex(preferredJobs, i);
            if any(preferredJob == ["Carry", "Driver"])
                memberJobs(i) = preferredJob;
            else
                memberJobs(i) = localResolveCarryJob(scores(i).NormalizedName, archetypeInfo);
            end
            continue;
        end

        preferredJob = localPreferredJobAtIndex(preferredJobs, i);
        if strlength(preferredJob) > 0 && preferredJob ~= "Carry"
            memberJobs(i) = preferredJob;
        else
            memberJobs(i) = localResolveSupportJob( ...
                scores(i).NormalizedName, string(teamInfo.Elements(i)), teamInfo, archetypeInfo, scores(i));
        end
        if localShouldDefaultToSupport(scores(i).NormalizedName)
            roles(i) = "Support";
        elseif scores(i).CarryScore >= max(6.5, scores(i).SupportScore + 2.0)
            roles(i) = "Hybrid";
        else
            roles(i) = "Support";
        end
    end

    [~, openerIndex] = max([scores.OpenerScore]);
    if openerIndex >= 1 && openerIndex <= numel(memberJobs) && roles(openerIndex) ~= "Carry" ...
            && ~any(memberJobs == "Opener")
        memberJobs(openerIndex) = "Opener";
    end
end

function job = localPreferredJobAtIndex(preferredJobs, index)
    job = "";
    if index >= 1 && index <= numel(preferredJobs)
        job = string(preferredJobs(index));
    end
end

function carryIndex = localChooseCarryIndex(scores, archetypeInfo)
    recommended = getFieldOrDefault(archetypeInfo, 'RecommendedCarryIndices', []);
    if ~isempty(recommended)
        valid = recommended(recommended >= 1 & recommended <= numel(scores));
        if ~isempty(valid)
            carryIndex = valid(1);
            return;
        end
    end

    carryScores = [scores.CarryScore];
    [~, carryIndex] = max(carryScores);
end

function order = localBuildExecutionOrder(scores, roles, memberJobs, archetypeInfo)
    memberCount = numel(scores);
    sortMatrix = zeros(memberCount, 4);
    for i = 1:memberCount
        sortMatrix(i, 1) = localRolePriority(roles(i), scores(i), archetypeInfo);
        sortMatrix(i, 2) = localJobPriority(memberJobs(i), roles(i), scores(i), archetypeInfo);
        sortMatrix(i, 3) = -scores(i).SupportScore;
        sortMatrix(i, 4) = -scores(i).CarryScore;
    end
    sorted = sortrows([(1:memberCount).', sortMatrix], [2 3 4 5]);
    order = sorted(:, 1).';
end

function priority = localRolePriority(role, score, archetypeInfo)
    if nargin >= 3 && localShouldAdvanceAuraApplicator(score, archetypeInfo)
        priority = 1;
        return;
    end
    switch char(role)
        case 'Support'
            priority = 1;
        case 'Hybrid'
            priority = 2;
        otherwise
            priority = 3;
    end
end

function priority = localJobPriority(job, role, score, archetypeInfo)
    job = string(job);
    if localShouldAdvanceAuraApplicator(score, archetypeInfo)
        priority = 4;
        return;
    end
    priority = localOpenerPriority(score.NormalizedName, role, archetypeInfo) - getFieldOrDefault(score, 'OpenerScore', 0);
    switch char(job)
        case 'Opener'
            priority = min(priority, 5);
        case 'Trigger'
            priority = min(priority, 12);
        case 'Driver'
            priority = max(15, priority);
        case 'Sustain'
            priority = max(18, priority);
        otherwise
            priority = max(20, priority);
    end
end

function budget = localResolveMemberBudget(role, job, rotationDuration, archetypeInfo)
    role = string(role);
    job = string(job);
    primary = string(getFieldOrDefault(archetypeInfo, 'PrimaryArchetype', ""));
    confidence = double(getFieldOrDefault(archetypeInfo, 'Confidence', 0));

    if role == "Hybrid"
        budget = min(6.0, max(4.0, 0.30 * rotationDuration));
    else
        budget = min(5.0, max(2.5, 0.22 * rotationDuration));
    end

    switch char(job)
        case 'Opener'
            budget = min(3.6, max(2.0, 0.14 * rotationDuration));
        case 'Trigger'
            budget = min(4.8, max(2.4, 0.18 * rotationDuration));
        case 'Driver'
            budget = min(6.5, max(4.2, 0.30 * rotationDuration));
        case 'Sustain'
            budget = min(4.2, max(2.2, 0.16 * rotationDuration));
        otherwise
            % Use the base budget.
    end

    if any(primary == ["Aggravate", "Spread", "Overload"]) && role == "Hybrid"
        budget = max(budget, min(6.5, 0.32 * rotationDuration));
    elseif any(primary == ["Freeze", "Vaporize", "Melt", "Plunge", "GeoHypercarry", "AnemoHypercarry", "Mono"])
        budget = min(budget, 4.8);
    end

    if confidence < 0.65 && primary == "Hypercarry"
        switch char(role)
            case 'Support'
                budget = max(budget, min(5.2, max(3.2, 0.24 * rotationDuration)));
            case 'Hybrid'
                budget = max(budget, min(6.2, max(4.6, 0.32 * rotationDuration)));
        end
    end
end

function job = localResolveCarryJob(normalizedName, archetypeInfo)
    normalizedName = string(normalizedName);
    primary = string(getFieldOrDefault(archetypeInfo, 'PrimaryArchetype', ""));
    if any(primary == ["Hyperbloom", "Bloom", "Burgeon", "Aggravate", "Spread"]) ...
            && any(normalizedName == ["alhaitham", "cyno", "clorinde", "keqing", "nahida", ...
            "kamisatoayato", "tighnari", "kinich", "nefer", "lauma"])
        job = "Driver";
    else
        job = "Carry";
    end
end

function job = localResolveSupportJob(normalizedName, element, teamInfo, archetypeInfo, score) %#ok<INUSD>
    normalizedName = string(normalizedName);
    element = string(element);
    primary = string(getFieldOrDefault(archetypeInfo, 'PrimaryArchetype', ""));
    job = "Utility";

    sustainNames = ["baizhu", "yaoyao", "diona", "layla", "charlotte", "barbara", ...
        "sangonomiyakokomi", "qiqi", "jean", "kirara", "zhongli", "thoma"];
    openerNames = ["xianyun", "faruzan", "bennett", "furina", "mona", "nahida", ...
        "chevreuse", "xilonen", "citlali", "escoffier", "shenhe", "gorou", ...
        "kujousara", "yunjin", "kaedeharakazuha", "sucrose", "nicole"];
    triggerNames = ["fischl", "yaemiko", "kukishinobu", "raidenshogun", "xiangling", ...
        "thoma", "dehya", "xingqiu", "yelan", "ororon", "beidou"];

    switch char(primary)
        case 'Bloom'
            if normalizedName == "nilou" || any(normalizedName == ["nahida", "furina", "baizhu", "yaoyao"])
                job = "Opener";
            elseif element == "Hydro" || element == "Dendro"
                job = "Trigger";
            end

        case 'Hyperbloom'
            if any(normalizedName == ["kukishinobu", "raidenshogun", "yaemiko", "fischl"])
                job = "Trigger";
            elseif any(normalizedName == ["nahida", "baizhu", "yaoyao", "xingqiu", "yelan", "furina", "sangonomiyakokomi", "barbara"])
                job = "Opener";
            elseif score.CarryScore >= max(6.0, score.SupportScore + 1.0)
                job = "Driver";
            end

        case 'Burgeon'
            if any(normalizedName == ["thoma", "dehya"])
                job = "Trigger";
            elseif any(normalizedName == ["nahida", "baizhu", "yaoyao", "xingqiu", "yelan", "furina", "sangonomiyakokomi", "barbara"])
                job = "Opener";
            end

        case 'Freeze'
            if element == "Anemo" || any(normalizedName == ["mona", "furina", "shenhe", "escoffier"])
                job = "Opener";
            elseif element == "Hydro"
                job = "Trigger";
            elseif any(normalizedName == sustainNames)
                job = "Sustain";
            end

        case 'Vaporize'
            if any(normalizedName == ["xingqiu", "yelan", "furina", "mona"])
                job = "Trigger";
            elseif any(normalizedName == ["bennett", "kaedeharakazuha", "sucrose", "xilonen", "zhongli", "citlali", "chevreuse"])
                job = "Opener";
            elseif any(normalizedName == sustainNames)
                job = "Sustain";
            end

        case 'Melt'
            if any(normalizedName == ["xiangling", "citlali", "rosaria"])
                job = "Trigger";
            elseif any(normalizedName == ["bennett", "kaedeharakazuha", "sucrose", "shenhe", "charlotte"])
                job = "Opener";
            elseif any(normalizedName == sustainNames)
                job = "Sustain";
            end

        case 'Overload'
            if any(normalizedName == ["chevreuse", "bennett", "kujousara", "iansan"])
                job = "Opener";
            elseif any(normalizedName == ["fischl", "yaemiko", "beidou", "ororon", "kukishinobu"])
                job = "Trigger";
            elseif any(normalizedName == sustainNames)
                job = "Sustain";
            end

        case {'Aggravate', 'Spread'}
            if any(normalizedName == ["nahida", "baizhu", "yaoyao", "zhongli"])
                job = "Opener";
            elseif any(normalizedName == ["fischl", "yaemiko", "kukishinobu", "raidenshogun"])
                job = "Trigger";
            elseif score.CarryScore >= max(6.0, score.SupportScore + 1.0)
                job = "Driver";
            elseif any(normalizedName == sustainNames)
                job = "Sustain";
            end

        case 'Plunge'
            if any(normalizedName == ["xianyun", "faruzan", "bennett", "furina"])
                job = "Opener";
            elseif any(normalizedName == sustainNames)
                job = "Sustain";
            end

        case 'AnemoHypercarry'
            if any(normalizedName == ["faruzan", "bennett", "furina", "zhongli"])
                job = "Opener";
            end

        case 'GeoHypercarry'
            if any(normalizedName == ["gorou", "zhongli", "albedo", "furina", "xilonen", "kachina"])
                job = "Opener";
            end
    end

    if job == "Utility"
        if any(normalizedName == sustainNames)
            job = "Sustain";
        elseif any(normalizedName == openerNames)
            job = "Opener";
        elseif any(normalizedName == triggerNames)
            job = "Trigger";
        elseif score.CarryScore >= max(6.0, score.SupportScore + 1.0)
            job = "Driver";
        end
    end
end

function priority = localOpenerPriority(normalizedName, role, archetypeInfo)
    if role == "Carry"
        priority = 90;
        return;
    end

    if any(normalizedName == ["zhongli", "xilonen", "citlali", "escoffier", "chevreuse", "bennett", "mona", "faruzan", "gorou", "kujousara", "yunjin"])
        priority = 10;
    elseif any(normalizedName == ["nahida", "baizhu", "furina", "yelan", "xingqiu", "fischl", "xiangling", "rosaria", "diona", "layla", "kirara", "thoma", "xianyun", "iansan", "nicole"])
        priority = 20;
    else
        priority = 30;
    end

    primary = string(getFieldOrDefault(archetypeInfo, 'PrimaryArchetype', ""));
    switch char(primary)
        case 'Freeze'
            if any(normalizedName == ["kaedeharakazuha", "sucrose", "mona", "furina", "shenhe", "escoffier"])
                priority = min(priority, 8);
            end
        case 'Bloom'
            if any(normalizedName == ["nahida", "nilou", "furina", "baizhu", "yaoyao"])
                priority = min(priority, 8);
            end
        case 'Hyperbloom'
            if any(normalizedName == ["nahida", "xingqiu", "yelan", "baizhu", "kukishinobu", "raidenshogun"])
                priority = min(priority, 8);
            end
        case 'Overload'
            if any(normalizedName == ["chevreuse", "bennett", "kujousara", "iansan", "fischl"])
                priority = min(priority, 8);
            end
        case 'Plunge'
            if any(normalizedName == ["xianyun", "faruzan", "bennett", "furina"])
                priority = min(priority, 8);
            end
    end
end

function tf = localShouldAdvanceAuraApplicator(score, archetypeInfo)
    tf = false;
    normalizedName = string(getFieldOrDefault(score, 'NormalizedName', ""));
    teamNames = string(getFieldOrDefault(archetypeInfo, 'NormalizedNames', strings(1, 0)));
    hasAnemoAbsorber = any(teamNames == "venti") || any(teamNames == "kaedeharakazuha") ...
        || any(teamNames == "sucrose") || any(teamNames == "sayu");
    if ~hasAnemoAbsorber
        return;
    end
    if any(normalizedName == ["venti", "kaedeharakazuha", "sucrose", "sayu"])
        return;
    end
    if getFieldOrDefault(score, 'CarryScore', 0) < max(6.0, getFieldOrDefault(score, 'SupportScore', 0))
        return;
    end
    tf = any(normalizedName == ["amber", "barbara", "xiangling", "rosaria", "layla", "diona", "mona", "xingqiu", "yelan"]);
end

function memberPlan = localBuildMemberPlan(member, seed, score, role, targetBudget, archetypeInfo, job)
    memberPlan = localEmptyMemberPlan();
    memberPlan.Name = string(member.Name);
    memberPlan.DisplayName = string(getFieldOrDefault(member, 'DisplayName', member.Name));
    memberPlan.Role = string(role);
    memberPlan.Job = string(job);
    memberPlan.TargetBudget = targetBudget;
    memberPlan.SeedSource = seed.Source;
    memberPlan.SeedIsExplicit = logical(getFieldOrDefault(seed, 'IsExplicit', false));

    switch char(role)
        case 'Carry'
            if localShouldUseHybridCarryFallback(score, member.Name, archetypeInfo)
                [tokens, source] = localBuildHybridTokens(member, seed, archetypeInfo, memberPlan.Job);
                if isempty(tokens) || (numel(tokens) == 1 && strcmpi(tokens{1}, 'AUTO'))
                    [tokens, source] = localBuildSupportTokens(member, seed, archetypeInfo, memberPlan.Job);
                    source = "support-lean-carry";
                else
                    source = "hybrid-carry-fallback";
                end
            else
                [tokens, source] = localBuildCarryTokens(member, seed, archetypeInfo, memberPlan.Job);
            end
        case 'Hybrid'
            [tokens, source] = localBuildHybridTokens(member, seed, archetypeInfo, memberPlan.Job);
        otherwise
            if localShouldUseHybridSupportFallback(seed, score, member.Name, archetypeInfo)
                [tokens, source] = localBuildHybridTokens(member, seed, archetypeInfo, memberPlan.Job);
                if isempty(tokens) || (numel(tokens) == 1 && strcmpi(tokens{1}, 'AUTO'))
                    [tokens, source] = localBuildSupportTokens(member, seed, archetypeInfo, memberPlan.Job);
                else
                    source = "hybrid-support-fallback";
                end
            else
                [tokens, source] = localBuildSupportTokens(member, seed, archetypeInfo, memberPlan.Job);
            end
    end

    if isempty(tokens)
        tokens = {'AUTO'};
        source = "fallback";
    end
    tokens = localNormalizeTokenList(tokens);
    allowExpand = localResolvePlanExpansionPolicy(role, member.Name, archetypeInfo);
    if strcmpi(char(string(source)), 'hybrid-support-fallback')
        allowExpand = true;
    end
    tokens = localConformTokensToBudget(tokens, targetBudget, member.Name, allowExpand);

    memberPlan.PlanningSource = string(source);
    memberPlan.RotationTokens = tokens;
    memberPlan.RotationText = localRotationTextFromTokens(tokens);
    memberPlan.EstimatedDuration = localEstimateRotationDuration(tokens, member.Name);
    if memberPlan.EstimatedDuration <= 0 && role == "Carry"
        memberPlan.EstimatedDuration = targetBudget;
    end
    memberPlan.Preview = localPreviewRotation(tokens);
end

function carryBudget = localResolveCarryBudget(carryBudget, score, characterName, rotationDuration, archetypeInfo)
    carryBudget = max(0, double(carryBudget));
    confidence = double(getFieldOrDefault(archetypeInfo, 'Confidence', 0));
    if localShouldUseHybridCarryFallback(score, characterName, archetypeInfo)
        cappedBudget = max(4.8, min(7.5, 0.38 * double(rotationDuration)));
        if confidence < 0.70
            cappedBudget = min(cappedBudget, max(4.6, 0.34 * double(rotationDuration)));
        end
        carryBudget = min(carryBudget, cappedBudget);
    end
end

function tf = localShouldUseHybridCarryFallback(score, characterName, archetypeInfo)
    normalizedName = localNormalizeName(characterName);
    supportLead = double(getFieldOrDefault(score, 'SupportScore', 0)) - double(getFieldOrDefault(score, 'CarryScore', 0));
    confidence = double(getFieldOrDefault(archetypeInfo, 'Confidence', 0));
    primary = string(getFieldOrDefault(archetypeInfo, 'PrimaryArchetype', ""));

    tf = false;
    if supportLead < 2.0
        return;
    end
    if ~localShouldDefaultToSupport(normalizedName)
        return;
    end
    if confidence >= 0.85 && any(primary == ["Freeze", "Vaporize", "Melt", "Plunge", "GeoHypercarry", "AnemoHypercarry", "Hyperbloom", "Bloom", "Burgeon", "Overload", "Aggravate", "Spread"])
        return;
    end
    tf = true;
end

function tf = localShouldUseHybridSupportFallback(seed, score, characterName, archetypeInfo)
    normalizedName = localNormalizeName(characterName);
    confidence = double(getFieldOrDefault(archetypeInfo, 'Confidence', 0));
    primary = string(getFieldOrDefault(archetypeInfo, 'PrimaryArchetype', ""));
    referenceTokens = getFieldOrDefault(seed, 'ReferenceTokens', {});
    explicitTokens = getFieldOrDefault(seed, 'ExplicitTokens', {});
    supportLead = double(getFieldOrDefault(score, 'SupportScore', 0)) - double(getFieldOrDefault(score, 'CarryScore', 0));

    tf = false;
    if confidence >= 0.65 || primary ~= "Hypercarry"
        return;
    end
    if ~localShouldDefaultToSupport(normalizedName)
        return;
    end
    if supportLead < 1.0
        return;
    end
    if ~isempty(explicitTokens)
        return;
    end
    if isempty(referenceTokens)
        return;
    end

    supportDuration = localEstimateRotationDuration(localBuildSupportTokensFromSeed(referenceTokens), characterName);
    referenceDuration = localEstimateRotationDuration(referenceTokens, characterName);
    tf = referenceDuration >= supportDuration + 1.0;
end

function memberPlan = localFitMemberPlanToBudget(memberPlan, characterName, targetBudget)
    if nargin < 3 || isempty(targetBudget) || ~isfinite(targetBudget)
        return;
    end
    targetBudget = max(0, double(targetBudget));

    tokens = localNormalizeTokenList(getFieldOrDefault(memberPlan, 'RotationTokens', {}));
    if isempty(tokens)
        memberPlan.EstimatedDuration = 0;
        return;
    end
    if numel(tokens) == 1 && strcmpi(tokens{1}, 'AUTO')
        return;
    end

    currentDuration = localEstimateRotationDuration(tokens, characterName);
    if currentDuration <= targetBudget + 1e-9
        memberPlan.EstimatedDuration = currentDuration;
        return;
    end

    trimmedTokens = localTrimTokensToHardBudget(tokens, targetBudget, characterName);
    if isempty(trimmedTokens)
        memberPlan.RotationTokens = tokens(1);
        memberPlan.RotationText = localRotationTextFromTokens(memberPlan.RotationTokens);
        memberPlan.Preview = localPreviewRotation(memberPlan.RotationTokens);
        memberPlan.EstimatedDuration = localEstimateRotationDuration(memberPlan.RotationTokens, characterName);
        return;
    end

    memberPlan.RotationTokens = trimmedTokens;
    memberPlan.RotationText = localRotationTextFromTokens(trimmedTokens);
    memberPlan.Preview = localPreviewRotation(trimmedTokens);
    memberPlan.EstimatedDuration = localEstimateRotationDuration(trimmedTokens, characterName);
end

function [tokens, source] = localBuildSupportTokens(member, seed, archetypeInfo, job)
    normalizedName = localNormalizeName(member.Name);
    namedTokens = localNamedSupportTokens(normalizedName, archetypeInfo, job);
    useNamedTokens = ~logical(getFieldOrDefault(seed, 'IsExplicit', false)) ...
        && ~isempty(namedTokens) ...
        && (seed.HasAuto || localShouldPreferNamedSupportTemplate(normalizedName));

    if useNamedTokens && ~isempty(namedTokens)
        tokens = namedTokens;
        source = "named-support";
        return;
    end

    if ~isempty(seed.ExplicitTokens)
        tokens = localBuildSupportTokensFromSeed(seed.ExplicitTokens);
        source = "seed-support";
        return;
    end

    if ~isempty(getFieldOrDefault(seed, 'ReferenceTokens', {}))
        tokens = localBuildSupportTokensFromSeed(seed.ReferenceTokens);
        source = "reference-support";
        return;
    end

    if ~isempty(namedTokens)
        tokens = namedTokens;
        source = "named-support";
    else
        tokens = localGenericSupportTokens(normalizedName);
        source = "generic-support";
    end
end

function [tokens, source] = localBuildHybridTokens(member, seed, archetypeInfo, job)
    normalizedName = localNormalizeName(member.Name);
    namedTokens = localNamedHybridTokens(normalizedName, archetypeInfo, job);
    if ~logical(getFieldOrDefault(seed, 'IsExplicit', false)) ...
            && ~isempty(namedTokens) ...
            && (seed.HasAuto || localShouldPreferNamedHybridTemplate(normalizedName))
        tokens = namedTokens;
        source = "named-hybrid";
        return;
    end

    if seed.HasAuto
        supportTokens = localBuildSupportTokensFromSeed(getFieldOrDefault(seed, 'ReferenceTokens', {}));
        onFieldTail = localBuildOnFieldTail(getFieldOrDefault(seed, 'ReferenceTokens', {}));
        tokens = [supportTokens(:); onFieldTail(:)].';
        if isempty(tokens)
            tokens = {'AUTO'};
            source = "auto-hybrid";
        else
            source = "reference-hybrid";
        end
        return;
    end

    supportTokens = localBuildSupportTokensFromSeed(seed.ExplicitTokens);
    onFieldTail = localBuildOnFieldTail(seed.ExplicitTokens);
    tokens = [supportTokens(:); onFieldTail(:)].';
    if isempty(tokens)
        tokens = seed.ExplicitTokens;
    end
    source = "seed-hybrid";
end

function [tokens, source] = localBuildCarryTokens(member, seed, archetypeInfo, job) %#ok<INUSD>
    normalizedName = localNormalizeName(member.Name);
    namedTokens = localNamedCarryTokens(normalizedName, archetypeInfo, job);
    if ~logical(getFieldOrDefault(seed, 'IsExplicit', false)) && ~isempty(namedTokens)
        tokens = namedTokens;
        source = "named-carry";
        return;
    end

    if seed.HasAuto
        referenceTokens = getFieldOrDefault(seed, 'ReferenceTokens', {});
        if isempty(referenceTokens)
            tokens = {'AUTO'};
            source = "auto-carry";
        else
            tokens = referenceTokens;
            source = "reference-carry";
        end
        return;
    end

    tokens = seed.ExplicitTokens;
    source = "seed-carry";
end

function tokens = localBuildSupportTokensFromSeed(seedTokens)
    tokens = cell(0, 1);
    keptSkill = false;
    keptBurst = false;
    persistentSeen = containers.Map('KeyType', 'char', 'ValueType', 'double');

    for i = 1:numel(seedTokens)
        token = string(seedTokens{i});
        tokenKey = char(lower(token));
        keep = false;

        if localIsSwitchToken(token)
            keep = true;
        elseif localIsElementalSkillToken(token) && ~keptSkill
            keep = true;
            keptSkill = true;
        elseif localIsBurstToken(token) && ~keptBurst
            keep = true;
            keptBurst = true;
        elseif localIsPersistentSupportToken(token)
            if ~isKey(persistentSeen, tokenKey)
                persistentSeen(tokenKey) = 0;
            end
            if persistentSeen(tokenKey) < 6
                keep = true;
                persistentSeen(tokenKey) = persistentSeen(tokenKey) + 1;
            end
        end

        if keep
            tokens{end + 1, 1} = char(token); %#ok<AGROW>
        end
    end

    if isempty(tokens)
        for i = 1:min(2, numel(seedTokens))
            tokens{end + 1, 1} = char(string(seedTokens{i})); %#ok<AGROW>
        end
    end
end

function tail = localBuildOnFieldTail(seedTokens)
    tail = cell(0, 1);
    if isempty(seedTokens)
        return;
    end

    for i = numel(seedTokens):-1:1
        token = string(seedTokens{i});
        if localIsOnFieldToken(token)
            tail = [{char(token)}; tail]; %#ok<AGROW>
        elseif ~isempty(tail)
            break;
        end
    end

    if isempty(tail)
        for i = 1:numel(seedTokens)
            token = string(seedTokens{i});
            if localIsOnFieldToken(token)
                tail{end + 1, 1} = char(token); %#ok<AGROW>
            end
        end
    end

    if numel(tail) > 5
        tail = tail(1:5);
    end
end

function tokens = localConformTokensToBudget(tokens, targetBudget, characterName, allowExpand)
    if nargin < 4
        allowExpand = true;
    end
    if isempty(tokens) || targetBudget <= 0
        return;
    end
    if numel(tokens) == 1 && strcmpi(tokens{1}, 'AUTO')
        return;
    end

    totalDuration = localEstimateRotationDuration(tokens, characterName);
    if totalDuration > targetBudget + 0.80
        tokens = localTrimTokensToBudget(tokens, targetBudget, characterName);
        totalDuration = localEstimateRotationDuration(tokens, characterName);
    end
    if allowExpand && totalDuration < targetBudget - 1.20
        tokens = localExpandTokensToBudget(tokens, targetBudget, characterName);
    end
end

function tokens = localTrimTokensToBudget(tokens, targetBudget, characterName)
    if isempty(tokens)
        return;
    end

    trimmed = cell(0, 1);
    elapsed = 0;
    for i = 1:numel(tokens)
        token = string(tokens{i});
        duration = localEstimateActionDuration(characterName, token, 0.60);
        if ~isfinite(duration)
            duration = 0.60;
        end

        if i > 1 && elapsed + duration > targetBudget + 0.30
            break;
        end

        trimmed{end + 1, 1} = char(token); %#ok<AGROW>
        elapsed = elapsed + duration;
    end

    if ~isempty(trimmed)
        tokens = trimmed;
    else
        tokens = tokens(1);
    end
end

function trimmedTokens = localTrimTokensToHardBudget(tokens, targetBudget, characterName)
    trimmedTokens = cell(0, 1);
    if isempty(tokens) || targetBudget <= 0
        return;
    end

    elapsed = 0;
    for i = 1:numel(tokens)
        token = string(tokens{i});
        duration = localEstimateActionDuration(characterName, token, 0.60);
        if ~isfinite(duration) || duration <= 0
            duration = 0.60;
        end

        if elapsed + duration > targetBudget + 1e-9
            if isempty(trimmedTokens) && duration <= targetBudget + 0.20
                trimmedTokens{1, 1} = char(token);
            end
            break;
        end

        trimmedTokens{end + 1, 1} = char(token); %#ok<AGROW>
        elapsed = elapsed + duration;
    end
end

function tokens = localExpandTokensToBudget(tokens, targetBudget, characterName)
    if isempty(tokens)
        return;
    end

    tail = localBuildOnFieldTail(tokens);
    if isempty(tail)
        return;
    end

    currentDuration = localEstimateRotationDuration(tokens, characterName);
    tailDuration = localEstimateRotationDuration(tail, characterName);
    if tailDuration <= 0
        return;
    end

    loopGuard = 0;
    while currentDuration + min(tailDuration, 1.0) <= targetBudget + 0.40 && loopGuard < 8
        for i = 1:numel(tail)
            nextToken = tail{i};
            nextDuration = localEstimateActionDuration(characterName, nextToken, 0.60);
            if currentDuration + nextDuration > targetBudget + 0.50
                break;
            end
            tokens{end + 1, 1} = nextToken; %#ok<AGROW>
            currentDuration = currentDuration + nextDuration;
        end
        loopGuard = loopGuard + 1;
        if currentDuration >= targetBudget - 0.30
            break;
        end
    end
end

function tokens = localNamedSupportTokens(normalizedName, archetypeInfo, job)
    primary = localArchetypeKey(archetypeInfo, 'PrimaryArchetype');
    job = string(job);
    tokens = {};
    switch char(normalizedName)
        case 'furina'
            if any(primary == ["Bloom", "Hyperbloom", "Burgeon"])
                tokens = {'E', 'Q'};
            elseif primary == "Plunge"
                tokens = {'Q', 'E'};
            else
                tokens = {'Q', 'E'};
            end
        case 'nilou'
            tokens = {'E', 'Dance1', 'Dance2', 'Dance3', 'Aura', 'Q'};
        case 'nicole'
            tokens = {'E', 'Q', 'Projection', 'Unity', 'Projection'};
        case 'faruzan'
            tokens = {'Q', 'E', 'Collapse'};
        case 'gorou'
            tokens = {'E', 'Q', 'Collapse', 'GeoWave'};
        case 'bennett'
            tokens = {'Q', 'E'};
        case 'mona'
            tokens = {'Q', 'E'};
        case 'chevreuse'
            if primary == "Overload"
                tokens = {'E', 'LoadedShot', 'Q', 'Overload'};
            else
                tokens = {'E', 'Q'};
            end
        case 'zhongli'
            if any(primary == ["GeoHypercarry", "Plunge"])
                tokens = {'EHold', 'Q'};
            else
                tokens = {'EHold'};
            end
        case 'sucrose'
            tokens = {'E', 'Q'};
        case 'kaedeharakazuha'
            if any(primary == ["Freeze", "Vaporize", "Melt"])
                tokens = {'EHold', 'PlungeMix', 'Q'};
            else
                tokens = {'EHold', 'PlungeMix', 'Q'};
            end
        case 'shenhe'
            if primary == "Freeze"
                tokens = {'Q', 'EPress'};
            else
                tokens = {'EPress', 'Q'};
            end
        case 'nahida'
            if any(primary == ["Bloom", "Hyperbloom", "Spread", "Aggravate"])
                tokens = {'EPress', 'Q'};
            else
                tokens = {'EPress', 'Q'};
            end
        case 'xingqiu'
            tokens = {'E', 'Q'};
        case 'yelan'
            tokens = {'E', 'Q'};
        case 'fischl'
            tokens = {'E'};
        case 'beidou'
            tokens = {'E', 'Q'};
        case 'xiangling'
            tokens = {'E', 'Q'};
        case 'xianyun'
            if primary == "Plunge"
                tokens = {'E', 'Q'};
            else
                tokens = {'E', 'Q'};
            end
        case 'yaemiko'
            tokens = {'E1', 'E2', 'E3', 'Q'};
        case 'xilonen'
            tokens = {'E', 'Source', 'Q', 'Source'};
        case 'kukishinobu'
            tokens = {'E'};
        case 'baizhu'
            tokens = {'E', 'Q'};
        case 'yaoyao'
            tokens = {'E', 'Q'};
        case 'kirara'
            tokens = {'EHold', 'Q'};
        case 'thoma'
            tokens = {'E', 'Q'};
        case 'rosaria'
            tokens = {'E', 'Q'};
        case 'layla'
            tokens = {'Q', 'E'};
        case 'diona'
            tokens = {'EHold', 'Q'};
        case 'charlotte'
            tokens = {'E', 'Q'};
        case 'jean'
            tokens = {'E', 'Q'};
        case 'barbara'
            tokens = {'E', 'Q'};
        case 'sangonomiyakokomi'
            tokens = {'E', 'Q'};
        case 'kujousara'
            tokens = {'E', 'Q'};
        case 'iansan'
            tokens = {'E', 'Q'};
        case 'ororon'
            tokens = {'E', 'Q'};
        case 'kachina'
            tokens = {'E', 'Q'};
        case 'albedo'
            tokens = {'E', 'Q'};
        case 'yunjin'
            tokens = {'E', 'Q'};
        otherwise
            tokens = {};
    end
end

function tokens = localNamedHybridTokens(normalizedName, archetypeInfo, job) %#ok<INUSD>
    primary = localArchetypeKey(archetypeInfo, 'PrimaryArchetype');
    tokens = {};
    switch char(normalizedName)
        case 'durin'
            tokens = {'AUTO'};
        case 'beidou'
            if job == "Trigger"
                tokens = {'E', 'Q'};
            else
                tokens = {'E', 'Q', 'N1', 'N2'};
            end
        case 'yaemiko'
            if any(primary == ["Aggravate", "Spread", "Hyperbloom", "Overload"])
                tokens = {'E1', 'E2', 'E3', 'Q'};
            else
                tokens = {'E1', 'E2', 'E3'};
            end
        case 'nefer'
            if any(primary == ["Bloom", "Hyperbloom", "Burgeon"])
                tokens = {'E', 'Phantasm', 'Phantasm', 'Q', 'LunarBloom', 'Phantasm', 'LunarBloom'};
            else
                tokens = {'E', 'Phantasm', 'Phantasm', 'Q', 'Phantasm'};
            end
        case 'nilou'
            tokens = {'E', 'Dance1', 'Dance2', 'Dance3', 'Aura', 'Q'};
        otherwise
            tokens = {};
    end
end

function tokens = localNamedCarryTokens(normalizedName, archetypeInfo, job) %#ok<INUSD>
    primary = localArchetypeKey(archetypeInfo, 'PrimaryArchetype');
    tokens = {};
    switch char(normalizedName)
        case 'columbina'
            tokens = {'E1', 'E2', 'E3', 'SA3', 'Heavy', 'MoonCont', 'Q', 'MoonBloom'};
        case 'lauma'
            if any(primary == ["Bloom", "Hyperbloom", "Burgeon"])
                tokens = {'E', 'Sanctuary', 'Sanctuary', 'HoldE', 'Q', 'LunarBloom', 'Sanctuary', 'LunarBloom'};
            else
                tokens = {'E', 'Sanctuary', 'Sanctuary', 'HoldE', 'Q'};
            end
        case 'nefer'
            if any(primary == ["Bloom", "Hyperbloom", "Burgeon"])
                tokens = {'E', 'Phantasm', 'Phantasm', 'Q', 'LunarBloom', 'Phantasm', 'LunarBloom'};
            else
                tokens = {'E', 'Phantasm', 'Phantasm', 'Q', 'Phantasm', 'Phantasm'};
            end
        case 'arlecchino'
            tokens = {'E', 'DebtTick', 'Charge', 'N1', 'N2', 'N3', 'N4A', 'N4B', 'N5', 'Q'};
        case 'neuvillette'
            if any(primary == ["Freeze", "Vaporize", "Mono"])
                tokens = {'E', 'Q', 'Droplet', 'Charge', 'Beam', 'Drain', 'Beam', 'Charge'};
            else
                tokens = {'E', 'Q', 'Droplet', 'Charge', 'Beam', 'Drain', 'Beam'};
            end
        case 'kaeya'
            if any(primary == ["Freeze", "Melt", "Vaporize"])
                tokens = {'E', 'Q', 'N1', 'N2', 'CA', 'N1', 'N2', 'CA'};
            else
                tokens = {'E', 'Q', 'N1', 'N2', 'CA'};
            end
        case 'mualani'
            tokens = {'E', 'Bite', 'Bite', 'Missile', 'Q', 'Bite'};
        case 'raidenshogun'
            tokens = {'E', 'Q', 'B1', 'B2', 'B3', 'B4', 'B5', 'BCA', 'B1', 'B2', 'B3', 'B4', 'B5'};
        case 'xiao'
            if primary == "Plunge"
                tokens = {'E', 'E', 'Q', 'PlungSlash', 'PlungImpact', 'PlungSlash', 'PlungImpact', 'PlungSlash', 'PlungImpact', 'PlungSlash'};
            else
                tokens = {'E', 'E', 'Q', 'PlungSlash', 'PlungImpact', 'PlungSlash', 'PlungImpact', 'PlungSlash'};
            end
        case 'clorinde'
            tokens = {'E', 'Q', 'B1', 'B2', 'B3', 'BCA', 'B1', 'B2', 'B3', 'BCA'};
        case 'hutao'
            if any(primary == ["Vaporize", "Melt"])
                tokens = {'E', 'Q', 'N1', 'CA', 'N1', 'CA', 'N1', 'CA', 'N1'};
            else
                tokens = {'E', 'Q', 'N1', 'CA', 'N1', 'CA', 'N1', 'CA'};
            end
        case 'navia'
            if any(primary == ["GeoHypercarry", "Crystallize"])
                tokens = {'Q', 'E', 'Charge', 'N1', 'N2', 'E', 'Charge', 'E'};
            else
                tokens = {'Q', 'E', 'Charge', 'N1', 'N2', 'E', 'Charge'};
            end
        case 'keqing'
            tokens = {'E', 'Q', 'N1', 'N2', 'CA', 'N1', 'N2', 'CA'};
        case 'ningguang'
            tokens = {'E', 'Q', 'N1', 'CA', 'N1', 'CA'};
        case 'noelle'
            tokens = {'E', 'Q', 'N1', 'N2', 'N3', 'N4', 'N1', 'N2', 'N3', 'N4'};
        case 'klee'
            tokens = {'E', 'Q', 'N1', 'CA', 'N1', 'CA', 'N2', 'CA'};
        case 'gaming'
            tokens = {'E', 'Q', 'PlungSlash', 'PlungImpact', 'PlungSlash', 'PlungImpact', 'PlungSlash', 'PlungImpact'};
        case 'wriothesley'
            tokens = {'E', 'Q', 'N1', 'N2', 'N3', 'CA', 'N1', 'N2', 'N3', 'CA'};
        case 'tartaglia'
            tokens = {'E', 'Q', 'N1', 'N2', 'N3', 'Charge', 'N1', 'N2', 'Charge'};
        case 'alhaitham'
            if any(primary == ["Hyperbloom", "Spread"])
                tokens = {'E', 'Q', 'N1', 'N2', 'CA', 'QMirror', 'N1', 'N2', 'Mirror3', ...
                    'N1', 'N2', 'CA', 'Mirror2', 'N1', 'N2', 'Mirror3', ...
                    'N1', 'N2', 'CA', 'Mirror2', 'N1', 'N2', 'Mirror3'};
            else
                tokens = {'E', 'Q', 'N1', 'N2', 'CA', 'QMirror', 'N1', 'N2', 'Mirror3'};
            end
        case 'cyno'
            tokens = {'E', 'Q', 'N1', 'N2', 'N3', 'E', 'N1', 'N2', 'N3'};
        case 'wanderer'
            tokens = {'E', 'Q', 'N1', 'N2', 'CA', 'N1', 'N2', 'CA'};
        case 'kamisatoayaka'
            if primary == "Freeze"
                tokens = {'E', 'Q', 'N1', 'N2', 'CA', 'N1', 'N2', 'CA', 'N1', 'N2', 'CA', ...
                    'N1', 'CA', 'N1', 'N2', 'CA', 'N1', 'N2', 'CA'};
            else
                tokens = {'E', 'Q', 'N1', 'N2', 'CA', 'N1', 'CA'};
            end
        case 'kamisatoayato'
            tokens = {'Q', 'E', 'N1', 'N2', 'N3', 'N1', 'N2', 'N3'};
        case 'diluc'
            tokens = {'Q', 'E', 'N1', 'E', 'N2', 'E', 'N3', 'CA'};
        case 'yoimiya'
            tokens = {'E', 'Q', 'N1', 'N2', 'N3', 'N4', 'N5', 'N1', 'N2', 'N3', 'N4', 'N5'};
        otherwise
            tokens = {};
    end
end

function tokens = localGenericSupportTokens(normalizedName)
    switch char(normalizedName)
        case {'zhongli'}
            tokens = {'E', 'Q'};
        case {'yelan', 'xingqiu', 'xiangling', 'fischl', 'nahida', 'baizhu', 'collei', 'yaoyao', ...
                'sucrose', 'kaedeharakazuha', 'xilonen', 'iansan', 'xianyun', 'rosaria', ...
                'diona', 'layla', 'kirara', 'thoma', 'charlotte', 'jean', 'barbara', ...
                'sangonomiyakokomi', 'albedo', 'ororon', 'kachina', 'sayu', 'yunjin', 'kujousara'}
            tokens = {'E', 'Q'};
        otherwise
            tokens = {'E', 'Q'};
    end
end

function duration = localEstimateRotationDuration(tokens, characterName)
    duration = 0;
    if isempty(tokens)
        return;
    end
    if numel(tokens) == 1 && strcmpi(tokens{1}, 'AUTO')
        duration = 0;
        return;
    end

    for i = 1:numel(tokens)
        duration = duration + localEstimateActionDuration(characterName, tokens{i}, 0.60);
    end
end

function duration = localEstimateActionDuration(characterName, action, fallbackDuration)
    if nargin < 3 || isempty(fallbackDuration)
        fallbackDuration = 0.60;
    end

    action = string(action);
    if strlength(action) == 0
        duration = 0;
        return;
    end

    lowerAction = lower(action);
    duration = fallbackDuration;

    if lowerAction == "auto"
        duration = NaN;
        return;
    end

    token = regexp(char(lowerAction), '^(?:n|na|b)(\d+)$', 'tokens', 'once');
    if ~isempty(token)
        normalIndex = str2double(token{1});
        duration = min(0.85, 0.28 + 0.08 * normalIndex);
        return;
    end

    switch lowerAction
        case {"e", "skill", "epress", "ehold"}
            duration = 0.70;
        case {"exq", "enhancedskill"}
            duration = 0.65;
        case {"q", "burst"}
            duration = 1.25;
        case {"charge", "charged", "heavy", "ca"}
            duration = 0.78;
        case "plunge"
            duration = 0.95;
        case {"plungemix"}
            duration = 0.85;
        case {"droplet", "drain"}
            duration = 0.35;
        case {"beam"}
            duration = 0.90;
        case {"bite"}
            duration = 0.72;
        case {"missile"}
            duration = 0.58;
        case {"phantasm"}
            duration = 0.80;
        case {"sanctuary"}
            duration = 1.90;
        case {"lunarbloom"}
            duration = 1.25;
        case {"bloom"}
            duration = 0.90;
        case {"switchpneuma", "switchousia"}
            duration = 0.25;
        case {"usher", "cheval", "crab"}
            duration = 1.45;
        case "singer"
            duration = 1.80;
        case {"debttick", "summon", "arkhe"}
            duration = 0.40;
        case {"collapse", "geowave", "qdot", "qoz", "rain1", "rain2", "throw", "oz", "pillar", "ring", "source", "trikarma", "bursttrikarma", "starwicker", "mooncont", "moonbloom", "eye", "icicle", "drill"}
            duration = 0.45;
        case {"projection"}
            duration = 3.00;
        case {"unity"}
            duration = 0.10;
        case {"pyronado", "aura"}
            duration = 0.50;
        case {"plungslash"}
            duration = 0.20;
        case {"plungimpact"}
            duration = 0.72;
        case {"bca"}
            duration = 0.70;
        otherwise
            switch lower(char(string(characterName)))
                case 'skirk'
                    if any(strcmp(lowerAction, ["n4a", "n4b", "n5"]))
                        duration = 0.60;
                    end
                case 'arlecchino'
                    if any(strcmp(lowerAction, ["n4a", "n4b"]))
                        duration = 0.45;
                    end
                case 'neuvillette'
                    if contains(lowerAction, "beam") || contains(lowerAction, "drain")
                        duration = 0.90;
                    end
            end
    end
end

function tf = localIsElementalSkillToken(token)
    token = lower(char(string(token)));
    tf = strcmp(token, 'e') || strcmp(token, 'skill') ...
        || startsWith(token, 'ehold') || startsWith(token, 'epress') ...
        || startsWith(token, 'skill') || strcmp(token, 'exq');
end

function tf = localIsBurstToken(token)
    token = lower(char(string(token)));
    tf = strcmp(token, 'q') || strcmp(token, 'burst') ...
        || ~isempty(regexp(token, '^q\d+$', 'once')) ...
        || any(strcmp(token, {'qphysical', 'qpyro'}));
end

function tf = localIsSwitchToken(token)
    token = lower(char(string(token)));
    tf = any(strcmp(token, {'switchpneuma', 'switchousia'}));
end

function tf = localIsPersistentSupportToken(token)
    token = lower(char(string(token)));
    patterns = {'summon', 'loop', 'projection', 'spirit', 'moon', 'singer', 'usher', 'cheval', ...
        'crab', 'overload', 'grenade', 'heal', 'phantom', 'star', 'skull', 'arkhe', ...
        'support', 'field', 'wave', 'connector', 'round', 'collapse', 'geowave', ...
        'pathfinder', 'droplet', 'drain', 'loadedshot', 'debttick', 'qdot', 'qoz', ...
        'rain', 'throw', 'oz', 'eye', 'pillar', 'ring', 'source', 'trikarma', ...
        'starwicker', 'pyronado', 'mirror', 'radish', 'icicle', 'drill', ...
        'sanctuary', 'phantasm', 'lunarbloom', 'bloom'};
    tf = false;
    for i = 1:numel(patterns)
        if contains(token, patterns{i})
            tf = true;
            return;
        end
    end
end

function tf = localIsOnFieldToken(token)
    token = lower(char(string(token)));
    tf = false;

    if regexp(token, '^n\d', 'once')
        tf = true;
        return;
    end
    if regexp(token, '^na\d', 'once')
        tf = true;
        return;
    end
    if regexp(token, '^b\d', 'once')
        tf = true;
        return;
    end

    exactMatches = {'ca', 'charge', 'charged', 'heavy', 'plunge', 'aimed', 'aimedc1', ...
        'combo', 'final', 'sa3', 'blade', 'mirror3', 'mirror2', 'qmirror', 'drain', 'droplet', ...
        'beam', 'bite', 'missile', 'plungemix', 'bca', 'phantasm', 'sanctuary', 'lunarbloom', 'bloom'};
    if any(strcmp(token, exactMatches))
        tf = true;
        return;
    end

    containsMatches = {'beam', 'normal', 'charged', 'plunge', 'mirror', 'blade', 'mortuary', 'bite', 'missile', 'phantasm', 'sanctuary', 'bloom'};
    for i = 1:numel(containsMatches)
        if contains(token, containsMatches{i})
            tf = true;
            return;
        end
    end
end

function text = localRotationTextFromTokens(tokens)
    tokenStrings = localTokenStringList(tokens);
    if isempty(tokenStrings)
        text = "AUTO";
        return;
    end
    text = join(tokenStrings(:), newline);
end

function preview = localPreviewRotation(tokens)
    tokenStrings = localTokenStringList(tokens);
    if isempty(tokenStrings)
        preview = "AUTO";
        return;
    end
    preview = join(tokenStrings(:).', " > ");
    if strlength(preview) > 160
        preview = extractBefore(preview, 158) + "…";
    end
end

function planRoot = localCreatePlanDirectory()
    root = fullfile(tempdir, 'genshin_dmg_calc_team_rotations');
    if exist(root, 'dir') ~= 7
        mkdir(root);
    end

    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
    stamp = regexprep(stamp, '[^0-9A-Za-z_]', '');
    planRoot = fullfile(root, sprintf('teamplan_%s_%04d', stamp, randi([0, 9999])));
    mkdir(planRoot);
end

function filePath = localWritePlanFile(planRoot, orderIndex, memberName, rotationText)
    safeName = regexprep(char(string(memberName)), '[^a-zA-Z0-9_-]', '_');
    filePath = fullfile(planRoot, sprintf('%02d_%s.txt', orderIndex, safeName));

    fid = fopen(filePath, 'w');
    if fid == -1
        error('Unable to create planned rotation file: %s', filePath);
    end
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', char(string(rotationText)));
end

function tokens = localDropAutoToken(tokens)
    tokens = localNormalizeTokenList(tokens);
    if isempty(tokens)
        return;
    end
    if numel(tokens) == 1 && strcmpi(tokens{1}, 'AUTO')
        tokens = {};
    end
end

function value = localBaseCarryScore(normalizedName)
    if any(normalizedName == [ ...
            "skirk", "arlecchino", "neuvillette", "alhaitham", "clorinde", "cyno", ...
            "hutao", "diluc", "wriothesley", "wanderer", "xiao", "kamisatoayaka", ...
            "kamisatoayato", "gaming", "navia", "mualani", "mavuika", "chasca", ...
            "kinich", "varesa", "keqing", "yoimiya", "raidenshogun", "klee", ...
            "tighnari", "sethos", "aratakiitto", "eula", "ningguang", "yanfei", ...
            "freminet", "razor", "columbina", "nefer", "candace"])
        value = 8.5;
    elseif any(normalizedName == ["lauma", "flins", "linnea", "zibai", "durin", "noelle", "barbara"])
        value = 5.5;
    elseif normalizedName == "nilou"
        value = 4.0;
    else
        value = 3.0;
    end
end

function value = localBaseSupportScore(normalizedName)
    if any(normalizedName == [ ...
            "furina", "escoffier", "citlali", "xilonen", "chevreuse", "iansan", ...
            "nicole", "xianyun", "mona", "bennett", "nahida", "yelan", "xingqiu", ...
            "xiangling", "fischl", "kaedeharakazuha", "sucrose", "zhongli", "faruzan", ...
            "gorou", "yunjin", "kujousara", "rosaria", "diona", "layla", "thoma", ...
            "kirara", "baizhu", "yaoyao", "collei", "charlotte", "jean", "barbara", ...
            "sangonomiyakokomi", "albedo", "ororon", "kachina", "sayu", "nilou"])
        value = 8.0;
    elseif any(normalizedName == ["lauma", "flins", "linnea", "zibai", "durin", "dehya", "candace"])
        value = 5.5;
    else
        value = 3.0;
    end
end

function allowExpand = localResolvePlanExpansionPolicy(role, characterName, archetypeInfo)
    normalizedName = localNormalizeName(characterName);
    primary = localArchetypeKey(archetypeInfo, 'PrimaryArchetype'); %#ok<NASGU>

    if role == "Support"
        allowExpand = false;
        return;
    end

    allowExpand = ~any(normalizedName == [ ...
        "alhaitham", "kamisatoayaka", "kamisatoayato", "xiao", ...
        "raidenshogun", "neuvillette", "mualani", "lauma", "nefer", ...
        "hutao", "navia"]);
end

function normalized = localNormalizeName(name)
    normalized = string(regexprep(lower(char(string(name))), '[^a-z0-9]', ''));
end

function seed = localEmptySeed()
    seed = struct( ...
        'Name', "", ...
        'DisplayName', "", ...
        'SeedRotationFile', "", ...
        'SeedRotationText', "", ...
        'Source', "", ...
        'Tokens', {cell(0, 1)}, ...
        'ReferenceTokens', {cell(0, 1)}, ...
        'ExplicitTokens', {cell(0, 1)}, ...
        'IsExplicit', false, ...
        'HasAuto', false, ...
        'EstimatedDuration', 0);
end

function score = localEmptyScore()
    score = struct( ...
        'Name', "", ...
        'NormalizedName', "", ...
        'CarryScore', 0, ...
        'SupportScore', 0, ...
        'OpenerScore', 0);
end

function tf = localShouldDefaultToSupport(normalizedName)
    tf = any(normalizedName == [ ...
        "furina", "escoffier", "citlali", "xilonen", "chevreuse", "iansan", ...
        "nicole", "xianyun", "mona", "bennett", "nahida", "yelan", "xingqiu", ...
        "xiangling", "fischl", "kaedeharakazuha", "sucrose", "zhongli", "faruzan", ...
        "gorou", "yunjin", "kujousara", "rosaria", "diona", "layla", "thoma", ...
        "kirara", "baizhu", "yaoyao", "collei", "charlotte", "jean", "barbara", ...
        "sangonomiyakokomi", "albedo", "ororon", "kachina", "sayu"]);
end

function tf = localShouldPreferNamedSupportTemplate(normalizedName)
    tf = any(normalizedName == [ ...
        "furina", "nilou", "nicole", "zhongli", "kaedeharakazuha", "nahida", ...
        "xingqiu", "yelan", "fischl", "xiangling", "xianyun", "xilonen", ...
        "chevreuse", "kukishinobu", "baizhu", "yaoyao", "kirara", "thoma", "rosaria", ...
        "layla", "diona", "charlotte", "barbara", "sangonomiyakokomi", ...
        "kujousara", "iansan", "ororon", "kachina", "albedo", "yunjin", ...
        "faruzan", "gorou", "bennett", "mona", "sucrose", "shenhe"]);
end

function tf = localShouldPreferNamedHybridTemplate(normalizedName)
    tf = any(normalizedName == ["nefer", "nilou"]);
end

function value = localArchetypeKey(archetypeInfo, fieldName)
    if nargin < 2 || isempty(fieldName)
        fieldName = 'PrimaryArchetype';
    end
    value = string(getFieldOrDefault(archetypeInfo, fieldName, ""));
end

function memberPlan = localEmptyMemberPlan()
    memberPlan = struct( ...
        'Name', "", ...
        'DisplayName', "", ...
        'Role', "", ...
        'Job', "", ...
        'Order', 0, ...
        'TargetBudget', 0, ...
        'EstimatedDuration', 0, ...
        'StartTime', 0, ...
        'EndTime', 0, ...
        'RotationTokens', {cell(0, 1)}, ...
        'RotationText', "", ...
        'Preview', "", ...
        'PlanningSource', "", ...
        'SeedSource', "", ...
        'SeedIsExplicit', false, ...
        'TempRotationFile', "");
end

function candidate = localEmptyPlanCandidate()
    candidate = struct( ...
        'CandidateLabel', "", ...
        'Score', -inf, ...
        'Summary', "", ...
        'CarryIndex', 0, ...
        'Roles', strings(1, 0), ...
        'MemberJobs', strings(1, 0), ...
        'OrderSeed', zeros(1, 0), ...
        'MemberPlans', struct([]), ...
        'ExecutionOrder', zeros(1, 0), ...
        'ExecutionTable', table(), ...
        'TimelineResult', struct(), ...
        'CandidateCount', 0);
end

function tokens = localNormalizeTokenList(tokens)
    if isempty(tokens)
        tokens = {};
        return;
    end

    if isstring(tokens)
        tokens = cellstr(tokens(:));
        return;
    end

    if ischar(tokens)
        tokenStrings = string(tokens);
        tokens = cellstr(tokenStrings(:));
        return;
    end

    if ~iscell(tokens)
        tokenStrings = string(tokens);
        tokens = cellstr(tokenStrings(:));
        return;
    end

    flattened = cell(0, 1);
    for i = 1:numel(tokens)
        current = tokens{i};
        if iscell(current)
            nested = localNormalizeTokenList(current);
            flattened = [flattened; nested(:)]; %#ok<AGROW>
        else
            currentStrings = string(current);
            currentStrings = currentStrings(:);
            for j = 1:numel(currentStrings)
                tokenValue = strtrim(char(currentStrings(j)));
                if strlength(string(tokenValue)) > 0
                    flattened{end + 1, 1} = tokenValue; %#ok<AGROW>
                end
            end
        end
    end

    tokens = flattened;
end

function tokenStrings = localTokenStringList(tokens)
    tokens = localNormalizeTokenList(tokens);
    if isempty(tokens)
        tokenStrings = strings(0, 1);
        return;
    end

    tokenStrings = strings(numel(tokens), 1);
    for i = 1:numel(tokens)
        tokenStrings(i) = string(strtrim(char(tokens{i})));
    end
end
