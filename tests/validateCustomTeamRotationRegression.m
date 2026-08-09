function validateCustomTeamRotationRegression()
% Verify ordered custom team actions take precedence over the optimizer.
    initProjectPaths();
    skirk = getDefaultCharacterConfig('Skirk');
    escoffier = getDefaultCharacterConfig('Escoffier');
    actions = [ ...
        struct('MemberIndex', 2, 'Token', 'E'), ...
        struct('MemberIndex', 2, 'Token', 'Q'), ...
        struct('MemberIndex', 1, 'Token', 'Q'), ...
        struct('MemberIndex', 1, 'Token', 'E'), ...
        struct('MemberIndex', 1, 'Token', 'N1')];
    plan = buildCustomTeamRotationPlan({skirk, escoffier}, actions, 120);
    assert(string(plan.SelectionMode) == "Custom team rotation");
    assert(isequal(plan.ExecutionOrder, [2 1]));
    assert(isequal(string(plan.MemberPlans(2).RotationTokens), ["E"; "Q"]));

    invalidActions = [actions(1), actions(3), actions(2)];
    didRejectInterleavedMember = false;
    try
        buildCustomTeamRotationPlan({skirk, escoffier}, invalidActions, 120);
    catch ME
        didRejectInterleavedMember = contains(string(ME.message), "cannot return");
    end
    assert(didRejectInterleavedMember);

    team = struct( ...
        'Members', {{skirk, escoffier}}, ...
        'PlanOptions', struct('CustomRotationActions', actions), ...
        'SharedBuffs', struct());
    [result, members] = simulateTeamDPS(team, struct('Level', 90, 'Res', 0.10, 'DefReduct', 0));
    assert(string(result.PlannedRotation.SelectionMode) == "Custom team rotation");
    assert(result.DPS >= 0);
    assert(abs(result.DPS - sum([members.DPS])) < 1e-9, ...
        'Primary team DPS must match the sum of member standalone DPS values.');
    assert(abs(result.MemberDPSSum - result.DPS) < 1e-9, ...
        'MemberDPSSum must remain aligned with the primary team DPS display rule.');
    assert(isfield(result, 'CycleDPS'), ...
        'Cycle-normalized DPS must be retained as a separate diagnostic value.');
    fprintf('Custom team rotation regression passed.\n');
end
