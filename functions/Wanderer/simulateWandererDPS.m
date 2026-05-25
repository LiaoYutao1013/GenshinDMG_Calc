function [totalDMG, dps, breakdown, rotationTime, audit] = simulateWandererDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Wanderer simulator for Windfavored normals, descent arrows, and burst nuke.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Wanderer', 'rotation_Wanderer.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Wanderer', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    talentPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Wanderer', 'talents_Wanderer.csv');
    talent = readtable(talentPath);
    skillLevel = talentLevel + 3 * double(constellation >= 3);
    windFavoredPoints = getTalentValue(talent, 'Skill', 'InitialKuugoryokuPoints', skillLevel);
    speedFactor = 1 - 0.10 * double(constellation >= 1);
    build.AtkBonus = getFieldOrDefault(build, 'AtkBonus', 0) + 0.30 * double(getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1);
    build.CritRate = getFieldOrDefault(build, 'CritRate', 0) + 0.20 * double(getFieldOrDefault(teamContext, 'CryoCount', 0) >= 1);
    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'PostSetSkillActiveTime', 10.0, ...
        'PostSetAuxCounter', windFavoredPoints, 'LunarisAttackName', "ElementalArt_Launch", 'LunarisDamageParam', "ElementalArt_Damage", 'Note', "Windfavored entry");
    % Windfavored normal multipliers are stored in the Skill talent group.
    actions.N1 = struct('TalentGroup', "Skill", 'Param', "KuugoFushoudanDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'SkillWindowMultiplier', 0.15, ...
        'LunarisAttackName', "ElementalArt_Bullet_1", 'LunarisDamageParam', "NormalAttack_01_Damage|NormalAttack_ElementalArt_Ratio|MUL", 'Note', "Kuugo: Fushoudan");
    actions.CA = struct('TalentGroup', "Skill", 'Param', "KuugoToufukaiDMG", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'SkillWindowMultiplier', 0.12, ...
        'ApplyGauge', 0, 'CanApplyAura', false, 'Note', "Kuugo: Toufukai");
    actions.Descent = struct('TalentGroup', "Normal", 'Param', "x1HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 0.40, 'HitCount', 4, 'C1DamageBonus', 0.25, ...
        'LunarisAttackName', "ElementalArt_Bullet_HoverDash", 'LunarisDamageParam', "PermanentSkill_2_Damage|Constellation_1_ExtraDamagePercentage|ADD", 'Note', "Descent effect arrows");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'HitCount', 1 + double(constellation >= 6), ...
        'CritDMGBonus', 0.70 * double(constellation >= 6), 'PostSetBurstActiveTime', 1.0, ...
        'LunarisAttackName', "ElementalBurst_Bullet", 'LunarisDamageParam', "ElementalBurst_Damage", 'Note', "Kyougen: Five Ceremonial Plays");

    defaultRotation = {'E', 'N1', 'N1', 'CA', 'Descent', 'N1', 'N1', 'CA', 'Descent', 'Q'};
    if getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1
        defaultRotation = {'E', 'N1', 'N1', 'CA', 'Descent', 'N1', 'N1', 'CA', 'Descent', 'N1', 'CA', 'Q'};
    end
    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.45, ...
        'DefaultRotation', {defaultRotation}, ...
        'ActionTimeMap', struct('E', 0.75, 'N1', 0.30 * speedFactor, 'CA', 0.35 * speedFactor, 'Descent', 0.60, 'Q', 1.05), ...
        'Actions', actions);

    build.NormalDMGBonus = getFieldOrDefault(build, 'NormalDMGBonus', 0) + 0.30;
    build.ChargedDMGBonus = getFieldOrDefault(build, 'ChargedDMGBonus', 0) + 0.30;

    [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS( ...
        'Wanderer', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

