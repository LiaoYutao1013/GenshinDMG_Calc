function [totalDMG, dps, breakdown, rotationTime, audit] = simulateVentiDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Venti explicit tap / hold E and burst script with approximation.
    % Tap and hold skill damage, burst DoT, and absorbed-element follow-up
    % are modeled as separate actions with constellation bonuses applied.
    % Remaining approximation: approximate mode still falls back to team
    % priority Pyro > Hydro > Electro > Cryo when no explicit aura exists.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Venti', 'rotation_Venti.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Venti', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    absorbedElement = localResolveAbsorbedElement(teamContext, enemy);
    absorbedMultiplier = double(strlength(absorbedElement) > 0);
    c2AnemoResShred = 0.24 * double(constellation >= 2);
    c4AnemoBonus = 0.25 * double(constellation >= 4);
    c6CritDamageBonus = 1.00 * double(constellation >= 6);
    absorbedResShred = 0.20 * double(constellation >= 6);

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "PressDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'BaseActionDamageBonus', c4AnemoBonus, ...
        'ExtraResShred', c2AnemoResShred, 'C6CritDMGBonus', c6CritDamageBonus, ...
        'LunarisAttackName', "WindBlade_FX", 'LunarisDamageParam', "WindBladeDamage", 'Note', "Skyward Sonnet tap");
    actions.EHold = struct('TalentGroup', "Skill", 'Param', "HoldDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'BaseActionDamageBonus', c4AnemoBonus, ...
        'ExtraResShred', c2AnemoResShred, 'C6CritDMGBonus', c6CritDamageBonus, ...
        'LunarisAttackName', "WindBlade_FX_Land", 'LunarisDamageParam', "WindBladeDamage_Land", 'Note', "Skyward Sonnet hold");
    actions.QDot = struct('TalentGroup', "Burst", 'Param', "DoT", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", 'BaseMultiplier', 1.00, 'HitCount', 20, 'BaseActionDamageBonus', c4AnemoBonus, ...
        'ExtraResShred', 0.20 * double(constellation >= 6), 'C6CritDMGBonus', c6CritDamageBonus, ...
        'LunarisAttackName', "Hurricane_FX", 'LunarisDamageParam', "Elemental_Burst_Damage", 'Note', "Wind''s Grand Ode");
    actions.QInfuse = struct('TalentGroup', "Burst", 'Param', "AdditionalElementalDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', absorbedElement, 'BaseMultiplier', absorbedMultiplier, 'HitCount', 16, ...
        'AllowAmplify', absorbedMultiplier, 'ExtraResShred', absorbedResShred, ...
        'LunarisAttackName', "Hurricane_Mix", 'LunarisDamageParam', "Hurricane_Mix_Damage", 'Note', "Absorbed element");

    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.85, ...
        'DefaultRotation', {{'EHold', 'QDot', 'QInfuse', 'E'}}, ...
        'ActionTimeMap', struct('E', 0.70, 'EHold', 1.05, 'QDot', 8.00, 'QInfuse', 0.10), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS( ...
        'Venti', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

function element = localResolveAbsorbedElement(teamContext, enemy)
    enemyState = getFieldOrDefault(teamContext, 'EnemyState', []);
    if ~localShouldIgnoreApproximateEnemyState(enemyState, enemy)
        element = localResolveAuraPriorityElement(enemyState);
        if strlength(element) > 0
            return;
        end
    end

    if nargin >= 2 && isstruct(enemy)
        initialAura = string(getFieldOrDefault(enemy, 'InitialAuraElement', ""));
        if any(strcmpi(initialAura, ["Pyro", "Hydro", "Electro", "Cryo"]))
            element = initialAura;
            return;
        end
    end

    if ~localUsesApproximateAbsorptionFallback(teamContext, enemy)
        element = "";
        return;
    end

    priority = ["Pyro", "Hydro", "Electro", "Cryo"];
    for i = 1:numel(priority)
        fieldName = char(priority(i) + "Count");
        if getFieldOrDefault(teamContext, fieldName, 0) > 0
            element = priority(i);
            return;
        end
    end
    element = "";
end

function tf = localUsesApproximateAbsorptionFallback(teamContext, enemy)
    reactionMode = string(getFieldOrDefault(teamContext, 'ReactionMode', ""));
    if nargin >= 2 && isstruct(enemy)
        enemyMode = string(getFieldOrDefault(enemy, 'ReactionMode', ""));
        if strlength(enemyMode) > 0
            reactionMode = enemyMode;
        end
    end
    tf = strcmpi(char(reactionMode), 'Approximate');
end

function tf = localShouldIgnoreApproximateEnemyState(enemyState, enemy)
    reactionMode = string(getFieldOrDefault(enemyState, 'ReactionMode', ""));
    autoSupport = logical(getFieldOrDefault(enemyState, 'AutoSupportAura', false));
    hasExplicitInitialAura = false;
    if nargin >= 2 && isstruct(enemy)
        hasExplicitInitialAura = strlength(string(getFieldOrDefault(enemy, 'InitialAuraElement', ""))) > 0 ...
            && getFieldOrDefault(enemy, 'InitialAuraGauge', 0) > 0;
    end
    tf = autoSupport && strcmpi(char(reactionMode), 'Approximate') && ~hasExplicitInitialAura;
end

function element = localResolveAuraPriorityElement(enemyState)
    element = "";
    if isempty(enemyState) || ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    priority = ["Pyro", "Hydro", "Electro", "Cryo"];
    for i = 1:numel(priority)
        if localHasAura(enemyState, priority(i))
            element = priority(i);
            return;
        end
    end
end

function tf = localHasAura(enemyState, auraElement)
    tf = false;
    if ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    for i = 1:numel(enemyState.Auras)
        if strcmpi(char(enemyState.Auras(i).Element), char(string(auraElement))) ...
                && getFieldOrDefault(enemyState.Auras(i), 'Gauge', 0) > 1e-6
            tf = true;
            return;
        end
    end
end
