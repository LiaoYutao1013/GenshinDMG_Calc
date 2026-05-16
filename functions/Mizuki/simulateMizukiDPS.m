function [totalDMG, dps, breakdown, rotationTime] = simulateMizukiDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Mizuki simulator emphasizing Dreamdrifter anemo ticks and EM-based swirl support.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Mizuki', 'rotation_Mizuki.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Mizuki', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    skillLevel = talentLevel + 3 * double(constellation >= 3);
    burstLevel = talentLevel + 3 * double(constellation >= 5);
    swirlBase = 723.0;

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'BaseMultiplier', 1.00, 'PostSetSkillActiveTime', 5.0, 'Note', "Dreamdrifter entry");
    actions.Drift = struct('TalentGroup', "Skill", 'Param', "ContinuousAttackDMG", 'DamageField', "SkillDMGBonus", ...
        'BaseMultiplier', 1.00, 'SkillWindowMultiplier', 0.08, 'Note', "Dreamdrifter tick");
    actions.Swirl = struct('TalentGroup', "Skill", 'Param', "ElementalMasteryBasedSwirlDMGIncrease", 'DamageField', "SkillDMGBonus", ...
        'MVOverride', 0, 'AllowTransformative', 1, 'ReactionElement', "Anemo", ...
        'ReactionBaseDamage', swirlBase, 'ReactionEMWeight', 0, ...
        'FlatMVBonus', 0, 'Note', "Dreamdrifter swirl");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 12.0, 'Note', "Burst cast");
    actions.Shockwave = struct('TalentGroup', "Burst", 'Param', "MunenShockwaveDMG", 'DamageField', "BurstDMGBonus", ...
        'BaseMultiplier', 1.00, 'HitCount', 4, 'Note', "Snack shockwave");
    actions.C1Swirl = struct('TalentGroup', "Skill", 'Param', "ElementalMasteryBasedSwirlDMGIncrease", 'DamageField', "SkillDMGBonus", ...
        'MVOverride', 0, 'AllowTransformative', 1, 'ReactionElement', "Anemo", ...
        'ReactionBaseDamage', 0, 'ReactionEMWeight', 11.0, 'Note', "C1 empowered swirl");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {{'Q', 'Shockwave', 'Shockwave', 'E', 'Drift', 'Swirl', 'Drift', 'Swirl', 'Drift', 'Swirl', 'Drift', 'Swirl', 'C1Swirl'}}, ...
        'ActionTimeMap', struct('E', 0.75, 'Drift', 1.00, 'Swirl', 1.00, 'Q', 1.05, 'Shockwave', 2.20, 'C1Swirl', 0.10), ...
        'Actions', actions);

    if constellation < 1
        spec.DefaultRotation = {{'Q', 'Shockwave', 'Shockwave', 'E', 'Drift', 'Swirl', 'Drift', 'Swirl', 'Drift', 'Swirl', 'Drift', 'Swirl'}};
    end
    if constellation >= 6
        actions.Swirl.ReactionCritRate = 0.30;
        actions.Swirl.ReactionCritDMG = 1.00;
        actions.C1Swirl.ReactionCritRate = 0.30;
        actions.C1Swirl.ReactionCritDMG = 1.00;
        spec.Actions = actions;
    end
    if constellation >= 2
        c2Bonus = 0.04 * max(0, getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0));
        actions.E.C2DamageBonus = c2Bonus;
        actions.Drift.C2DamageBonus = c2Bonus;
        actions.Q.C2DamageBonus = c2Bonus;
        actions.Shockwave.C2DamageBonus = c2Bonus;
        spec.Actions = actions;
    end
    if constellation >= 4
        actions.Shockwave.C4DamageBonus = 0.10;
        spec.Actions = actions;
    end

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Mizuki', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
