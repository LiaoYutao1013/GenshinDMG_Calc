function validateOdetteAlyoshaRegression()
    initProjectPaths();
    enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

    odette = getDefaultCharacterConfig('Odette');
    [odetteDMG, ~, odetteBreakdown, odetteTime] = simulateOdetteDPS( ...
        odette.Build, enemy, odette.RotationFile, 10, 1, []);
    assert(odetteDMG > 0 && odetteTime > 0, 'Odette baseline simulation must produce damage and time.');
    assert(any(string(odetteBreakdown.Action) == "Dot"), 'Odette AUTO rotation must include the dance DoT.');

    sandrone = getDefaultCharacterConfig('Sandrone');
    electro = getDefaultCharacterConfig('Alyosha');
    context = buildTeamContext({odette, sandrone, electro}, 20, struct());
    [~, ~, stellarBreakdown] = simulateOdetteDPS(odette.Build, enemy, odette.RotationFile, 10, 1, context);
    assert(any(contains(string(stellarBreakdown.Action), "Stellar")), ...
        'Odette must expose Stellar-Conduct damage while the team enables it.');

    [alyoshaDMG, ~, alyoshaBreakdown, alyoshaTime] = simulateAlyoshaDPS( ...
        electro.Build, enemy, electro.RotationFile, 10, 0, []);
    assert(alyoshaDMG > 0 && alyoshaTime >= 14, 'Alyosha must retain the full Hunting Field duration.');
    assert(any(string(alyoshaBreakdown.Action) == "Tugarin"), 'Alyosha AUTO rotation must include Tugarin attacks.');
end
