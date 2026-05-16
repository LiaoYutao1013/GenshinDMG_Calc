function [totalDMG, dps, breakdown, rotationTime] = simulateIllugaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Illuga simulator using EM-scaled geo press/hold skill and burst.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Illuga', 'rotation_Illuga.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Illuga', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    actions = struct();
    actions.Press = struct('TalentGroup', "Skill", 'Param', "PressDMG", 'DamageField', "SkillDMGBonus", ...
        'BaseMultiplier', 1.00, 'ActionScalingMode', "EM", 'Note', "Press skill");
    actions.Hold = struct('TalentGroup', "Skill", 'Param', "HoldDMG", 'DamageField', "SkillDMGBonus", ...
        'BaseMultiplier', 1.00, 'ActionScalingMode', "EM", 'Note', "Hold skill");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'BaseMultiplier', 1.00, 'ActionScalingMode', "EM", 'PostSetBurstActiveTime', 20.0, 'Note', "Burst");

    spec = struct( ...
        'Element', "Geo", ...
        'ScalingMode', "EM", ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {{'Press', 'Q', 'Hold'}}, ...
        'ActionTimeMap', struct('Press', 0.55, 'Hold', 0.85, 'Q', 1.00), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Illuga', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
