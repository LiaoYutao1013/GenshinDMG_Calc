function enemyState = createEnemyState(enemy, teamContext, triggerElement)
    % 创建一个轻量级敌人元素附着状态。
    % 当前版本优先解决“能否稳定打出增幅反应”的问题：
    % 1. 支持初始附着；
    % 2. 支持按队伍构成自动补充支援附着；
    % 3. 支持简单的附着衰减与消耗；
    % 4. 后续角色可在此基础上继续扩展更复杂的反应链。
    if nargin < 1 || isempty(enemy)
        enemy = struct();
    end
    if nargin < 2 || isempty(teamContext)
        teamContext = struct();
    end
    if nargin < 3
        triggerElement = "";
    end

    initialElement = string(getFieldOrDefault(enemy, 'InitialAuraElement', ""));
    initialGauge = double(getFieldOrDefault(enemy, 'InitialAuraGauge', 0));
    if strlength(initialElement) == 0
        initialElement = localInferSupportAura(triggerElement, teamContext);
        initialGauge = 1.0 * double(strlength(initialElement) > 0);
    end

    auras = repmat(struct('Element', "", 'Gauge', 0), 1, 0);
    if strlength(initialElement) > 0 && initialGauge > 0
        auras = struct('Element', initialElement, 'Gauge', initialGauge);
    end

    enemyState = struct( ...
        'Time', 0, ...
        'Auras', auras, ...
        'EnableElementalAura', logical(getFieldOrDefault(enemy, 'EnableElementalAura', true)), ...
        'AutoSupportAura', logical(getFieldOrDefault(enemy, 'AutoSupportAura', true)), ...
        'SupportAuraGauge', double(getFieldOrDefault(enemy, 'SupportAuraGauge', 1.0)), ...
        'LastReaction', "");
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
