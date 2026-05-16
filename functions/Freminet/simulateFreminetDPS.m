function [totalDMG, dps, breakdown, rotationTime] = simulateFreminetDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Freminet simulator emphasizing Level 4 Shattering Pressure and burst-enhanced frost pressure generation.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Freminet', 'rotation_Freminet.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Freminet', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    workBuild = build;
    if constellation >= 6 && (getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1 || getFieldOrDefault(teamContext, 'ElectroCount', 0) >= 1)
        workBuild.CritDMG = getFieldOrDefault(workBuild, 'CritDMG', 0) + 0.36;
    end

    shatterBonus = 0.40 * double(getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1);
    speedFactor = 1 / (1 + getFieldOrDefault(teamContext, 'MikaATKSpeedBonus', 0));
    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "UpwardThrustDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'Note', "Pressurized Floe");
    actions.Frost = struct('TalentGroup', "Skill", 'Param', "FrostDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'Note', "Pers frost wave");
    actions.BFrost = struct('TalentGroup', "Skill", 'Param', "FrostDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 2.00, 'Note', "Burst-enhanced frost wave");
    actions.P4 = struct('TalentGroup', "Skill", 'Param', "Level4ShatteringPressureDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Physical", 'BaseMultiplier', 1.00, 'FlatDamageBonus', shatterBonus, ...
        'CritRateBonus', 0.15 * double(constellation >= 1), 'Note', "Level 4 Shattering Pressure");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 10.0, 'Note', "Shadowhunter's Ambush");
    actions.Thorn = struct('TalentGroup', "Skill", 'Param', "SpiritbreathThornDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'Note', "Spiritbreath Thorn");

    spec = struct( ...
        'Element', "Cryo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.80, ...
        'DefaultRotation', {{'E', 'Frost', 'Frost', 'Frost', 'P4', 'Q', 'E', 'BFrost', 'BFrost', 'P4', 'Thorn'}}, ...
        'ActionTimeMap', struct('E', 0.70, 'Frost', 0.45 * speedFactor, 'BFrost', 0.40 * speedFactor, 'P4', 0.85, 'Q', 1.00, 'Thorn', 0.10), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Freminet', workBuild, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
