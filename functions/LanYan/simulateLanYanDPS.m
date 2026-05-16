function [totalDMG, dps, breakdown, rotationTime] = simulateLanYanDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Lan Yan simulator using imported catalyst normals, charged attack and skill/burst damage.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'LanYan', 'rotation_LanYan.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'LanYan', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    actions = struct();
    actions.N1 = struct('TalentGroup', "Normal", 'Param', "x1HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 1");
    actions.N2 = struct('TalentGroup', "Normal", 'Param', "x2HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 2");
    actions.N3 = struct('TalentGroup', "Normal", 'Param', "x3HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 3");
    actions.N4 = struct('TalentGroup', "Normal", 'Param', "x4HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 4");
    actions.Charged = struct('TalentGroup', "Normal", 'Param', "ChargedAttackDMG", 'DamageField', "ChargedDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Charged");
    actions.E = struct('TalentGroup', "Skill", 'Param', "FeathermoonRingDMG", 'DamageField', "SkillDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Feathermoon Ring");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Burst");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.8, ...
        'DefaultRotation', {{'E', 'Q', 'N1', 'N2', 'N3', 'N4', 'Charged'}}, ...
        'ActionTimeMap', struct('N1', 0.34, 'N2', 0.34, 'N3', 0.38, 'N4', 0.48, 'Charged', 0.65, 'E', 0.55, 'Q', 1.00), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'LanYan', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
