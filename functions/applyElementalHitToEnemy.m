function [enemyState, reaction] = applyElementalHitToEnemy(enemyState, triggerElement, gaugeUnits, teamContext, deltaTime)
    % 将一次元素命中结算到敌人附着状态上，并返回此次命中的反应结果。
    if nargin < 3 || isempty(gaugeUnits)
        gaugeUnits = 1.0;
    end
    if nargin < 4 || isempty(teamContext)
        teamContext = struct();
    end
    if nargin < 5 || isempty(deltaTime)
        deltaTime = 0;
    end

    triggerElement = string(triggerElement);
    reaction = struct( ...
        'Name', "", ...
        'IsAmplifying', false, ...
        'AmplifyMultiplier', 1.0, ...
        'ConsumedAura', "", ...
        'AppliedAura', triggerElement);

    if ~logical(getFieldOrDefault(enemyState, 'EnableElementalAura', true))
        return;
    end

    enemyState = localAdvanceTime(enemyState, deltaTime);
    enemyState = localEnsureSupportAura(enemyState, triggerElement, teamContext);
    [auraIndex, auraElement, auraGauge] = localPickAura(enemyState);
    if auraIndex == 0
        enemyState = localReplaceAura(enemyState, triggerElement, gaugeUnits);
        return;
    end

    reaction = localResolveReaction(triggerElement, auraElement);
    reaction.ConsumedAura = auraElement;
    if reaction.Name == ""
        enemyState = localReplaceAura(enemyState, triggerElement, max(gaugeUnits, auraGauge));
        return;
    end

    if reaction.IsAmplifying
        enemyState.Auras(auraIndex).Gauge = max(0, auraGauge - localAmpConsumption(triggerElement, auraElement, gaugeUnits));
        if enemyState.Auras(auraIndex).Gauge <= 1e-6
            enemyState.Auras(auraIndex) = [];
            enemyState = localEnsureSupportAura(enemyState, triggerElement, teamContext);
        end
    else
        enemyState.Auras(auraIndex).Gauge = max(0, auraGauge - 0.80 * gaugeUnits);
        if enemyState.Auras(auraIndex).Gauge <= 1e-6
            enemyState.Auras(auraIndex) = [];
            enemyState = localReplaceAura(enemyState, triggerElement, 0.60 * gaugeUnits);
        end
    end

    enemyState.LastReaction = reaction.Name;
end

function enemyState = localAdvanceTime(enemyState, deltaTime)
    enemyState.Time = getFieldOrDefault(enemyState, 'Time', 0) + deltaTime;
    if ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    decayPerSecond = 0.16;
    keepMask = true(1, numel(enemyState.Auras));
    for i = 1:numel(enemyState.Auras)
        enemyState.Auras(i).Gauge = max(0, enemyState.Auras(i).Gauge - decayPerSecond * deltaTime);
        keepMask(i) = enemyState.Auras(i).Gauge > 1e-6;
    end
    enemyState.Auras = enemyState.Auras(keepMask);
end

function enemyState = localEnsureSupportAura(enemyState, triggerElement, teamContext)
    if ~logical(getFieldOrDefault(enemyState, 'AutoSupportAura', true))
        return;
    end
    if isfield(enemyState, 'Auras') && ~isempty(enemyState.Auras)
        return;
    end

    supportAura = localInferSupportAura(triggerElement, teamContext);
    if strlength(supportAura) == 0
        return;
    end
    enemyState = localReplaceAura(enemyState, supportAura, getFieldOrDefault(enemyState, 'SupportAuraGauge', 1.0));
end

function [auraIndex, auraElement, auraGauge] = localPickAura(enemyState)
    auraIndex = 0;
    auraElement = "";
    auraGauge = 0;
    if ~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)
        return;
    end

    gauges = [enemyState.Auras.Gauge];
    [auraGauge, auraIndex] = max(gauges);
    auraElement = string(enemyState.Auras(auraIndex).Element);
end

function enemyState = localReplaceAura(enemyState, auraElement, gaugeUnits)
    if gaugeUnits <= 0 || strlength(string(auraElement)) == 0
        return;
    end
    enemyState.Auras = struct('Element', string(auraElement), 'Gauge', gaugeUnits);
end

function reaction = localResolveReaction(triggerElement, auraElement)
    triggerElement = lower(char(string(triggerElement)));
    auraElement = lower(char(string(auraElement)));

    reaction = struct( ...
        'Name', "", ...
        'IsAmplifying', false, ...
        'AmplifyMultiplier', 1.0);

    switch triggerElement
        case 'hydro'
            switch auraElement
                case 'pyro'
                    reaction.Name = "Vaporize";
                    reaction.IsAmplifying = true;
                    reaction.AmplifyMultiplier = 2.0;
                case 'electro'
                    reaction.Name = "ElectroCharged";
                case 'dendro'
                    reaction.Name = "Bloom";
                case 'cryo'
                    reaction.Name = "Frozen";
            end

        case 'pyro'
            switch auraElement
                case 'hydro'
                    reaction.Name = "Vaporize";
                    reaction.IsAmplifying = true;
                    reaction.AmplifyMultiplier = 1.5;
                case 'cryo'
                    reaction.Name = "Melt";
                    reaction.IsAmplifying = true;
                    reaction.AmplifyMultiplier = 2.0;
                case 'electro'
                    reaction.Name = "Overload";
                case 'dendro'
                    reaction.Name = "Burning";
            end

        case 'cryo'
            switch auraElement
                case 'pyro'
                    reaction.Name = "Melt";
                    reaction.IsAmplifying = true;
                    reaction.AmplifyMultiplier = 1.5;
                case 'hydro'
                    reaction.Name = "Frozen";
            end

        case 'electro'
            switch auraElement
                case 'hydro'
                    reaction.Name = "ElectroCharged";
                case 'pyro'
                    reaction.Name = "Overload";
                case 'dendro'
                    reaction.Name = "Quicken";
            end

        case 'dendro'
            switch auraElement
                case 'hydro'
                    reaction.Name = "Bloom";
                case 'electro'
                    reaction.Name = "Quicken";
                case 'pyro'
                    reaction.Name = "Burning";
            end
    end
end

function consumed = localAmpConsumption(triggerElement, auraElement, gaugeUnits)
    triggerElement = lower(char(string(triggerElement)));
    auraElement = lower(char(string(auraElement)));

    switch [triggerElement '>' auraElement]
        case 'hydro>pyro'
            consumed = 0.50 * gaugeUnits;
        case 'pyro>hydro'
            consumed = 1.00 * gaugeUnits;
        case 'pyro>cryo'
            consumed = 0.50 * gaugeUnits;
        case 'cryo>pyro'
            consumed = 1.00 * gaugeUnits;
        otherwise
            consumed = 1.00 * gaugeUnits;
    end
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
