function [totalDMG, dps, breakdown, rotationTime] = simulateJahodaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Jahoda simulator using smoke bomb, flask follow-up and robot burst assistance.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Jahoda', 'rotation_Jahoda.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Jahoda', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    actions = struct();
    actions.N1 = struct('TalentGroup', "Normal", 'Param', "x1HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 1");
    actions.N2 = struct('TalentGroup', "Normal", 'Param', "x2HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 2");
    actions.N3 = struct('TalentGroup', "Normal", 'Param', "x3HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 3");
    actions.Aimed = struct('TalentGroup', "Normal", 'Param', "FullyChargedAimedShot", 'DamageField', "ChargedDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Fully charged shot");
    actions.E = struct('TalentGroup', "Skill", 'Param', "SmokeBombDMG", 'DamageField', "SkillDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Smoke bomb");
    actions.Flask = struct('TalentGroup', "Skill", 'Param', "FilledTreasureFlaskDMG", 'DamageField', "SkillDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Filled flask");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 12.0, 'Note', "Burst");
    actions.Robot = struct('TalentGroup', "Burst", 'Param', "PurrsonalCoordinatedAssistanceRobotDMG", 'DamageField', "BurstDMGBonus", 'BaseMultiplier', 1.00, 'HitCount', 3, 'Note', "Robot assistance");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.75, ...
        'DefaultRotation', {{'E', 'Flask', 'Q', 'Robot', 'Robot', 'N1', 'N2', 'N3'}}, ...
        'ActionTimeMap', struct('N1', 0.35, 'N2', 0.32, 'N3', 0.40, 'Aimed', 0.65, 'E', 0.55, 'Flask', 0.75, 'Q', 1.05, 'Robot', 2.40), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Jahoda', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
