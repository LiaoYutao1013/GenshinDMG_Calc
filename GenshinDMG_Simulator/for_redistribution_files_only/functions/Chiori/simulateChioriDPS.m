function [totalDMG, dps, breakdown, rotationTime] = simulateChioriDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Chiori simulator emphasizing Tamoto uptime and burst slash.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Chiori', 'rotation_Chiori.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Chiori', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "UpwardSweepAttackDMG", 'DamageField', "SkillDMGBonus", ...
        'BaseMultiplier', 1.00, 'PostSetSkillActiveTime', 17.0, 'C1DamageBonus', 0.10, 'Note', "Fluttering Hasode");
    actions.Doll = struct('TalentGroup', "Skill", 'Param', "TamotoDMG", 'DamageField', "SkillDMGBonus", ...
        'BaseMultiplier', 1.00, 'SkillWindowMultiplier', 0.08, 'C2DamageBonus', 0.12, 'Note', "Tamoto slash");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'BaseMultiplier', 1.00, 'C6CritDMGBonus', 0.30, 'Note', "Twin Blades");

    spec = struct( ...
        'Element', "Geo", ...
        'ScalingMode', "DEF", ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {{'E', 'Doll', 'Doll', 'Doll', 'Doll', 'Q'}}, ...
        'ActionTimeMap', struct('E', 0.55, 'Doll', 3.20, 'Q', 1.10), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Chiori', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end
