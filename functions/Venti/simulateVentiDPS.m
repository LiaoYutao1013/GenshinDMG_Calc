function [totalDMG, dps, breakdown, rotationTime] = simulateVentiDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 温迪高精度近似模拟。
    % 建模要点：
    % 1. 区分点按/长按 E、Q 本体风伤、元素转化附加伤；
    % 2. C2 通过 E 减风抗/物抗与 Q 后重置 E 的轴体现；
    % 3. C4/C6 的风伤与暴伤/减抗直接并入对应窗口；
    % 4. 吸收元素按队伍元素优先级推断，默认优先火->水->雷->冰。
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
        'LunarisAttackName', "Hurricane_FX", 'LunarisDamageParam', "Elemental_Burst_Damage", 'Note', "Wind's Grand Ode");
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

    [totalDMG, dps, breakdown, rotationTime] = simulateSimpleCharacterDPS( ...
        'Venti', build, enemy, seqFile, talentLevel, constellation, teamContext, spec);
end

function element = localResolveAbsorbedElement(teamContext, enemy)
    if nargin >= 2 && isstruct(enemy)
        initialAura = string(getFieldOrDefault(enemy, 'InitialAuraElement', ""));
        if any(strcmpi(initialAura, ["Pyro", "Hydro", "Electro", "Cryo"]))
            element = initialAura;
            return;
        end
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
