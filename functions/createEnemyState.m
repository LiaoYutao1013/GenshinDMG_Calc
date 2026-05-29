function enemyState = createEnemyState(enemy, teamContext, triggerElement)
    % 创建统一怪物元素状态。
    %
    % 该状态对象同时服务于：
    % 1. 通用角色模拟器；
    % 2. 队伍模拟入口；
    % 3. 统一元素反应结算引擎。
    %
    % 当前版本除了常规元素附着外，还显式维护：
    % - 激化底态；
    % - 感电持续态；
    % - 燃烧持续态；
    % - 绽放种子列表。
    if nargin < 1 || isempty(enemy)
        enemy = struct();
    end
    if nargin < 2 || isempty(teamContext)
        teamContext = struct();
    end
    if nargin < 3
        triggerElement = "";
    end

    reactionMode = localResolveReactionMode(enemy, teamContext);
    autoSupportAura = logical(getFieldOrDefault(enemy, 'AutoSupportAura', reactionMode == "Approximate"));

    initialElement = string(getFieldOrDefault(enemy, 'InitialAuraElement', ""));
    initialGauge = double(getFieldOrDefault(enemy, 'InitialAuraGauge', 0));
    if strlength(initialElement) == 0 && autoSupportAura
        initialElement = localInferSupportAura(triggerElement, teamContext);
        initialGauge = 1.0 * double(strlength(initialElement) > 0);
    end

    auras = repmat(localMakeAura("", 0, 0, 0), 1, 0);
    if strlength(initialElement) > 0 && initialGauge > 0
        auras = localMakeAura(initialElement, initialGauge, 0, 1);
    end

    enemyState = struct( ...
        'Time', 0, ...
        'Auras', auras, ...
        'AuraSequenceCounter', double(numel(auras)), ...
        'Quicken', struct('Active', false, 'Gauge', 0, 'DecayPerSecond', 0.125), ...
        'Frozen', struct('Active', false, 'Gauge', 0, 'DecayPerSecond', 0.125), ...
        'ElectroCharged', localMakeTimedReactionState(1.0, "Electro"), ...
        'Burning', localMakeTimedReactionState(0.25, "Pyro"), ...
        'DendroCores', repmat(localMakeDendroCore(), 1, 0), ...
        'EnableElementalAura', logical(getFieldOrDefault(enemy, 'EnableElementalAura', true)), ...
        'ReactionMode', reactionMode, ...
        'AutoSupportAura', autoSupportAura, ...
        'SupportAuraGauge', double(getFieldOrDefault(enemy, 'SupportAuraGauge', 1.0)), ...
        'ReactionLevel', double(getFieldOrDefault(enemy, 'ReactionLevel', 90)), ...
        'AuraDecayScale', double(getFieldOrDefault(enemy, 'AuraDecayScale', 1.0)), ...
        'LastReaction', "");
end

function reactionMode = localResolveReactionMode(enemy, teamContext)
    % ReactionMode controls whether the enemy state should synthesize a
    % support aura automatically. "Realistic" means every aura must come
    % from explicit hits or an explicit enemy initial state.
    reactionMode = string(getFieldOrDefault(enemy, 'ReactionMode', ""));
    if strlength(reactionMode) == 0
        reactionMode = string(getFieldOrDefault(teamContext, 'ReactionMode', ""));
    end
    token = lower(char(reactionMode));
    switch token
        case {'realistic', 'real', 'explicit', 'sequence'}
            reactionMode = "Realistic";
        case {'approximate', 'approx', 'supportaura', 'legacy'}
            reactionMode = "Approximate";
        otherwise
            reactionMode = "Approximate";
    end
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

function state = localMakeTimedReactionState(tickInterval, reactionElement)
    state = struct( ...
        'Active', false, ...
        'Gauge', 0, ...
        'DecayPerSecond', 0.10, ...
        'TickTimer', 0, ...
        'TickInterval', double(tickInterval), ...
        'ReactionBonus', 0, ...
        'SourceEM', 0, ...
        'SourceCritRate', [], ...
        'SourceCritDMG', [], ...
        'SourceResShred', 0, ...
        'ReactionElement', string(reactionElement), ...
        'SourceType', "", ...
        'SourceCharacter', "", ...
        'SourceAction', "", ...
        'UseSnapshot', false);
end

function core = localMakeDendroCore()
    core = struct( ...
        'TimeRemaining', 0, ...
        'Gauge', 0, ...
        'OwnerElement', "Dendro", ...
        'ReactionName', "Bloom", ...
        'ReactionBonus', 0, ...
        'SourceEM', 0, ...
        'SourceCritRate', [], ...
        'SourceCritDMG', [], ...
        'SourceResShred', 0, ...
        'ReactionElement', "Dendro", ...
        'SourceType', "", ...
        'SourceCharacter', "", ...
        'SourceAction', "", ...
        'UseSnapshot', false);
end

function decayPerSecond = localDefaultDecayPerSecond(auraElement, gaugeUnits)
    auraElement = lower(char(string(auraElement)));
    gaugeUnits = max(0.25, double(gaugeUnits));

    switch auraElement
        case {'pyro', 'hydro', 'cryo', 'electro', 'dendro'}
            duration = 2.5 * gaugeUnits + 7.0;
        otherwise
            duration = 2.0 * gaugeUnits + 6.0;
    end

    decayPerSecond = gaugeUnits / max(duration, 1.0);
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
