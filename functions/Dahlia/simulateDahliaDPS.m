function [totalDMG, dps, breakdown, rotationTime] = simulateDahliaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Dahlia simulator using direct ATK-scaled hydro damage and burst shield window.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Dahlia', 'rotation_Dahlia.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Dahlia', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    actions = struct();
    actions.N1 = struct('TalentGroup', "Normal", 'Param', "x1HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 1");
    actions.N2 = struct('TalentGroup', "Normal", 'Param', "x2HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 2");
    actions.N3 = struct('TalentGroup', "Normal", 'Param', "x3HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 3");
    actions.N4 = struct('TalentGroup', "Normal", 'Param', "x4HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Normal 4");
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Radiant Psalm");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 12.0, 'Note', "Sacred Favor");

    spec = struct( ...
        'Element', "Hydro", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {{'E', 'Q', 'N1', 'N2', 'N3', 'N4'}}, ...
        'ActionTimeMap', struct('N1', 0.35, 'N2', 0.35, 'N3', 0.42, 'N4', 0.50, 'E', 0.60, 'Q', 1.00), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Dahlia', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
