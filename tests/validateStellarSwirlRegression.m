function validateStellarSwirlRegression()
    initProjectPaths();
    enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
    odette = getDefaultCharacterConfig('Odette');
    sandrone = getDefaultCharacterConfig('Sandrone');
    venti = getDefaultCharacterConfig('Venti');
    context = buildTeamContext({odette, sandrone, venti}, 20, struct());
    assert(context.StellarSwirlEnabled, 'Odette, Sandrone, and Anemo must enable Stellar Swirl.');

    state = createEnemyState(enemy, context, "Cryo");
    state.Auras = struct('Element', "Cryo", 'Gauge', 1.0, 'AppliedTime', 0, 'AppliedSequence', 1);
    hit = struct('HitElement', "Anemo", 'ApplyElement', "Anemo", 'ApplyGauge', 1.0, ...
        'AllowTransformative', true, 'ReactionElement', "Cryo");
    result = resolveReactionForHit(state, hit, struct('EM', 0), context, enemy);
    assert(result.PrimaryReaction == "StellarSwirl", 'Cryo Swirl must convert to Stellar Swirl in the enabled team.');
    assert(result.ReactionDamage > 0, 'Stellar Swirl must retain transformative damage.');

    furnaceBuild = odette.Build;
    furnaceBuild.ArtifactSet1 = 'Heart of the Furnace';
    furnaceBuild.ArtifactSet1Pieces = 4;
    furnaceBuild.ArtifactAssumeStellarGlimmerActive = true;
    furnaceBuffs = getArtifactTeamBuffs('Odette', furnaceBuild);
    assert(abs(furnaceBuffs.StellarGlimmerBonus - 0.50) < 1e-9, ...
        'Heart of the Furnace must expose its triggered team Stellar Glimmer bonus.');
end
