function enemyState = advanceEnemyStateTime(enemyState, deltaTime, triggerElement, teamContext)
    % Advance the lightweight enemy aura state without applying a hit.
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

    enemyState.Time = getFieldOrDefault(enemyState, 'Time', 0) + deltaTime;
    if isfield(enemyState, 'Auras') && ~isempty(enemyState.Auras)
        decayPerSecond = 0.16;
        newAuras = repmat(struct('Element', "", 'Gauge', 0), 1, 0);
        for i = 1:numel(enemyState.Auras)
            currentGauge = double(enemyState.Auras(i).Gauge);
            if numel(currentGauge) > 1
                currentGauge = currentGauge(1);
            end
            currentGauge = max(0, currentGauge - decayPerSecond * deltaTime);
            if currentGauge > 1e-6
                newAuras(end + 1) = struct( ... %#ok<AGROW>
                    'Element', string(enemyState.Auras(i).Element), ...
                    'Gauge', currentGauge);
            end
        end
        enemyState.Auras = newAuras;
    end

    if logical(getFieldOrDefault(enemyState, 'AutoSupportAura', true)) ...
            && (~isfield(enemyState, 'Auras') || isempty(enemyState.Auras))
        supportAura = localInferSupportAura(triggerElement, teamContext);
        if strlength(supportAura) > 0
            enemyState.Auras = struct( ...
                'Element', supportAura, ...
                'Gauge', getFieldOrDefault(enemyState, 'SupportAuraGauge', 1.0));
        end
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
