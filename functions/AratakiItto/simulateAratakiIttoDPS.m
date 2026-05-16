function [totalDMG, dps, breakdown, rotationTime] = simulateAratakiIttoDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Itto simulator for Superlative Superstrength string and burst slashes.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'AratakiItto', 'rotation_AratakiItto.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'AratakiItto', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    talentPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'AratakiItto', 'talents_AratakiItto.csv');
    talent = readtable(talentPath);
    burstLevel = talentLevel + 3 * double(constellation >= 5);
    burstAtkBonus = getTalentValue(talent, 'Burst', 'ATKBonus', burstLevel);
    chargedBoost = getTalentValue(talent, 'Normal', 'AratakiKesagiriComboSlashDMG', talentLevel);
    finisherBoost = getTalentValue(talent, 'Normal', 'AratakiKesagiriFinalSlashDMG', talentLevel);

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Geo", 'ActionScalingMode', "DEF", 'BaseMultiplier', 1.00, 'PostSetStacks', 5, 'Note', "Ushi");
    actions.Combo = struct('TalentGroup', "Normal", 'Param', "AratakiKesagiriComboSlashDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Geo", 'ActionScalingMode', "DEF", 'BaseMultiplier', 1.00, 'HitCount', 4, ...
        'FlatDamageBonus', burstAtkBonus, 'Note', "Kesagiri combo");
    actions.Final = struct('TalentGroup', "Normal", 'Param', "AratakiKesagiriFinalSlashDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Geo", 'ActionScalingMode', "DEF", 'BaseMultiplier', 1.00, 'FlatDamageBonus', finisherBoost, 'Note', "Kesagiri final");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "ATKBonus", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Geo", 'ActionScalingMode', "DEF", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 11.0, 'Note', "Raging Oni King");
    actions.Slash = struct('TalentGroup', "Normal", 'Param', "SaichimonjiSlashDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Geo", 'ActionScalingMode', "DEF", 'BaseMultiplier', 1.00, 'HitCount', 4 + double(constellation >= 6), 'Note', "Saichimonji slash");

    build.DEFBonus = getFieldOrDefault(build, 'DEFBonus', 0) + 0.25;
    build.GeoDMGBonus = getFieldOrDefault(build, 'GeoDMGBonus', 0) + 0.20;

    spec = struct( ...
        'Element', "Geo", ...
        'ScalingMode', "DEF", ...
        'DefaultActionTime', 0.70, ...
        'DefaultRotation', {{'E', 'Q', 'Combo', 'Final', 'Slash'}}, ...
        'ActionTimeMap', struct('E', 0.75, 'Combo', 0.25, 'Final', 0.35, 'Q', 1.05, 'Slash', 0.55), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'AratakiItto', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
