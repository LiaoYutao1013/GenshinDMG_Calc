function [totalDMG, dps, breakdown, rotationTime, audit] = simulateOroronDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Ororon simulator emphasizing Night's Sling bounces and burst pulses.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Ororon', 'rotation_Ororon.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Ororon', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SpiritOrbDMG", 'DamageField', "SkillDMGBonus", ...
        'BaseMultiplier', 1.00, 'Note', "Night's Sling");
    actions.Bounce = struct('TalentGroup', "Skill", 'Param', "SpiritOrbDMG", 'DamageField', "SkillDMGBonus", ...
        'BaseMultiplier', 1.00, 'HitCount', 3, 'C1DamageBonus', 0.10, 'Note', "Spirit Orb bounces");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "RitualDMG", 'DamageField', "BurstDMGBonus", ...
        'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 9.0, 'Note', "Dark Voices Echo");
    actions.Wave = struct('TalentGroup', "Burst", 'Param', "SoundwaveCollisionDMG", 'DamageField', "BurstDMGBonus", ...
        'BaseMultiplier', 1.00, 'HitCount', 3, 'AllowCatalyze', 1, 'Note', "Burst pulse");

    spec = struct( ...
        'Element', "Electro", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.8, ...
        'DefaultRotation', {{'E', 'Bounce', 'Q', 'Wave', 'Wave', 'Wave', 'Wave', 'Wave'}}, ...
        'ActionTimeMap', struct('E', 0.60, 'Bounce', 1.10, 'Q', 0.95, 'Wave', 1.50), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS( ...
        'Ororon', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

