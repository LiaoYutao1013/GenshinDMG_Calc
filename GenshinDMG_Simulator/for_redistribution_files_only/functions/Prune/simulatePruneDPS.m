function [totalDMG, dps, breakdown, rotationTime] = simulatePruneDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Prune simulator modeling swirl-enabled hammer conversion and burst hunter-seeker follow-up.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Prune', 'rotation_Prune.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Prune', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    convertedElement = localResolvePruneConvertedElement(teamContext);
    burstAtkBonus = 0.10 * double(constellation >= 2);

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "RingADingDingHexhunterChimeDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'PostSetSkillActiveTime', 6.0, 'Note', "Hexhunter Chime");
    actions.Swirl = struct('TalentGroup', "Skill", 'Param', "RingADingDingHexhunterChimeDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'MVOverride', 0, 'AllowTransformative', 1, 'ReactionElement', "Anemo", ...
        'ReactionBaseDamage', 723.0, 'Note', "Skill swirl trigger");
    actions.Hammer = struct('TalentGroup', "Skill", 'Param', "ClangClangWitchtributionComesDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', convertedElement, 'BaseMultiplier', 1.00 + burstAtkBonus, 'C4FlatMVBonus', 0.80, 'Note', "Converted oathhammer");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00 + burstAtkBonus, 'PostSetBurstActiveTime', 12.0 + 4.0 * double(constellation >= 6), ...
        'Note', "Burst cast");
    actions.Bell = struct('TalentGroup', "Burst", 'Param', "WitchlureBellDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00 + burstAtkBonus, 'HitCount', 4, 'Note', "Hunter-seeker bell");
    actions.PassiveHammer = struct('TalentGroup', "Burst", 'Param', "WitchlureBellDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', convertedElement, 'MVOverride', 1.50, 'BaseMultiplier', 1.00 + burstAtkBonus, 'Note', "Passive converted hammer");
    actions.C4Bounce = struct('TalentGroup', "Burst", 'Param', "WitchlureBellDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', convertedElement, 'MVOverride', 0.80, 'Note', "C4 ricochet");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {{'E', 'Swirl', 'Hammer', 'Q', 'Bell', 'PassiveHammer', 'Bell', 'PassiveHammer', 'Bell', 'PassiveHammer'}}, ...
        'ActionTimeMap', struct('E', 0.70, 'Swirl', 0.10, 'Hammer', 0.90, 'Q', 1.05, 'Bell', 2.20, 'PassiveHammer', 0.10, 'C4Bounce', 0.10), ...
        'Actions', actions);

    if constellation >= 4
        spec.DefaultRotation = {{'E', 'Swirl', 'Hammer', 'C4Bounce', 'Q', 'Bell', 'PassiveHammer', 'C4Bounce', 'Bell', 'PassiveHammer', 'C4Bounce', 'Bell', 'PassiveHammer', 'C4Bounce'}};
    end

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Prune', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

function element = localResolvePruneConvertedElement(teamContext)
    priority = ["Pyro", "Hydro", "Cryo", "Electro"];
    for i = 1:numel(priority)
        fieldName = char(priority(i) + "Count");
        if getFieldOrDefault(teamContext, fieldName, 0) > 0
            element = priority(i);
            return;
        end
    end
    element = "Anemo";
end
