function validateAmberRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false, ...
        'EnemyCount', 1, ...
        'TargetCount', 1);

    cfg = getDefaultCharacterConfig('Amber', struct('Constellation', 2, 'TalentLevel', 10));
    teamContext = buildTeamContext({cfg}, 20, struct('ReactionMode', "Realistic"), enemy);

    rotationFile = [tempname, '.txt'];
    cleanup = onCleanup(@() localDeleteIfExists(rotationFile)); %#ok<NASGU>
    fid = fopen(rotationFile, 'w');
    assert(fid > 0, 'Failed to create temporary Amber regression rotation file.');
    fprintf(fid, 'Aimed\nAimedC1\nEManual\nQ\n');
    fclose(fid);

    [damage, ~, breakdown, rotationTime, audit] = simulateAmberDPS( ...
        cfg.Build, enemy, rotationFile, cfg.TalentLevel, cfg.Constellation, teamContext);

    actions = string(breakdown.Action);
    notes = string(breakdown.Note);
    qRows = breakdown(actions == "Q", :);

    assert(damage > 0 && rotationTime > 0, ...
        'Amber regression should produce positive damage and rotation time.');
    assert(isequal(actions', ["Aimed", "AimedC1", "EManual", "Q"]), ...
        'Amber regression should keep the charged-shot, C1 arrow, manual bunny detonation, and burst order.');
    assert(any(contains(notes, "Charged shot")), ...
        'Amber regression should preserve the charged-shot annotation.');
    assert(any(contains(notes, "C1 extra arrow")), ...
        'Amber regression should preserve the C1 arrow annotation.');
    assert(any(contains(notes, "C2 manual detonation")), ...
        'Amber regression should preserve the C2 manual detonation annotation.');
    assert(height(qRows) == 1 && contains(string(qRows.Note), "Fiery Rain waves") && contains(string(qRows.Note), "x18"), ...
        'Amber burst regression should keep the 18-wave Fiery Rain breakdown note.');
    assert(istable(audit.Rows) && height(audit.Rows) == 4, ...
        'Amber regression should expose one audit row per scripted action.');
    assert(~any(audit.Rows.ApplyGaugeFallback | audit.Rows.ICDFallback), ...
        'Amber regression should avoid generic fallback gauge or ICD metadata.');

    disp('validateAmberRegression passed');
end

function localDeleteIfExists(path)
    if exist(path, 'file') == 2
        delete(path);
    end
end
