function [totalDMG, dps, breakdown, rotationTime] = simulateGorouDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Gorou simulator for skill field and burst crystal collapse.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Gorou', 'rotation_Gorou.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Gorou', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    talentPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Gorou', 'talents_Gorou.csv');
    talent = readtable(talentPath);
    skillLevel = talentLevel + 3 * double(constellation >= 3);
    burstLevel = talentLevel + 3 * double(constellation >= 5);
    defBoost = getTalentValue(talent, 'Skill', 'DEFIncrease', skillLevel) / 1000;
    geoBonus = getTalentValue(talent, 'Skill', 'GeoDMGBonus', skillLevel);

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Geo", 'ActionScalingMode', "DEF", 'BaseMultiplier', 1.00, 'Note', "Inuzaka All-Round Defense");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Geo", 'ActionScalingMode', "DEF", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 9.0, 'Note', "Juuga: Forward Unto Victory");
    actions.Collapse = struct('TalentGroup', "Burst", 'Param', "CrystalCollapseDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Geo", 'ActionScalingMode', "DEF", 'BaseMultiplier', 1.00, 'HitCount', 3 + double(constellation >= 2), 'Note', "Crystal collapse");

    build.DEFBonus = getFieldOrDefault(build, 'DEFBonus', 0) + defBoost;
    build.GeoDMGBonus = getFieldOrDefault(build, 'GeoDMGBonus', 0) + geoBonus;

    spec = struct( ...
        'Element', "Geo", ...
        'ScalingMode', "DEF", ...
        'DefaultActionTime', 0.70, ...
        'DefaultRotation', {{'E', 'Q', 'Collapse'}}, ...
        'ActionTimeMap', struct('E', 0.75, 'Q', 1.00, 'Collapse', 0.55), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Gorou', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
