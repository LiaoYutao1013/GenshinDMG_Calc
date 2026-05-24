function validateAyakaRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false, ...
        'EnemyCount', 1, ...
        'TargetCount', 1);

    cfg2 = getDefaultCharacterConfig('KamisatoAyaka', struct('Constellation', 2, 'TalentLevel', 10));
    cfg6 = getDefaultCharacterConfig('KamisatoAyaka', struct('Constellation', 6, 'TalentLevel', 10));
    ctx2 = buildTeamContext({cfg2}, 20, struct('ReactionMode', "Realistic"), enemy);
    ctx6 = buildTeamContext({cfg6}, 20, struct('ReactionMode', "Realistic"), enemy);

    [damage2, ~, breakdown2, rotationTime2, audit2] = simulateKamisatoAyakaDPS( ...
        cfg2.Build, enemy, cfg2.RotationFile, cfg2.TalentLevel, cfg2.Constellation, ctx2);
    [damage6, ~, breakdown6, rotationTime6, audit6] = simulateKamisatoAyakaDPS( ...
        cfg6.Build, enemy, cfg6.RotationFile, cfg6.TalentLevel, cfg6.Constellation, ctx6);

    actions2 = string(breakdown2.Action);
    notes2 = string(breakdown2.Note);
    actions6 = string(breakdown6.Action);

    assert(damage2 > 0 && rotationTime2 > 0 && damage6 > 0 && rotationTime6 > 0, ...
        'Ayaka regression should produce positive damage and rotation time for both C2 and C6.');
    assert(any(actions2 == "QCutC2") && any(actions2 == "QBloomC2"), ...
        'Ayaka C2 regression should keep the side-storm follow-up actions.');
    assert(any(contains(notes2, "C2 side storm x2 expected")) ...
        && any(contains(notes2, "C2 side storm bloom x2 expected")), ...
        'Ayaka C2 regression should preserve the expected-value side-storm notes.');
    assert(sum(actions6 == "CA6") == 1, ...
        'Ayaka C6 regression should keep exactly one first charged attack C6 row.');
    assert(localAppearsInOrder(actions6, ["QCut", "QCutC2", "QBloom", "QBloomC2", "CA6", "CA"]), ...
        'Ayaka C6 regression should preserve burst segments before the C6 charged-attack handoff.');
    assert(height(audit2.Rows) == height(breakdown2) && height(audit6.Rows) == height(breakdown6), ...
        'Ayaka regression should expose one audit row per scripted action.');

    disp('validateAyakaRegression passed');
end

function tf = localAppearsInOrder(actions, expected)
    cursor = 0;
    tf = true;
    for i = 1:numel(expected)
        matches = find(actions == expected(i));
        matches = matches(matches > cursor);
        if isempty(matches)
            tf = false;
            return;
        end
        cursor = matches(1);
    end
end
