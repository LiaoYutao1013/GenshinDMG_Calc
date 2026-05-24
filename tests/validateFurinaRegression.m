function validateFurinaRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false, ...
        'EnemyCount', 1, ...
        'TargetCount', 1);

    cfg = getDefaultCharacterConfig('Furina', struct('Constellation', 0, 'TalentLevel', 10));
    teamContext = buildTeamContext({cfg}, 20, struct('ReactionMode', "Realistic"), enemy);

    singerRotation = [tempname, '.txt'];
    cleanup = onCleanup(@() localDeleteIfExists(singerRotation)); %#ok<NASGU>
    fid = fopen(singerRotation, 'w');
    assert(fid > 0, 'Failed to create temporary Furina regression rotation file.');
    fprintf(fid, 'SwitchPneuma\nE\nSinger\nSinger\n');
    fclose(fid);

    [damage10, ~, breakdown10] = simulateFurinaDPS( ...
        cfg.Build, enemy, singerRotation, 10, cfg.Constellation, teamContext);
    [damage15, ~, breakdown15] = simulateFurinaDPS( ...
        cfg.Build, enemy, singerRotation, 15, cfg.Constellation, teamContext);

    healRows10 = breakdown10(strcmp(string(breakdown10.Action), "Singer_Heal"), :);
    healRows15 = breakdown15(strcmp(string(breakdown15.Action), "Singer_Heal"), :);
    talent10 = readtable(char(resolveCharacterDataFile('Furina', 'talents')), 'TextType', 'string');
    singerRow = talent10(strcmp(string(talent10.Param), "众水的歌者治疗量"), :);
    assert(~isempty(singerRow) && isfinite(singerRow.AuxLevel10(1)) && singerRow.AuxLevel10(1) > 0, ...
        'Furina talent export should persist the singer flat-heal AuxLevel column.');
    assert(height(healRows10) == 2, 'Furina Singer regression should record one heal row per Singer tick.');
    assert(all(healRows10.Damage > 0), 'Furina Singer heal rows should stay positive.');
    assert(sum(healRows15.Damage) > sum(healRows10.Damage), ...
        'Furina Singer heal should scale upward when the aux flat heal value increases by talent level.');
    assert(damage10 > 0 && damage15 > 0, ...
        'Furina Singer regression should keep the opening skill damage active.');

    disp('validateFurinaRegression passed');
end

function localDeleteIfExists(path)
    if exist(path, 'file') == 2
        delete(path);
    end
end
