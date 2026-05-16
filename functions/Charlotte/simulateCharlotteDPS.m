function [totalDMG, dps, breakdown, rotationTime] = simulateCharlotteDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Charlotte simulator focusing on held skill mark damage and burst camera pulses.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Charlotte', 'rotation_Charlotte.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Charlotte', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    workBuild = build;
    if constellation >= 2
        workBuild.AtkBonus = getFieldOrDefault(workBuild, 'AtkBonus', 0) + 0.30;
    end

    actions = struct();
    actions.EHold = struct('TalentGroup', "Skill", 'Param', "PhotoDMGHold", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'Note', "Held framing shot");
    actions.Mark = struct('TalentGroup', "Skill", 'Param', "xFocusedImpressionMarkDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'Note', "Focused Impression");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 4.0, 'Note', "Still Photo");
    actions.Kamera = struct('TalentGroup', "Burst", 'Param', "KameraDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'Note', "Newsflash camera pulse");
    actions.C6Assist = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'MVOverride', 1.80, ...
        'DamageField', "BurstDMGBonus", 'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'Note', "C6 coordinated report");

    defaultRotation = {'EHold', 'Mark', 'Mark', 'Mark', 'Mark', 'Q', 'Kamera', 'Kamera', 'Kamera', 'Kamera'};
    if constellation >= 6
        defaultRotation = {'EHold', 'Mark', 'Mark', 'Mark', 'Mark', 'Q', 'Kamera', 'Kamera', 'C6Assist', 'Kamera', 'Kamera', 'C6Assist'};
    end

    spec = struct( ...
        'Element', "Cryo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.90, ...
        'DefaultRotation', {defaultRotation}, ...
        'ActionTimeMap', struct('EHold', 0.95, 'Mark', 1.20, 'Q', 1.05, 'Kamera', 0.85, 'C6Assist', 0.10), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Charlotte', workBuild, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
