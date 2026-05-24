function validateXianyunRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false, ...
        'EnemyCount', 1, ...
        'TargetCount', 1);

    cfgC2 = getDefaultCharacterConfig('Xianyun', struct('Constellation', 2));
    cfgC3 = getDefaultCharacterConfig('Xianyun', struct('Constellation', 3));
    cfgC6 = getDefaultCharacterConfig('Xianyun', struct('Constellation', 6));
    rotationFile = [tempname, '.txt'];
    c6NoBurstRotation = [tempname, '.txt'];
    c6BurstRotation = [tempname, '.txt'];
    cleanupObj = onCleanup(@() localDeleteIfExists(rotationFile)); %#ok<NASGU>
    cleanupC6NoBurst = onCleanup(@() localDeleteIfExists(c6NoBurstRotation)); %#ok<NASGU>
    cleanupC6Burst = onCleanup(@() localDeleteIfExists(c6BurstRotation)); %#ok<NASGU>

    fid = fopen(rotationFile, 'w');
    assert(fid > 0, 'Failed to create temporary Xianyun regression rotation file.');
    fprintf(fid, 'Q\nStarwicker\nStarwicker\n');
    fclose(fid);

    fid = fopen(c6NoBurstRotation, 'w');
    assert(fid > 0, 'Failed to create no-burst Xianyun C6 rotation file.');
    fprintf(fid, 'E\nSkyladder\nDriftcloudWave\n');
    fclose(fid);

    fid = fopen(c6BurstRotation, 'w');
    assert(fid > 0, 'Failed to create burst Xianyun C6 rotation file.');
    fprintf(fid, 'Q\nE\nSkyladder\nDriftcloudWave\n');
    fclose(fid);

    contextC2 = buildTeamContext({cfgC2}, 20, struct('ReactionMode', "Realistic"), enemy);
    contextC3 = buildTeamContext({cfgC3}, 20, struct('ReactionMode', "Realistic"), enemy);
    contextC6 = buildTeamContext({cfgC6}, 20, struct('ReactionMode', "Realistic"), enemy);

    [~, ~, breakdownC2] = simulateXianyunDPS( ...
        cfgC2.Build, enemy, rotationFile, cfgC2.TalentLevel, cfgC2.Constellation, contextC2);
    [~, ~, breakdownC3] = simulateXianyunDPS( ...
        cfgC3.Build, enemy, rotationFile, cfgC3.TalentLevel, cfgC3.Constellation, contextC3);
    [~, ~, breakdownC6NoBurst] = simulateXianyunDPS( ...
        cfgC6.Build, enemy, c6NoBurstRotation, cfgC6.TalentLevel, cfgC6.Constellation, contextC6);
    [~, ~, breakdownC6Burst] = simulateXianyunDPS( ...
        cfgC6.Build, enemy, c6BurstRotation, cfgC6.TalentLevel, cfgC6.Constellation, contextC6);

    qHealC2 = sum(breakdownC2.Damage(strcmpi(string(breakdownC2.Action), "Q_Heal")));
    qHealC3 = sum(breakdownC3.Damage(strcmpi(string(breakdownC3.Action), "Q_Heal")));
    tickHealC2 = sum(breakdownC2.Damage(strcmpi(string(breakdownC2.Action), "Starwicker_Heal")));
    tickHealC3 = sum(breakdownC3.Damage(strcmpi(string(breakdownC3.Action), "Starwicker_Heal")));
    c6NoBurstWave = breakdownC6NoBurst(strcmpi(string(breakdownC6NoBurst.Action), "DriftcloudWave"), :);
    c6BurstWave = breakdownC6Burst(strcmpi(string(breakdownC6Burst.Action), "DriftcloudWave"), :);

    assert(qHealC3 > qHealC2, ...
        'Xianyun C3 should increase the initial burst heal via the higher burst talent level.');
    assert(tickHealC3 > tickHealC2, ...
        'Xianyun C3 should increase Starwicker tick healing via the higher burst talent level.');
    assert(height(c6NoBurstWave) == 1 && height(c6BurstWave) == 1, ...
        'Xianyun C6 regression should isolate one Driftcloud Wave row per scripted rotation.');
    assert(~contains(string(c6NoBurstWave.Note), "C6 crit"), ...
        'Xianyun C6 should not grant the crit window before the burst is active.');
    assert(contains(string(c6BurstWave.Note), "C6 crit"), ...
        'Xianyun C6 should annotate the crit window after the burst is active.');
    assert(c6BurstWave.Damage > c6NoBurstWave.Damage, ...
        'Xianyun C6 Driftcloud Wave should only gain the extra crit damage inside the burst window.');

    disp('validateXianyunRegression passed');
end

function localDeleteIfExists(path)
    if exist(path, 'file') == 2
        delete(path);
    end
end
