function [totalDMG, dps, breakdown, rotationTime] = simulateFaruzanDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Faruzan simulator focusing on skill shot, collapse vortex, and burst nuke.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Faruzan', 'rotation_Faruzan.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Faruzan', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    actions = struct();
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 12.0, 'Note', "The Wind's Secret Ways");
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'Note', "Wind Realm of Nasamjnin");
    actions.Collapse = struct('TalentGroup', "Skill", 'Param', "PressurizedCollapseVortexDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'Note', "Pressurized Collapse");
    actions.C6Collapse = struct('TalentGroup', "Skill", 'Param', "PressurizedCollapseVortexDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'HitCount', 2, ...
        'CritDMGBonus', 0.40 * double(constellation >= 6), 'PostSetSkillActiveTime', 18.0, 'Note', "C6 collapse procs");

    defaultRotation = {'Q', 'E', 'Collapse'};
    if constellation >= 6
        defaultRotation = {'Q', 'E', 'Collapse', 'C6Collapse'};
    end

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {defaultRotation}, ...
        'ActionTimeMap', struct('Q', 1.00, 'E', 0.75, 'Collapse', 0.85, 'C6Collapse', 2.60), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Faruzan', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
