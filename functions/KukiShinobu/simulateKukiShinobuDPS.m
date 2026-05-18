function [totalDMG, dps, breakdown, rotationTime] = simulateKukiShinobuDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Shinobu simulator for ring ticks and burst pulses.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'KukiShinobu', 'rotation_KukiShinobu.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'KukiShinobu', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    talentPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'KukiShinobu', 'talents_KukiShinobu.csv');
    talent = readtable(talentPath);
    skillLevel = talentLevel + 3 * double(constellation >= 3);
    burstLevel = talentLevel + 3 * double(constellation >= 5);
    hpWeightRing = 0.25 / max(getTalentValue(talent, 'Skill', 'GrassRingOfSanctificationDMG', skillLevel), 1e-6);
    hpWeightBurst = 0.18 / max(getTalentValue(talent, 'Burst', 'SingleInstanceDMG', burstLevel), 1e-6);
    aggravateReady = getFieldOrDefault(teamContext, 'DendroCount', 0) >= 1;

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", 'BaseMultiplier', 1.00, 'AllowCatalyze', double(aggravateReady), 'PostSetSkillActiveTime', 12.0, 'Note', "Sanctifying Ring setup");
    actions.Ring = struct('TalentGroup', "Skill", 'Param', "GrassRingOfSanctificationDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Electro", 'BaseMultiplier', 1.00, 'HPWeight', hpWeightRing, ...
        'HitCount', 6 + double(constellation >= 2), 'AllowCatalyze', double(aggravateReady), 'Note', "Sanctifying ring");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SingleInstanceDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Electro", 'BaseMultiplier', 1.00, 'HPWeight', hpWeightBurst, ...
        'HitCount', 8 + 2 * double(constellation >= 2), 'AllowCatalyze', double(aggravateReady), 'Note', "Gyoei Narukami Kariyama Rite");

    spec = struct( ...
        'Element', "Electro", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.70, ...
        'DefaultRotation', {{'E', 'Ring', 'Q'}}, ...
        'ActionTimeMap', struct('E', 0.70, 'Ring', 12.00, 'Q', 2.10), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'KukiShinobu', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
