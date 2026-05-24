function validateLanYanRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false, ...
        'EnemyCount', 2, ...
        'TargetCount', 2);

    pyroMate = getDefaultCharacterConfig('Amber');
    cfgC0 = getDefaultCharacterConfig('LanYan', struct('Constellation', 0));
    cfgC1 = getDefaultCharacterConfig('LanYan', struct('Constellation', 1));
    cfgC3 = getDefaultCharacterConfig('LanYan', struct('Constellation', 3));
    cfgC4 = getDefaultCharacterConfig('LanYan', struct('Constellation', 4));

    teamContextC0 = buildTeamContext({cfgC0, pyroMate}, 20, struct('ReactionMode', "Realistic"), enemy);
    teamContextC1 = buildTeamContext({cfgC1, pyroMate}, 20, struct('ReactionMode', "Realistic"), enemy);

    [damageC0, ~, breakdownC0] = simulateLanYanDPS( ...
        cfgC0.Build, enemy, cfgC0.RotationFile, cfgC0.TalentLevel, cfgC0.Constellation, teamContextC0);
    [damageC1, ~, breakdownC1] = simulateLanYanDPS( ...
        cfgC1.Build, enemy, cfgC1.RotationFile, cfgC1.TalentLevel, cfgC1.Constellation, teamContextC1);

    burstRows = breakdownC0(strcmp(string(breakdownC0.Action), "Q"), :);
    assert(height(burstRows) == 1 && contains(string(burstRows.Note(1)), "x3"), ...
        'LanYan burst should resolve as 3 hits, not the old 4-hit approximation.');
    assert(damageC1 > damageC0, ...
        'LanYan C1 should outperform C0 when the absorbed extra ring is available.');
    assert(any(strcmp(string(breakdownC1.Action), "ERingExtra")), ...
        'LanYan C1 breakdown should include the extra Feathermoon ring action.');
    assert(any(strcmp(string(breakdownC1.Action), "EAbsorbExtra")), ...
        'LanYan C1 breakdown should include the absorbed extra ring action.');

    rotationFile = [tempname, '.txt'];
    cleanup = onCleanup(@() localDeleteIfExists(rotationFile)); %#ok<NASGU>
    fid = fopen(rotationFile, 'w');
    assert(fid > 0, 'Failed to create temporary LanYan regression rotation file.');
    fprintf(fid, 'Q\nEDash\n');
    fclose(fid);

    teamContextC3 = buildTeamContext({cfgC3}, 20, struct('ReactionMode', "Realistic"), enemy);
    teamContextC4 = buildTeamContext({cfgC4}, 20, struct('ReactionMode', "Realistic"), enemy);
    [damageC3, ~, breakdownC3] = simulateLanYanDPS( ...
        cfgC3.Build, enemy, rotationFile, cfgC3.TalentLevel, cfgC3.Constellation, teamContextC3);
    [damageC4, ~, breakdownC4] = simulateLanYanDPS( ...
        cfgC4.Build, enemy, rotationFile, cfgC4.TalentLevel, cfgC4.Constellation, teamContextC4);

    assert(damageC4 > damageC3, ...
        'LanYan C4 should buff the post-burst skill follow-up through the EM window.');
    assert(any(contains(string(breakdownC4.Note), "C4 EM")) ...
        && ~any(contains(string(breakdownC3.Note), "C4 EM")), ...
        'LanYan C4 breakdown should record the active EM window.');

    disp('validateLanYanRegression passed');
end

function localDeleteIfExists(path)
    if exist(path, 'file') == 2
        delete(path);
    end
end
