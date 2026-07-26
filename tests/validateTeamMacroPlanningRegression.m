function validateTeamMacroPlanningRegression()
    initProjectPaths();

    skirkMacro = getCharacterRotationMacro('Skirk', "Carry", struct());
    assert(skirkMacro.Defined && any(strcmpi(string(skirkMacro.Tokens), "ExQ")), ...
        'Skirk carry macro should include the Seven-Phase follow-up action.');
    assert(sum(startsWith(string(skirkMacro.Tokens), "N")) >= 5, ...
        'Skirk carry macro should contain a meaningful Seven-Phase normal string.');

    furinaMacro = getCharacterRotationMacro('Furina', "Support", struct());
    escoffierMacro = getCharacterRotationMacro('Escoffier', "Support", struct());
    citlaliMacro = getCharacterRotationMacro('Citlali', "Support", struct());
    assert(any(furinaMacro.Provides == "DamageBonus") && any(escoffierMacro.Provides == "CryoSupport") ...
        && any(citlaliMacro.Provides == "CryoSupport"), ...
        'Freeze support macros should declare the setup effects they provide to Skirk.');

    enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0, ...
        'ReactionMode', "Realistic", 'AutoSupportAura', false);
    members = {getDefaultCharacterConfig('Skirk'), getDefaultCharacterConfig('Escoffier'), ...
        getDefaultCharacterConfig('Furina'), getDefaultCharacterConfig('Citlali')};
    spec = struct('Members', {members}, 'CycleDuration', 20, 'SimulationHorizon', 120, ...
        'SharedBuffs', struct(), 'PlanOptions', struct('DisableAutoPlan', true));
    result = simulateTeamDPS(spec, enemy);
    assert(result.RotationDuration == 20 && result.SimulationHorizon == 120, ...
        'Team entry should keep the combat cycle separate from the report horizon.');

    disp('validateTeamMacroPlanningRegression passed');
end
