function validateFischlRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false, ...
        'EnemyCount', 1, ...
        'TargetCount', 1);

    cfg = getDefaultCharacterConfig('Fischl', struct('Constellation', 6, 'TalentLevel', 10));
    ctx = buildTeamContext({cfg}, 20, struct('ReactionMode', "Realistic"), enemy);

    [damage, ~, breakdown, rotationTime, audit] = simulateFischlDPS( ...
        cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, ctx);

    actions = string(breakdown.Action);
    ozRows = breakdown(actions == "Oz", :);
    qOzRows = breakdown(actions == "QOz", :);

    assert(damage > 0 && rotationTime > 0, ...
        'Fischl regression should produce positive damage and rotation time.');
    assert(isequal(actions', ["E", "Oz", "Q", "QOz"]), ...
        'Fischl regression should preserve the summon -> Oz -> burst -> Oz refresh order.');
    assert(height(ozRows) == 1 && contains(string(ozRows.Note), "x10"), ...
        'Fischl regression should keep the 10-shot Oz turret note.');
    assert(height(qOzRows) == 1 && contains(string(qOzRows.Note), "x10"), ...
        'Fischl regression should keep the 10-shot Oz refresh note.');
    assert(~any(audit.Rows.ApplyGaugeFallback | audit.Rows.ICDFallback), ...
        'Fischl regression should keep explicit gauge and ICD metadata for the scripted rotation.');

    explicitRotationFile = [tempname, '.txt'];
    cleanup = onCleanup(@() localDeleteIfExists(explicitRotationFile)); %#ok<NASGU>
    fid = fopen(explicitRotationFile, 'w');
    assert(fid > 0, 'Failed to create temporary Fischl regression rotation file.');
    fprintf(fid, 'E\nOzJointAttack\nOzA4Retribution\nQ\n');
    fclose(fid);

    [~, ~, explicitBreakdown, explicitRotationTime, explicitAudit] = simulateFischlDPS( ...
        cfg.Build, enemy, explicitRotationFile, cfg.TalentLevel, cfg.Constellation, ctx);

    explicitActions = string(explicitBreakdown.Action);
    jointRow = explicitBreakdown(explicitActions == "OzJointAttack", :);
    a4Row = explicitBreakdown(explicitActions == "OzA4Retribution", :);
    jointAudit = explicitAudit.Rows(string(explicitAudit.Rows.Action) == "OzJointAttack", :);
    a4Audit = explicitAudit.Rows(string(explicitAudit.Rows.Action) == "OzA4Retribution", :);

    assert(explicitRotationTime > 0, ...
        'Fischl explicit follow-up regression should produce positive rotation time.');
    assert(isequal(explicitActions', ["E", "OzJointAttack", "OzA4Retribution", "Q"]), ...
        'Fischl explicit follow-up regression should preserve the scripted summon, C6, A4, and burst order.');
    assert(height(jointRow) == 1 && jointRow.Damage > 0 && contains(string(jointRow.Note), "C6 Oz coordinated attack"), ...
        'Fischl explicit follow-up regression should expose a non-zero C6 Oz coordinated attack row.');
    assert(height(a4Row) == 1 && a4Row.Damage > jointRow.Damage && contains(string(a4Row.Note), "A4 Thundering Retribution"), ...
        'Fischl explicit follow-up regression should expose a stronger A4 retribution row.');
    assert(abs((a4Row.Damage / jointRow.Damage) - (8 / 3)) < 1e-6, ...
        'Fischl explicit follow-up regression should preserve the documented 80%% vs 30%% ATK split.');
    assert(height(jointAudit) == 1 && string(jointAudit.LunarisAttackName) == "Talent_D_Crow_NormalAttack_01", ...
        'Fischl C6 follow-up regression should map to the Oz joint-attack Lunaris entry.');
    assert(height(a4Audit) == 1 && string(a4Audit.LunarisAttackName) == "Talent_ElementReactionAttackThunder_Hit", ...
        'Fischl A4 follow-up regression should map to the retribution Lunaris entry.');
    assert(~any(explicitAudit.Rows.ApplyGaugeFallback | explicitAudit.Rows.ICDFallback), ...
        'Fischl explicit follow-up regression should avoid generic fallback gauge or ICD metadata.');

    disp('validateFischlRegression passed');
end

function localDeleteIfExists(path)
    if exist(path, 'file') == 2
        delete(path);
    end
end
