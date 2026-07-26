function validateEffectiveArtifactSubstatsRegression()
% Verify that the single effective-substat input drives final panel stats.
    initProjectPaths();

    cfg = getDefaultCharacterConfig('Skirk');
    highRollBuild = initializeEffectiveArtifactBuild('Skirk', cfg.Build, 30);
    lowRollBuild = initializeEffectiveArtifactBuild('Skirk', cfg.Build, 10);
    highPanel = getCharacterFinalPanel('Skirk', highRollBuild, struct());
    lowPanel = getCharacterFinalPanel('Skirk', lowRollBuild, struct());

    assert(highRollBuild.ArtifactEffectiveSubstatCount == 30);
    assert(lowRollBuild.ArtifactEffectiveSubstatCount == 10);
    assert(contains(string(highRollBuild.ArtifactEffectiveSubstatProfile), "ATK Crit"));
    assert(highPanel.ATK > lowPanel.ATK);
    assert(highPanel.CritDMG > lowPanel.CritDMG);

    furina = getDefaultCharacterConfig('Furina');
    furinaBuild = initializeEffectiveArtifactBuild('Furina', furina.Build, 30);
    assert(contains(string(furinaBuild.ArtifactEffectiveSubstatProfile), "HP Crit"));
    assert(contains(string(furinaBuild.ArtifactEffectiveSubstatAllocation), "HPBonus"));

    compiled = compileArtifactSetBonuses('Skirk', highRollBuild, struct());
    assert(abs(compiled.CritDMG - highPanel.Build.CritDMG) < 1e-9);
    fprintf('Effective artifact substat regression passed.\n');
end
