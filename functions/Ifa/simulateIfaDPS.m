function [totalDMG, dps, breakdown, rotationTime] = simulateIfaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Ifa simulator using imported catalyst normals, tonic shot and burst mark damage.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Ifa', 'rotation_Ifa.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Ifa', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    actions = struct();
    actions.N1 = struct('TalentGroup', "Normal", 'Param', "x1HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 1");
    actions.N2 = struct('TalentGroup', "Normal", 'Param', "x2HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 2");
    actions.N3 = struct('TalentGroup', "Normal", 'Param', "x3HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 3");
    actions.N4 = struct('TalentGroup', "Normal", 'Param', "x4HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 4");
    actions.E = struct('TalentGroup', "Skill", 'Param', "TonicshotDMG", 'DamageField', "SkillDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Tonicshot");
    actions.Mark = struct('TalentGroup', "Burst", 'Param', "SedationMarkDMG", 'DamageField', "BurstDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Sedation mark");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 15.0, 'Note', "Compound Sedation Field");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.8, ...
        'DefaultRotation', {{'Q', 'E', 'Mark', 'N1', 'N2', 'N3', 'N4', 'E', 'Mark'}}, ...
        'ActionTimeMap', struct('N1', 0.35, 'N2', 0.35, 'N3', 0.42, 'N4', 0.50, 'E', 0.55, 'Mark', 1.60, 'Q', 0.95), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Ifa', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
