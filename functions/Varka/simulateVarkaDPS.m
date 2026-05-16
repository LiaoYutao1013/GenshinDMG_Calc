function [totalDMG, dps, breakdown, rotationTime] = simulateVarkaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Varka simulator emphasizing Sturm und Drang stance strings.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Varka', 'rotation_Varka.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Varka', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", 'BaseMultiplier', 1.00, 'PostSetSkillActiveTime', 12.0, 'Note', "Skill");
    actions.S1 = struct('TalentGroup', "Skill", 'Param', "SturmUndDrang1HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'SkillWindowMultiplier', 0.08, 'Note', "Stance 1");
    actions.S2 = struct('TalentGroup', "Skill", 'Param', "SturmUndDrang2HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'SkillWindowMultiplier', 0.08, 'Note', "Stance 2");
    actions.S3 = struct('TalentGroup', "Skill", 'Param', "SturmUndDrang3HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'SkillWindowMultiplier', 0.08, 'Note', "Stance 3");
    actions.S4 = struct('TalentGroup', "Skill", 'Param', "SturmUndDrang4HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'SkillWindowMultiplier', 0.08, 'Note', "Stance 4");
    actions.S5 = struct('TalentGroup', "Skill", 'Param', "SturmUndDrang5HitDMG", 'DamageField', "NormalDMGBonus", 'BaseMultiplier', 1.00, 'SkillWindowMultiplier', 0.08, 'Note', "Stance 5");
    actions.Ascend = struct('TalentGroup', "Skill", 'Param', "FourWindsAscensionDMG", 'DamageField', "SkillDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Four Winds Ascension");
    actions.Devour = struct('TalentGroup', "Skill", 'Param', "AzureDevourDMG", 'DamageField', "SkillDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Azure Devour");
    actions.Q1 = struct('TalentGroup', "Burst", 'Param', "Skill1HitDMG", 'DamageField', "BurstDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Burst hit 1");
    actions.Q2 = struct('TalentGroup', "Burst", 'Param', "Skill2HitDMG", 'DamageField', "BurstDMGBonus", 'BaseMultiplier', 1.00, 'Note', "Burst hit 2");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {{'E', 'S1', 'S2', 'S3', 'S4', 'S5', 'Ascend', 'Devour', 'Q1', 'Q2'}}, ...
        'ActionTimeMap', struct('E', 0.55, 'S1', 0.30, 'S2', 0.32, 'S3', 0.40, 'S4', 0.42, 'S5', 0.55, 'Ascend', 0.85, 'Devour', 0.60, 'Q1', 0.70, 'Q2', 0.55), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Varka', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
