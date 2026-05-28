function [totalDMG, dps, breakdown, rotationTime, audit] = simulateKaeyaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Kaeya explicit Frostgnaw / Glacial Waltz script.
    % E, Q, and the grounded string are modeled as separate actions with
    % explicit C1 cryo-aura crit gating and C6 burst tick handling.
    % Remaining approximation: the script still does not fabricate C2 kill
    % extensions without explicit enemy-defeat data.
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Kaeya', 'rotation_Kaeya.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Kaeya', 'Constellation', constellation, 'Build', build)}, 20, struct());
    end

    burstTicks = 8 + double(constellation >= 6);
    cryoAuraBonus = 0.15 * double(constellation >= 1);
    meltReady = getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1;

    actions = struct();
    actions.E = struct('TalentGroup', "Skill", 'Param', "SkillDMG", 'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'AllowAmplify', double(meltReady), ...
        'LunarisAttackName', "Avatar_Keaya_IceShield_Impact", 'LunarisDamageParam', "damage", 'Note', "Frostgnaw");
    actions.Q = struct('TalentGroup', "Burst", 'Param', "SkillDMG", 'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Cryo", 'BaseMultiplier', 1.00, 'HitCount', burstTicks, 'AllowAmplify', double(meltReady), ...
        'PostSetBurstActiveTime', 8.0, 'LunarisAttackName', "Avatar_Keaya_FrozenTrap", 'LunarisDamageParam', "Damage", 'Note', "Glacial Waltz");
    actions.N1 = struct('TalentGroup', "Normal", 'Param', "x1HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Physical", 'BaseMultiplier', 1.00, 'CritRateBonus', cryoAuraBonus, 'Note', "Normal 1");
    actions.N2 = struct('TalentGroup', "Normal", 'Param', "x2HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Physical", 'BaseMultiplier', 1.00, 'CritRateBonus', cryoAuraBonus, 'Note', "Normal 2");
    actions.N3 = struct('TalentGroup', "Normal", 'Param', "x3HitDMG", 'DamageField', "NormalDMGBonus", ...
        'ActionElement', "Physical", 'BaseMultiplier', 1.00, 'CritRateBonus', cryoAuraBonus, 'Note', "Normal 3");
    actions.CA = struct('TalentGroup', "Normal", 'Param', "ChargedAttackDMG", 'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Physical", 'BaseMultiplier', 1.00, 'HitCount', 2, 'CritRateBonus', cryoAuraBonus, ...
        'ApplyGauge', 0, 'CanApplyAura', false, 'StrikeType', "Slash", 'Note', "Charged attack");

    spec = struct( ...
        'Element', "Cryo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.70, ...
        'BeforeActionFn', @localBeforeAction, ...
        'DefaultRotation', {{'E', 'Q', 'N1', 'N2', 'N3', 'CA'}}, ...
        'ActionTimeMap', struct('E', 0.60, 'Q', 1.00, 'N1', 0.35, 'N2', 0.40, 'N3', 0.48, 'CA', 0.72), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS( ...
        'Kaeya', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

function [state, actionSpec, actionTime, note] = localBeforeAction( ...
        state, actionKey, actionSpec, actionTime, note, hookContext) %#ok<INUSD>
    if ~any(actionKey == ["N1", "N2", "N3", "CA"])
        return;
    end

    enemyState = getFieldOrDefault(hookContext, 'EnemyState', struct());
    if localHasCryoOrFrozen(enemyState)
        note = localAppendNote(note, "C1 cryo crit");
    else
        actionSpec.CritRateBonus = max(0, getFieldOrDefault(actionSpec, 'CritRateBonus', 0) - 0.15);
    end
end

function tf = localHasCryoOrFrozen(enemyState)
    tf = false;
    if getFieldOrDefault(getFieldOrDefault(enemyState, 'Frozen', struct()), 'Active', false)
        tf = true;
        return;
    end
    if ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    for i = 1:numel(enemyState.Auras)
        if strcmpi(char(enemyState.Auras(i).Element), 'Cryo') ...
                && getFieldOrDefault(enemyState.Auras(i), 'Gauge', 0) > 1e-6
            tf = true;
            return;
        end
    end
end

function note = localAppendNote(baseNote, suffix)
    if strlength(string(baseNote)) == 0
        note = string(suffix);
    else
        note = string(baseNote) + ", " + string(suffix);
    end
end
