function [totalDMG, dps, breakdown, rotationTime] = simulateYunJinDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Yun Jin simulator for held counters and burst cast damage.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'YunJin', 'rotation_YunJin.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'YunJin', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    actions = struct();
    actions.EPress = struct('TalentGroup', "Skill", 'Param', "PressDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Geo", 'ActionScalingMode', "DEF", 'BaseMultiplier', 1.00, 'Note', "Opening Flourish press");
    actions.EHold = struct('TalentGroup', "Skill", 'Param', "ChargeLevel2DMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Geo", 'ActionScalingMode', "DEF", 'BaseMultiplier', 1.00, 'Note', "Opening Flourish hold");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Geo", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 12.0, 'Note', "Cliffbreaker Banner");

    spec = struct( ...
        'Element', "Geo", ...
        'ScalingMode', "DEF", ...
        'DefaultActionTime', 0.80, ...
        'DefaultRotation', {{'EHold', 'Q'}}, ...
        'ActionTimeMap', struct('EPress', 0.55, 'EHold', 0.85, 'Q', 1.00), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'YunJin', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
