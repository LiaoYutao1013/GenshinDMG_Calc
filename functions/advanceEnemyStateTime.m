function [enemyState, reactionPackets] = advanceEnemyStateTime(enemyState, deltaTime, triggerElement, teamContext)
    % 推进怪物元素状态，同时结算持续反应和延迟爆炸。
    %
    % 返回的 reactionPackets 供统一反应入口或角色脚本收集，用于把
    % 感电、燃烧、绽放种子爆炸等非直伤命中的附加伤害并回本轮结果。
    if nargin < 2 || isempty(deltaTime)
        deltaTime = 0;
    end
    if nargin < 3
        triggerElement = "";
    end
    if nargin < 4 || isempty(teamContext)
        teamContext = struct();
    end
    if isempty(enemyState)
        enemyState = createEnemyState(struct(), teamContext, triggerElement);
    end

    reactionPackets = repmat(localMakePacket(), 1, 0);
    enemyState.Time = getFieldOrDefault(enemyState, 'Time', 0) + deltaTime;
    decayScale = max(0, getFieldOrDefault(enemyState, 'AuraDecayScale', 1.0));

    if isfield(enemyState, 'Auras') && ~isempty(enemyState.Auras)
        newAuras = repmat(localMakeAura("", 0, 0), 1, 0);
        for i = 1:numel(enemyState.Auras)
            currentGauge = double(enemyState.Auras(i).Gauge);
            if numel(currentGauge) > 1
                currentGauge = currentGauge(1);
            end
            decayPerSecond = double(getFieldOrDefault(enemyState.Auras(i), 'DecayPerSecond', 0.125));
            currentGauge = max(0, currentGauge - decayPerSecond * decayScale * deltaTime);
            if currentGauge > 1e-6
                newAuras(end + 1) = localMakeAura( ... %#ok<AGROW>
                    enemyState.Auras(i).Element, currentGauge, decayPerSecond);
            end
        end
        enemyState.Auras = newAuras;
    end

    if isfield(enemyState, 'Quicken') && getFieldOrDefault(enemyState.Quicken, 'Active', false)
        enemyState.Quicken.Gauge = max(0, enemyState.Quicken.Gauge ...
            - getFieldOrDefault(enemyState.Quicken, 'DecayPerSecond', 0.125) * decayScale * deltaTime);
        enemyState.Quicken.Active = enemyState.Quicken.Gauge > 1e-6;
    end

    enemyState = localAdvanceFrozenState(enemyState);

    [enemyState, reactionPackets] = localAdvanceTimedReaction( ...
        enemyState, reactionPackets, 'ElectroCharged', 'ElectroCharged', teamContext, deltaTime);
    [enemyState, reactionPackets] = localAdvanceTimedReaction( ...
        enemyState, reactionPackets, 'Burning', 'Burning', teamContext, deltaTime);
    [enemyState, reactionPackets] = localAdvanceDendroCores(enemyState, reactionPackets, deltaTime, teamContext);

    if localUsesApproximateSupportAura(enemyState) ...
            && (~isfield(enemyState, 'Auras') || isempty(enemyState.Auras)) ...
            && ~getFieldOrDefault(enemyState.Quicken, 'Active', false)
        supportAura = localInferSupportAura(triggerElement, teamContext);
        if strlength(supportAura) > 0
            enemyState.Auras = localMakeAura(supportAura, getFieldOrDefault(enemyState, 'SupportAuraGauge', 1.0), 0.125);
        end
    end
end

function [enemyState, packets] = localAdvanceTimedReaction(enemyState, packets, fieldName, reactionName, teamContext, deltaTime)
    if ~isfield(enemyState, fieldName)
        return;
    end

    state = enemyState.(fieldName);
    if ~getFieldOrDefault(state, 'Active', false)
        return;
    end

    state.Gauge = max(0, state.Gauge - 0.10 * deltaTime);
    state.TickTimer = getFieldOrDefault(state, 'TickTimer', 0) + deltaTime;
    tickInterval = max(0.1, getFieldOrDefault(state, 'TickInterval', 1.0));
    while state.TickTimer >= tickInterval && state.Gauge > 1e-6
        state.TickTimer = state.TickTimer - tickInterval;
        packets(end + 1) = localMakePacket(reactionName, teamContext, state); %#ok<AGROW>
    end

    state.Active = state.Gauge > 1e-6;
    enemyState.(fieldName) = state;
end

function enemyState = localAdvanceFrozenState(enemyState)
    if ~isfield(enemyState, 'Frozen')
        return;
    end

    hydroGauge = localAuraGauge(enemyState, "Hydro");
    cryoGauge = localAuraGauge(enemyState, "Cryo");
    enemyState.Frozen.Gauge = min(hydroGauge, cryoGauge);
    enemyState.Frozen.Active = enemyState.Frozen.Gauge > 1e-6;
end

function [enemyState, packets] = localAdvanceDendroCores(enemyState, packets, deltaTime, teamContext)
    if ~isfield(enemyState, 'DendroCores') || isempty(enemyState.DendroCores)
        return;
    end

    kept = repmat(localEmptyCore(), 1, 0);
    for i = 1:numel(enemyState.DendroCores)
        core = enemyState.DendroCores(i);
        core.TimeRemaining = core.TimeRemaining - deltaTime;
        if core.TimeRemaining <= 1e-6
            packets(end + 1) = localMakePacket(string(getFieldOrDefault(core, 'ReactionName', "Bloom")), teamContext, core); %#ok<AGROW>
        else
            kept(end + 1) = core; %#ok<AGROW>
        end
    end
    enemyState.DendroCores = kept;
end

function packet = localMakePacket(reactionName, teamContext, snapshot)
    if nargin < 1
        reactionName = "";
    end
    if nargin < 2
        teamContext = struct();
    end
    if nargin < 3 || isempty(snapshot)
        snapshot = struct();
    end

    useSnapshot = logical(getFieldOrDefault(snapshot, 'UseSnapshot', false));
    if useSnapshot
        reactionBonus = getFieldOrDefault(snapshot, 'ReactionBonus', 0);
        critRate = getFieldOrDefault(snapshot, 'SourceCritRate', []);
        critDMG = getFieldOrDefault(snapshot, 'SourceCritDMG', []);
    else
        reactionBonus = localResolvePacketBonus(reactionName, teamContext);
        critRate = getFieldOrDefault(teamContext, 'ReactionCritRate', []);
        critDMG = getFieldOrDefault(teamContext, 'ReactionCritDMG', []);
    end

    packet = struct( ...
        'ReactionName', string(reactionName), ...
        'ReactionBonus', reactionBonus, ...
        'CritRate', critRate, ...
        'CritDMG', critDMG, ...
        'ReactionElement', string(getFieldOrDefault(snapshot, 'ReactionElement', "")), ...
        'SourceEM', getFieldOrDefault(snapshot, 'SourceEM', 0), ...
        'SourceResShred', getFieldOrDefault(snapshot, 'SourceResShred', 0), ...
        'UseSnapshot', useSnapshot);
end

function bonus = localResolvePacketBonus(reactionName, teamContext)
    reactionName = lower(char(string(reactionName)));
    bonus = 0;
    switch reactionName
        case 'bloom'
            bonus = bonus + getFieldOrDefault(teamContext, 'NilouBloomBonus', 0) ...
                + getFieldOrDefault(teamContext, 'LunarBloomBonus', 0);
        case 'electrocharged'
            bonus = bonus + getFieldOrDefault(teamContext, 'LunarChargedBonus', 0);
        case 'burning'
            bonus = bonus + getFieldOrDefault(teamContext, 'ReactionDMGBonus', 0);
        case 'stellarconduct'
            bonus = bonus + getFieldOrDefault(teamContext, 'StellarConductBonus', 0) ...
                + getFieldOrDefault(teamContext, 'SandroneStellarConductC1Bonus', 0);
    end
end

function aura = localMakeAura(element, gaugeUnits, decayPerSecond)
    aura = struct( ...
        'Element', string(element), ...
        'Gauge', max(0, double(gaugeUnits)), ...
        'DecayPerSecond', max(0, double(decayPerSecond)));
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

function core = localEmptyCore()
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
        'UseSnapshot', false);
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
