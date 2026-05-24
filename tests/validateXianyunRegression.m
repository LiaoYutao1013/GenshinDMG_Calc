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
    rotationFile = [tempname, '.txt'];
    cleanupObj = onCleanup(@() localDeleteIfExists(rotationFile)); %#ok<NASGU>

    fid = fopen(rotationFile, 'w');
    assert(fid > 0, 'Failed to create temporary Xianyun regression rotation file.');
    fprintf(fid, 'Q\nStarwicker\nStarwicker\n');
    fclose(fid);

    contextC2 = buildTeamContext({cfgC2}, 20, struct('ReactionMode', "Realistic"), enemy);
    contextC3 = buildTeamContext({cfgC3}, 20, struct('ReactionMode', "Realistic"), enemy);

    [~, ~, breakdownC2] = simulateXianyunDPS( ...
        cfgC2.Build, enemy, rotationFile, cfgC2.TalentLevel, cfgC2.Constellation, contextC2);
    [~, ~, breakdownC3] = simulateXianyunDPS( ...
        cfgC3.Build, enemy, rotationFile, cfgC3.TalentLevel, cfgC3.Constellation, contextC3);

    qHealC2 = sum(breakdownC2.Damage(strcmpi(string(breakdownC2.Action), "Q_Heal")));
    qHealC3 = sum(breakdownC3.Damage(strcmpi(string(breakdownC3.Action), "Q_Heal")));
    tickHealC2 = sum(breakdownC2.Damage(strcmpi(string(breakdownC2.Action), "Starwicker_Heal")));
    tickHealC3 = sum(breakdownC3.Damage(strcmpi(string(breakdownC3.Action), "Starwicker_Heal")));

    assert(qHealC3 > qHealC2, ...
        'Xianyun C3 should increase the initial burst heal via the higher burst talent level.');
    assert(tickHealC3 > tickHealC2, ...
        'Xianyun C3 should increase Starwicker tick healing via the higher burst talent level.');

    disp('validateXianyunRegression passed');
end

function localDeleteIfExists(path)
    if exist(path, 'file') == 2
        delete(path);
    end
end
