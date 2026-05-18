function [totalDMG, dps, breakdown, rotationTime] = simulateAmberDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 安柏高精度近似模拟。
    % 建模要点：
    % 1. 重击按满蓄力火箭处理，C1 追加副箭期望伤害；
    % 2. 兔兔伯爵区分正常爆炸与 C2 手动点爆强化；
    % 3. Q 拆为连续火雨段并写入天赋暴击率加成；
    % 4. 默认按速切挂火/手动点兔轴建模。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Amber', 'rotation_Amber.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Amber', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    weakpointAtkBonus = 0.15;
    fieryRainCritBonus = 0.10;
    qWaveCount = 18;
    allowAmplify = double(getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1 || getFieldOrDefault(teamContext, 'CryoCount', 0) >= 1);

    actions = struct();
    actions.Aimed = struct('TalentGroup', "Normal", 'Param', "FullyChargedAimedShot", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'BaseActionDamageBonus', weakpointAtkBonus, ...
        'AllowAmplify', allowAmplify, 'Note', "Charged shot");
    actions.AimedC1 = struct('TalentGroup', "Normal", 'Param', "FullyChargedAimedShot", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 0.20 * double(constellation >= 1), 'BaseActionDamageBonus', weakpointAtkBonus, ...
        'AllowAmplify', allowAmplify, ...
        'Note', "C1 extra arrow");
    actions.E = struct('TalentGroup', "Skill", 'Param', "ExplosionDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'AllowAmplify', allowAmplify, 'Note', "Baron Bunny explosion");
    actions.EManual = struct('TalentGroup', "Skill", 'Param', "ExplosionDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00 + 2.00 * double(constellation >= 2), ...
        'AllowAmplify', allowAmplify, 'Note', "C2 manual detonation");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "FieryRainDMGPerWave", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'HitCount', qWaveCount, 'CritRateBonus', fieryRainCritBonus, ...
        'AllowAmplify', allowAmplify, 'Note', "Fiery Rain waves");

    spec = struct( ...
        'Element', "Pyro", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {{'Aimed', 'E', 'Q'}}, ...
        'ActionTimeMap', struct('Aimed', 1.00, 'AimedC1', 0.05, 'E', 0.75, 'EManual', 0.30, 'Q', 2.00), ...
        'Actions', actions);

    if constellation >= 1
        spec.DefaultRotation = {{'Aimed', 'AimedC1', 'E', 'Q'}};
    end
    if constellation >= 2
        spec.DefaultRotation = {{'Aimed', 'AimedC1', 'EManual', 'Q'}};
    end

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Amber', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
