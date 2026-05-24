function validateDurinRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false, ...
        'EnemyCount', 1, ...
        'TargetCount', 1);

    cfg = getDefaultCharacterConfig('Durin', struct('Constellation', 0, 'TalentLevel', 10));
    teamContext = buildTeamContext({cfg}, 20, struct('ReactionMode', "Realistic", 'DurinMode', "Dark"), enemy);

    rotationFile = [tempname, '.txt'];
    cleanup = onCleanup(@() localDeleteIfExists(rotationFile)); %#ok<NASGU>
    fid = fopen(rotationFile, 'w');
    assert(fid > 0, 'Failed to create temporary Durin regression rotation file.');
    fprintf(fid, 'E\nDeny\nQ\nDarkTick\n');
    fclose(fid);

    noAuraContext = teamContext;
    noAuraContext.EnemyState = createEnemyState(enemy, noAuraContext, "Pyro");
    noAuraContext.EnemyState.Auras = noAuraContext.EnemyState.Auras([]); %#ok<AGROW>
    noAuraContext.EnemyState.Frozen.Active = false;
    noAuraContext.EnemyState.Frozen.Gauge = 0;

    hydroAuraContext = teamContext;
    hydroAuraEnemy = enemy;
    hydroAuraEnemy.InitialAuraElement = "Hydro";
    hydroAuraEnemy.InitialAuraGauge = 1.0;
    hydroAuraContext.EnemyState = createEnemyState(hydroAuraEnemy, hydroAuraContext, "Pyro");

    [damageNoAura, ~, noAuraBreakdown] = simulateDurinDPS( ...
        cfg.Build, enemy, rotationFile, cfg.TalentLevel, cfg.Constellation, noAuraContext);
    [damageHydroAura, ~, hydroAuraBreakdown] = simulateDurinDPS( ...
        cfg.Build, enemy, rotationFile, cfg.TalentLevel, cfg.Constellation, hydroAuraContext);

    denyMaskNoAura = matches(string(noAuraBreakdown.Action), ["Deny1", "Deny2", "Deny3"]);
    denyMaskHydroAura = matches(string(hydroAuraBreakdown.Action), ["Deny1", "Deny2", "Deny3"]);
    denyRowsNoAura = noAuraBreakdown(denyMaskNoAura, :);
    denyRowsHydroAura = hydroAuraBreakdown(denyMaskHydroAura, :);
    assert(height(denyRowsNoAura) == 3 && height(denyRowsHydroAura) == 3, ...
        'Durin regression should preserve all three Deny branch hits.');
    assert(all(~contains(lower(string(denyRowsNoAura.Note)), "vaporize") & ~contains(lower(string(denyRowsNoAura.Note)), "melt")), ...
        'Durin dark regression should not invent amplify reactions without an explicit Hydro/Cryo aura.');
    assert(any(contains(lower(string(denyRowsHydroAura.Note)), "vaporize")), ...
        'Durin dark regression should honor an explicit Hydro aura for the Deny branch.');
    assert(damageHydroAura > damageNoAura, ...
        'Durin dark regression should deal more damage when a real Hydro aura is present.');

    audit = auditCharacterReactionMetadata('Durin', struct('Constellation', 0, 'TalentLevel', 10), enemy);
    assert(istable(audit.Rows) && ~any(audit.Rows.ApplyGaugeFallback | audit.Rows.ICDFallback), ...
        'Durin audit should resolve ApplyGauge and ICD metadata without generic fallback rows.');

    disp('validateDurinRegression passed');
end

function localDeleteIfExists(path)
    if exist(path, 'file') == 2
        delete(path);
    end
end
