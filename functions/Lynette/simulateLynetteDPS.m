function [totalDMG, dps, breakdown, rotationTime, audit] = simulateLynetteDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Lynette simulator covering quickswap skill, Ousia blade, and burst box plus converted shots.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Lynette', 'rotation_Lynette.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Lynette', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    convertedElement = localResolveLynetteAbsorbElement(teamContext);
    convertedMultiplier = double(convertedElement ~= "Anemo");
    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "EnigmaThrustDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'Note', "Enigma Thrust");
    actions.Blade = struct('TalentGroup', "Skill", 'Param', "SurgingBladeDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'Note', "Surging Blade");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'PostSetBurstActiveTime', 12.0, 'Note', "Magic Trick");
    actions.Box = struct('TalentGroup', "Burst", 'Param', "BogglecatBoxDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'HitCount', 3, 'Note', "Bogglecat box");
    actions.Vivid = struct('TalentGroup', "Burst", 'Param', "VividShotDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', convertedElement, 'BaseMultiplier', convertedMultiplier, 'HitCount', 3 + double(constellation >= 2), 'Note', "Infused vivid shot");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.75, ...
        'DefaultRotation', {{'E', 'Blade', 'Q', 'Box', 'Vivid'}}, ...
        'ActionTimeMap', struct('E', 0.75, 'Blade', 0.15, 'Q', 1.00, 'Box', 4.50, 'Vivid', 4.50), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS( ...
        'Lynette', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

function element = localResolveLynetteAbsorbElement(teamContext)
    priority = ["Pyro", "Hydro", "Electro", "Cryo"];
    for i = 1:numel(priority)
        fieldName = char(priority(i) + "Count");
        if getFieldOrDefault(teamContext, fieldName, 0) > 0
            element = priority(i);
            return;
        end
    end
    element = "Anemo";
end

