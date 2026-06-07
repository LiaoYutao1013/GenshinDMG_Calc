function [totalDMG, dps, breakdown, rotationTime, audit] = simulateVarkaDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % Varka 高精度模拟。
    %
    % 当前落地范围：
    % 1. Sturm und Drang 下左右手分离建模：
    %    - 左手固定风元素；
    %    - 右手按 Pyro > Hydro > Electro > Cryo 的队伍优先级取元素；
    %    - 若队内不存在上述元素，则右手回退为物理段。
    % 2. Four Winds' Ascension / Azure Devour 的次数、充能回转与命座分支：
    %    - C1 额外可用次数与 Lyrical Libation；
    %    - C2 额外 800% ATK 风伤追击；
    %    - C4 扩散后 10s 风伤 / 对应元素伤加成；
    %    - C6 免费衔接在 Sturm 期间保留，直到被对应特殊动作消耗。
    % 3. Wind's Vanguard 的扩散叠层、每层 7.5% 增伤与 C6 每层 20% 暴伤。
    %
    % 待进一步核验的点：
    % 1. Lunaris 仅给出部分“分裂成多元素段”的合并倍率，因此当前按等分拆段；
    % 2. Varka 专属招式的真实 ApplyGauge / ICD 仍待更细来源校准；
    % 3. C6 “短时间内”的精确游戏侧时限仍待更细来源校准；
    %    当前实现保留到 Sturm 结束或被对应特殊动作消耗。
    if nargin < 3 || isempty(seqFile)
        seqFile = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Varka', 'rotation_Varka.txt');
    end
    if nargin < 4 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end
    if nargin < 6 || isempty(teamContext)
        teamContext = buildTeamContext({struct('Name', 'Varka', 'Constellation', constellation, 'Build', build)}, 20, struct(), enemy);
    end

    dataFolder = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'Varka');
    base = readtable(fullfile(dataFolder, 'characters_Varka.csv'));
    talent = readtable(fullfile(dataFolder, 'talents_Varka.csv'));

    normalLevel = localClampTalentLevel(talentLevel);
    skillLevel = localClampTalentLevel(talentLevel + 3 * double(constellation >= 3));
    burstLevel = localClampTalentLevel(talentLevel + 3 * double(constellation >= 5));

    rightHandElement = localResolveRightHandElement(teamContext);
    rightHandFallback = "Physical";
    ascensionBonus = localResolveAscensionBonus(base, build, teamContext, rightHandElement);
    sturmMultiplier = localResolveSturmMultiplier(teamContext);
    fourWindsCooldown = getTalentValue(talent, 'Skill', 'FourWindsAscensionCD', skillLevel);
    sturmDuration = getTalentValue(talent, 'Skill', 'SturmUndDrangDuration', skillLevel);
    fourWindsMaxUses = 2 + double(constellation >= 1);
    normalRefund = 0.5;
    if getFieldOrDefault(teamContext, 'HexereiCount', 0) >= 2
        normalRefund = 1.0;
    end

    varkaConfig = struct( ...
        'RightHandElement', rightHandElement, ...
        'RightHandFallback', rightHandFallback, ...
        'AscensionBonus', ascensionBonus, ...
        'SturmMultiplier', sturmMultiplier, ...
        'NormalLevel', normalLevel, ...
        'SkillLevel', skillLevel, ...
        'BurstLevel', burstLevel, ...
        'SturmDuration', sturmDuration, ...
        'FourWindsCooldown', fourWindsCooldown, ...
        'FourWindsMaxUses', fourWindsMaxUses, ...
        'NormalRefund', normalRefund, ...
        'Constellation', constellation);

    [expandedSeqFile, cleanupObj] = localPrepareRotationFile(seqFile, constellation); %#ok<NASGU>

    actions = localBuildActions(normalLevel, skillLevel, burstLevel, constellation);
    spec = struct( ...
        'Element', "Anemo", ...
        'ScalingMode', "ATK", ...
        'DefaultActionTime', 0.20, ...
        'DefaultRotation', {localDefaultExpandedRotation(constellation)}, ...
        'ActionTimeMap', localBuildActionTimeMap(constellation), ...
        'InitializeStateFn', @(state, hookContext) localInitializeState(state, hookContext, varkaConfig), ...
        'BeforeActionFn', @(state, actionKey, actionSpec, actionTime, note, hookContext) ...
            localBeforeAction(state, actionKey, actionSpec, actionTime, note, hookContext, varkaConfig), ...
        'AfterHitFn', @(state, actionKey, actionSpec, hitIndex, reactionResult, note, hookContext) ...
            localAfterHit(state, actionKey, actionSpec, hitIndex, reactionResult, note, hookContext, varkaConfig), ...
        'AfterActionFn', @(state, actionKey, actionSpec, actionDamage, reactionTags, note, hookContext) ...
            localAfterAction(state, actionKey, actionSpec, actionDamage, reactionTags, note, hookContext, varkaConfig), ...
        'AdvanceStateFn', @(state, actionTime, hookContext) ...
            localAdvanceState(state, actionTime, hookContext, varkaConfig), ...
        'Actions', actions);

    [totalDMG, dps, breakdown, rotationTime, audit] = simulateSimpleCharacterDPS( ...
        'Varka', build, enemy, expandedSeqFile, talentLevel, constellation, teamContext, spec);
end

function actions = localBuildActions(normalLevel, skillLevel, burstLevel, constellation)
    actions = struct();

    actions.E = struct( ...
        'TalentGroup', "Skill", ...
        'TalentLevelOverride', skillLevel, ...
        'Param', "SkillDMG", ...
        'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", ...
        'ApplyElement', "Anemo", ...
        'ApplyGauge', 1.0, ...
        'ICDRule', "Independent", ...
        'ICDGroup', "Varka_ElementalArt", ...
        'LunarisAttackName', "ElementalArt", ...
        'LunarisDamageParam', "ElementalArt_Damage", ...
        'Note', "Windbound Execution");

    actions.EHold = struct( ...
        'TalentGroup', "Skill", ...
        'TalentLevelOverride', skillLevel, ...
        'Param', "SkillDMG", ...
        'DamageField', "SkillDMGBonus", ...
        'ActionElement', "Anemo", ...
        'MVOverride', 0, ...
        'ApplyGauge', 0.0, ...
        'CanApplyAura', false, ...
        'CanTriggerReaction', false, ...
        'Note', "Windbound Execution hold");

    normalPairs = { ...
        "N1Left", "x1HitDMG", "SturmUndDrang1HitDMG"; ...
        "N1Right", "x1HitDMG", "SturmUndDrang1HitDMG"; ...
        "N2Left", "x2HitDMG", "SturmUndDrang2HitDMG"; ...
        "N2Right", "x2HitDMG", "SturmUndDrang2HitDMG"; ...
        "N3Left", "x3HitDMG", "SturmUndDrang3HitDMG"; ...
        "N3Right", "x3HitDMG", "SturmUndDrang3HitDMG"; ...
        "N4Left", "x4HitDMG", "SturmUndDrang4HitDMG"; ...
        "N4Right", "x4HitDMG", "SturmUndDrang4HitDMG"; ...
        "N5Left", "x5HitDMG", "SturmUndDrang5HitDMG"; ...
        "N5Right", "x5HitDMG", "SturmUndDrang5HitDMG"};
    for i = 1:size(normalPairs, 1)
        actionName = char(normalPairs{i, 1});
        baseParam = string(normalPairs{i, 2});
        sturmParam = string(normalPairs{i, 3});
        isLeft = contains(actionName, 'Left');
        actions.(actionName) = struct( ...
            'TalentGroup', "Normal", ...
            'TalentLevelOverride', normalLevel, ...
            'Param', baseParam, ...
            'DamageField', "NormalDMGBonus", ...
            'ActionElement', "Physical", ...
            'BaseMultiplier', 0.50, ...
            'ApplyGauge', 0.0, ...
            'CanApplyAura', false, ...
            'DisableLunarisLookup', true, ...
            'VarkaDualAttack', true, ...
            'VarkaLeftHand', isLeft, ...
            'VarkaRightHand', ~isLeft, ...
            'VarkaBaseParam', baseParam, ...
            'VarkaSturmParam', sturmParam, ...
            'VarkaOathEligible', true, ...
            'VarkaRefundSource', ~isLeft, ...
            'VarkaComponentLabel', string(actionName), ...
            'Note', string(actionName));
    end

    actions.ChargedLeft = struct( ...
        'TalentGroup', "Normal", ...
        'TalentLevelOverride', normalLevel, ...
        'Param', "ChargedAttackDMG", ...
        'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Physical", ...
        'BaseMultiplier', 0.50, ...
        'ApplyGauge', 0.0, ...
        'CanApplyAura', false, ...
        'DisableLunarisLookup', true, ...
        'VarkaDualAttack', true, ...
        'VarkaLeftHand', true, ...
        'VarkaRightHand', false, ...
        'VarkaBaseParam', "ChargedAttackDMG", ...
        'VarkaSturmParam', "SturmUndDrangChargedAttackDMG", ...
        'VarkaOathEligible', true, ...
        'Note', "Charged left");
    actions.ChargedRight = struct( ...
        'TalentGroup', "Normal", ...
        'TalentLevelOverride', normalLevel, ...
        'Param', "ChargedAttackDMG", ...
        'DamageField', "ChargedDMGBonus", ...
        'ActionElement', "Physical", ...
        'BaseMultiplier', 0.50, ...
        'ApplyGauge', 0.0, ...
        'CanApplyAura', false, ...
        'DisableLunarisLookup', true, ...
        'VarkaDualAttack', true, ...
        'VarkaLeftHand', false, ...
        'VarkaRightHand', true, ...
        'VarkaBaseParam', "ChargedAttackDMG", ...
        'VarkaSturmParam', "SturmUndDrangChargedAttackDMG", ...
        'VarkaOathEligible', true, ...
        'Note', "Charged right");

    actions.FourWindsRight = localMakeSpecialAction( ...
        "Ascend", "Right", skillLevel, "Skill", "FourWindsAscensionDMG", "SkillDMGBonus", 0.50, false, false, "Four Winds right");
    actions.FourWindsAnemo = localMakeSpecialAction( ...
        "Ascend", "Anemo", skillLevel, "Skill", "FourWindsAscensionDMG", "SkillDMGBonus", 0.50, false, constellation < 2, "Four Winds anemo");
    actions.FourWindsC2 = localMakeSpecialAction( ...
        "Ascend", "C2", skillLevel, "Skill", "FourWindsAscensionDMG", "SkillDMGBonus", 1.00, true, true, "Four Winds C2");

    actions.AzureDevourRight1 = localMakeSpecialAction( ...
        "Devour", "Right1", skillLevel, "Skill", "AzureDevourDMG", "ChargedDMGBonus", 0.25, false, false, "Azure Devour right 1");
    actions.AzureDevourAnemo1 = localMakeSpecialAction( ...
        "Devour", "Anemo1", skillLevel, "Skill", "AzureDevourDMG", "ChargedDMGBonus", 0.25, false, false, "Azure Devour anemo 1");
    actions.AzureDevourRight2 = localMakeSpecialAction( ...
        "Devour", "Right2", skillLevel, "Skill", "AzureDevourDMG", "ChargedDMGBonus", 0.25, false, false, "Azure Devour right 2");
    actions.AzureDevourAnemo2 = localMakeSpecialAction( ...
        "Devour", "Anemo2", skillLevel, "Skill", "AzureDevourDMG", "ChargedDMGBonus", 0.25, false, constellation < 2, "Azure Devour anemo 2");
    actions.AzureDevourC2 = localMakeSpecialAction( ...
        "Devour", "C2", skillLevel, "Skill", "AzureDevourDMG", "ChargedDMGBonus", 1.00, true, true, "Azure Devour C2");

    actions.Q1 = struct( ...
        'TalentGroup', "Burst", ...
        'TalentLevelOverride', burstLevel, ...
        'Param', "Skill1HitDMG", ...
        'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", ...
        'ApplyElement', "Anemo", ...
        'ApplyGauge', 1.0, ...
        'ICDRule', "Independent", ...
        'ICDGroup', "Varka_BurstLeadingSlash", ...
        'LunarisAttackName', "ElementalBurst", ...
        'LunarisDamageParam', "ElementalBurst_Attack1", ...
        'VarkaBurstLeadingSlash', true, ...
        'Note', "Northwind Avatar slash 1");
    actions.Q2 = struct( ...
        'TalentGroup', "Burst", ...
        'TalentLevelOverride', burstLevel, ...
        'Param', "Skill2HitDMG", ...
        'DamageField', "BurstDMGBonus", ...
        'ActionElement', "Anemo", ...
        'ApplyElement', "Anemo", ...
        'ApplyGauge', 1.0, ...
        'ICDRule', "Independent", ...
        'ICDGroup', "Varka_BurstFollowSlash", ...
        'LunarisAttackName', "ElementalBurst", ...
        'LunarisDamageParam', "ElementalBurst_Attack2", ...
        'Note', "Northwind Avatar slash 2");
end

function action = localMakeSpecialAction(kind, component, skillLevel, talentGroup, paramName, damageField, baseMultiplier, isC2, isTerminal, note)
    isAnemoComponent = contains(component, "Anemo") || contains(component, "C2");
    if isAnemoComponent
        lunarisDamageParam = "Special_ElementalArt_02|_ABILITY_Avatar_Varka_ArtDamageUp_GV|MUL|Talent1_Rate|MUL";
        lunarisAttackName = "Special_ElementalArt";
        icdGroup = "Varka_SpecialAnemo";
    else
        lunarisDamageParam = "Special_ElementalArt_01|_ABILITY_Avatar_Varka_ArtDamageUp_GV|MUL|Talent1_Rate|MUL";
        lunarisAttackName = "Special_ElementalArt";
        icdGroup = "Varka_SpecialElement";
    end
    action = struct( ...
        'TalentGroup', string(talentGroup), ...
        'TalentLevelOverride', skillLevel, ...
        'Param', string(paramName), ...
        'DamageField', string(damageField), ...
        'ActionElement', "Anemo", ...
        'ApplyElement', "Anemo", ...
        'BaseMultiplier', baseMultiplier, ...
        'ApplyGauge', 1.0, ...
        'ICDRule', "Independent", ...
        'ICDGroup', icdGroup, ...
        'LunarisAttackName', lunarisAttackName, ...
        'LunarisDamageParam', lunarisDamageParam, ...
        'VarkaSpecialKind', string(kind), ...
        'VarkaSpecialComponent', string(component), ...
        'VarkaSpecialStart', any(strcmp(component, ["Right", "Right1"])), ...
        'VarkaSpecialTerminal', isTerminal, ...
        'VarkaSpecialC2', isC2, ...
        'VarkaOathEligible', ~isC2, ...
        'Note', string(note));
end

function [state, actionSpec, actionTime, note] = localBeforeAction(state, actionKey, actionSpec, actionTime, note, hookContext, cfg)
    state = localEnsureStateFields(state, cfg);
    note = string(note);

    if state.SkillActiveTime <= 1e-6
        state.PendingFreeDevour = false;
        state.PendingFreeAscend = false;
    end

    if logical(getFieldOrDefault(actionSpec, 'VarkaDualAttack', false))
        [actionSpec, note] = localConfigureDualAttack(actionSpec, note, state, cfg);
    end

    if isfield(actionSpec, 'VarkaSpecialKind')
        [state, actionSpec, note] = localConfigureSpecialAttack(state, actionSpec, note, cfg);
    end

    if logical(getFieldOrDefault(actionSpec, 'VarkaBurstLeadingSlash', false))
        [actionSpec, note] = localConfigureBurstLeadingSlash(actionSpec, note, cfg);
    end

    [actionSpec, note] = localApplySharedBonuses(actionSpec, note, state, cfg);
    actionTime = max(0, actionTime);
end

function [actionSpec, note] = localConfigureDualAttack(actionSpec, note, state, cfg)
    if state.SkillActiveTime > 1e-6
        actionSpec.TalentGroup = "Skill";
        actionSpec.TalentLevelOverride = cfg.SkillLevel;
        actionSpec.Param = string(getFieldOrDefault(actionSpec, 'VarkaSturmParam', actionSpec.Param));
        actionSpec.ICDRule = "Standard (3h/2.5s)";
        actionSpec.ICDGroup = localResolveDualAttackICDGroup(actionSpec);
        actionSpec.ApplyGauge = 1.0;
        actionSpec.CanApplyAura = true;
        actionSpec.CanTriggerReaction = true;
        actionSpec.BaseMultiplier = getFieldOrDefault(actionSpec, 'BaseMultiplier', 1.0) * cfg.SturmMultiplier;
        actionSpec.DisableLunarisLookup = true;
        actionSpec.LunarisAttackName = "";
        actionSpec.LunarisDamageParam = "";

        if logical(getFieldOrDefault(actionSpec, 'VarkaLeftHand', false))
            actionSpec = localAssignElementReactionMetadata(actionSpec, "Anemo");
        else
            rightElement = cfg.RightHandElement;
            if strlength(rightElement) > 0
                actionSpec = localAssignElementReactionMetadata(actionSpec, rightElement);
                note = localAppendNote(note, "right=" + rightElement);
            else
                actionSpec.ActionElement = cfg.RightHandFallback;
                actionSpec.ApplyElement = "";
                actionSpec.ApplyGauge = 0.0;
                actionSpec.CanApplyAura = false;
                actionSpec.CanTriggerReaction = false;
                actionSpec.AllowAmplify = 0;
                actionSpec.AllowCatalyze = 0;
                actionSpec.ICDGroup = "";
                note = localAppendNote(note, "right=Physical");
            end
        end
    else
        actionSpec.TalentGroup = "Normal";
        actionSpec.TalentLevelOverride = cfg.NormalLevel;
        actionSpec.Param = string(getFieldOrDefault(actionSpec, 'VarkaBaseParam', actionSpec.Param));
        actionSpec.ActionElement = "Physical";
        actionSpec.ApplyElement = "";
        actionSpec.ApplyGauge = 0.0;
        actionSpec.CanApplyAura = false;
        actionSpec.CanTriggerReaction = false;
        actionSpec.AllowAmplify = 0;
        actionSpec.AllowCatalyze = 0;
        actionSpec.ICDGroup = "";
        actionSpec.DisableLunarisLookup = true;
        actionSpec.LunarisAttackName = "";
        actionSpec.LunarisDamageParam = "";
    end
end

function [state, actionSpec, note] = localConfigureSpecialAttack(state, actionSpec, note, cfg)
    state = localEnsureStateFields(state, cfg);
    kind = string(getFieldOrDefault(actionSpec, 'VarkaSpecialKind', ""));
    component = string(getFieldOrDefault(actionSpec, 'VarkaSpecialComponent', ""));
    isStart = logical(getFieldOrDefault(actionSpec, 'VarkaSpecialStart', false));
    if isStart
        [state, note] = localBeginSpecialGroup(state, kind, note, cfg);
    end

    if ~strcmp(state.ActiveSpecialKind, kind)
        actionSpec = localInvalidateAction(actionSpec, note);
        return;
    end

    if ~state.ActiveSpecialValid
        actionSpec = localInvalidateAction(actionSpec, note);
        return;
    end

    if logical(getFieldOrDefault(actionSpec, 'VarkaSpecialC2', false))
        if cfg.Constellation < 2
            actionSpec = localInvalidateAction(actionSpec, note);
            return;
        end
        actionSpec.MVOverride = 8.0;
        actionSpec = localAssignElementReactionMetadata(actionSpec, "Anemo");
        actionSpec.ApplyGauge = 1.0;
        actionSpec.ICDRule = "Independent";
        actionSpec.ICDGroup = "Varka_SpecialC2";
        actionSpec.DisableLunarisLookup = true;
        actionSpec.LunarisAttackName = "";
        actionSpec.LunarisDamageParam = "";
        note = localAppendNote(note, "C2");
        return;
    end

    actionSpec.BaseMultiplier = getFieldOrDefault(actionSpec, 'BaseMultiplier', 1.0) ...
        * cfg.SturmMultiplier * state.ActiveSpecialDamageMultiplier;
    actionSpec.ApplyGauge = 1.0;
    actionSpec.ICDRule = "Independent";

    if contains(component, "Right")
        if strlength(cfg.RightHandElement) == 0
            actionSpec = localInvalidateAction(actionSpec, localAppendNote(note, "no infused partner"));
            return;
        end
        actionSpec = localAssignElementReactionMetadata(actionSpec, cfg.RightHandElement);
        actionSpec.ICDGroup = "Varka_SpecialElement";
        actionSpec.DisableLunarisLookup = false;
        actionSpec.LunarisAttackName = "Special_ElementalArt";
        actionSpec.LunarisDamageParam = "Special_ElementalArt_01";
        note = localAppendNote(note, "right=" + cfg.RightHandElement);
    else
        actionSpec = localAssignElementReactionMetadata(actionSpec, "Anemo");
        actionSpec.ICDGroup = "Varka_SpecialAnemo";
        actionSpec.DisableLunarisLookup = false;
        actionSpec.LunarisAttackName = "Special_ElementalArt";
        actionSpec.LunarisDamageParam = "Special_ElementalArt_02";
    end
end

function [actionSpec, note] = localConfigureBurstLeadingSlash(actionSpec, note, cfg)
    if strlength(cfg.RightHandElement) > 0
        actionSpec = localAssignElementReactionMetadata(actionSpec, cfg.RightHandElement);
        note = localAppendNote(note, "slash1=" + cfg.RightHandElement);
    else
        actionSpec = localAssignElementReactionMetadata(actionSpec, "Anemo");
    end
end

function [actionSpec, note] = localApplySharedBonuses(actionSpec, note, state, cfg)
    actionElement = string(getFieldOrDefault(actionSpec, 'ActionElement', ""));
    isAnemo = strcmp(actionElement, "Anemo");
    isRightHandElement = strlength(cfg.RightHandElement) > 0 && strcmp(actionElement, cfg.RightHandElement);

    if cfg.AscensionBonus > 0 && (isAnemo || isRightHandElement)
        actionSpec.FlatDamageBonus = getFieldOrDefault(actionSpec, 'FlatDamageBonus', 0) + cfg.AscensionBonus;
    end

    if state.C4BuffTime > 1e-6 && (isAnemo || (strlength(state.C4Element) > 0 && strcmp(actionElement, state.C4Element)))
        actionSpec.FlatDamageBonus = getFieldOrDefault(actionSpec, 'FlatDamageBonus', 0) + 0.20;
        note = localAppendNote(note, "C4");
    end

    if logical(getFieldOrDefault(actionSpec, 'VarkaOathEligible', false)) && state.Stacks > 0
        actionSpec.PerStackDamageBonus = 0.075;
        note = localAppendNote(note, "Oath x" + string(state.Stacks));
    else
        actionSpec.PerStackDamageBonus = 0;
    end

    if cfg.Constellation >= 6 && state.Stacks > 0
        actionSpec.CritDMGBonus = getFieldOrDefault(actionSpec, 'CritDMGBonus', 0) + 0.20 * state.Stacks;
    end
end

function [state, note] = localAfterHit(state, actionKey, actionSpec, hitIndex, reactionResult, note, hookContext, cfg)
    %#ok<INUSD>
    triggeredReactions = string(getFieldOrDefault(reactionResult, 'TriggeredReactions', strings(0, 1)));
    if any(strcmpi(triggeredReactions, "swirl"))
        if state.OathCooldown <= 1e-6
            state = localAddOathStack(state);
            state.OathCooldown = 1.0;
            note = localAppendNote(note, "Oath+1");
        end
        if cfg.Constellation >= 4
            state.C4BuffTime = 10.0;
            state.C4Element = cfg.RightHandElement;
        end
    end
end

function [state, note] = localAfterAction(state, actionKey, actionSpec, actionDamage, reactionTags, note, hookContext, cfg)
    %#ok<INUSD>
    if strcmp(actionKey, "E") && actionDamage > 0
        state.SkillActiveTime = cfg.SturmDuration;
        state.SpecialCharges = cfg.FourWindsMaxUses;
        state.SpecialCooldowns = zeros(1, 0);
        state.SpecialRefundsRemaining = 15;
        state.LyricalReady = cfg.Constellation >= 1;
        state.PendingFreeDevour = false;
        state.PendingFreeAscend = false;
        state.ActiveSpecialKind = "";
        state.ActiveSpecialValid = false;
        state.ActiveSpecialDamageMultiplier = 1.0;
        note = localAppendNote(note, "Sturm enter");
        if strlength(cfg.RightHandElement) > 0
            note = localAppendNote(note, "right=" + cfg.RightHandElement);
        else
            note = localAppendNote(note, "right=Physical");
        end
    end

    if logical(getFieldOrDefault(actionSpec, 'VarkaRefundSource', false)) && state.SkillActiveTime > 1e-6 && actionDamage > 0
        if state.SpecialRefundsRemaining > 0
            [state.SpecialCharges, state.SpecialCooldowns] = localRefundSpecialCooldown( ...
                state.SpecialCharges, state.SpecialCooldowns, cfg.FourWindsMaxUses, cfg.NormalRefund);
            state.SpecialRefundsRemaining = max(0, state.SpecialRefundsRemaining - 1);
        end
    end

    if logical(getFieldOrDefault(actionSpec, 'VarkaSpecialTerminal', false))
        if state.ActiveSpecialValid && actionDamage > 0 && cfg.Constellation >= 6 && ~state.ActiveSpecialFromC6
            if strcmp(state.ActiveSpecialKind, "Ascend")
                state.PendingFreeDevour = true;
            elseif strcmp(state.ActiveSpecialKind, "Devour")
                state.PendingFreeAscend = true;
            end
        end
        state.ActiveSpecialKind = "";
        state.ActiveSpecialValid = false;
        state.ActiveSpecialDamageMultiplier = 1.0;
        state.ActiveSpecialFromC6 = false;
    end
end

function state = localAdvanceState(state, actionTime, hookContext, cfg)
    %#ok<INUSD>
    state = localEnsureStateFields(state, cfg);
    state.OathCooldown = max(0, state.OathCooldown - actionTime);
    state.C4BuffTime = max(0, state.C4BuffTime - actionTime);

    if state.SkillActiveTime <= 1e-6
        state.PendingFreeDevour = false;
        state.PendingFreeAscend = false;
    end

    if ~isempty(state.OathTimers)
        state.OathTimers = max(0, state.OathTimers - actionTime);
        state.OathTimers = state.OathTimers(state.OathTimers > 1e-6);
    end
    state.Stacks = numel(state.OathTimers);

    if ~isempty(state.SpecialCooldowns)
        state.SpecialCooldowns = max(0, state.SpecialCooldowns - actionTime);
        recovered = sum(state.SpecialCooldowns <= 1e-6);
        if recovered > 0
            state.SpecialCooldowns = state.SpecialCooldowns(state.SpecialCooldowns > 1e-6);
            state.SpecialCharges = min(cfg.FourWindsMaxUses, state.SpecialCharges + recovered);
        end
    end
end

function state = localInitializeState(state, hookContext, cfg)
    %#ok<INUSD>
    state = localEnsureStateFields(state, cfg);
end

function [state, note] = localBeginSpecialGroup(state, kind, note, cfg)
    state = localEnsureStateFields(state, cfg);
    state.ActiveSpecialKind = kind;
    state.ActiveSpecialValid = true;
    state.ActiveSpecialDamageMultiplier = 1.0;
    state.ActiveSpecialFromC6 = false;

    if state.SkillActiveTime <= 1e-6
        state.ActiveSpecialValid = false;
        note = localAppendNote(note, "not in Sturm");
        return;
    end
    if strlength(cfg.RightHandElement) == 0
        state.ActiveSpecialValid = false;
        note = localAppendNote(note, "no infused partner");
        return;
    end

    if strcmp(kind, "Ascend") && state.PendingFreeAscend
        state.PendingFreeAscend = false;
        state.ActiveSpecialFromC6 = true;
        note = localAppendNote(note, "C6 free");
    elseif strcmp(kind, "Devour") && state.PendingFreeDevour
        state.PendingFreeDevour = false;
        state.ActiveSpecialFromC6 = true;
        note = localAppendNote(note, "C6 free");
    else
        if state.SpecialCharges <= 0
            state.ActiveSpecialValid = false;
            note = localAppendNote(note, "no Four Winds use");
            return;
        end
        state.SpecialCharges = state.SpecialCharges - 1;
        state.SpecialCooldowns(end + 1) = cfg.FourWindsCooldown; %#ok<AGROW>
        note = localAppendNote(note, "uses=" + string(state.SpecialCharges) + "/" + string(cfg.FourWindsMaxUses));
    end

    if state.LyricalReady && cfg.Constellation >= 1
        state.ActiveSpecialDamageMultiplier = 2.0;
        state.LyricalReady = false;
        note = localAppendNote(note, "Lyrical");
    end
end

function [charges, cooldowns] = localRefundSpecialCooldown(charges, cooldowns, maxCharges, refundAmount)
    if isempty(cooldowns) || refundAmount <= 0
        return;
    end
    cooldowns = cooldowns - refundAmount;
    recovered = sum(cooldowns <= 1e-6);
    if recovered > 0
        cooldowns = cooldowns(cooldowns > 1e-6);
        charges = min(maxCharges, charges + recovered);
    end
end

function state = localAddOathStack(state)
    if isempty(state.OathTimers)
        state.OathTimers = 8.0;
    elseif numel(state.OathTimers) < 4
        state.OathTimers(end + 1) = 8.0; %#ok<AGROW>
    else
        [~, idx] = min(state.OathTimers);
        state.OathTimers(idx) = 8.0;
    end
    state.Stacks = numel(state.OathTimers);
end

function state = localEnsureStateFields(state, cfg)
    if ~isfield(state, 'SpecialCharges')
        state.SpecialCharges = cfg.FourWindsMaxUses;
    end
    if ~isfield(state, 'SpecialCooldowns')
        state.SpecialCooldowns = zeros(1, 0);
    end
    if ~isfield(state, 'SpecialRefundsRemaining')
        state.SpecialRefundsRemaining = 15;
    end
    if ~isfield(state, 'LyricalReady')
        state.LyricalReady = cfg.Constellation >= 1;
    end
    if ~isfield(state, 'OathTimers')
        state.OathTimers = zeros(1, 0);
    end
    if ~isfield(state, 'OathCooldown')
        state.OathCooldown = 0;
    end
    if ~isfield(state, 'C4BuffTime')
        state.C4BuffTime = 0;
    end
    if ~isfield(state, 'C4Element')
        state.C4Element = "";
    end
    if ~isfield(state, 'PendingFreeDevour')
        state.PendingFreeDevour = false;
    end
    if ~isfield(state, 'PendingFreeAscend')
        state.PendingFreeAscend = false;
    end
    if ~isfield(state, 'ActiveSpecialKind')
        state.ActiveSpecialKind = "";
    end
    if ~isfield(state, 'ActiveSpecialValid')
        state.ActiveSpecialValid = false;
    end
    if ~isfield(state, 'ActiveSpecialDamageMultiplier')
        state.ActiveSpecialDamageMultiplier = 1.0;
    end
    if ~isfield(state, 'ActiveSpecialFromC6')
        state.ActiveSpecialFromC6 = false;
    end
end

function actionSpec = localInvalidateAction(actionSpec, note)
    actionSpec.MVOverride = 0;
    actionSpec.FlatDirectATKWeight = 0;
    actionSpec.FlatDirectHPWeight = 0;
    actionSpec.FlatDirectDEFWeight = 0;
    actionSpec.FlatDirectEMWeight = 0;
    actionSpec.ApplyElement = "";
    actionSpec.ApplyGauge = 0.0;
    actionSpec.CanApplyAura = false;
    actionSpec.CanTriggerReaction = false;
    actionSpec.AllowAmplify = 0;
    actionSpec.AllowCatalyze = 0;
    actionSpec.ICDGroup = "";
    actionSpec.DisableLunarisLookup = true;
    actionSpec.LunarisAttackName = "";
    actionSpec.LunarisDamageParam = "";
    actionSpec.Note = localAppendNote(string(getFieldOrDefault(actionSpec, 'Note', "")), note);
end

function [expandedSeqFile, cleanupObj] = localPrepareRotationFile(seqFile, constellation)
    rawTokens = {};
    if strlength(string(seqFile)) > 0 && exist(char(string(seqFile)), 'file') == 2
        rawTokens = readRotationTokens(seqFile);
    end
    if isempty(rawTokens) || (numel(rawTokens) == 1 && strcmpi(char(string(rawTokens{1})), 'AUTO'))
        rawTokens = localDefaultPublicRotation();
    end

    expandedTokens = localExpandRotationTokens(rawTokens, constellation);
    expandedSeqFile = [tempname, '.txt'];
    fid = fopen(expandedSeqFile, 'w');
    if fid < 0
        error('simulateVarkaDPS:RotationFile', 'Unable to create temporary rotation file.');
    end
    for i = 1:numel(expandedTokens)
        fprintf(fid, '%s\n', expandedTokens{i});
    end
    fclose(fid);
    cleanupObj = onCleanup(@() localDeleteTempFile(expandedSeqFile));
end

function tokens = localExpandRotationTokens(rawTokens, constellation)
    tokens = cell(0, 1);
    for i = 1:numel(rawTokens)
        token = upper(strtrim(char(string(rawTokens{i}))));
        switch token
            case 'E'
                appendList = {'E'};
            case 'EHOLD'
                appendList = {'EHold'};
            case {'N1', 'S1'}
                appendList = {'N1Left', 'N1Right'};
            case {'N2', 'S2'}
                appendList = {'N2Left', 'N2Right'};
            case {'N3', 'S3'}
                appendList = {'N3Left', 'N3Right'};
            case {'N4', 'S4'}
                appendList = {'N4Left', 'N4Right'};
            case {'N5', 'S5'}
                appendList = {'N5Left', 'N5Right'};
            case {'CA', 'CHARGED'}
                appendList = {'ChargedLeft', 'ChargedRight'};
            case {'ASCEND', 'FWA'}
                appendList = {'FourWindsRight', 'FourWindsAnemo'};
                if constellation >= 2
                    appendList{end + 1} = 'FourWindsC2'; %#ok<AGROW>
                end
            case {'DEVOUR', 'AD'}
                appendList = {'AzureDevourRight1', 'AzureDevourAnemo1', 'AzureDevourRight2', 'AzureDevourAnemo2'};
                if constellation >= 2
                    appendList{end + 1} = 'AzureDevourC2'; %#ok<AGROW>
                end
            case {'Q', 'BURST'}
                appendList = {'Q1', 'Q2'};
            otherwise
                appendList = {rawTokens{i}};
        end
        tokens = [tokens; appendList(:)]; %#ok<AGROW>
    end
end

function tokens = localDefaultPublicRotation()
    tokens = {'E', 'N1', 'N2', 'N3', 'Ascend', 'Devour', 'N4', 'N5', 'Q'};
end

function tokens = localDefaultExpandedRotation(constellation)
    tokens = localExpandRotationTokens(localDefaultPublicRotation(), constellation);
end

function actionTimeMap = localBuildActionTimeMap(constellation)
    actionTimeMap = struct( ...
        'E', 0.58, ...
        'EHold', 0.75, ...
        'N1Left', 0.18, ...
        'N1Right', 0.18, ...
        'N2Left', 0.18, ...
        'N2Right', 0.18, ...
        'N3Left', 0.22, ...
        'N3Right', 0.22, ...
        'N4Left', 0.24, ...
        'N4Right', 0.24, ...
        'N5Left', 0.28, ...
        'N5Right', 0.28, ...
        'ChargedLeft', 0.32, ...
        'ChargedRight', 0.32, ...
        'FourWindsRight', 0.22, ...
        'FourWindsAnemo', 0.22, ...
        'AzureDevourRight1', 0.16, ...
        'AzureDevourAnemo1', 0.16, ...
        'AzureDevourRight2', 0.16, ...
        'AzureDevourAnemo2', 0.16, ...
        'Q1', 0.42, ...
        'Q2', 0.34);
    if constellation >= 2
        actionTimeMap.FourWindsC2 = 0.08;
        actionTimeMap.AzureDevourC2 = 0.08;
    end
end

function rightHandElement = localResolveRightHandElement(teamContext)
    [timelineElement, usedTimeline] = localResolveVarkaRightHandElementFromTimeline(teamContext);
    if usedTimeline && strlength(timelineElement) > 0
        rightHandElement = timelineElement;
        return;
    end

    priority = ["Pyro", "Hydro", "Electro", "Cryo"];
    rightHandElement = "";
    for i = 1:numel(priority)
        countField = priority(i) + "Count";
        if getFieldOrDefault(teamContext, char(countField), 0) >= 1
            rightHandElement = priority(i);
            return;
        end
    end
end

function [element, usedTimeline] = localResolveVarkaRightHandElementFromTimeline(teamContext)
    element = "";
    usedTimeline = false;

    timelineTable = getFieldOrDefault(teamContext, 'TimelineTable', table());
    if isempty(timelineTable) || ~istable(timelineTable) || height(timelineTable) == 0
        return;
    end
    if ~all(ismember({'Character', 'Action', 'StartTime'}, timelineTable.Properties.VariableNames))
        return;
    end

    rowCharacters = string(timelineTable.Character);
    rowActions = lower(strtrim(string(timelineTable.Action)));
    anchorMask = strcmpi(rowCharacters, "Varka") ...
        & any(rowActions == ["e", "ascend", "fwa", "devour", "ad", "q", "q1", ...
            "fourwindsright", "fourwindsanemo", "fourwindsc2", ...
            "azuredevourright1", "azuredevouranemo1", "azuredevourright2", ...
            "azuredevouranemo2", "azuredevourc2"], 2);
    if ~any(anchorMask)
        return;
    end

    usedTimeline = true;
    anchorRow = localResolveVarkaAnchorRow(timelineTable(anchorMask, :));
    priorRows = localResolveVarkaPriorRows(timelineTable, anchorRow);
    if isempty(priorRows)
        return;
    end

    latestRow = priorRows(end, :);
    if ismember('AuraState', latestRow.Properties.VariableNames)
        auraState = string(latestRow.AuraState(1));
        if strlength(strtrim(auraState)) > 0
            element = localResolveVarkaAuraStateElement(auraState);
            if strlength(element) > 0
                return;
            end
        end
    end

    element = localResolveVarkaElementFromRecentHits(priorRows);
end

function anchorRow = localResolveVarkaAnchorRow(rows)
    sortKey = double(rows.StartTime);
    if ismember('Order', rows.Properties.VariableNames)
        sortRows = [sortKey, double(rows.Order), (1:height(rows)).'];
        sortRows = sortrows(sortRows, [1 2 3]);
        order = sortRows(:, 3);
    else
        [~, order] = sort(sortKey);
    end
    anchorRow = rows(order(1), :);
end

function priorRows = localResolveVarkaPriorRows(timelineTable, anchorRow)
    startTimes = double(timelineTable.StartTime);
    priorMask = startTimes < double(anchorRow.StartTime(1)) - 1e-9;

    if ismember('Order', timelineTable.Properties.VariableNames) ...
            && ismember('Order', anchorRow.Properties.VariableNames)
        sameTimeMask = abs(startTimes - double(anchorRow.StartTime(1))) <= 1e-9 ...
            & double(timelineTable.Order) < double(anchorRow.Order(1));
        priorMask = priorMask | sameTimeMask;
    end

    priorRows = timelineTable(priorMask, :);
    if isempty(priorRows)
        return;
    end

    if ismember('Order', priorRows.Properties.VariableNames)
        sortRows = [double(priorRows.StartTime), double(priorRows.Order), (1:height(priorRows)).'];
        sortRows = sortrows(sortRows, [1 2 3]);
        priorRows = priorRows(sortRows(:, 3), :);
    else
        [~, order] = sort(double(priorRows.StartTime));
        priorRows = priorRows(order, :);
    end
end

function element = localResolveVarkaAuraStateElement(auraState)
    element = "";
    priority = localResolveVarkaRightHandPriority();
    auraText = string(auraState);
    for i = 1:numel(priority)
        if contains(auraText, priority(i) + ":", 'IgnoreCase', true)
            element = priority(i);
            return;
        end
    end
end

function element = localResolveVarkaElementFromRecentHits(priorRows)
    element = "";
    if isempty(priorRows)
        return;
    end

    hitElements = repmat("", height(priorRows), 1);
    if ismember('HitElement', priorRows.Properties.VariableNames)
        hitElements = string(priorRows.HitElement);
    end

    applyGauge = zeros(height(priorRows), 1);
    if ismember('ApplyGauge', priorRows.Properties.VariableNames)
        applyGauge = double(priorRows.ApplyGauge);
    end

    priority = localResolveVarkaRightHandPriority();
    for rowIndex = height(priorRows):-1:1
        if applyGauge(rowIndex) <= 0
            continue;
        end

        rowElement = string(hitElements(rowIndex));
        for priorityIndex = 1:numel(priority)
            if strcmpi(rowElement, priority(priorityIndex))
                element = priority(priorityIndex);
                return;
            end
        end
    end
end

function priority = localResolveVarkaRightHandPriority()
    priority = ["Pyro", "Hydro", "Electro", "Cryo"];
end

function bonus = localResolveAscensionBonus(base, build, teamContext, rightHandElement)
    if strlength(rightHandElement) == 0
        bonus = 0;
        return;
    end
    atkValue = (base.BaseATK(1) + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0) + getFieldOrDefault(teamContext, 'ATKBonus', 0)) ...
        + getFieldOrDefault(build, 'FlatATK', 0) + getFieldOrDefault(teamContext, 'FlatATK', 0);
    bonus = min(0.25, 0.10 * max(0, atkValue) / 1000);
end

function multiplier = localResolveSturmMultiplier(teamContext)
    anemoReady = getFieldOrDefault(teamContext, 'AnemoCount', 0) >= 2;
    pairedReady = max([ ...
        getFieldOrDefault(teamContext, 'PyroCount', 0), ...
        getFieldOrDefault(teamContext, 'HydroCount', 0), ...
        getFieldOrDefault(teamContext, 'ElectroCount', 0), ...
        getFieldOrDefault(teamContext, 'CryoCount', 0)]) >= 2;
    if anemoReady && pairedReady
        multiplier = 2.20;
    elseif anemoReady || pairedReady
        multiplier = 1.40;
    else
        multiplier = 1.00;
    end
end

function aura = localResolvePreferredAmplifyAura(element)
    switch upper(char(string(element)))
        case 'PYRO'
            aura = "Hydro";
        case 'HYDRO'
            aura = "Pyro";
        case 'CRYO'
            aura = "Pyro";
        otherwise
            aura = "";
    end
end

function actionSpec = localAssignElementReactionMetadata(actionSpec, element)
    element = string(element);
    actionSpec.ActionElement = element;
    actionSpec.ApplyElement = element;
    actionSpec.CanApplyAura = true;
    actionSpec.CanTriggerReaction = true;
    actionSpec.PreferredAmplifyAura = localResolvePreferredAmplifyAura(element);
    actionSpec.AllowAmplify = double(strlength(actionSpec.PreferredAmplifyAura) > 0);
    actionSpec.AllowCatalyze = double(strcmpi(char(element), 'Electro') || strcmpi(char(element), 'Dendro'));
end

function group = localResolveDualAttackICDGroup(actionSpec)
    if logical(getFieldOrDefault(actionSpec, 'VarkaLeftHand', false))
        group = "Varka_SturmLeft";
    else
        group = "Varka_SturmRight";
    end
end

function level = localClampTalentLevel(level)
    level = max(1, min(15, round(level)));
end

function note = localAppendNote(baseNote, suffix)
    if strlength(string(baseNote)) == 0
        note = string(suffix);
    else
        note = string(baseNote) + ", " + string(suffix);
    end
end

function localDeleteTempFile(filePath)
    if exist(filePath, 'file') == 2
        delete(filePath);
    end
end
