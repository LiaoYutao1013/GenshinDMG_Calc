function [totalDMG, dps, breakdown, rotationTime] = simulateShikanoinHeizouDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Heizou simulator for declension-stacked skill and burst iris hits.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'ShikanoinHeizou', 'rotation_ShikanoinHeizou.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'ShikanoinHeizou', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    talentPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'ShikanoinHeizou', 'talents_ShikanoinHeizou.csv');
    talent = readtable(talentPath);
    skillLevel = talentLevel + 3 * double(constellation >= 3);
    declensionBonus = getTalentValue(talent, 'Skill', 'DeclensionDMGBonus', skillLevel);
    convictionBonus = getTalentValue(talent, 'Skill', 'ConvictionDMGBonus', skillLevel);

    actions = struct();
    actions.NA = struct('TalentGroup', "Normal", 'Param', "x5HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 0.20, 'HitCount', 5, 'Note', "Normal string");
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00 + 4 * declensionBonus + convictionBonus, 'Note', "Heartstopper Strike");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "FudouStyleVacuumSluggerDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'Note', "Vacuum Slugger");
    actions.Iris = struct('TalentGroup', "Burst", 'Param', "WindmusterIrisDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'HitCount', 4, 'Note', "Windmuster Iris");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.60, ...
        'DefaultRotation', {{'NA', 'E', 'Q', 'Iris'}}, ...
        'ActionTimeMap', struct('NA', 1.05, 'E', 0.80, 'Q', 1.00, 'Iris', 0.20), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'ShikanoinHeizou', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
