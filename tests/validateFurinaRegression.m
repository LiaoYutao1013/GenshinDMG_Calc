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

    [damage10, ~, breakdown10, ~, audit10] = simulateFurinaDPS( ...
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

    singerAuditRows = audit10.Rows(strcmp(string(audit10.Rows.Action), "Singer"), :);
    assert(height(singerAuditRows) == 2 ...
        && all(singerAuditRows.ApplyGaugeSource == "not_applicable") ...
        && all(isnan(singerAuditRows.ApplyGauge)), ...
        'Furina Singer audit rows should stay as non-damaging utility actions.');

    sharedApproxBonus = getFieldOrDefault(teamContext, 'ApproxFurinaBonus', 0);
    assert(sharedApproxBonus > 0, ...
        'Furina team context should still expose an approximate shared burst bonus for teammates.');
    assert(abs(sharedApproxBonus - 0.60) > 1e-6, ...
        'Furina team context should now derive the shared burst bonus from timeline behavior instead of the legacy fixed C0 constant.');

    normalRotation = [tempname, '.txt'];
    normalCleanup = onCleanup(@() localDeleteIfExists(normalRotation)); %#ok<NASGU>
    fid = fopen(normalRotation, 'w');
    assert(fid > 0, 'Failed to create temporary Furina normal regression rotation file.');
    fprintf(fid, 'N1\n');
    fclose(fid);

    noApproxContext = teamContext;
    noApproxContext.AllDMGBonus = getFieldOrDefault(noApproxContext, 'AllDMGBonus', 0) - sharedApproxBonus;
    noApproxContext.ApproxFurinaBonus = 0;

    [normalDamageWith, ~, normalBreakdown] = simulateFurinaDPS( ...
        cfg.Build, enemy, normalRotation, 10, cfg.Constellation, teamContext);
    [normalDamageWithout, ~] = simulateFurinaDPS( ...
        cfg.Build, enemy, normalRotation, 10, cfg.Constellation, noApproxContext);
    assert(abs(normalDamageWith - normalDamageWithout) < 1e-6 * max(1, abs(normalDamageWith)), ...
        'Furina self simulation should strip ApproxFurinaBonus to avoid double-counting the shared burst heuristic.');

    chars = readtable(char(resolveCharacterDataFile('Furina', 'characters')), 'TextType', 'string');
    baseATK = double(chars.BaseATK(1));
    atkValue = (baseATK + getFieldOrDefault(cfg.Build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(cfg.Build, 'AtkBonus', 0) + getFieldOrDefault(noApproxContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(cfg.Build, 'FlatATK', 0) + getFieldOrDefault(noApproxContext, 'FlatATK', 0);
    critMult = calcExpectedCritMultiplier(getFieldOrDefault(cfg.Build, 'CritRate', 0), getFieldOrDefault(cfg.Build, 'CritDMG', 0));
    normalBonus = 1 + getFieldOrDefault(cfg.Build, 'NormalDMGBonus', 0) ...
        + getFieldOrDefault(cfg.Build, 'PhysicalDMGBonus', 0) ...
        + getFieldOrDefault(noApproxContext, 'PhysicalDMGBonus', 0) ...
        + getFieldOrDefault(noApproxContext, 'AllDMGBonus', 0);
    expectedN1Damage = atkValue * double(talent10.Level10(1)) * normalBonus * critMult ...
        * calcDamageMultiplier(90, enemy, getFieldOrDefault(cfg.Build, 'ResShred', 0) ...
        + getFieldOrDefault(noApproxContext, 'PhysicalResShred', 0));

    n1Rows = normalBreakdown(strcmp(string(normalBreakdown.Action), "N1"), :);
    assert(height(n1Rows) == 1, 'Furina normal regression should isolate one N1 row.');
    assert(abs(n1Rows.Damage - expectedN1Damage) < 1e-6 * max(1, expectedN1Damage), ...
        'Furina N1 should now use the physical ATK-based path instead of the old HP-based Hydro approximation.');

    barbara = getDefaultCharacterConfig('Barbara');
    lisa = getDefaultCharacterConfig('Lisa');
    furinaTeam = buildTeamContext({cfg, barbara, lisa}, 20, struct('ReactionMode', "Realistic"), enemy);
    soloFurinaTeam = buildTeamContext({cfg}, 20, struct('ReactionMode', "Realistic"), enemy);
    assert(getFieldOrDefault(furinaTeam, 'ApproxFurinaBonus', 0) > getFieldOrDefault(soloFurinaTeam, 'ApproxFurinaBonus', 0), ...
        'Furina timeline-derived team bonus should increase when a more realistic multi-member rotation can build better HP rhythm and burst coverage.');

    disp('validateFurinaRegression passed');
end

function localDeleteIfExists(path)
    if exist(path, 'file') == 2
        delete(path);
    end
end
