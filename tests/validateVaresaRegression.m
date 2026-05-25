function validateVaresaRegression()
    initProjectPaths();

    enemy = struct( ...
        'Level', 90, ...
        'Res', 0.10, ...
        'DefReduct', 0, ...
        'ReactionMode', "Realistic", ...
        'AutoSupportAura', false, ...
        'EnemyCount', 1, ...
        'TargetCount', 1);

    cfg = getDefaultCharacterConfig('Varesa', struct('TalentLevel', 10, 'Constellation', 0));
    hydroMate = getDefaultCharacterConfig('Barbara');
    soloContext = buildTeamContext({cfg}, 20, struct('ReactionMode', "Realistic"), enemy);
    hydroContext = buildTeamContext({cfg, hydroMate}, 20, struct('ReactionMode', "Realistic"), enemy);
    hydroAuraEnemy = enemy;
    hydroAuraEnemy.InitialAuraElement = "Hydro";
    hydroAuraEnemy.InitialAuraGauge = 1.0;
    explicitHydroContext = hydroContext;
    explicitHydroContext.EnemyState = createEnemyState(hydroAuraEnemy, explicitHydroContext, "Electro");
    approximateHydroEnemy = enemy;
    approximateHydroEnemy.ReactionMode = "Approximate";
    approximateHydroEnemy.AutoSupportAura = true;
    approximateHydroContext = buildTeamContext({cfg, hydroMate}, 20, struct('ReactionMode', "Approximate"), approximateHydroEnemy);

    [soloDamage, ~, soloBreakdown, soloTime, audit] = simulateVaresaDPS( ...
        cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, soloContext);
    [hydroDamage, ~, hydroBreakdown] = simulateVaresaDPS( ...
        cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, hydroContext);
    [explicitHydroDamage, ~, explicitHydroBreakdown] = simulateVaresaDPS( ...
        cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, explicitHydroContext);
    [approximateHydroDamage, ~, approximateHydroBreakdown] = simulateVaresaDPS( ...
        cfg.Build, approximateHydroEnemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, approximateHydroContext);

    soloActions = string(soloBreakdown.Action);
    soloNotes = string(soloBreakdown.Note);
    hydroActions = string(hydroBreakdown.Action);
    hydroNotes = string(hydroBreakdown.Note);
    explicitHydroActions = string(explicitHydroBreakdown.Action);
    explicitHydroNotes = string(explicitHydroBreakdown.Note);
    approximateHydroActions = string(approximateHydroBreakdown.Action);
    expectedSequence = ["E", "Rush", "Leap", "Plunge", "Q", "Finisher"];

    assert(soloDamage > 0 && soloTime > 0, ...
        'Varesa regression should produce positive damage and rotation time.');
    assert(localAppearsInOrder(soloActions, expectedSequence), ...
        'Varesa regression should preserve the rush, plunge, burst, and finisher order.');
    assert(any(contains(soloNotes, "Rush state entered")), ...
        'Varesa regression should preserve the rush-state annotation.');
    assert(any(contains(soloNotes, "Empowered plunge")), ...
        'Varesa regression should preserve the empowered plunge annotation.');
    assert(any(contains(soloNotes, "Burst finisher")), ...
        'Varesa regression should preserve the finisher annotation.');
    assert(~any(soloActions == "ElectroCharged"), ...
        'Varesa solo regression should not inject Electro-Charged rows without Hydro support.');
    assert(~any(hydroActions == "ElectroCharged"), ...
        'Varesa realistic Hydro-team regression should not invent plunge Electro-Charged without an explicit enemy aura.');
    assert(sum(explicitHydroActions == "ElectroCharged") == 3, ...
        'Varesa explicit Hydro-aura regression should emit one Electro-Charged splash per plunge window.');
    assert(any(contains(explicitHydroNotes, "Electro-Charged splash from plunge")), ...
        'Varesa explicit Hydro-aura regression should keep the plunge Electro-Charged annotation.');
    assert(explicitHydroDamage > soloDamage, ...
        'Varesa explicit Hydro-aura regression should outdamage the solo script once plunge Electro-Charged is enabled.');
    assert(sum(approximateHydroActions == "ElectroCharged") == 3, ...
        'Varesa approximate-mode regression should keep the Hydro support-aura fallback alive.');
    assert(approximateHydroDamage > hydroDamage, ...
        'Varesa approximate-mode regression should still deal more damage than realistic Hydro-only team context.');
    assert(istable(audit.Rows) && ~any(audit.Rows.ApplyGaugeFallback | audit.Rows.ICDFallback), ...
        'Varesa regression should keep the explicit audit metadata wired for the scripted rotation.');

    disp('validateVaresaRegression passed');
end

function tf = localAppearsInOrder(actions, expected)
    cursor = 0;
    tf = true;
    for i = 1:numel(expected)
        matches = find(actions == expected(i));
        matches = matches(matches > cursor);
        if isempty(matches)
            tf = false;
            return;
        end
        cursor = matches(1);
    end
end
