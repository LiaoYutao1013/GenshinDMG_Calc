function [totalDMG, dps, breakdown, rotationTime] = simulateHutaoDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Hu Tao simulator focusing on Paramita Papilio charged attacks, Blood Blossom ticks, and low-HP burst.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Hutao', 'rotation_Hutao.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Hutao', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    dataFolder = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Hutao');
    base = readtable(fullfile(dataFolder, 'characters_Hutao.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Hutao.csv'));
    skillLevel = talentLevel + 3 * double(constellation >= 3);

    maxHP = base.BaseHP(1) * (1 + getFieldOrDefault(build, 'HPBonus', 0)) + getFieldOrDefault(build, 'FlatHP', 0);
    baseATK = base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0);
    hpToATK = getTalentValue(talent, 'Skill', 'ATKIncrease', skillLevel);
    bonusATK = min(4.0 * baseATK, maxHP * hpToATK);

    workBuild = build;
    workBuild.FlatATK = getFieldOrDefault(workBuild, 'FlatATK', 0) + bonusATK;
    workBuild.PyroDMGBonus = getFieldOrDefault(workBuild, 'PyroDMGBonus', 0) + 0.33;

    bloodMV = getTalentValue(talent, 'Skill', 'BloodBlossomDMG', skillLevel);
    bloodHpWeight = 0;
    if constellation >= 2 && bloodMV > 0
        bloodHpWeight = 0.10 / bloodMV;
    end

    allowVape = getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1;
    preferredAura = "";
    if allowVape
        preferredAura = "Hydro";
    end

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "ATKIncrease", 'MVOverride', 0, ...
        'DamageField', "SkillDMGBonus", 'PostSetSkillActiveTime', 9.0, 'ApplyGauge', 0, 'CanApplyAura', false, 'Note', "Guide to Afterlife");
    actions.N1 = struct('TalentGroup', "Normal", 'Param', "x1HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'AllowAmplify', double(allowVape), 'LunarisAttackName', "Attack01", 'Note', "Paramita normal 1");
    actions.CA = struct('TalentGroup', "Normal", 'Param', "ChargedAttack", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'AllowAmplify', double(allowVape), 'LunarisAttackName', "ChargedAttack", 'Note', "Paramita charged attack");
    actions.Blossom = struct('TalentGroup', "Skill", 'Param', "BloodBlossomDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'HPWeight', bloodHpWeight, ...
        'AllowAmplify', double(allowVape), 'LunarisDamageParam', "BloodBlossomDMG", 'Note', "Blood Blossom tick");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "LowHPSkillDMG", 'ActionScalingMode', "HP", ...
        'DamageField', "BurstDMGBonus", 'ActionElement', "Pyro", 'BaseMultiplier', 1.00, ...
        'AllowAmplify', double(allowVape), 'LunarisDamageParam', "LowHPSkillDMG", 'Note', "Spirit Soother");

    defaultRotation = {'E', 'N1', 'CA', 'N1', 'CA', 'N1', 'CA', 'N1', 'CA', 'N1', 'CA', 'Blossom', 'Blossom', 'Q'};
    if constellation >= 1
        defaultRotation = {'E', 'N1', 'CA', 'N1', 'CA', 'N1', 'CA', 'N1', 'CA', 'N1', 'CA', 'N1', 'CA', 'Blossom', 'Blossom', 'Q'};
    end

    spec = struct( ...
        'Element', "Pyro", ...
        'ScalingMode', "ATK", ...
        'PreferredAmplifyAura', preferredAura, ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {defaultRotation}, ...
        'ActionTimeMap', struct('E', 0.65, 'N1', 0.28, 'CA', 0.75, 'Blossom', 0.10, 'Q', 1.05), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Hutao', workBuild, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
