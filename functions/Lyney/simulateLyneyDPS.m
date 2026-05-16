function [totalDMG, dps, breakdown, rotationTime] = simulateLyneyDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Lyney simulator focusing on Prop Arrow strings, Grin-Malkin detonations, and stack-consuming skill.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Lyney', 'rotation_Lyney.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Lyney', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    talentPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Lyney', 'talents_Lyney.csv');
    talent = readtable(talentPath);
    skillLevel = talentLevel + 3 * double(constellation >= 3);
    skillBase = getTalentValue(talent, 'Skill', 'SkillDMG', skillLevel);
    perStackMV = getTalentValue(talent, 'Skill', 'SkillDMGBonus', skillLevel);
    perStackMultiplier = 0;
    if skillBase > 0
        perStackMultiplier = perStackMV / skillBase;
    end

    workBuild = build;
    workBuild.CritDMG = getFieldOrDefault(workBuild, 'CritDMG', 0) + 0.60 * double(constellation >= 2);
    workBuild.PyroDMGBonus = getFieldOrDefault(workBuild, 'PyroDMGBonus', 0) ...
        + 0.60 + 0.20 * min(3, max(0, getFieldOrDefault(teamContext, 'PyroCount', 0) - 1));

    actions = struct();
    actions.Aimed1 = struct('TalentGroup', "Normal", 'Param', "PropArrowDMG", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'PostAddMarks', 1, 'C1AddMarks', 1, 'Note', "Prop Arrow");
    actions.Aimed2 = struct('TalentGroup', "Normal", 'Param', "PropArrowDMG", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'PostAddMarks', 1, 'Note', "Prop Arrow");
    actions.Aimed3 = struct('TalentGroup', "Normal", 'Param', "PropArrowDMG", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'PostAddMarks', 1, 'Note', "Prop Arrow");
    actions.Strike = struct('TalentGroup', "Normal", 'Param', "PyrotechnicStrikeDMG", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'Note', "Pyrotechnic Strike");
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'PerMarkMultiplier', perStackMultiplier, ...
        'PostSetMarks', 0, 'Note', "Bewildering Lights");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'Note', "Miracle Parade");
    actions.Firework = struct('TalentGroup', "Burst", 'Param', "ExplosiveFireworkDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 1.00, 'Note', "Explosive firework");
    actions.Reprised = struct('TalentGroup', "Normal", 'Param', "PyrotechnicStrikeDMG", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Pyro", 'BaseMultiplier', 0.80, 'HitCount', 3, 'Note', "C6 Reprised strikes");

    defaultRotation = {'Aimed1', 'Strike', 'Aimed2', 'Strike', 'Aimed3', 'Strike', 'E', 'Q', 'Firework'};
    if constellation >= 6
        defaultRotation = {'Aimed1', 'Strike', 'Aimed2', 'Strike', 'Aimed3', 'Strike', 'Reprised', 'E', 'Q', 'Firework'};
    end

    spec = struct( ...
        'Element', "Pyro", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {defaultRotation}, ...
        'ActionTimeMap', struct('Aimed1', 1.05, 'Aimed2', 1.05, 'Aimed3', 1.05, 'Strike', 0.45, 'E', 0.80, 'Q', 1.05, 'Firework', 0.50, 'Reprised', 0.10), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Lyney', workBuild, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
