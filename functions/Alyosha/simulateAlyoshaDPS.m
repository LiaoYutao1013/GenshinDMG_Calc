function [totalDMG, dps, breakdown, rotationTime, audit] = simulateAlyoshaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Alyosha: Hunter's Mark enables Hunter's Precision for field attacks.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Alyosha', 'rotation_Alyosha.txt');
    end
    if nargin < 4 || isempty(talentLevel), talentLevel = 10; end
    if nargin < 5 || isempty(constellation), constellation = 0; end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Alyosha', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end
    skillLevel = talentLevel + 3 * double(constellation >= 3);
    burstLevel = talentLevel + 3 * double(constellation >= 5);
    talent = readtable(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Alyosha', 'talents_Alyosha.csv'));
    hunterATKBonus = getTalentValue(talent, 'Skill', 'HuntersPrecisionATKBonus', skillLevel);
    erBonus = min(0.70, 0.0035 * 100 * max(0, getFieldOrDefault(build, 'ER', 1) - 1));

    actions = struct();
    actions.E = localElectroAction('Skill', skillLevel, 'PressDMG', 'SkillDMGBonus', 1, 'Thunderbolt Strike');
    actions.E.PostSetStacks = 1;
    actions.Hold = localElectroAction('Skill', skillLevel, 'HoldDMG', 'SkillDMGBonus', 1, 'Charged Thunderbolt Strike');
    actions.Hold.PostSetStacks = 1;
    actions.Q = struct('TalentGroup', "Burst", 'TalentLevelOverride', burstLevel, 'Param', "Duration", 'MVOverride', 0, ...
        'DamageField', "BurstDMGBonus", 'ActionElement', "Electro", 'PostSetBurstActiveTime', 14 + 6 * double(constellation >= 2), ...
        'ApplyGauge', 0, 'CanApplyAura', false, 'CanTriggerReaction', false, 'Note', "Hunter's Advance");
    actions.Field = localElectroAction('Burst', burstLevel, 'FulguriteHuntingFieldDMG', 'BurstDMGBonus', 7, 'Fulgurite Hunting Field');
    actions.Field.HitTimeline = 2 * ones(1, 7);
    actions.Field.PerStackATKBonus = hunterATKBonus;
    actions.Field.BaseActionDamageBonus = erBonus;
    actions.Tugarin = localElectroAction('Burst', burstLevel, 'TugarinDMG', 'BurstDMGBonus', 7, 'Tugarin coordinated attack');
    actions.Tugarin.HitTimeline = 2 * ones(1, 7);
    actions.Tugarin.PerStackATKBonus = hunterATKBonus;
    actions.Tugarin.BaseActionDamageBonus = erBonus;
    actions.Tugarin.ActionTimeOverride = 0.01;
    spec = struct('Element', "Electro", 'ScalingMode', "ATK", 'DefaultActionTime', 0.60, ...
        'DefaultRotation', {{'E', 'Q', 'Field', 'Tugarin'}}, ...
        'ActionTimeMap', struct('E', 0.70, 'Hold', 0.95, 'Q', 0.85, 'Field', 14, 'Tugarin', 0.01), 'Actions', actions);
    [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS('Alyosha', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

function action = localElectroAction(group, level, param, field, hitCount, note)
    action = struct('TalentGroup', group, 'TalentLevelOverride', level, 'Param', param, 'DamageField', field, ...
        'ActionElement', "Electro", 'BaseMultiplier', 1, 'HitCount', hitCount, 'ApplyGauge', 1, ...
        'AllowCatalyze', 1, 'Note', note);
end
