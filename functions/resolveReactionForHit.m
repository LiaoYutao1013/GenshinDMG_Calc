function result = resolveReactionForHit(enemyState, hitDescriptor, build, teamContext, enemy, deltaTime)
    % 统一元素反应结算入口。
    %
    % 输入：
    % - enemyState: 当前怪物元素状态
    % - hitDescriptor: 本次命中的结构化描述
    % - build / teamContext / enemy: 用于计算反应伤害与增益
    % - deltaTime: 与上次命中的间隔，用于推进附着衰减和持续反应
    %
    % 输出：
    % - EnemyState: 更新后的怪物状态
    % - AmplifyMultiplier: 本次直伤应乘的增幅倍率
    % - CatalyzeFlatDamage: 本次直伤应追加的激化附加值
    % - ReactionDamage: 本次命中额外产生的独立反应伤害
    % - TriggeredReactions: 本次命中及时间推进产生的反应标签
    % - PrimaryReaction: 本次命中直接触发的主反应
    if nargin < 2 || isempty(hitDescriptor)
        hitDescriptor = struct();
    end
    if nargin < 3 || isempty(build)
        build = struct();
    end
    if nargin < 4 || isempty(teamContext)
        teamContext = struct();
    end
    if nargin < 5 || isempty(enemy)
        enemy = struct();
    end
    if nargin < 6 || isempty(deltaTime)
        deltaTime = 0;
    end
    if isempty(enemyState)
        enemyState = createEnemyState(enemy, teamContext, getFieldOrDefault(hitDescriptor, 'HitElement', ""));
    end
    enemyState = localEnsureEnemyStateSchema(enemyState);

    result = localMakeEmptyResult(enemyState);
    [enemyState, timedPackets] = advanceEnemyStateTime( ...
        enemyState, deltaTime, getFieldOrDefault(hitDescriptor, 'HitElement', ""), teamContext);
    result.EnemyState = enemyState;

    for i = 1:numel(timedPackets)
        packet = timedPackets(i);
        result.ReactionDamage = result.ReactionDamage + localResolvePacketDamage( ...
            packet, build, teamContext, enemy, result.EnemyState);
        result.TriggeredReactions(end + 1, 1) = lower(string(packet.ReactionName)); %#ok<AGROW>
    end

    if logical(getFieldOrDefault(hitDescriptor, 'ResolveReactionAsDamage', false))
        forcedReaction = string(getFieldOrDefault(hitDescriptor, 'ForceReactionName', ""));
        if strlength(forcedReaction) == 0
            forcedReaction = localInferForcedReactionName(hitDescriptor);
        end
        if strlength(forcedReaction) > 0
            result.PrimaryReaction = forcedReaction;
            decoratedDescriptor = localDecorateReactionElement(hitDescriptor, forcedReaction, struct('ConsumedAura', ""));
            result.ReactionDamage = result.ReactionDamage + localResolveTransformativeDamage( ...
                forcedReaction, build, teamContext, enemy, result.EnemyState, ...
                localResolveCustomReactionBase(hitDescriptor, build, forcedReaction), ...
                getFieldOrDefault(hitDescriptor, 'ReactionBonus', getFieldOrDefault(build, 'ReactionDMGBonus', 0)), ...
                decoratedDescriptor);
            result.TriggeredReactions(end + 1, 1) = lower(forcedReaction); %#ok<AGROW>
        end
        result.TriggeredReactions = unique(result.TriggeredReactions(strlength(result.TriggeredReactions) > 0), 'stable');
        return;
    end

    if ~logical(getFieldOrDefault(result.EnemyState, 'EnableElementalAura', true))
        return;
    end

    hitElement = string(getFieldOrDefault(hitDescriptor, 'HitElement', ""));
    applyElement = string(getFieldOrDefault(hitDescriptor, 'ApplyElement', hitElement));
    applyGauge = double(getFieldOrDefault(hitDescriptor, 'ApplyGauge', 1.0));
    canApplyAura = logical(getFieldOrDefault(hitDescriptor, 'CanApplyAura', strlength(applyElement) > 0));
    canTriggerReaction = logical(getFieldOrDefault(hitDescriptor, 'CanTriggerReaction', true));
    preferredAura = string(getFieldOrDefault(hitDescriptor, 'PreferredAura', ""));
    forceReaction = string(getFieldOrDefault(hitDescriptor, 'ForceReactionName', ""));
    postReactionApplyGauge = applyGauge;

    if strlength(preferredAura) > 0 && localUsesApproximateSupportAura(result.EnemyState)
        result.EnemyState = localForceAura(result.EnemyState, preferredAura, getFieldOrDefault(result.EnemyState, 'SupportAuraGauge', 1.0));
    end
    result.EnemyState = localEnsureSupportAura(result.EnemyState, hitElement, teamContext);
    preReactionEnemyState = result.EnemyState;

    if ~canTriggerReaction
        if canApplyAura && strlength(applyElement) > 0
            result.EnemyState = localApplyPostReactionAura(result.EnemyState, applyElement, applyGauge, "");
        end
        result.EnemyState = localRefreshFrozenState(result.EnemyState);
        return;
    end

    directReaction = localResolvePrimaryReaction(result.EnemyState, hitElement, forceReaction, teamContext);
    result.PrimaryReaction = directReaction.Name;

    emOverride = getFieldOrDefault(hitDescriptor, 'ReactionEMOverride', []);
    if isempty(emOverride)
        em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    else
        em = double(emOverride);
    end
    reactionBonus = getFieldOrDefault(hitDescriptor, 'ReactionBonus', getFieldOrDefault(build, 'ReactionDMGBonus', 0));

    switch lower(char(directReaction.Name))
        case {'vaporize', 'melt'}
            if logical(getFieldOrDefault(hitDescriptor, 'AllowAmplify', false))
                result.AmplifyMultiplier = localAmplifyMultiplier(directReaction.Name, hitElement, em, reactionBonus);
            end
            [result.EnemyState, postReactionApplyGauge] = localConsumeAuraForAmplify( ...
                result.EnemyState, directReaction, applyGauge);

        case 'frozen'
            result.EnemyState = localConsumeAuraForDirectReaction(result.EnemyState, directReaction, applyGauge);
            result.EnemyState = localActivateFrozen(result.EnemyState, applyGauge);

        case 'quicken'
            [result.EnemyState, quickenGauge, postReactionApplyGauge] = localConsumeAuraForQuicken( ...
                result.EnemyState, directReaction, applyGauge);
            result.EnemyState = localActivateQuicken(result.EnemyState, quickenGauge);
            result.TriggeredReactions(end + 1, 1) = "quicken"; %#ok<AGROW>

        case 'aggravate'
            if logical(getFieldOrDefault(hitDescriptor, 'AllowCatalyze', false))
                result.CatalyzeFlatDamage = localCatalyzeFlatDamage("Aggravate", em, reactionBonus);
            end

        case 'spread'
            if logical(getFieldOrDefault(hitDescriptor, 'AllowCatalyze', false))
                result.CatalyzeFlatDamage = localCatalyzeFlatDamage("Spread", em, reactionBonus);
            end

        case {'electrocharged', 'overload', 'superconduct', 'stellarconduct', 'swirl', 'crystallize', 'bloom', 'burning', ...
                'lunarcharged', 'lunarcrystallize', 'lunarbloom'}
            [result, postReactionApplyGauge] = localResolveTransformativeReaction( ...
                result, directReaction, hitDescriptor, build, teamContext, enemy, applyGauge);

        otherwise
            if logical(getFieldOrDefault(hitDescriptor, 'AllowCatalyze', false)) ...
                    && getFieldOrDefault(result.EnemyState.Quicken, 'Active', false)
                catalyzeName = localResolveCatalyzeReactionName(hitElement);
                if strlength(catalyzeName) > 0
                    result.PrimaryReaction = catalyzeName;
                    result.CatalyzeFlatDamage = localCatalyzeFlatDamage(catalyzeName, em, reactionBonus);
                    result.TriggeredReactions(end + 1, 1) = lower(catalyzeName); %#ok<AGROW>
                end
            end
    end

    result = localResolveSupplementalReactions( ...
        result, preReactionEnemyState, directReaction, hitDescriptor, build, teamContext, enemy, applyGauge);

    if result.PrimaryReaction ~= ""
        result.TriggeredReactions(end + 1, 1) = lower(string(result.PrimaryReaction)); %#ok<AGROW>
    end

    if canApplyAura && strlength(applyElement) > 0
        result.EnemyState = localApplyPostReactionAura( ...
            result.EnemyState, applyElement, postReactionApplyGauge, directReaction.Name);
    end
    result.EnemyState = localRefreshFrozenState(result.EnemyState);
    result.EnemyState.LastReaction = string(result.PrimaryReaction);
    result.TriggeredReactions = unique(result.TriggeredReactions(strlength(result.TriggeredReactions) > 0), 'stable');
end

function [result, residualApplyGauge] = localResolveTransformativeReaction(result, directReaction, hitDescriptor, build, teamContext, enemy, applyGauge)
    reactionName = string(directReaction.Name);
    reactionBonus = getFieldOrDefault(hitDescriptor, 'ReactionBonus', 0);
    customBase = localResolveCustomReactionBase(hitDescriptor, build, reactionName);
    residualApplyGauge = applyGauge;
    if localShouldConsumeAuraOnDirectTransformativeReaction(reactionName)
        [result.EnemyState, residualApplyGauge] = localConsumeAuraForAmplify( ...
            result.EnemyState, directReaction, applyGauge);
    end
    if localShouldConsumeQuickenOnTransformativeReaction(reactionName, directReaction, result.EnemyState)
        result.EnemyState = localConsumeQuickenForAuraReaction(result.EnemyState, applyGauge);
    end

    switch lower(char(reactionName))
        case 'electrocharged'
            result.EnemyState.ElectroCharged = localActivateTimedReactionState( ...
                getFieldOrDefault(result.EnemyState, 'ElectroCharged', struct()), ...
                applyGauge, reactionBonus, hitDescriptor, build, teamContext, "Electro");
        case 'burning'
            result.EnemyState.Burning = localActivateTimedReactionState( ...
                getFieldOrDefault(result.EnemyState, 'Burning', struct()), ...
                applyGauge, reactionBonus, hitDescriptor, build, teamContext, "Pyro");
        case 'bloom'
            newCore = localMakeDendroCore(applyGauge, reactionBonus, hitDescriptor, build, teamContext);
            existing = getFieldOrDefault(result.EnemyState, 'DendroCores', repmat(newCore, 1, 0));
            if numel(existing) >= 5
                result.ReactionDamage = result.ReactionDamage + localResolveStoredReactionDamage( ...
                    "Bloom", existing(1), build, teamContext, enemy, result.EnemyState);
                result.TriggeredReactions(end + 1, 1) = "bloom"; %#ok<AGROW>
                existing = existing(2:end);
            end
            result.EnemyState.DendroCores = [existing, newCore];
        otherwise
            if localShouldDealDirectTransformativeDamage(reactionName, hitDescriptor, customBase)
                hitDescriptor = localDecorateReactionElement(hitDescriptor, reactionName, directReaction);
                result.ReactionDamage = result.ReactionDamage + localResolveTransformativeDamage( ...
                    reactionName, build, teamContext, enemy, result.EnemyState, customBase, reactionBonus, hitDescriptor);
            end
    end
end

function damage = localResolveTransformativeDamage(reactionName, build, teamContext, enemy, enemyState, customBase, reactionBonus, hitDescriptor)
    emOverride = getFieldOrDefault(hitDescriptor, 'ReactionEMOverride', []);
    if isempty(emOverride)
        em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    else
        em = emOverride;
    end
    reactionElement = string(getFieldOrDefault(hitDescriptor, 'ReactionElement', getFieldOrDefault(hitDescriptor, 'HitElement', "")));
    baseDamage = customBase;
    if baseDamage <= 0
        baseDamage = getReactionBaseDamage(reactionName, getFieldOrDefault(enemyState, 'ReactionLevel', 90));
    end

    critRate = getFieldOrDefault(hitDescriptor, 'ReactionCritRate', []);
    critDMG = getFieldOrDefault(hitDescriptor, 'ReactionCritDMG', []);
    if isempty(critRate)
        critRate = getFieldOrDefault(teamContext, 'ReactionCritRate', []);
    end
    if isempty(critDMG)
        critDMG = getFieldOrDefault(teamContext, 'ReactionCritDMG', []);
    end

    totalBonus = localResolveReactionFamilyBonus(reactionName, build, teamContext, hitDescriptor) + reactionBonus;
    resShredOverride = getFieldOrDefault(hitDescriptor, 'ReactionResShredOverride', []);
    if isempty(resShredOverride)
        resShred = getElementResShredValue(reactionElement, build, teamContext) ...
            + getFieldOrDefault(hitDescriptor, 'ExtraResShred', 0);
    else
        resShred = resShredOverride + getFieldOrDefault(hitDescriptor, 'ExtraResShred', 0);
    end
    damage = calcReactionDamage(baseDamage, em, enemy, resShred, 1 + totalBonus, critRate, critDMG);
    damage = damage + localResolveTeamReactionFlatDamage( ...
        reactionName, teamContext, enemy, resShred, totalBonus, critRate, critDMG);
end

function damage = localResolveTeamReactionFlatDamage(reactionName, teamContext, enemy, resShred, totalBonus, critRate, critDMG)
    damage = 0;
    switch lower(char(string(reactionName)))
        case 'stellarconduct'
            flatBase = getFieldOrDefault(teamContext, 'QiqiC6StellarConductFlatDamage', 0);
            if flatBase > 0
                damage = calcReactionDamage(flatBase, 0, enemy, resShred, 1 + totalBonus, critRate, critDMG);
            end
    end
end

function totalBonus = localResolveReactionFamilyBonus(reactionName, build, teamContext, hitDescriptor)
    reactionName = lower(char(string(reactionName)));
    totalBonus = 0;
    if nargin >= 4 && (logical(getFieldOrDefault(hitDescriptor, 'ResolveReactionAsDamage', false)) ...
            || logical(getFieldOrDefault(hitDescriptor, 'UseReactionBonusSnapshot', false)))
        return;
    end
    switch reactionName
        case 'superconduct'
            totalBonus = totalBonus + getFieldOrDefault(teamContext, 'SuperconductBonus', 0);
        case 'overload'
            totalBonus = totalBonus + getFieldOrDefault(teamContext, 'OverloadBonus', 0);
        case 'bloom'
            totalBonus = totalBonus + getFieldOrDefault(teamContext, 'NilouBloomBonus', 0) ...
                + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0);
        case 'electrocharged'
            totalBonus = totalBonus + getFieldOrDefault(teamContext, 'LunarChargedBonus', 0);
        case 'lunarcharged'
            totalBonus = totalBonus + getFieldOrDefault(teamContext, 'LunarChargedBonus', 0);
        case 'lunarcrystallize'
            totalBonus = totalBonus + getFieldOrDefault(teamContext, 'LunarCrystallizeBonus', 0);
        case 'lunarbloom'
            totalBonus = totalBonus + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0);
        case 'stellarconduct'
            totalBonus = totalBonus ...
                + getFieldOrDefault(teamContext, 'StellarConductBonus', 0) ...
                + getFieldOrDefault(teamContext, 'SandroneStellarConductC1Bonus', 0);
        case 'swirl'
            reactionElement = lower(char(string(getFieldOrDefault(hitDescriptor, 'ReactionElement', ""))));
            if strcmp(reactionElement, 'cryo')
                totalBonus = totalBonus + getFieldOrDefault(teamContext, 'CryoSwirlBonus', 0);
            end
    end
end

function baseDamage = localResolveCustomReactionBase(hitDescriptor, build, reactionName)
    baseDamage = getFieldOrDefault(hitDescriptor, 'ReactionBaseDamage', 0) ...
        + getFieldOrDefault(hitDescriptor, 'ReactionATKWeight', 0) * getFieldOrDefault(hitDescriptor, 'ATKValue', getFieldOrDefault(build, 'FlatATK', 0)) ...
        + getFieldOrDefault(hitDescriptor, 'ReactionHPWeight', 0) * getFieldOrDefault(hitDescriptor, 'HPValue', getFieldOrDefault(build, 'FlatHP', 0)) ...
        + getFieldOrDefault(hitDescriptor, 'ReactionDEFWeight', 0) * getFieldOrDefault(hitDescriptor, 'DEFValue', getFieldOrDefault(build, 'FlatDEF', 0)) ...
        + getFieldOrDefault(hitDescriptor, 'ReactionEMWeight', 0) * getFieldOrDefault(hitDescriptor, 'EMValue', getFieldOrDefault(build, 'EM', 0));

    if baseDamage > 0
        return;
    end

    switch lower(char(string(reactionName)))
        case 'aggravate'
            baseDamage = getReactionBaseDamage('Aggravate', 90);
        case 'spread'
            baseDamage = getReactionBaseDamage('Spread', 90);
    end
end

function hitDescriptor = localDecorateReactionElement(hitDescriptor, reactionName, directReaction)
    explicitElement = string(getFieldOrDefault(hitDescriptor, 'ReactionElement', ""));
    if strlength(explicitElement) > 0
        hitDescriptor.ReactionElement = explicitElement;
        return;
    end

    switch lower(char(string(reactionName)))
        case {'swirl', 'crystallize'}
            hitDescriptor.ReactionElement = string(getFieldOrDefault(directReaction, 'ConsumedAura', ""));
        otherwise
            defaultElement = localReactionElement(reactionName);
            if strlength(defaultElement) > 0
                hitDescriptor.ReactionElement = defaultElement;
            else
                hitDescriptor.ReactionElement = string(getFieldOrDefault(hitDescriptor, 'HitElement', ""));
            end
    end
end

function reactionName = localInferForcedReactionName(hitDescriptor)
    reactionName = string(getFieldOrDefault(hitDescriptor, 'ForceReactionName', ""));
    if strlength(reactionName) > 0
        return;
    end

    reactionElement = lower(char(string(getFieldOrDefault(hitDescriptor, 'ReactionElement', ""))));
    hitElement = lower(char(string(getFieldOrDefault(hitDescriptor, 'HitElement', ""))));
    baseDamage = getFieldOrDefault(hitDescriptor, 'ReactionBaseDamage', 0);
    customReactionWeights = abs(getFieldOrDefault(hitDescriptor, 'ReactionATKWeight', 0)) ...
        + abs(getFieldOrDefault(hitDescriptor, 'ReactionHPWeight', 0)) ...
        + abs(getFieldOrDefault(hitDescriptor, 'ReactionDEFWeight', 0)) ...
        + abs(getFieldOrDefault(hitDescriptor, 'ReactionEMWeight', 0));

    if baseDamage <= 0 && customReactionWeights <= 0
        return;
    end

    switch reactionElement
        case 'anemo'
            reactionName = "Swirl";
        case 'geo'
            reactionName = "Crystallize";
        otherwise
            switch hitElement
                case 'electro'
                    reactionName = "ElectroCharged";
                case 'dendro'
                    reactionName = "Bloom";
                case 'pyro'
                    reactionName = "Overload";
                otherwise
                    reactionName = "";
            end
    end
end

function name = localResolveCatalyzeReactionName(hitElement)
    switch lower(char(string(hitElement)))
        case 'electro'
            name = "Aggravate";
        case 'dendro'
            name = "Spread";
        otherwise
            name = "";
    end
end

function base = localCatalyzeFlatDamage(reactionName, em, reactionBonus)
    baseDamage = getReactionBaseDamage(reactionName, 90);
    base = baseDamage * (1 + 5 * max(0, em) / (max(0, em) + 1200) + max(0, reactionBonus));
end

function multiplier = localAmplifyMultiplier(reactionName, hitElement, em, reactionBonus)
    switch lower(char(string(reactionName)))
        case 'vaporize'
            if strcmpi(char(string(hitElement)), 'hydro')
                baseMultiplier = 2.0;
            else
                baseMultiplier = 1.5;
            end
        case 'melt'
            if strcmpi(char(string(hitElement)), 'pyro')
                baseMultiplier = 2.0;
            else
                baseMultiplier = 1.5;
            end
        otherwise
            baseMultiplier = 1.0;
    end

    emBonus = 2.78 * max(0, em) / (max(0, em) + 1400);
    multiplier = baseMultiplier * (1 + emBonus + max(0, reactionBonus));
end

function reaction = localResolvePrimaryReaction(enemyState, hitElement, forcedName, teamContext)
    reaction = struct('Name', "", 'ConsumedAura', "", 'AuraIndex', 0);
    if strlength(forcedName) > 0
        reaction.Name = string(forcedName);
        return;
    end

    hitElement = lower(char(string(hitElement)));
    if getFieldOrDefault(getFieldOrDefault(enemyState, 'Frozen', struct()), 'Active', false)
        switch hitElement
            case 'pyro'
                reaction.Name = "Melt";
                reaction.ConsumedAura = "Cryo";
                reaction.AuraIndex = localFindAuraIndex(enemyState, "Cryo");
                return;
            case 'electro'
                reaction.Name = localResolveSuperconductReactionName(teamContext);
                reaction.ConsumedAura = "Cryo";
                reaction.AuraIndex = localFindAuraIndex(enemyState, "Cryo");
                return;
            case 'dendro'
                reaction.Name = "Bloom";
                reaction.ConsumedAura = "Hydro";
                reaction.AuraIndex = localFindAuraIndex(enemyState, "Hydro");
                return;
        end
    end

    [auraIndex, auraElement] = localPickAura(enemyState);
    auraElementLower = lower(char(string(auraElement)));

    if getFieldOrDefault(enemyState.Quicken, 'Active', false)
        if strcmp(hitElement, 'electro')
            reaction.Name = "Aggravate";
            return;
        elseif strcmp(hitElement, 'dendro')
            reaction.Name = "Spread";
            return;
        elseif (~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)) && strcmp(hitElement, 'hydro')
            reaction.Name = "Bloom";
            reaction.ConsumedAura = "Quicken";
            return;
        elseif (~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)) && strcmp(hitElement, 'pyro')
            reaction.Name = "Burning";
            reaction.ConsumedAura = "Quicken";
            return;
        end
    end

    reaction.AuraIndex = auraIndex;
    reaction.ConsumedAura = auraElement;
    switch hitElement
        case 'hydro'
            switch auraElementLower
                case 'pyro'
                    reaction.Name = "Vaporize";
                case 'electro'
                    reaction.Name = "ElectroCharged";
                case 'dendro'
                    reaction.Name = "Bloom";
                case 'cryo'
                    reaction.Name = "Frozen";
            end
        case 'pyro'
            switch auraElementLower
                case 'hydro'
                    reaction.Name = "Vaporize";
                case 'cryo'
                    reaction.Name = "Melt";
                case 'electro'
                    reaction.Name = "Overload";
                case 'dendro'
                    reaction.Name = "Burning";
            end
        case 'cryo'
            switch auraElementLower
                case 'pyro'
                    reaction.Name = "Melt";
                case 'hydro'
                    reaction.Name = "Frozen";
                case 'electro'
                    reaction.Name = localResolveSuperconductReactionName(teamContext);
            end
        case 'electro'
            switch auraElementLower
                case 'hydro'
                    reaction.Name = "ElectroCharged";
                case 'pyro'
                    reaction.Name = "Overload";
                case 'cryo'
                    reaction.Name = localResolveSuperconductReactionName(teamContext);
                case 'dendro'
                    reaction.Name = "Quicken";
            end
        case 'dendro'
            switch auraElementLower
                case 'hydro'
                    reaction.Name = "Bloom";
                case 'electro'
                    reaction.Name = "Quicken";
                case 'pyro'
                    reaction.Name = "Burning";
            end
        case 'anemo'
            if any(strcmp(auraElement, ["Pyro", "Hydro", "Electro", "Cryo"]))
                reaction.Name = "Swirl";
            end
        case 'geo'
            if any(strcmp(auraElement, ["Pyro", "Hydro", "Electro", "Cryo"]))
                reaction.Name = "Crystallize";
            end
    end
end

function reactionName = localResolveSuperconductReactionName(teamContext)
    if logical(getFieldOrDefault(teamContext, 'StellarConductEnabled', false))
        reactionName = "StellarConduct";
    else
        reactionName = "Superconduct";
    end
end

function [auraIndex, auraElement] = localPickAura(enemyState)
    auraIndex = 0;
    auraElement = "";
    if ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    gauges = [enemyState.Auras.Gauge];
    maxGauge = max(gauges);
    candidateMask = abs(gauges - maxGauge) <= 1e-6;
    candidateIndices = find(candidateMask);
    if numel(candidateIndices) == 1
        auraIndex = candidateIndices(1);
    else
        sortRows = zeros(numel(candidateIndices), 4);
        for idx = 1:numel(candidateIndices)
            currentIndex = candidateIndices(idx);
            sortRows(idx, :) = [ ...
                -double(enemyState.Auras(currentIndex).Gauge), ...
                double(getFieldOrDefault(enemyState.Auras(currentIndex), 'AppliedSequence', currentIndex)), ...
                double(getFieldOrDefault(enemyState.Auras(currentIndex), 'AppliedTime', 0)), ...
                currentIndex];
        end
        sortRows = sortrows(sortRows, [1 2 3 4]);
        auraIndex = sortRows(1, 4);
    end
    auraElement = string(enemyState.Auras(auraIndex).Element);
end

function auraIndex = localFindAuraIndex(enemyState, auraElement)
    auraIndex = 0;
    if ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    for i = 1:numel(enemyState.Auras)
        if strcmpi(char(enemyState.Auras(i).Element), char(string(auraElement)))
            auraIndex = i;
            return;
        end
    end
end

function [enemyState, residualApplyGauge] = localConsumeAuraForAmplify(enemyState, reaction, applyGauge)
    residualApplyGauge = 0;
    if reaction.AuraIndex <= 0 || ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    auraElement = lower(char(string(reaction.ConsumedAura)));
    reactionName = lower(char(string(reaction.Name)));
    auraGauge = double(getFieldOrDefault(enemyState.Auras(reaction.AuraIndex), 'Gauge', 0));
    reactionCoeff = localResolveReactionCoefficient(reactionName, auraElement);
    taxedTriggerGauge = localResolveTaxedTriggerGauge(reactionName, applyGauge);
    residualApplyGauge = max(0, taxedTriggerGauge - auraGauge / max(reactionCoeff, eps));

    if strcmp(reactionName, 'vaporize')
        if strcmp(auraElement, 'pyro')
            consumed = 2.0 * taxedTriggerGauge;
        else
            consumed = 0.5 * taxedTriggerGauge;
        end
    elseif strcmp(reactionName, 'melt')
        if strcmp(auraElement, 'cryo')
            consumed = 2.0 * taxedTriggerGauge;
        else
            consumed = 0.5 * taxedTriggerGauge;
        end
    else
        consumed = reactionCoeff * taxedTriggerGauge;
    end

    enemyState.Auras(reaction.AuraIndex).Gauge = max(0, auraGauge - consumed);
    if enemyState.Auras(reaction.AuraIndex).Gauge <= 1e-6
        enemyState.Auras(reaction.AuraIndex) = [];
    end
    enemyState = localRefreshFrozenState(enemyState);
end

function enemyState = localConsumeAuraForDirectReaction(enemyState, reaction, applyGauge)
    [enemyState, ~] = localConsumeAuraForAmplify(enemyState, reaction, applyGauge);
end

function enemyState = localConsumeQuickenForAuraReaction(enemyState, applyGauge)
    if ~getFieldOrDefault(getFieldOrDefault(enemyState, 'Quicken', struct()), 'Active', false)
        return;
    end

    enemyState.Quicken.Gauge = max(0, double(getFieldOrDefault(enemyState.Quicken, 'Gauge', 0)) - localApplyAuraTax(applyGauge));
    enemyState.Quicken.Active = enemyState.Quicken.Gauge > 1e-6;
end

function gauge = localApplyAuraTax(applyGauge)
    gauge = max(0, 0.8 * double(applyGauge));
end

function gauge = localResolveTaxedTriggerGauge(reactionName, applyGauge)
    reactionName = lower(char(string(reactionName)));
    switch reactionName
        case {'swirl', 'crystallize'}
            gauge = max(0, 0.5 * double(applyGauge));
        otherwise
            gauge = localApplyAuraTax(applyGauge);
    end
end

function coeff = localResolveReactionCoefficient(reactionName, auraElement)
    reactionName = lower(char(string(reactionName)));
    auraElement = lower(char(string(auraElement)));

    switch reactionName
        case 'vaporize'
            if strcmp(auraElement, 'pyro')
                coeff = 2.0;
            else
                coeff = 0.5;
            end
        case 'melt'
            if strcmp(auraElement, 'cryo')
                coeff = 2.0;
            else
                coeff = 0.5;
            end
        otherwise
            coeff = 1.0;
    end
end

function [enemyState, quickenGauge, residualApplyGauge] = localConsumeAuraForQuicken(enemyState, reaction, applyGauge)
    quickenGauge = 0;
    residualApplyGauge = 0;
    if reaction.AuraIndex <= 0 || ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    auraGauge = double(getFieldOrDefault(enemyState.Auras(reaction.AuraIndex), 'Gauge', 0));
    taxedTriggerGauge = localResolveTaxedTriggerGauge(reaction.Name, applyGauge);
    quickenGauge = min(auraGauge, taxedTriggerGauge);
    [enemyState, residualApplyGauge] = localConsumeAuraForAmplify(enemyState, reaction, applyGauge);
end

function enemyState = localActivateQuicken(enemyState, quickenGauge)
    quickenGauge = max(0, double(quickenGauge));
    if quickenGauge <= 1e-6
        return;
    end

    existingGauge = double(getFieldOrDefault(enemyState.Quicken, 'Gauge', 0));
    enemyState.Quicken.Active = true;
    if quickenGauge > existingGauge + 1e-6
        enemyState.Quicken.Gauge = quickenGauge;
        enemyState.Quicken.DecayPerSecond = 1 / max(5 * quickenGauge + 6, 1.0);
    else
        enemyState.Quicken.Gauge = existingGauge;
    end
end

function enemyState = localActivateFrozen(enemyState, applyGauge)
    if ~isfield(enemyState, 'Frozen') || isempty(enemyState.Frozen)
        enemyState.Frozen = struct('Active', false, 'Gauge', 0, 'DecayPerSecond', 0.125);
    end
    enemyState.Frozen.Active = true;
    enemyState.Frozen.Gauge = max(getFieldOrDefault(enemyState.Frozen, 'Gauge', 0), applyGauge);
end

function enemyState = localApplyPostReactionAura(enemyState, applyElement, applyGauge, directReactionName)
    applyElement = string(applyElement);
    directReactionName = lower(char(string(directReactionName)));

    switch directReactionName
        case {'vaporize', 'melt'}
            if strcmpi(char(applyElement), 'anemo') || strcmpi(char(applyElement), 'geo')
                return;
            end
            enemyState = localAddOrReplaceAura(enemyState, applyElement, max(0, applyGauge));
        case {'overload', 'superconduct', 'stellarconduct', 'swirl', 'crystallize'}
            if strcmpi(char(applyElement), 'anemo') || strcmpi(char(applyElement), 'geo')
                return;
            end
            enemyState = localAddOrReplaceAura(enemyState, applyElement, max(0, applyGauge));
        case 'electrocharged'
            if strcmpi(char(applyElement), 'anemo') || strcmpi(char(applyElement), 'geo')
                return;
            end
            % Electro-Charged keeps Hydro and Electro coexisting for later hits.
            enemyState = localAddOrReplaceAura(enemyState, applyElement, applyGauge);
        case {'burning', 'bloom', 'hyperbloom', 'burgeon'}
            return;
        otherwise
            if strcmpi(char(applyElement), 'anemo') || strcmpi(char(applyElement), 'geo')
                return;
            end
            enemyState = localAddOrReplaceAura(enemyState, applyElement, applyGauge);
    end
end

function enemyState = localAddOrReplaceAura(enemyState, auraElement, gaugeUnits)
    if gaugeUnits <= 0 || strlength(string(auraElement)) == 0
        return;
    end

    nextSeq = getFieldOrDefault(enemyState, 'AuraSequenceCounter', 0) + 1;
    enemyState.AuraSequenceCounter = nextSeq;

    if ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        enemyState.Auras = localMakeAura(auraElement, gaugeUnits, getFieldOrDefault(enemyState, 'Time', 0), nextSeq);
        return;
    end

    for i = 1:numel(enemyState.Auras)
        if strcmpi(char(enemyState.Auras(i).Element), char(string(auraElement)))
            existingGauge = double(getFieldOrDefault(enemyState.Auras(i), 'Gauge', 0));
            existingDecay = double(getFieldOrDefault(enemyState.Auras(i), 'DecayPerSecond', ...
                localDefaultDecayPerSecond(auraElement, existingGauge)));
            remainingLifetime = existingGauge / max(existingDecay, 1e-9);
            refreshedLifetime = max(remainingLifetime, localResolveAuraLifetime(auraElement, gaugeUnits));
            enemyState.Auras(i).Gauge = max(existingGauge, gaugeUnits);
            enemyState.Auras(i).DecayPerSecond = enemyState.Auras(i).Gauge / max(refreshedLifetime, 1.0);
            enemyState.Auras(i).AppliedTime = getFieldOrDefault(enemyState, 'Time', 0);
            enemyState.Auras(i).AppliedSequence = nextSeq;
            return;
        end
    end

    enemyState.Auras(end + 1) = localMakeAura(auraElement, gaugeUnits, getFieldOrDefault(enemyState, 'Time', 0), nextSeq); %#ok<AGROW>
end

function enemyState = localForceAura(enemyState, auraElement, gaugeUnits)
    nextSeq = getFieldOrDefault(enemyState, 'AuraSequenceCounter', 0) + 1;
    enemyState.AuraSequenceCounter = nextSeq;
    enemyState.Auras = localMakeAura(auraElement, gaugeUnits, getFieldOrDefault(enemyState, 'Time', 0), nextSeq);
end

function enemyState = localEnsureSupportAura(enemyState, triggerElement, teamContext)
    if ~localUsesApproximateSupportAura(enemyState)
        return;
    end
    if (isfield(enemyState, 'Auras') && ~isempty(enemyState.Auras)) ...
            || getFieldOrDefault(enemyState.Quicken, 'Active', false)
        return;
    end

    supportAura = localInferSupportAura(triggerElement, teamContext);
    if strlength(supportAura) == 0
        return;
    end
    enemyState = localAddOrReplaceAura(enemyState, supportAura, getFieldOrDefault(enemyState, 'SupportAuraGauge', 1.0));
end

function aura = localInferSupportAura(triggerElement, teamContext)
    triggerElement = lower(char(string(triggerElement)));
    pyroCount = getFieldOrDefault(teamContext, 'PyroCount', 0);
    hydroCount = getFieldOrDefault(teamContext, 'HydroCount', 0);
    cryoCount = getFieldOrDefault(teamContext, 'CryoCount', 0);
    dendroCount = getFieldOrDefault(teamContext, 'DendroCount', 0);
    electroCount = getFieldOrDefault(teamContext, 'ElectroCount', 0);

    switch triggerElement
        case 'hydro'
            if pyroCount >= 1
                aura = "Pyro";
            elseif electroCount >= 1
                aura = "Electro";
            elseif dendroCount >= 1
                aura = "Dendro";
            else
                aura = "";
            end
        case 'pyro'
            if cryoCount >= 1
                aura = "Cryo";
            elseif hydroCount >= 1
                aura = "Hydro";
            elseif electroCount >= 1
                aura = "Electro";
            elseif dendroCount >= 1
                aura = "Dendro";
            else
                aura = "";
            end
        case 'cryo'
            if pyroCount >= 1
                aura = "Pyro";
            elseif hydroCount >= 1
                aura = "Hydro";
            elseif electroCount >= 1
                aura = "Electro";
            else
                aura = "";
            end
        case 'electro'
            if hydroCount >= 1
                aura = "Hydro";
            elseif pyroCount >= 1
                aura = "Pyro";
            elseif dendroCount >= 1
                aura = "Dendro";
            else
                aura = "";
            end
        case 'dendro'
            if hydroCount >= 1
                aura = "Hydro";
            elseif electroCount >= 1
                aura = "Electro";
            elseif pyroCount >= 1
                aura = "Pyro";
            else
                aura = "";
            end
        otherwise
            aura = "";
    end
end

function tf = localUsesApproximateSupportAura(enemyState)
    reactionMode = lower(char(string(getFieldOrDefault(enemyState, 'ReactionMode', ""))));
    if strlength(string(reactionMode)) == 0
        tf = logical(getFieldOrDefault(enemyState, 'AutoSupportAura', true));
        return;
    end
    tf = strcmp(reactionMode, 'approximate') && logical(getFieldOrDefault(enemyState, 'AutoSupportAura', true));
end

function damage = localResolvePacketDamage(packet, build, teamContext, enemy, enemyState)
    reactionName = string(getFieldOrDefault(packet, 'ReactionName', ""));
    hitDescriptor = struct( ...
        'ReactionElement', string(getFieldOrDefault(packet, 'ReactionElement', localReactionElement(reactionName))), ...
        'ReactionCritRate', getFieldOrDefault(packet, 'CritRate', []), ...
        'ReactionCritDMG', getFieldOrDefault(packet, 'CritDMG', []), ...
        'ReactionEMOverride', getFieldOrDefault(packet, 'SourceEM', []), ...
        'ReactionResShredOverride', getFieldOrDefault(packet, 'SourceResShred', []), ...
        'UseReactionBonusSnapshot', logical(getFieldOrDefault(packet, 'UseSnapshot', false)));
    damage = localResolveTransformativeDamage( ...
        reactionName, build, teamContext, enemy, enemyState, 0, ...
        getFieldOrDefault(packet, 'ReactionBonus', 0), hitDescriptor);
end

function element = localReactionElement(reactionName)
    switch lower(char(string(reactionName)))
        case {'overload', 'burning', 'burgeon'}
            element = "Pyro";
        case {'electrocharged', 'aggravate'}
            element = "Electro";
        case {'spread', 'bloom', 'hyperbloom'}
            element = "Dendro";
        case 'swirl'
            element = "Anemo";
        case 'crystallize'
            element = "Geo";
        case 'superconduct'
            element = "Cryo";
        case 'stellarconduct'
            element = "Cryo";
        case 'shatter'
            element = "Physical";
        otherwise
            element = "";
    end
end

function result = localResolveSupplementalReactions(result, preReactionEnemyState, directReaction, hitDescriptor, build, teamContext, enemy, applyGauge)
    result = localResolveCoexistingAuraSupplementalReactions( ...
        result, preReactionEnemyState, directReaction, hitDescriptor, build, teamContext, enemy, applyGauge);
    result = localResolveShatterReaction(result, hitDescriptor, build, teamContext, enemy, applyGauge);
    result = localResolveCoreConversionReaction(result, hitDescriptor, build, teamContext, enemy);
end

function result = localResolveCoexistingAuraSupplementalReactions( ...
        result, preReactionEnemyState, directReaction, hitDescriptor, build, teamContext, enemy, applyGauge)
    result = localResolveHydroElectroSupplementalReactions( ...
        result, preReactionEnemyState, directReaction, hitDescriptor, build, teamContext, enemy, applyGauge);
    result = localResolveElectroDendroSupplementalReactions( ...
        result, preReactionEnemyState, directReaction, hitDescriptor, build, teamContext, enemy, applyGauge);
end

function result = localResolveHydroElectroSupplementalReactions( ...
        result, preReactionEnemyState, directReaction, hitDescriptor, build, teamContext, enemy, applyGauge)
    if ~localHasCoexistingAura(preReactionEnemyState, "Hydro", "Electro")
        return;
    end

    hitElement = lower(char(string(getFieldOrDefault(hitDescriptor, 'HitElement', ""))));
    directReactionName = lower(char(string(getFieldOrDefault(directReaction, 'Name', ""))));
    superconductName = localResolveSuperconductReactionName(teamContext);

    switch hitElement
        case 'pyro'
            if ~strcmp(directReactionName, 'vaporize')
                result = localApplySecondaryReaction( ...
                    result, "Vaporize", "Hydro", hitDescriptor, build, teamContext, enemy, applyGauge);
            end
            if ~strcmp(directReactionName, 'overload')
                result = localApplySecondaryReaction( ...
                    result, "Overload", "Electro", hitDescriptor, build, teamContext, enemy, applyGauge);
            end
        case 'cryo'
            if ~strcmp(directReactionName, 'frozen')
                result = localApplySecondaryReaction( ...
                    result, "Frozen", "Hydro", hitDescriptor, build, teamContext, enemy, applyGauge);
            end
            if ~strcmpi(directReactionName, char(superconductName))
                result = localApplySecondaryReaction( ...
                    result, superconductName, "Electro", hitDescriptor, build, teamContext, enemy, applyGauge);
            end
        case 'dendro'
            if ~strcmp(directReactionName, 'bloom')
                result = localApplySecondaryReaction( ...
                    result, "Bloom", "Hydro", hitDescriptor, build, teamContext, enemy, applyGauge);
            end
            if ~strcmp(directReactionName, 'quicken')
                result = localApplySecondaryReaction( ...
                    result, "Quicken", "Electro", hitDescriptor, build, teamContext, enemy, applyGauge);
            end
    end
end

function result = localResolveElectroDendroSupplementalReactions( ...
        result, preReactionEnemyState, directReaction, hitDescriptor, build, teamContext, enemy, applyGauge)
    hasElectroAura = localAuraGauge(preReactionEnemyState, "Electro") > 1e-6;
    hasDendroAura = localAuraGauge(preReactionEnemyState, "Dendro") > 1e-6;
    hasQuickenAura = getFieldOrDefault(getFieldOrDefault(preReactionEnemyState, 'Quicken', struct()), 'Active', false);
    if ~hasElectroAura || (~hasDendroAura && ~hasQuickenAura)
        return;
    end

    hitElement = lower(char(string(getFieldOrDefault(hitDescriptor, 'HitElement', ""))));
    directReactionName = lower(char(string(getFieldOrDefault(directReaction, 'Name', ""))));
    dendroReactionAura = localResolveDendroReactionSupplementalAura(preReactionEnemyState);
    if strlength(dendroReactionAura) == 0
        return;
    end

    switch hitElement
        case 'hydro'
            if ~strcmp(directReactionName, 'electrocharged')
                result = localApplySecondaryReaction( ...
                    result, "ElectroCharged", "Electro", hitDescriptor, build, teamContext, enemy, applyGauge);
            end
            if ~strcmp(directReactionName, 'bloom')
                result = localApplySecondaryReaction( ...
                    result, "Bloom", dendroReactionAura, hitDescriptor, build, teamContext, enemy, applyGauge);
            end
        case 'pyro'
            if ~strcmp(directReactionName, 'overload')
                result = localApplySecondaryReaction( ...
                    result, "Overload", "Electro", hitDescriptor, build, teamContext, enemy, applyGauge);
            end
            if ~strcmp(directReactionName, 'burning')
                result = localApplySecondaryReaction( ...
                    result, "Burning", dendroReactionAura, hitDescriptor, build, teamContext, enemy, applyGauge);
            end
    end
end

function aura = localResolveDendroReactionSupplementalAura(enemyState)
    if localAuraGauge(enemyState, "Dendro") > 1e-6
        aura = "Dendro";
    elseif getFieldOrDefault(getFieldOrDefault(enemyState, 'Quicken', struct()), 'Active', false)
        aura = "Quicken";
    else
        aura = "";
    end
end

function result = localApplySecondaryReaction( ...
        result, reactionName, consumedAura, hitDescriptor, build, teamContext, enemy, applyGauge)
    reactionName = string(reactionName);
    reaction = struct( ...
        'Name', reactionName, ...
        'ConsumedAura', string(consumedAura), ...
        'AuraIndex', localFindAuraIndex(result.EnemyState, consumedAura));

    switch lower(char(reactionName))
        case {'vaporize', 'melt'}
            if logical(getFieldOrDefault(hitDescriptor, 'AllowAmplify', false))
                emOverride = getFieldOrDefault(hitDescriptor, 'ReactionEMOverride', []);
                if isempty(emOverride)
                    em = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
                else
                    em = double(emOverride);
                end
                reactionBonus = getFieldOrDefault(hitDescriptor, 'ReactionBonus', getFieldOrDefault(build, 'ReactionDMGBonus', 0));
                result.AmplifyMultiplier = max( ...
                    result.AmplifyMultiplier, ...
                    localAmplifyMultiplier(reactionName, getFieldOrDefault(hitDescriptor, 'HitElement', ""), em, reactionBonus));
            end
            [result.EnemyState, ~] = localConsumeAuraForAmplify(result.EnemyState, reaction, applyGauge);
        case 'frozen'
            result.EnemyState = localConsumeAuraForDirectReaction(result.EnemyState, reaction, applyGauge);
            result.EnemyState = localActivateFrozen(result.EnemyState, applyGauge);
        case 'quicken'
            [result.EnemyState, quickenGauge] = localConsumeAuraForQuicken(result.EnemyState, reaction, applyGauge);
            result.EnemyState = localActivateQuicken(result.EnemyState, quickenGauge);
        otherwise
            result = localResolveTransformativeReaction( ...
                result, reaction, hitDescriptor, build, teamContext, enemy, applyGauge);
    end

    result.TriggeredReactions(end + 1, 1) = lower(reactionName); %#ok<AGROW>
end

function result = localResolveShatterReaction(result, hitDescriptor, build, teamContext, enemy, applyGauge)
    if ~getFieldOrDefault(getFieldOrDefault(result.EnemyState, 'Frozen', struct()), 'Active', false)
        return;
    end
    if ~localCanTriggerShatter(hitDescriptor)
        return;
    end

    shatterDescriptor = localDecorateReactionElement(hitDescriptor, "Shatter", struct());
    shatterDescriptor.ReactionElement = "Physical";
    result.ReactionDamage = result.ReactionDamage + localResolveTransformativeDamage( ...
        "Shatter", build, teamContext, enemy, result.EnemyState, 0, ...
        getFieldOrDefault(hitDescriptor, 'ReactionBonus', 0), shatterDescriptor);
    result.EnemyState = localConsumeFrozenState(result.EnemyState, max(1.0, applyGauge));
    if result.PrimaryReaction == ""
        result.PrimaryReaction = "Shatter";
    end
    result.TriggeredReactions(end + 1, 1) = "shatter"; %#ok<AGROW>
end

function result = localResolveCoreConversionReaction(result, hitDescriptor, build, teamContext, enemy)
    if ~isfield(result.EnemyState, 'DendroCores') || isempty(result.EnemyState.DendroCores)
        return;
    end

    hitElement = lower(char(string(getFieldOrDefault(hitDescriptor, 'HitElement', ""))));
    switch hitElement
        case 'electro'
            reactionName = "Hyperbloom";
        case 'pyro'
            reactionName = "Burgeon";
        otherwise
            return;
    end

    coreCount = min(numel(result.EnemyState.DendroCores), max(1, round(double(getFieldOrDefault(hitDescriptor, 'CoreReactionCount', 1)))));
    if coreCount <= 0
        return;
    end

    reactionDescriptor = localDecorateReactionElement(hitDescriptor, reactionName, struct());
    for i = 1:coreCount
        result.ReactionDamage = result.ReactionDamage + localResolveTransformativeDamage( ...
            reactionName, build, teamContext, enemy, result.EnemyState, 0, ...
            getFieldOrDefault(hitDescriptor, 'ReactionBonus', 0), reactionDescriptor);
    end
    result.EnemyState.DendroCores(1:coreCount) = [];
    if result.PrimaryReaction == ""
        result.PrimaryReaction = reactionName;
    end
    result.TriggeredReactions(end + 1, 1) = lower(string(reactionName)); %#ok<AGROW>
end

function tf = localCanTriggerShatter(hitDescriptor)
    hitElement = lower(char(string(getFieldOrDefault(hitDescriptor, 'HitElement', ""))));
    strikeType = lower(char(string(getFieldOrDefault(hitDescriptor, 'StrikeType', ""))));
    tf = logical(getFieldOrDefault(hitDescriptor, 'CanShatter', false)) ...
        || strcmp(hitElement, 'geo') ...
        || strcmp(strikeType, 'blunt');
end

function enemyState = localConsumeFrozenState(enemyState, consumedGauge)
    enemyState = localConsumeAuraByElement(enemyState, "Hydro", 0.5 * consumedGauge);
    enemyState = localConsumeAuraByElement(enemyState, "Cryo", 0.5 * consumedGauge);
    enemyState = localRefreshFrozenState(enemyState);
end

function tf = localHasCoexistingAura(enemyState, firstElement, secondElement)
    tf = localAuraGauge(enemyState, firstElement) > 1e-6 ...
        && localAuraGauge(enemyState, secondElement) > 1e-6;
end

function enemyState = localConsumeAuraByElement(enemyState, auraElement, consumedGauge)
    if consumedGauge <= 0 || ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    keepMask = true(1, numel(enemyState.Auras));
    for i = 1:numel(enemyState.Auras)
        if strcmpi(char(enemyState.Auras(i).Element), char(string(auraElement)))
            enemyState.Auras(i).Gauge = max(0, enemyState.Auras(i).Gauge - consumedGauge);
            keepMask(i) = enemyState.Auras(i).Gauge > 1e-6;
            break;
        end
    end
    enemyState.Auras = enemyState.Auras(keepMask);
end

function enemyState = localRefreshFrozenState(enemyState)
    if ~isfield(enemyState, 'Frozen') || isempty(enemyState.Frozen)
        enemyState.Frozen = struct('Active', false, 'Gauge', 0, 'DecayPerSecond', 0.125);
    end

    hydroGauge = localAuraGauge(enemyState, "Hydro");
    cryoGauge = localAuraGauge(enemyState, "Cryo");
    enemyState.Frozen.Gauge = min(hydroGauge, cryoGauge);
    enemyState.Frozen.Active = enemyState.Frozen.Gauge > 1e-6;
end

function gauge = localAuraGauge(enemyState, auraElement)
    gauge = 0;
    if ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    for i = 1:numel(enemyState.Auras)
        if strcmpi(char(enemyState.Auras(i).Element), char(string(auraElement)))
            gauge = max(gauge, double(enemyState.Auras(i).Gauge));
        end
    end
end

function tf = localShouldDealDirectTransformativeDamage(reactionName, hitDescriptor, customBase)
    tf = logical(getFieldOrDefault(hitDescriptor, 'AllowTransformative', false)) || customBase > 0;
    if tf
        return;
    end

    switch lower(char(string(reactionName)))
        case {'overload', 'superconduct', 'stellarconduct', 'swirl', 'lunarcharged', 'lunarbloom'}
            tf = true;
        otherwise
            tf = false;
    end
end

function tf = localShouldConsumeAuraOnDirectTransformativeReaction(reactionName)
    switch lower(char(string(reactionName)))
        case {'overload', 'superconduct', 'stellarconduct', 'swirl', 'crystallize', 'bloom', 'burning'}
            tf = true;
        otherwise
            tf = false;
    end
end

function tf = localShouldConsumeQuickenOnTransformativeReaction(reactionName, reaction, enemyState)
    tf = any(strcmpi(char(string(reactionName)), {'bloom', 'burning'})) ...
        && getFieldOrDefault(getFieldOrDefault(enemyState, 'Quicken', struct()), 'Active', false) ...
        && strcmpi(char(string(getFieldOrDefault(reaction, 'ConsumedAura', ""))), 'quicken');
end

function state = localActivateTimedReactionState(state, applyGauge, reactionBonus, hitDescriptor, build, teamContext, reactionElement)
    state.Active = true;
    state.Gauge = max(getFieldOrDefault(state, 'Gauge', 0), applyGauge);
    state.DecayPerSecond = localDefaultDecayPerSecond(reactionElement, state.Gauge);
    state.TickTimer = 0;
    state.ReactionBonus = reactionBonus;
    state.SourceEM = getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0);
    state.SourceCritRate = getFieldOrDefault(hitDescriptor, 'ReactionCritRate', getFieldOrDefault(teamContext, 'ReactionCritRate', []));
    state.SourceCritDMG = getFieldOrDefault(hitDescriptor, 'ReactionCritDMG', getFieldOrDefault(teamContext, 'ReactionCritDMG', []));
    state.SourceResShred = getElementResShredValue(reactionElement, build, teamContext) ...
        + getFieldOrDefault(hitDescriptor, 'ExtraResShred', 0);
    state.ReactionElement = string(reactionElement);
    state.SourceType = string(getFieldOrDefault(hitDescriptor, 'SourceType', ""));
    state.SourceCharacter = string(getFieldOrDefault(hitDescriptor, 'SourceCharacter', ""));
    state.SourceAction = string(getFieldOrDefault(hitDescriptor, 'SourceAction', ""));
    state.UseSnapshot = true;
end

function core = localMakeDendroCore(applyGauge, reactionBonus, hitDescriptor, build, teamContext)
    core = struct( ...
        'TimeRemaining', 6.0, ...
        'Gauge', applyGauge, ...
        'OwnerElement', "Dendro", ...
        'ReactionName', "Bloom", ...
        'ReactionBonus', reactionBonus, ...
        'SourceEM', getFieldOrDefault(build, 'EM', 0) + getFieldOrDefault(teamContext, 'EMBonus', 0), ...
        'SourceCritRate', getFieldOrDefault(hitDescriptor, 'ReactionCritRate', getFieldOrDefault(teamContext, 'ReactionCritRate', [])), ...
        'SourceCritDMG', getFieldOrDefault(hitDescriptor, 'ReactionCritDMG', getFieldOrDefault(teamContext, 'ReactionCritDMG', [])), ...
        'SourceResShred', getElementResShredValue("Dendro", build, teamContext) + getFieldOrDefault(hitDescriptor, 'ExtraResShred', 0), ...
        'ReactionElement', "Dendro", ...
        'SourceType', string(getFieldOrDefault(hitDescriptor, 'SourceType', "")), ...
        'SourceCharacter', string(getFieldOrDefault(hitDescriptor, 'SourceCharacter', "")), ...
        'SourceAction', string(getFieldOrDefault(hitDescriptor, 'SourceAction', "")), ...
        'UseSnapshot', true);
end

function damage = localResolveStoredReactionDamage(reactionName, snapshot, build, teamContext, enemy, enemyState)
    hitDescriptor = struct( ...
        'ReactionElement', string(getFieldOrDefault(snapshot, 'ReactionElement', localReactionElement(reactionName))), ...
        'ReactionCritRate', getFieldOrDefault(snapshot, 'SourceCritRate', []), ...
        'ReactionCritDMG', getFieldOrDefault(snapshot, 'SourceCritDMG', []), ...
        'ReactionEMOverride', getFieldOrDefault(snapshot, 'SourceEM', []), ...
        'ReactionResShredOverride', getFieldOrDefault(snapshot, 'SourceResShred', []), ...
        'UseReactionBonusSnapshot', true);
    damage = localResolveTransformativeDamage( ...
        reactionName, build, teamContext, enemy, enemyState, 0, ...
        getFieldOrDefault(snapshot, 'ReactionBonus', 0), hitDescriptor);
end

function aura = localMakeAura(element, gaugeUnits, appliedTime, appliedSequence)
    if nargin < 3 || isempty(appliedTime)
        appliedTime = 0;
    end
    if nargin < 4 || isempty(appliedSequence)
        appliedSequence = 0;
    end
    aura = struct( ...
        'Element', string(element), ...
        'Gauge', max(0, double(gaugeUnits)), ...
        'DecayPerSecond', localDefaultDecayPerSecond(element, gaugeUnits), ...
        'AppliedTime', double(appliedTime), ...
        'AppliedSequence', double(appliedSequence));
end

function decayPerSecond = localDefaultDecayPerSecond(auraElement, gaugeUnits)
    duration = localResolveAuraLifetime(auraElement, gaugeUnits);
    gaugeUnits = max(0.25, double(gaugeUnits));
    decayPerSecond = gaugeUnits / max(duration, 1.0);
end

function duration = localResolveAuraLifetime(auraElement, gaugeUnits)
    auraElement = lower(char(string(auraElement)));
    gaugeUnits = max(0.25, double(gaugeUnits));
    switch auraElement
        case {'pyro', 'hydro', 'cryo', 'electro', 'dendro'}
            % Approximate the standard origin-aura lifetime in seconds from the
            % raw applied gauge, then convert it into a linear gauge decay rate.
            duration = 2.5 * gaugeUnits + 7.0;
        otherwise
            duration = 2.0 * gaugeUnits + 6.0;
    end
end

function result = localMakeEmptyResult(enemyState)
    result = struct( ...
        'EnemyState', enemyState, ...
        'AmplifyMultiplier', 1.0, ...
        'CatalyzeFlatDamage', 0, ...
        'ReactionDamage', 0, ...
        'PrimaryReaction', "", ...
        'TriggeredReactions', strings(0, 1));
end

function enemyState = localEnsureEnemyStateSchema(enemyState)
    defaults = createEnemyState(struct(), struct(), "");
    defaultFields = fieldnames(defaults);
    for i = 1:numel(defaultFields)
        fieldName = defaultFields{i};
        if ~isfield(enemyState, fieldName) || isempty(enemyState.(fieldName))
            enemyState.(fieldName) = defaults.(fieldName);
        end
    end
end
