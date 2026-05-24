function validateChevreuseRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false, ...
        'EnemyCount', 1, ...
        'TargetCount', 1);

    cfg = getDefaultCharacterConfig('Chevreuse', struct('Constellation', 2, 'TalentLevel', 10));
    pyroCfg = getDefaultCharacterConfig('Amber');
    electroCfg = getDefaultCharacterConfig('Lisa');
    teamContext = buildTeamContext({cfg, pyroCfg, electroCfg}, 20, struct('ReactionMode', "Realistic"), enemy);
    invalidContext = buildTeamContext({cfg, pyroCfg, getDefaultCharacterConfig('Barbara')}, 20, struct('ReactionMode', "Realistic"), enemy);

    assert(getFieldOrDefault(teamContext, 'ChevreuseOverloadReady', false), ...
        'Chevreuse team context should enable overload support for Pyro/Electro-only teams.');
    assert(~getFieldOrDefault(invalidContext, 'ChevreuseOverloadReady', false), ...
        'Chevreuse overload support should stay disabled once a non-Pyro/Electro teammate is added.');

    rotationFile = [tempname, '.txt'];
    cleanup = onCleanup(@() localDeleteIfExists(rotationFile)); %#ok<NASGU>
    fid = fopen(rotationFile, 'w');
    assert(fid > 0, 'Failed to create temporary Chevreuse regression rotation file.');
    fprintf(fid, 'E\nLoadedShot\nQ\nGrenade\nHeal\nOverload\n');
    fclose(fid);

    [damage, ~, breakdown] = simulateChevreuseDPS( ...
        cfg.Build, enemy, rotationFile, cfg.TalentLevel, cfg.Constellation, teamContext);
    [~, ~, invalidBreakdown] = simulateChevreuseDPS( ...
        cfg.Build, enemy, rotationFile, cfg.TalentLevel, cfg.Constellation, invalidContext);

    assert(any(strcmp(string(breakdown.Action), "E")), 'Chevreuse regression should include the skill hit.');
    assert(any(strcmp(string(breakdown.Action), "LoadedShot")), 'Chevreuse regression should include the loaded shot.');
    assert(any(strcmp(string(breakdown.Action), "Q")), 'Chevreuse regression should include the burst cast.');
    assert(any(strcmp(string(breakdown.Action), "Grenade")), 'Chevreuse regression should include the burst follow-up.');
    assert(any(strcmp(string(breakdown.Action), "Overload")), 'Chevreuse regression should include overload damage.');
    invalidOverloadRows = invalidBreakdown(strcmp(string(invalidBreakdown.Action), "Overload"), :);
    assert(height(invalidOverloadRows) == 1 && invalidOverloadRows.Damage(1) == 0, ...
        'Chevreuse overload action should stay inert when the team does not meet the Pyro/Electro-only requirement.');
    assert(damage > 0, 'Chevreuse regression should produce positive damage.');

    disp('validateChevreuseRegression passed');
end

function localDeleteIfExists(path)
    if exist(path, 'file') == 2
        delete(path);
    end
end
