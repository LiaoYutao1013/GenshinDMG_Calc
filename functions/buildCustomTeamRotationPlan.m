function plan = buildCustomTeamRotationPlan(members, actions, rotationDuration)
% Build a team plan from an ordered sequence of member/action pairs.
% The simulator executes one contiguous action block per member, so a member
% cannot be re-entered after another member's block has started.
    if nargin < 3 || isempty(rotationDuration)
        rotationDuration = getFixedSimulationDuration();
    end
    actions = localNormalizeActions(actions, numel(members));
    if isempty(actions)
        error('Custom team rotation must contain at least one action.');
    end

    memberPlans = localEmptyMemberPlans(members);
    cursor = 0;
    seenMembers = false(1, numel(members));
    activeMember = 0;
    executionOrder = zeros(1, 0);
    for i = 1:numel(actions)
        memberIndex = actions(i).MemberIndex;
        if memberIndex ~= activeMember
            if seenMembers(memberIndex)
                error(['Custom rotation cannot return to a character after another character acts. ' ...
                    'Keep the actions of each character in one contiguous block.']);
            end
            activeMember = memberIndex;
            seenMembers(memberIndex) = true;
            executionOrder(end + 1) = memberIndex; %#ok<AGROW>
            memberPlans(memberIndex).StartTime = cursor;
            memberPlans(memberIndex).Order = numel(executionOrder);
        end
        token = char(actions(i).Token);
        memberPlans(memberIndex).RotationTokens{end + 1, 1} = token;
        cursor = cursor + estimateActionDuration(members{memberIndex}.Name, token, 0.60);
        memberPlans(memberIndex).EndTime = cursor;
    end

    for i = 1:numel(memberPlans)
        tokens = memberPlans(i).RotationTokens;
        memberPlans(i).EstimatedDuration = max(0, memberPlans(i).EndTime - memberPlans(i).StartTime);
        memberPlans(i).RotationText = string(strjoin(string(tokens(:)), newline));
        memberPlans(i).Preview = strjoin(string(tokens(:)).', " > ");
        if ~seenMembers(i)
            memberPlans(i).StartTime = rotationDuration;
            memberPlans(i).EndTime = rotationDuration;
        end
    end

    executionTable = localExecutionTable(memberPlans, executionOrder);
    plan = struct( ...
        'RotationDuration', rotationDuration, ...
        'CarryIndex', 0, ...
        'ExecutionOrder', executionOrder, ...
        'PlanDirectory', "", ...
        'MemberPlans', memberPlans, ...
        'ArchetypeInfo', identifyTeamArchetype(members, struct()), ...
        'ExecutionTable', executionTable, ...
        'CandidateCount', 1, ...
        'SelectionScore', NaN, ...
        'SelectionMode', "Custom team rotation", ...
        'SelectionSummary', "User-defined ordered actions", ...
        'SelectionMetrics', struct());
end

function actions = localNormalizeActions(rawActions, memberCount)
    actions = repmat(struct('MemberIndex', 0, 'Token', ""), 1, 0);
    for i = 1:numel(rawActions)
        memberIndex = round(double(getFieldOrDefault(rawActions(i), 'MemberIndex', 0)));
        token = upper(strtrim(string(getFieldOrDefault(rawActions(i), 'Token', ""))));
        if memberIndex < 1 || memberIndex > memberCount
            error('Custom rotation action %d references a member that is not enabled.', i);
        end
        if strlength(token) == 0
            error('Custom rotation action %d has no token.', i);
        end
        actions(end + 1) = struct('MemberIndex', memberIndex, 'Token', token); %#ok<AGROW>
    end
end

function plans = localEmptyMemberPlans(members)
    plans = repmat(struct( ...
        'Name', "", 'DisplayName', "", 'Role', "Custom", 'Order', 0, ...
        'TargetBudget', 0, 'EstimatedDuration', 0, 'StartTime', 0, 'EndTime', 0, ...
        'RotationTokens', {cell(0, 1)}, 'RotationText', "", 'Preview', "", ...
        'PlanningSource', "custom", 'SeedSource', "team-ui", 'TempRotationFile', ""), 1, numel(members));
    for i = 1:numel(members)
        plans(i).Name = string(members{i}.Name);
        plans(i).DisplayName = string(getFieldOrDefault(members{i}, 'DisplayName', members{i}.Name));
    end
end

function executionTable = localExecutionTable(plans, order)
    rows = cell(0, 8);
    for i = 1:numel(order)
        plan = plans(order(i));
        rows(end + 1, :) = {i, plan.DisplayName, plan.Role, "", plan.StartTime, ...
            plan.EndTime, plan.EstimatedDuration, plan.Preview}; %#ok<AGROW>
    end
    executionTable = cell2table(rows, 'VariableNames', { ...
        'Order', 'Character', 'Role', 'Job', 'StartTime', 'EndTime', 'ReservedTime', 'RotationPreview'});
end
