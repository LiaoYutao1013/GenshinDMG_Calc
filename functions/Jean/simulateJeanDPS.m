function [totalDMG, dps, breakdown, rotationTime] = simulateJeanDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 琴高精度近似模拟。
    % 建模要点：
    % 1. 区分点按 E、长按 E，以及 Q 落地伤和风场进出伤；
    % 2. Q 的治疗不计入 DPS，但伤害段完整保留；
    % 3. C1/C4 通过 E 长按增伤、Q 场内减风抗直接作用到对应动作；
    % 4. 默认按速切辅助轴建模，保留一定普攻补刀片段。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Jean', 'rotation_Jean.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Jean', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    c1HoldBonus = 0.40 * double(constellation >= 1);
    qFieldAnemoResShred = 0.40 * double(constellation >= 4);

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'Note', "Gale Blade tap");
    actions.EHold = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'SkillWindowMultiplier', c1HoldBonus, ...
        'PostSetSkillActiveTime', 1.0, 'Note', "Gale Blade hold");
    actions.QCast = struct('TalentGroup', "Burst", 'Param', "BurstDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 10.0, 'Note', "Dandelion Breeze cast");
    actions.QField = struct('TalentGroup', "Burst", 'Param', "FieldEnteringExitingDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'HitCount', 2, 'BurstWindowExtraResShred', qFieldAnemoResShred, ...
        'Note', "Field entry and exit");
    actions.N1 = struct('TalentGroup', "Normal", 'Param', "x1HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Physical", 'BaseMultiplier', 1.00, 'Note', "Normal 1");
    actions.N2 = struct('TalentGroup', "Normal", 'Param', "x2HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Physical", 'BaseMultiplier', 1.00, 'Note', "Normal 2");
    actions.N3 = struct('TalentGroup', "Normal", 'Param', "x3HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Physical", 'BaseMultiplier', 1.00, 'Note', "Normal 3");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.75, ...
        'DefaultRotation', {{'E', 'QCast', 'QField', 'N1', 'N2', 'N3'}}, ...
        'ActionTimeMap', struct('E', 0.70, 'EHold', 1.20, 'QCast', 1.20, 'QField', 0.10, 'N1', 0.40, 'N2', 0.45, 'N3', 0.55), ...
        'Actions', actions);

    if constellation >= 1
        spec.DefaultRotation = {{'EHold', 'QCast', 'QField', 'N1', 'N2', 'N3'}};
    end

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Jean', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
