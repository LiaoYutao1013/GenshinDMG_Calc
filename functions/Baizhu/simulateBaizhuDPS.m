function [totalDMG, dps, breakdown, rotationTime] = simulateBaizhuDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Baizhu simulator for skill poke plus repeated Spiritvein damage during burst uptime.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Baizhu', 'rotation_Baizhu.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Baizhu', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    talentPath = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Baizhu', 'talents_Baizhu.csv');
    talent = readtable(talentPath);
    burstLevel = talentLevel + 3 * double(constellation >= 5);
    spiritMV = getTalentValue(talent, 'Burst', 'SpiritveinDMG', burstLevel);
    spiritHPWeight = 0;
    if constellation >= 6 && spiritMV > 0
        spiritHPWeight = 0.08 / spiritMV;
    end

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Dendro", 'BaseMultiplier', 1.00, 'Note', "Universal Diagnosis");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SpiritveinDMG", 'MVOverride', 0, ...
        'DamageField', "BurstDMGBonus", 'PostSetBurstActiveTime', 14.0, 'Note', "Holistic Revivification");
    actions.Spirit = struct('TalentGroup', "Burst", 'Param', "SpiritveinDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Dendro", 'BaseMultiplier', 1.00, 'HPWeight', spiritHPWeight, 'HitCount', 6, 'Note', "Spiritvein");
    actions.Splice = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'MVOverride', 2.50, ...
        'DamageField', "SkillDMGBonus", 'ActionElement', "Dendro", 'HitCount', 3, 'Note', "C2 Gossamer Sprite: Splice");

    defaultRotation = {'E', 'Q', 'Spirit'};
    if constellation >= 2
        defaultRotation = {'E', 'Q', 'Spirit', 'Splice'};
    end

    spec = struct( ...
        'Element', "Dendro", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.90, ...
        'DefaultRotation', {defaultRotation}, ...
        'ActionTimeMap', struct('E', 0.70, 'Q', 0.90, 'Spirit', 12.00, 'Splice', 10.00), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Baizhu', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
