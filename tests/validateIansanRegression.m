function validateIansanRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false, ...
        'EnemyCount', 1, ...
        'TargetCount', 1);

    cfg = getDefaultCharacterConfig('Iansan', struct('Constellation', 1, 'TalentLevel', 10));
    cfg0 = getDefaultCharacterConfig('Iansan', struct('Constellation', 0, 'TalentLevel', 10));
    cfg6 = getDefaultCharacterConfig('Iansan', struct('Constellation', 6, 'TalentLevel', 10));
    hydroMate = getDefaultCharacterConfig('Barbara');
    electroMate = getDefaultCharacterConfig('Flins');
    teamContext = buildTeamContext({cfg, hydroMate, electroMate}, 20, struct('ReactionMode', "Realistic"), enemy);
    teamContext0 = buildTeamContext({cfg0, hydroMate, electroMate}, 20, struct('ReactionMode', "Realistic"), enemy);
    teamContext6 = buildTeamContext({cfg6, hydroMate, electroMate}, 20, struct('ReactionMode', "Realistic"), enemy);
    assert(getFieldOrDefault(teamContext, 'LunarChargedEnabled', false), ...
        'Iansan regression requires a Hydro/Electro team that enables Lunar-Charged support.');

    talent = readtable(fullfile('data', 'Iansan', 'talents_Iansan.csv'), 'TextType', 'string');
    shareRow = talent(strcmp(string(talent.Skill), "Support") & strcmp(string(talent.Param), "ATKShare"), :);
    assert(~isempty(shareRow), 'Iansan regression requires the ATKShare support row in talents_Iansan.csv.');
    baseShare = double(shareRow.Level10(1));
    assert(abs(getFieldOrDefault(teamContext0, 'IansanBurstATKBonus', 0) - baseShare) < 1e-9, ...
        'Iansan C0 team context should source the burst ATK support directly from talents_Iansan.csv.');
    expectedShare = double(shareRow.Level10(1)) + 0.06;
    assert(abs(getFieldOrDefault(teamContext, 'IansanBurstATKBonus', 0) - expectedShare) < 1e-9, ...
        'Iansan team context should source burst ATK support from talents_Iansan.csv plus known constellation increments.');
    assert(abs(getFieldOrDefault(teamContext6, 'IansanBurstATKBonus', 0) - (baseShare + 0.06 + 0.08)) < 1e-9, ...
        'Iansan C6 team context should add both documented constellation support increments to the imported base share.');

    rotationFile = [tempname, '.txt'];
    cleanup = onCleanup(@() localDeleteIfExists(rotationFile)); %#ok<NASGU>
    fid = fopen(rotationFile, 'w');
    assert(fid > 0, 'Failed to create temporary Iansan regression rotation file.');
    fprintf(fid, 'E\nSprint\nThrow\nQ\nBolt\nBolt\nBolt\n');
    fclose(fid);

    [damage, ~, breakdown, rotationTime, audit] = simulateIansanDPS( ...
        cfg.Build, enemy, rotationFile, cfg.TalentLevel, cfg.Constellation, teamContext);

    assert(damage > 0 && rotationTime > 0, ...
        'Iansan regression should produce positive damage over a positive rotation length.');
    boltRows = breakdown(strcmp(string(breakdown.Action), "Bolt"), :);
    assert(height(boltRows) == 3 && all(boltRows.Damage > 0), ...
        'Iansan regression should keep all scripted coordinated bolts active during burst.');
    assert(any(strcmp(string(breakdown.Action), "LunarCharged")), ...
        'Iansan regression should record Lunar-Charged reaction rows when Hydro/Electro support is present.');

    assert(istable(audit.Rows) && ~any(audit.Rows.ApplyGaugeFallback | audit.Rows.ICDFallback), ...
        'Iansan audit should resolve ApplyGauge and ICD metadata without generic fallback rows.');
    assert(any(strcmp(string(audit.Rows.Action), "Bolt")), ...
        'Iansan audit should include coordinated bolt follow-up actions.');

    disp('validateIansanRegression passed');
end

function localDeleteIfExists(path)
    if exist(path, 'file') == 2
        delete(path);
    end
end
