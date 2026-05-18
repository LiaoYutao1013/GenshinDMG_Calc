function [totalDMG, dps, breakdown, rotationTime] = simulateShikanoinHeizouDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Heizou simulator with declension stacks, swirl-fed setup, and burst iris follow-up.
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
    skillBase = getTalentValue(talent, 'Skill', 'SkillDMG', skillLevel);
    declensionBonus = getTalentValue(talent, 'Skill', 'DeclensionDMGBonus', skillLevel);
    convictionBonus = getTalentValue(talent, 'Skill', 'ConvictionDMGBonus', skillLevel);
    allowSwirl = double(localResolveSwirlElement(teamContext, enemy) ~= "");
    c1OpeningStack = double(constellation >= 1);
    c6PerStackCritRate = 0.04 * double(constellation >= 6);
    c6ConvictionCritDMG = 0.32 * double(constellation >= 6);
    declensionRatio = 0;
    convictionRatio = 0;
    if skillBase > 0
        declensionRatio = declensionBonus / skillBase;
        convictionRatio = convictionBonus / skillBase;
    end

    actions = struct();
    actions.N1 = struct('TalentGroup', "Normal", 'Param', "x1HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'SkillWindowDamageBonus', 0.00, 'Note', "Normal 1");
    actions.N2 = struct('TalentGroup', "Normal", 'Param', "x2HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'SkillWindowDamageBonus', 0.00, 'Note', "Normal 2");
    actions.N3 = struct('TalentGroup', "Normal", 'Param', "x3HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'SkillWindowDamageBonus', 0.00, 'Note', "Normal 3");
    actions.N4 = struct('TalentGroup', "Normal", 'Param', "x4HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'SkillWindowDamageBonus', 0.00, 'Note', "Normal 4");
    actions.N5 = struct('TalentGroup', "Normal", 'Param', "x5HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'SkillWindowDamageBonus', 0.00, 'Note', "Normal 5");
    actions.CA = struct('TalentGroup', "Normal", 'Param', "ChargedAttack", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'Note', "Charged attack");
    actions.Swirl1 = struct('TalentGroup', "Skill", 'Param', "DeclensionDMGBonus", 'MVOverride', 0, ...
        'DamageField', "SkillDMGBonus", 'ActionElement', "Anemo", 'AllowTransformative', allowSwirl, ...
        'ReactionElement', "Anemo", 'ReactionBaseDamage', 723.0, 'PostAddStacks', 1, 'PostMaxStacks', 4, ...
        'Note', "On-field swirl 1");
    actions.Swirl2 = struct('TalentGroup', "Skill", 'Param', "DeclensionDMGBonus", 'MVOverride', 0, ...
        'DamageField', "SkillDMGBonus", 'ActionElement', "Anemo", 'AllowTransformative', allowSwirl, ...
        'ReactionElement', "Anemo", 'ReactionBaseDamage', 723.0, 'PostAddStacks', 1, 'PostMaxStacks', 4, ...
        'Note', "On-field swirl 2");
    actions.Swirl3 = struct('TalentGroup', "Skill", 'Param', "DeclensionDMGBonus", 'MVOverride', 0, ...
        'DamageField', "SkillDMGBonus", 'ActionElement', "Anemo", 'AllowTransformative', allowSwirl, ...
        'ReactionElement', "Anemo", 'ReactionBaseDamage', 723.0, 'PostAddStacks', 1, 'PostMaxStacks', 4, ...
        'Note', "On-field swirl 3");
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'PreSetStacks', 0, ...
        'CritRateBonus', c1OpeningStack * 0.00, 'Note', "Heartstopper Strike tap");
    actions.EHold = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'PerStackMultiplier', declensionRatio, ...
        'PerStackCritRateBonus', 0, 'Note', "Heartstopper Strike hold");
    actions.EFull = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00 + convictionRatio, ...
        'PerStackMultiplier', declensionRatio, ...
        'PerStackDamageBonus', 0, 'CritRateBonus', 4 * c6PerStackCritRate, 'CritDMGBonus', c6ConvictionCritDMG, ...
        'PostSetStacks', 0, 'Note', "Heartstopper Strike full declension");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "FudouStyleVacuumSluggerDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'Note', "Vacuum Slugger");
    actions.Iris = struct('TalentGroup', "Burst", 'Param', "WindmusterIrisDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', localResolveBurstInfusedElement(teamContext, enemy), 'BaseMultiplier', localResolveIrisHitCount(teamContext, enemy) > 0, ...
        'HitCount', localResolveIrisHitCount(teamContext, enemy), 'AllowAmplify', localResolveIrisCanAmplify(teamContext, enemy), ...
        'PreferredAmplifyAura', localResolveIrisPreferredAura(teamContext, enemy), 'Note', "Windmuster Iris");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.55, ...
        'DefaultRotation', {{'Swirl1', 'Swirl2', 'Swirl3', 'EFull', 'Q', 'Iris'}}, ...
        'ActionTimeMap', struct( ...
            'N1', 0.28, 'N2', 0.26, 'N3', 0.30, 'N4', 0.32, 'N5', 0.42, ...
            'CA', 0.65, 'Swirl1', 0.10, 'Swirl2', 0.10, 'Swirl3', 0.10, ...
            'E', 0.55, 'EHold', 0.78, 'EFull', 0.82, 'Q', 1.00, 'Iris', 0.30), ...
        'Actions', localFinalizeHeizouActions(actions, constellation));

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'ShikanoinHeizou', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

function actions = localFinalizeHeizouActions(actions, constellation)
    if constellation >= 1
        actions.EFull.CritRateBonus = getFieldOrDefault(actions.EFull, 'CritRateBonus', 0) + 0.04;
        actions.E.CritRateBonus = 0.04;
    end
end

function hitCount = localResolveIrisHitCount(teamContext, enemy)
    element = localResolveBurstInfusedElement(teamContext, enemy);
    hitCount = 4 * double(strlength(element) > 0);
end

function element = localResolveBurstInfusedElement(teamContext, enemy)
    if nargin >= 2 && isstruct(enemy)
        initialAura = string(getFieldOrDefault(enemy, 'InitialAuraElement', ""));
        if any(strcmpi(initialAura, ["Pyro", "Hydro", "Electro", "Cryo"]))
            element = initialAura;
            return;
        end
    end
    priority = ["Pyro", "Hydro", "Electro", "Cryo"];
    for i = 1:numel(priority)
        if getFieldOrDefault(teamContext, char(priority(i) + "Count"), 0) >= 1
            element = priority(i);
            return;
        end
    end
    element = "";
end

function tf = localResolveIrisCanAmplify(teamContext, enemy)
    element = localResolveBurstInfusedElement(teamContext, enemy);
    switch lower(char(element))
        case 'pyro'
            tf = double(getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1 || getFieldOrDefault(teamContext, 'CryoCount', 0) >= 1);
        case 'hydro'
            tf = double(getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1);
        case 'cryo'
            tf = double(getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1);
        otherwise
            tf = 0;
    end
end

function aura = localResolveIrisPreferredAura(teamContext, enemy)
    element = localResolveBurstInfusedElement(teamContext, enemy);
    switch lower(char(element))
        case 'pyro'
            if getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1
                aura = "Hydro";
            elseif getFieldOrDefault(teamContext, 'CryoCount', 0) >= 1
                aura = "Cryo";
            else
                aura = "";
            end
        case 'hydro'
            aura = "Pyro";
        case 'cryo'
            aura = "Pyro";
        otherwise
            aura = "";
    end
end

function element = localResolveSwirlElement(teamContext, enemy)
    element = localResolveBurstInfusedElement(teamContext, enemy);
end
