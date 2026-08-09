function validateMizukiStellarSwirlRegression()
    initProjectPaths();
    enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
    mizuki = getDefaultCharacterConfig('Mizuki', struct('Constellation', 1));
    odette = getDefaultCharacterConfig('Odette');
    sandrone = getDefaultCharacterConfig('Sandrone');
    context = buildTeamContext({mizuki, odette, sandrone}, 20, struct());
    assert(context.StellarSwirlEnabled, 'Mizuki must receive the enabled Stellar Swirl team context.');

    [damage, ~, breakdown] = simulateMizukiDPS( ...
        mizuki.Build, enemy, mizuki.RotationFile, mizuki.TalentLevel, mizuki.Constellation, context);
    assert(damage > 0, 'Mizuki Stellar Swirl simulation must produce damage.');
    assert(any(string(breakdown.Action) == "C1Swirl"), 'Mizuki C1 rotation must include forced Stellar Swirl procs.');
end
