function meta = inferActionCombatMetadata(member, action, archetypeInfo, teamContext)
    % 统一队伍时间线的动作元数据推断。
    % 这里负责把 rotation token 解释成：
    % 1. 动作类别与伤害元素；
    % 2. 元素附着与预期反应；
    % 3. 粒子 / 回能估算；
    % 4. 持续效果窗口。
    if nargin < 1 || isempty(member)
        member = struct();
    end
    if nargin < 2
        action = "";
    end
    if nargin < 3 || isempty(archetypeInfo)
        archetypeInfo = struct();
    end
    if nargin < 4 || isempty(teamContext)
        teamContext = struct();
    end

    characterName = string(getFieldOrDefault(member, 'Name', ""));
    normalizedName = localNormalizeName(characterName);
    constellation = double(getFieldOrDefault(member, 'Constellation', 0));
    action = string(action);
    lowerAction = lower(char(action));
    characterElement = string(getCharacterElement(characterName));
    registryEntry = getCharacterRegistryEntry(characterName);
    weaponType = string(getFieldOrDefault(registryEntry, 'WeaponType', ""));

    meta = struct( ...
        'Character', characterName, ...
        'Action', action, ...
        'ActionClass', "Utility", ...
        'ConsumesActiveWindow', true, ...
        'HitElement', "", ...
        'ApplyElement', "", ...
        'ApplyGauge', 0.0, ...
        'CanApplyAura', false, ...
        'AllowAmplify', false, ...
        'AllowCatalyze', false, ...
        'PreferredAura', "", ...
        'EstimatedParticles', 0.0, ...
        'EstimatedOrbs', 0.0, ...
        'FlatEnergySelf', 0.0, ...
        'FlatEnergyTeam', 0.0, ...
        'ConsumesBurstEnergy', false, ...
        'BurstCost', 0.0, ...
        'EffectDuration', 0.0, ...
        'EffectTag', "", ...
        'EffectFirstTickDelay', 0.0, ...
        'EffectTickInterval', 0.0, ...
        'EffectTickCount', 0, ...
        'EffectTickAction', "", ...
        'EffectTickGauge', 0.0, ...
        'EffectTickElement', "", ...
        'EffectTickPreferredAura', "", ...
        'TriggeredFollowUpAction', "", ...
        'TriggeredFollowUpDelay', 0.0, ...
        'TriggeredFollowUpGauge', 0.0, ...
        'TriggeredFollowUpElement', "", ...
        'TriggeredFollowUpPreferredAura', "", ...
        'TriggeredFollowUpInternalCooldown', 0.0, ...
        'TriggeredFollowUpEligibleClasses', strings(1, 0), ...
        'TriggeredFollowUpForegroundOnly', true, ...
        'TriggeredFollowUpMaxCount', inf, ...
        'BackgroundDriverKind', "", ...
        'BackgroundDriverMode', "", ...
        'ResolveReactionAsDamage', false, ...
        'ForceReactionName', "", ...
        'ReactionElement', "", ...
        'ExpectedReaction', "");

    meta.ActionClass = localResolveActionClass(lowerAction);
    meta.ConsumesActiveWindow = ~any(meta.ActionClass == ["FollowUp", "Reaction", "Utility"]);
    meta.HitElement = localResolveActionElement( ...
        normalizedName, characterElement, weaponType, lowerAction, meta.ActionClass, archetypeInfo);

    if meta.HitElement ~= "" && ~any(strcmpi(char(meta.HitElement), {'physical', 'none'}))
        meta.ApplyElement = meta.HitElement;
        meta.ApplyGauge = localResolveApplyGauge(lowerAction, meta.ActionClass);
        meta.CanApplyAura = meta.ApplyGauge > 0;
    end

    if any(strcmpi(char(meta.HitElement), {'pyro', 'hydro', 'cryo'}))
        meta.AllowAmplify = true;
    end
    if any(strcmpi(char(meta.HitElement), {'electro', 'dendro'}))
        meta.AllowCatalyze = true;
    end

    meta.PreferredAura = localResolvePreferredAura(meta.HitElement, archetypeInfo);
    [meta.EstimatedParticles, meta.EstimatedOrbs] = localResolveEnergyPacket( ...
        normalizedName, lowerAction, meta.ActionClass, meta.HitElement);
    meta.FlatEnergySelf = localResolveFlatEnergySelf(member, normalizedName, lowerAction, teamContext);
    meta.FlatEnergyTeam = localResolveFlatEnergyTeam(normalizedName, lowerAction, teamContext);
    [meta.EffectDuration, meta.EffectTag, meta.EffectFirstTickDelay, ...
        meta.EffectTickInterval, meta.EffectTickCount, meta.EffectTickAction, meta.EffectTickGauge] = localResolveEffectDuration( ...
        normalizedName, lowerAction, meta.ActionClass, constellation);
    [meta.TriggeredFollowUpAction, meta.TriggeredFollowUpDelay, meta.TriggeredFollowUpGauge, ...
        meta.TriggeredFollowUpInternalCooldown, meta.TriggeredFollowUpEligibleClasses, ...
        meta.TriggeredFollowUpForegroundOnly, meta.TriggeredFollowUpMaxCount] = localResolveTriggeredFollowUpProfile( ...
        normalizedName, lowerAction, meta.EffectTag, meta.EffectDuration, constellation);
    meta = localApplyCharacterSpecificMetadata(meta, member, normalizedName, lowerAction, teamContext);

    forcedReaction = localResolveForcedReaction(lowerAction);
    if strlength(forcedReaction) > 0
        meta.ResolveReactionAsDamage = true;
        meta.ForceReactionName = forcedReaction;
        meta.ReactionElement = localResolveForcedReactionElement(forcedReaction);
        meta.ApplyElement = "";
        meta.ApplyGauge = 0;
        meta.CanApplyAura = false;
        meta.AllowAmplify = false;
        meta.AllowCatalyze = false;
        meta.ExpectedReaction = forcedReaction;
    end

    if meta.ActionClass == "Burst"
        meta.ConsumesBurstEnergy = true;
        meta.BurstCost = getCharacterBurstCost(characterName, ...
            getFieldOrDefault(member, 'TalentLevel', 10), ...
            getFieldOrDefault(member, 'Constellation', 0));
    end

    if strlength(string(meta.ExpectedReaction)) == 0
        meta.ExpectedReaction = localInferExpectedReaction(meta.HitElement, meta.PreferredAura, archetypeInfo);
    end
end

function actionClass = localResolveActionClass(lowerAction)
    if any(strcmp(lowerAction, {'bloom', 'lunarbloom', 'hyperbloom', 'burgeon', 'shatter', 'overload'}))
        actionClass = "Reaction";
        return;
    end
    if strcmp(lowerAction, 'q') || strcmp(lowerAction, 'burst') ...
            || ~isempty(regexp(lowerAction, '^q\d+$', 'once')) ...
            || any(strcmp(lowerAction, {'qphysical', 'qpyro'}))
        actionClass = "Burst";
        return;
    end
    if any(strcmp(lowerAction, {'beam', 'drain', 'droplet', 'loadedshot'})) ...
            || contains(lowerAction, 'beam') || contains(lowerAction, 'drain')
        actionClass = "Charged";
        return;
    end
    if strcmp(lowerAction, 'e') || strcmp(lowerAction, 'skill') ...
            || startsWith(lowerAction, 'ehold') || startsWith(lowerAction, 'epress') ...
            || ~isempty(regexp(lowerAction, '^e\d+$', 'once')) ...
            || ~isempty(regexp(lowerAction, '^resete\d+$', 'once')) ...
            || startsWith(lowerAction, 'skill') || strcmp(lowerAction, 'exq') ...
            || contains(lowerAction, 'dance') ...
            || any(strcmp(lowerAction, {'confirm', 'deny', 'grenade', 'sprint', 'throw', 'rush', 'leap', 'skyladder'}))
        actionClass = "Skill";
        return;
    end
    if any(strcmp(lowerAction, {'bite', 'missile'}))
        actionClass = "Normal";
        return;
    end
    if ~isempty(regexp(lowerAction, '^n\d', 'once')) || ~isempty(regexp(lowerAction, '^na\d', 'once')) ...
            || ~isempty(regexp(lowerAction, '^b\d', 'once'))
        actionClass = "Normal";
        return;
    end
    if any(strcmp(lowerAction, {'normal', 'combo', 'final', 'sa3'}))
        actionClass = "Normal";
        return;
    end
    if any(strcmp(lowerAction, {'ca', 'charge', 'charged', 'heavy', 'aimed', 'aimedc1'}))
        actionClass = "Charged";
        return;
    end
    if any(strcmp(lowerAction, {'bca'}))
        actionClass = "Charged";
        return;
    end
    if any(strcmp(lowerAction, {'rebuke', 'luster'}))
        actionClass = "Charged";
        return;
    end
    if any(strcmp(lowerAction, {'flaskfull', 'flaskpartial'}))
        actionClass = "Skill";
        return;
    end
    if contains(lowerAction, 'plunge') || contains(lowerAction, 'plung')
        actionClass = "Plunge";
        return;
    end
    if any(strcmp(lowerAction, {'blade', 'herald', 'heraldcoord', 'qstellar', 'casehit', 'thorn', ...
            'scenteddew', 'duckywaterball', 'robotstrike', 'meowball', 'meowbounce', ...
            'bolt', 'starwicker', 'projection', 'whitetick', 'darktick', 'singer', 'finisher'})) ...
            || contains(lowerAction, 'stellar') || contains(lowerAction, 'icicle')
        actionClass = "FollowUp";
        return;
    end
    if localIsPersistentToken(lowerAction)
        actionClass = "FollowUp";
        return;
    end
    actionClass = "Utility";
end

function hitElement = localResolveActionElement(normalizedName, characterElement, weaponType, lowerAction, actionClass, archetypeInfo)
    hitElement = "";

    if any(strcmpi(lowerAction, {'switchpneuma', 'switchousia', 'auto', 'unity'}))
        return;
    end

    switch lowerAction
        case {'bloom', 'lunarbloom', 'hyperbloom', 'burgeon'}
            hitElement = "Dendro";
            return;
        case 'shatter'
            hitElement = "Physical";
            return;
        case 'overload'
            hitElement = "Pyro";
            return;
    end

    if actionClass == "Skill" || actionClass == "Burst" || actionClass == "FollowUp"
        hitElement = characterElement;
        return;
    end

    if contains(lowerAction, 'plungemix')
        hitElement = characterElement;
        return;
    end

    if any(strcmpi(lowerAction, {'beam', 'drain', 'droplet', 'bite', 'missile', 'loadedshot', ...
            'bolt', 'projection', 'whitetick', 'darktick'})) ...
            || contains(lowerAction, 'beam') || contains(lowerAction, 'drain')
        hitElement = characterElement;
        return;
    end

    if actionClass == "Charged" && any(strcmpi(char(weaponType), {'Catalyst', 'Bow'}))
        hitElement = characterElement;
        return;
    end

    if actionClass == "Normal" || actionClass == "Charged" || actionClass == "Plunge"
        if strcmpi(char(weaponType), 'Catalyst')
            hitElement = characterElement;
            return;
        end

        if any(normalizedName == ["arlecchino", "hutao", "wriothesley", "clorinde", "cyno", ...
                "raidenshogun", "wanderer", "diluc", "kamisatoayaka", "kamisatoayato", ...
                "yoimiya", "gaming", "barbara", "mona", "sangonomiyakokomi", "yanfei", "klee", ...
                "lisa", "nahida", "charlotte", "sucrose", "shikanoinheizou", "mizuki", "nicole"])
            hitElement = characterElement;
            return;
        end

        if actionClass == "Plunge" ...
                && string(getFieldOrDefault(archetypeInfo, 'PrimaryArchetype', "")) == "Plunge" ...
                && any(normalizedName == ["xiao", "gaming", "hutao", "diluc", "navia", "varesa", "wanderer", "arlecchino"])
            hitElement = characterElement;
            return;
        end

        hitElement = "Physical";
        return;
    end

    if contains(lowerAction, 'rain') || contains(lowerAction, 'throw') || contains(lowerAction, 'chain') ...
            || contains(lowerAction, 'radish') || contains(lowerAction, 'spirit') || contains(lowerAction, 'pyronado') ...
            || contains(lowerAction, 'doll') || contains(lowerAction, 'projection') || contains(lowerAction, 'phantom') ...
            || contains(lowerAction, 'pathfinder') || contains(lowerAction, 'moon') || contains(lowerAction, 'star') ...
            || contains(lowerAction, 'skull') || contains(lowerAction, 'usher') || contains(lowerAction, 'cheval') ...
            || contains(lowerAction, 'crab') || contains(lowerAction, 'loop') || contains(lowerAction, 'field') ...
            || contains(lowerAction, 'wave') || contains(lowerAction, 'slash') ...
            || contains(lowerAction, 'case') || contains(lowerAction, 'thorn') || contains(lowerAction, 'dew') ...
            || contains(lowerAction, 'bite') || contains(lowerAction, 'missile') ...
            || contains(lowerAction, 'loadedshot') || contains(lowerAction, 'bolt') ...
            || contains(lowerAction, 'tick') || contains(lowerAction, 'rush') || contains(lowerAction, 'leap')
        hitElement = characterElement;
    end
end

function gauge = localResolveApplyGauge(lowerAction, actionClass)
    gauge = 0;
    if any(strcmp(lowerAction, {'bloom', 'lunarbloom', 'hyperbloom', 'burgeon', 'shatter', 'overload'}))
        return;
    end
    switch char(actionClass)
        case 'Burst'
            gauge = 1.0;
        case 'Skill'
            if contains(lowerAction, 'hold')
                gauge = 2.0;
            else
                gauge = 1.0;
            end
        case {'Normal', 'Charged', 'Plunge'}
            gauge = 1.0;
        case 'FollowUp'
            if contains(lowerAction, 'projection') || contains(lowerAction, 'unity')
                gauge = 0.0;
            else
                gauge = 1.0;
            end
    end
end

function reactionName = localResolveForcedReaction(lowerAction)
    switch lowerAction
        case 'bloom'
            reactionName = "Bloom";
        case 'lunarbloom'
            reactionName = "LunarBloom";
        case 'hyperbloom'
            reactionName = "Hyperbloom";
        case 'burgeon'
            reactionName = "Burgeon";
        case 'shatter'
            reactionName = "Shatter";
        case 'overload'
            reactionName = "Overload";
        otherwise
            reactionName = "";
    end
end

function reactionElement = localResolveForcedReactionElement(reactionName)
    switch lower(char(string(reactionName)))
        case {'bloom', 'lunarbloom', 'hyperbloom', 'burgeon'}
            reactionElement = "Dendro";
        case 'shatter'
            reactionElement = "Physical";
        case 'overload'
            reactionElement = "Pyro";
        otherwise
            reactionElement = "";
    end
end

function preferredAura = localResolvePreferredAura(hitElement, archetypeInfo)
    preferredAura = "";
    if strlength(string(hitElement)) == 0
        return;
    end

    auraPairs = getFieldOrDefault(archetypeInfo, 'PreferredAuraPairs', struct());
    fieldName = char(string(hitElement));
    if isstruct(auraPairs) && isfield(auraPairs, fieldName)
        preferredAura = string(getFieldOrDefault(auraPairs, fieldName, ""));
    end
end

function meta = localApplyCharacterSpecificMetadata(meta, member, normalizedName, lowerAction, teamContext)
    if nargin < 5 || isempty(teamContext)
        teamContext = struct();
    end

    constellation = double(getFieldOrDefault(member, 'Constellation', 0));

    switch char(normalizedName)
        case 'chevreuse'
            if strcmp(lowerAction, 'heal')
                meta.ConsumesActiveWindow = true;
                meta.HitElement = "";
                meta.ApplyElement = "";
                meta.ApplyGauge = 0.0;
                meta.CanApplyAura = false;
                meta.AllowAmplify = false;
                meta.AllowCatalyze = false;
            end

        case 'iansan'
            if strcmp(lowerAction, 'bolt')
                meta.ConsumesActiveWindow = true;
            end

        case 'xianyun'
            if strcmp(lowerAction, 'e')
                meta.HitElement = "";
                meta.ApplyElement = "";
                meta.ApplyGauge = 0.0;
                meta.CanApplyAura = false;
                meta.AllowAmplify = false;
                meta.AllowCatalyze = false;
            elseif any(strcmp(lowerAction, {'plunge1', 'plunge2', 'plunge3', 'driftcloudwave'}))
                meta.HitElement = "Anemo";
                meta.ApplyElement = "Anemo";
                meta.ApplyGauge = 1.0;
                meta.CanApplyAura = true;
                meta.AllowAmplify = false;
                meta.AllowCatalyze = false;
            elseif strcmp(lowerAction, 'starwicker')
                meta.ConsumesActiveWindow = true;
            end

        case 'varesa'
            if strcmp(lowerAction, 'finisher')
                meta.ConsumesActiveWindow = true;
            end

        case 'aino'
            aura = localResolveAinoPreferredAura(teamContext);
            if any(strcmp(lowerAction, {'e', 'e2'})) && constellation >= 1
                meta.EffectDuration = 15.0;
                meta.EffectTag = "AinoC1EM";
                if strcmp(lowerAction, 'e2') && constellation >= 4
                    meta.FlatEnergySelf = meta.FlatEnergySelf + 10;
                end
            elseif strcmp(lowerAction, 'q')
                meta.HitElement = "";
                meta.ApplyElement = "";
                meta.ApplyGauge = 0.0;
                meta.CanApplyAura = false;
                meta.AllowAmplify = false;
                meta.AllowCatalyze = false;
                meta.AllowTransformative = false;
                interval = 2.0;
                if localHasAscendantMoonsign(teamContext)
                    interval = 1.5;
                end
                meta.EffectDuration = 14.0;
                meta.EffectTag = "CoolYourJetsDucky";
                meta.EffectFirstTickDelay = interval;
                meta.EffectTickAction = "DuckyWaterBall";
                meta.EffectTickInterval = interval;
                meta.EffectTickCount = max(1, floor(14.0 / interval));
                meta.EffectTickGauge = 1.0;
                meta.EffectTickElement = "Hydro";
                meta.EffectTickPreferredAura = aura;

                if constellation >= 2
                    meta.TriggeredFollowUpAction = "DuckyWaterBallC2";
                    meta.TriggeredFollowUpDelay = 0.05;
                    meta.TriggeredFollowUpGauge = 1.0;
                    meta.TriggeredFollowUpElement = "Hydro";
                    meta.TriggeredFollowUpPreferredAura = aura;
                    meta.TriggeredFollowUpInternalCooldown = 5.0;
                    meta.TriggeredFollowUpEligibleClasses = ["Normal", "Charged", "Plunge", "Skill", "Burst", "FollowUp"];
                    meta.TriggeredFollowUpForegroundOnly = true;
                    meta.TriggeredFollowUpMaxCount = 3;
                end
            elseif any(strcmp(lowerAction, {'duckywaterball', 'duckywaterballc2'}))
                meta.HitElement = "Hydro";
                meta.ApplyElement = "Hydro";
                meta.ApplyGauge = 1.0;
                meta.CanApplyAura = true;
                meta.AllowAmplify = true;
                meta.AllowCatalyze = false;
                meta.PreferredAura = aura;
            end

        case 'jahoda'
            convertedElement = localResolveJahodaConvertedElement(teamContext);
            aura = localResolveJahodaPreferredAura(convertedElement, teamContext);
            moonsignActive = localHasAscendantMoonsign(teamContext);
            enhancementElements = localResolveJahodaEnhancementElements(teamContext, constellation, moonsignActive);
            if strcmp(lowerAction, 'flaskfull') && moonsignActive && strlength(convertedElement) > 0
                meta.HitElement = "";
                meta.ApplyElement = "";
                meta.ApplyGauge = 0.0;
                meta.CanApplyAura = false;
                meta.AllowAmplify = false;
                meta.AllowCatalyze = false;
                meta.AllowTransformative = false;
                meowballCount = 4;
                meta.EffectDuration = max(meta.EffectDuration, meowballCount);
                meta.EffectTag = "JahodaFlaskWindow";
                meta.EffectFirstTickDelay = 1.0;
                meta.EffectTickAction = "Meowball";
                meta.EffectTickInterval = 1.0;
                meta.EffectTickCount = meowballCount;
                meta.EffectTickGauge = double(convertedElement ~= "");
                meta.EffectTickElement = convertedElement;
                meta.EffectTickPreferredAura = aura;
            elseif strcmp(lowerAction, 'q')
                robotCount = 2 + double(any(strcmpi(enhancementElements, 'Electro')));
                robotInterval = 2.20 * (1 - 0.10 * double(any(strcmpi(enhancementElements, 'Cryo'))));
                meta.EffectDuration = 12.0;
                meta.EffectTag = "PurrsonalCoordinatedAssistanceRobots";
                meta.EffectTickAction = "RobotStrike";
                meta.EffectTickInterval = robotInterval;
                meta.EffectTickCount = max(1, floor(12.0 / robotInterval));
                meta.EffectTickGauge = double(convertedElement ~= "") * min(robotCount, 3);
                meta.EffectTickElement = convertedElement;
                meta.EffectTickPreferredAura = aura;
                if constellation >= 4 && strlength(convertedElement) > 0
                    meta.FlatEnergySelf = meta.FlatEnergySelf + 4;
                end
            elseif any(strcmp(lowerAction, {'meowball', 'meowbounce', 'robotstrike'}))
                meta.HitElement = convertedElement;
                meta.ApplyElement = convertedElement;
                meta.ApplyGauge = 1.0;
                meta.CanApplyAura = strlength(convertedElement) > 0;
                meta.AllowAmplify = any(strcmpi(convertedElement, {'Hydro', 'Pyro', 'Cryo'}));
                meta.AllowCatalyze = strcmpi(convertedElement, 'Electro');
                meta.PreferredAura = aura;
                if strcmp(lowerAction, 'meowball')
                    meta.FlatEnergySelf = meta.FlatEnergySelf + 2;
                end
            end

        case 'ifa'
            absorbedElement = localResolveIfaBurstElement(teamContext);
            aura = localResolveIfaPreferredAura(absorbedElement, teamContext);
            if strcmp(lowerAction, 'q')
                meta.EffectDuration = 7.6;
                meta.EffectTag = "IfaSedationField";
                meta.EffectFirstTickDelay = 1.6;
                meta.EffectTickAction = "Mark";
                meta.EffectTickInterval = 2.0;
                meta.EffectTickCount = 4;
                meta.EffectTickGauge = double(strlength(absorbedElement) > 0);
                meta.EffectTickElement = absorbedElement;
                meta.EffectTickPreferredAura = aura;
            elseif any(strcmp(lowerAction, {'supporttap', 'supporthold'})) && constellation >= 1
                meta.FlatEnergySelf = meta.FlatEnergySelf + 6;
            end
    end
end

function aura = localResolveAinoPreferredAura(teamContext)
    aura = "";
    if getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1
        aura = "Pyro";
    elseif getFieldOrDefault(teamContext, 'CryoCount', 0) >= 1
        aura = "Cryo";
    end
end

function tf = localHasAscendantMoonsign(teamContext)
    tf = hasAscendantMoonsign(teamContext);
end

function element = localResolveJahodaConvertedElement(teamContext)
    priority = ["Pyro", "Hydro", "Electro", "Cryo"];
    counts = [ ...
        getFieldOrDefault(teamContext, 'PyroCount', 0), ...
        getFieldOrDefault(teamContext, 'HydroCount', 0), ...
        getFieldOrDefault(teamContext, 'ElectroCount', 0), ...
        getFieldOrDefault(teamContext, 'CryoCount', 0)];
    element = "";
    bestCount = 0;
    for i = 1:numel(priority)
        if counts(i) > bestCount
            bestCount = counts(i);
            element = priority(i);
        end
    end
end

function elements = localResolveJahodaEnhancementElements(teamContext, constellation, moonsignActive)
    priority = ["Pyro", "Hydro", "Electro", "Cryo"];
    counts = [ ...
        getFieldOrDefault(teamContext, 'PyroCount', 0), ...
        getFieldOrDefault(teamContext, 'HydroCount', 0), ...
        getFieldOrDefault(teamContext, 'ElectroCount', 0), ...
        getFieldOrDefault(teamContext, 'CryoCount', 0)];
    [~, order] = sortrows([(-counts(:)) (1:numel(priority)).']);
    sortedPriority = priority(order);
    sortedCounts = counts(order);
    elements = sortedPriority(sortedCounts > 0);
    if isempty(elements)
        elements = strings(1, 0);
        return;
    end
    if ~(moonsignActive && constellation >= 2)
        elements = elements(1);
    else
        elements = elements(1:min(2, numel(elements)));
    end
end

function aura = localResolveJahodaPreferredAura(element, teamContext)
    aura = "";
    switch lower(char(string(element)))
        case 'hydro'
            if getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1
                aura = "Pyro";
            end
        case 'pyro'
            if getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1
                aura = "Hydro";
            elseif getFieldOrDefault(teamContext, 'CryoCount', 0) >= 1
                aura = "Cryo";
            end
        case 'electro'
            if getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1
                aura = "Hydro";
            elseif getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1
                aura = "Pyro";
            end
        case 'cryo'
            if getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1
                aura = "Pyro";
            end
    end
end

function element = localResolveIfaBurstElement(teamContext)
    priority = ["Pyro", "Hydro", "Electro", "Cryo"];
    counts = [ ...
        getFieldOrDefault(teamContext, 'PyroCount', 0), ...
        getFieldOrDefault(teamContext, 'HydroCount', 0), ...
        getFieldOrDefault(teamContext, 'ElectroCount', 0), ...
        getFieldOrDefault(teamContext, 'CryoCount', 0)];
    element = "";
    bestCount = 0;
    for i = 1:numel(priority)
        if counts(i) > bestCount
            bestCount = counts(i);
            element = priority(i);
        end
    end
end

function aura = localResolveIfaPreferredAura(element, teamContext)
    aura = "";
    switch lower(char(string(element)))
        case 'hydro'
            if getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1
                aura = "Pyro";
            end
        case 'pyro'
            if getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1
                aura = "Hydro";
            elseif getFieldOrDefault(teamContext, 'CryoCount', 0) >= 1
                aura = "Cryo";
            end
        case 'cryo'
            if getFieldOrDefault(teamContext, 'PyroCount', 0) >= 1
                aura = "Pyro";
            end
    end
end

function [particles, orbs] = localResolveEnergyPacket(normalizedName, lowerAction, actionClass, hitElement)
    particles = 0;
    orbs = 0;

    switch char(actionClass)
        case 'Skill'
            if contains(lowerAction, 'hold')
                particles = 4;
            else
                particles = 3;
            end
        case 'Burst'
            particles = 0;
        otherwise
            particles = 0;
    end

    if any(normalizedName == ["barbara", "sangonomiyakokomi"]) && strcmp(lowerAction, 'e')
        particles = 0;
    elseif normalizedName == "bennett" && any(strcmp(lowerAction, {'e', 'epress'}))
        particles = 2;
    elseif normalizedName == "bennett" && strcmp(lowerAction, 'ehold')
        particles = 3;
    elseif normalizedName == "hutao" && any(strcmp(lowerAction, {'e', 'epress'}))
        particles = 0;
    elseif normalizedName == "furina" && strcmp(lowerAction, 'e')
        particles = 4;
    elseif normalizedName == "chevreuse" && any(strcmp(lowerAction, {'e', 'epress'}))
        particles = 4;
    elseif normalizedName == "iansan" && strcmp(lowerAction, 'e')
        particles = 4;
    elseif normalizedName == "varesa" && strcmp(lowerAction, 'e')
        particles = 3;
    elseif normalizedName == "fischl" && strcmp(lowerAction, 'e')
        particles = 4;
    elseif normalizedName == "yaemiko" && strcmp(lowerAction, 'e')
        particles = 1;
    elseif normalizedName == "yaemiko" ...
            && (~isempty(regexp(lowerAction, '^e\d+$', 'once')) || ~isempty(regexp(lowerAction, '^resete\d+$', 'once')))
        particles = 0;
    elseif normalizedName == "alhaitham" && strcmp(lowerAction, 'e')
        particles = 3;
    elseif normalizedName == "kamisatoayaka" && strcmp(lowerAction, 'e')
        particles = 4;
    elseif normalizedName == "baizhu" && strcmp(lowerAction, 'e')
        particles = 3;
    elseif normalizedName == "navia" && strcmp(lowerAction, 'e')
        particles = 3;
    elseif normalizedName == "xiao" && strcmp(lowerAction, 'e')
        particles = 3;
    elseif normalizedName == "raidenshogun" && any(strcmp(lowerAction, {'e', 'q', 'burst'}))
        particles = 0;
    elseif normalizedName == "zhongli" && contains(lowerAction, 'hold')
        particles = 0;
    elseif normalizedName == "nahida" && any(strcmp(lowerAction, {'e', 'epress', 'ehold'}))
        particles = 3;
    elseif normalizedName == "kaedeharakazuha" && strcmp(lowerAction, 'epress')
        particles = 3;
    elseif normalizedName == "kaedeharakazuha" && strcmp(lowerAction, 'ehold')
        particles = 4;
    elseif normalizedName == "xianyun" && strcmp(lowerAction, 'e')
        particles = 5;
    elseif normalizedName == "zhongli" && strcmp(lowerAction, 'epress')
        particles = 2;
    elseif normalizedName == "xingqiu" && strcmp(lowerAction, 'e')
        particles = 5;
    elseif normalizedName == "yelan" && strcmp(lowerAction, 'e')
        particles = 4;
    elseif normalizedName == "kukishinobu" && strcmp(lowerAction, 'e')
        particles = 3;
    end

    if strlength(string(hitElement)) == 0 || strcmpi(char(hitElement), 'physical')
        particles = 0;
    end
end

function flatEnergy = localResolveFlatEnergySelf(member, normalizedName, lowerAction, teamContext)
    flatEnergy = 0;
    constellation = getFieldOrDefault(member, 'Constellation', 0);

    if normalizedName == "nicole" && any(strcmp(lowerAction, {'q', 'burst'}))
        flatEnergy = flatEnergy + getFieldOrDefault(teamContext, 'NicoleWeaponEnergyRestore', 0);
    elseif normalizedName == "qiqi" && constellation >= 1
        if strcmp(lowerAction, 'herald')
            flatEnergy = flatEnergy + 2;
            if logical(getFieldOrDefault(teamContext, 'StellarConductEnabled', false))
                flatEnergy = flatEnergy + 6;
            end
        end
    end
end

function flatEnergy = localResolveFlatEnergyTeam(normalizedName, lowerAction, teamContext)
    flatEnergy = 0;

    if normalizedName == "raidenshogun" && any(strcmp(lowerAction, {'q', 'burst'}))
        memberCount = max(1, double(getFieldOrDefault(teamContext, 'MemberCount', 4)));
        flatEnergy = 8.0 * memberCount;
    end
end

function [duration, tag, firstTickDelay, tickInterval, tickCount, tickAction, tickGauge] = localResolveEffectDuration(normalizedName, lowerAction, actionClass, constellation)
    duration = 0;
    tag = "";
    firstTickDelay = 0;
    tickInterval = 0;
    tickCount = 0;
    tickAction = "";
    tickGauge = 0;
    if nargin < 4 || isempty(constellation)
        constellation = 0;
    end

    if any(strcmp(lowerAction, {'oz', 'qoz', 'eye', 'pillar', 'ring', 'source', ...
            'trikarma', 'bursttrikarma', 'starwicker', 'rain1', 'rain2', ...
            'throw', 'qdot', 'qinfuse', 'geowave', 'collapse', 'bolt', ...
            'projection', 'whitetick', 'darktick', 'singer'}))
        return;
    end

    switch char(actionClass)
        case 'FollowUp'
            tag = "Persistent";
        case {'Skill', 'Burst'}
            tag = "ActionWindow";
    end

    switch char(normalizedName)
        case 'furina'
            if strcmp(lowerAction, 'q')
                duration = 18.0;
                tag = "Fanfare";
            elseif strcmp(lowerAction, 'e')
                duration = 30.0;
                tag = "SalonMembers";
            end
        case 'xiangling'
            if strcmp(lowerAction, 'q')
                duration = 10.0;
                tag = "Pyronado";
            elseif strcmp(lowerAction, 'e')
                duration = 6.0;
                tag = "Guoba";
            end
        case 'fischl'
            if any(strcmp(lowerAction, {'e', 'q'}))
                duration = 10.0;
                tag = "Oz";
            end
        case 'iansan'
            if strcmp(lowerAction, 'q')
                duration = 12.0;
                tag = "IansanTrainingGround";
            end
        case 'xianyun'
            if strcmp(lowerAction, 'q')
                duration = 16.0;
                tag = "AdeptalLegacy";
            end
        case 'varesa'
            if strcmp(lowerAction, 'q')
                duration = 10.0;
                tag = "VaresaBurstWindow";
            elseif strcmp(lowerAction, 'e')
                duration = 10.0;
                tag = "VaresaRushWindow";
            end
        case 'durin'
            if strcmp(lowerAction, 'q')
                duration = 20.0;
                tag = "DurinDragon";
            elseif any(strcmp(lowerAction, {'confirm', 'deny'}))
                duration = 30.0;
                tag = "DurinTransmutation";
            end
        case 'nicole'
            if strcmp(lowerAction, 'q')
                duration = 12.0;
                tag = "SilentContemplation";
            elseif strcmp(lowerAction, 'e')
                duration = 12.0;
                tag = "NicoleGrace";
            end
        case 'yaemiko'
            if ~isempty(regexp(lowerAction, '^e\d+$', 'once')) || ~isempty(regexp(lowerAction, '^resete\d+$', 'once')) ...
                    || strcmp(lowerAction, 'e')
                duration = 14.0;
                tag = "SesshouSakura";
            end
        case 'xingqiu'
            if strcmp(lowerAction, 'q')
                duration = 15.0;
                tag = "RainSwords";
            end
        case 'yelan'
            if strcmp(lowerAction, 'q')
                duration = 15.0;
                tag = "ExquisiteThrow";
            end
        case 'nahida'
            if any(strcmp(lowerAction, {'e', 'epress', 'ehold'}))
                duration = 25.0;
                tag = "SeedOfSkandha";
            elseif strcmp(lowerAction, 'q')
                duration = 15.0;
                tag = "ShrineOfMaya";
            end
        case 'baizhu'
            if strcmp(lowerAction, 'q')
                duration = 14.0;
                tag = "SeamlessShield";
            end
        case 'thoma'
            if strcmp(lowerAction, 'q')
                duration = 15.0 + 3.0 * double(constellation >= 2);
                tag = "CrimsonOoyoroi";
            end
        case 'dehya'
            if any(strcmp(lowerAction, {'e', 'e1', 'e2'}))
                duration = 12.0;
                tag = "FierySanctum";
            end
        case 'collei'
            if strcmp(lowerAction, 'q')
                duration = 6.0;
                tag = "CuileinAnbar";
            end
        case 'albedo'
            if strcmp(lowerAction, 'e')
                duration = 30.0;
                tag = "SolarIsotoma";
            end
        case 'chiori'
            if strcmp(lowerAction, 'e')
                duration = 17.0;
                tag = "Tamoto";
            end
        case 'emilie'
            if any(strcmp(lowerAction, {'e', 'skill'}))
                duration = 22.0;
                tag = "LumidouceCase";
            elseif any(strcmp(lowerAction, {'q', 'burst'}))
                duration = 2.8;
                tag = "AromaticExplication";
            end
        case 'xianyun'
            if strcmp(lowerAction, 'q')
                duration = 16.0;
                tag = "Starwicker";
            end
        case 'qiqi'
            if any(strcmp(lowerAction, {'e', 'epress', 'ehold'}))
                duration = 15.0;
                tag = "HeraldOfFrost";
            elseif strcmp(lowerAction, 'q')
                duration = 15.0;
                tag = "FortunePreservingTalisman";
            end
        case 'kaeya'
            if strcmp(lowerAction, 'q')
                duration = 8.0;
                tag = "GlacialWaltz";
            end
        case 'kaedeharakazuha'
            if strcmp(lowerAction, 'q')
                duration = 8.0;
                tag = "AutumnWhirlwind";
            end
        case 'bennett'
            if strcmp(lowerAction, 'q')
                duration = 12.0;
                tag = "InspirationField";
            end
        case 'beidou'
            if strcmp(lowerAction, 'q')
                duration = 15.0;
                tag = "Stormbreaker";
            end
        case 'zhongli'
            if any(strcmp(lowerAction, {'e', 'epress', 'ehold'}))
                duration = 20.0;
                tag = "StoneStele";
            end
        case 'raidenshogun'
            if strcmp(lowerAction, 'e')
                duration = 25.0;
                tag = "EyeOfStormyJudgment";
            elseif strcmp(lowerAction, 'q')
                duration = 7.0;
                tag = "MusouIsshin";
            end
        case 'sangonomiyakokomi'
            if strcmp(lowerAction, 'e')
                duration = 12.0;
                tag = "Kurage";
            end
        case 'kukishinobu'
            if strcmp(lowerAction, 'e')
                duration = 12.0;
                tag = "SanctifyingRing";
            end
        case 'yaoyao'
            if any(strcmp(lowerAction, {'e', 'skill'}))
                duration = 10.0;
                tag = "Yuegui";
            elseif strcmp(lowerAction, 'q')
                duration = 5.0;
                tag = "AdeptalLegacy";
            end
        case 'kachina'
            if strcmp(lowerAction, 'e')
                duration = 20.0;
                tag = "TurboTwirly";
            elseif strcmp(lowerAction, 'q')
                duration = 12.0;
                tag = "TimeToGetSerious";
            end
    end

    if duration <= 0 && localIsPersistentToken(lowerAction)
        duration = localGenericPersistentDuration(lowerAction);
        tag = "Persistent";
    end

    [firstTickDelay, tickInterval, tickCount, tickAction, tickGauge] = ...
        localResolveEffectTickProfile(normalizedName, lowerAction, tag, duration, constellation);
end

function [firstTickDelay, tickInterval, tickCount, tickAction, tickGauge] = ...
        localResolveEffectTickProfile(normalizedName, lowerAction, effectTag, duration, constellation)
    firstTickDelay = 0;
    tickInterval = 0;
    tickCount = 0;
    tickAction = "";
    tickGauge = 0;
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end

    if duration <= 0 || contains(lowerAction, 'tick') || contains(lowerAction, 'pulse')
        return;
    end

    switch char(normalizedName)
        case 'furina'
            if strcmp(effectTag, "SalonMembers")
                tickAction = "SalonTick";
                tickInterval = 2.4;
                tickGauge = 1.0;
            end

        case 'xiangling'
            if strcmp(effectTag, "Pyronado")
                tickAction = "PyronadoTick";
                tickInterval = 1.40;
                tickGauge = 1.0;
            end

        case 'fischl'
            if strcmp(effectTag, "Oz")
                tickAction = "OzTick";
                tickInterval = 1.00;
                tickGauge = 1.0;
            end

        case 'yaemiko'
            if strcmp(effectTag, "SesshouSakura")
                tickAction = "SesshouSakuraTick";
                tickInterval = 1.40;
                tickGauge = 1.0;
            end

        case 'nahida'
            if strcmp(effectTag, "SeedOfSkandha")
                tickAction = "TriKarmaTick";
                tickInterval = 2.50;
                tickGauge = 1.0;
            end

        case 'baizhu'
            if strcmp(effectTag, "SeamlessShield")
                tickAction = "SpiritveinTick";
                firstTickDelay = 2.00;
                tickInterval = 2.00;
                tickGauge = 1.0;
                tickCount = 6;
            end

        case 'collei'
            if strcmp(effectTag, "CuileinAnbar")
                tickAction = "CuileinLeap";
                tickInterval = 1.00;
                tickGauge = 1.0;
            end

        case 'chiori'
            if strcmp(effectTag, "Tamoto")
                tickAction = "TamotoSlash";
                tickInterval = 3.20;
                tickGauge = 1.0;
            end

        case 'emilie'
            if strcmp(effectTag, "LumidouceCase")
                tickAction = "CaseHit";
                firstTickDelay = 2.00;
                tickInterval = 2.00;
                tickGauge = 1.0;
            elseif strcmp(effectTag, "AromaticExplication")
                tickAction = "ScentedDew";
                firstTickDelay = 0.30;
                tickInterval = 0.30;
                tickGauge = 1.0;
            end

        case 'qiqi'
            if strcmp(effectTag, "HeraldOfFrost")
                tickAction = "HeraldTick";
                tickInterval = 2.00;
                tickGauge = 1.0;
            end

        case 'kaeya'
            if strcmp(effectTag, "GlacialWaltz")
                tickAction = "Icicle";
                firstTickDelay = 1.00;
                tickInterval = 1.00;
                tickGauge = 1.0;
                tickCount = 8 + double(constellation >= 6);
            end

        case 'kaedeharakazuha'
            if strcmp(effectTag, "AutumnWhirlwind")
                tickAction = "WhirlwindTick";
                tickInterval = 2.00;
                tickGauge = 1.0;
            end

        case 'kukishinobu'
            if strcmp(effectTag, "SanctifyingRing")
                tickAction = "RingTick";
                tickInterval = 1.50;
                tickGauge = 1.0;
            end

        case 'sangonomiyakokomi'
            if strcmp(effectTag, "Kurage")
                tickAction = "KurageTick";
                tickInterval = 2.00;
                tickGauge = 1.0;
            end

        case 'zhongli'
            if strcmp(effectTag, "StoneStele")
                tickAction = "PillarPulse";
                tickInterval = 2.00;
                tickGauge = 0.5;
            end

        case 'yaoyao'
            if strcmp(effectTag, "Yuegui")
                tickAction = "Radish";
                firstTickDelay = 1.90;
                tickInterval = 1.90;
                tickGauge = 1.0;
                tickCount = 5 + double(constellation >= 1);
            elseif strcmp(effectTag, "AdeptalLegacy")
                tickAction = "BurstRadish";
                firstTickDelay = 0.60;
                tickInterval = 0.60;
                tickGauge = 1.0;
                tickCount = 6 + 2 * double(constellation >= 6);
            end

        case 'kachina'
            if strcmp(effectTag, "TurboTwirly")
                tickAction = "Drill";
                firstTickDelay = 3.20;
                tickInterval = 3.20;
                tickGauge = 1.0;
                tickCount = 6;
            end

    end

    if tickInterval <= 0 || strlength(tickAction) == 0
        return;
    end

    if firstTickDelay <= 0
        firstTickDelay = tickInterval;
    end
    if tickCount <= 0
        tickCount = max(0, floor((duration - firstTickDelay + 1e-9) / tickInterval) + 1);
    end
end

function [followUpAction, followUpDelay, followUpGauge, internalCooldown, eligibleClasses, foregroundOnly, maxTriggerCount] = ...
        localResolveTriggeredFollowUpProfile(normalizedName, lowerAction, effectTag, duration, constellation) %#ok<INUSD>
    followUpAction = "";
    followUpDelay = 0;
    followUpGauge = 0;
    internalCooldown = 0;
    eligibleClasses = strings(1, 0);
    foregroundOnly = true;
    maxTriggerCount = inf;
    if nargin < 5 || isempty(constellation)
        constellation = 0;
    end

    if duration <= 0 || strlength(string(effectTag)) == 0
        return;
    end

    switch char(normalizedName)
        case 'nahida'
            if strcmp(effectTag, "SeedOfSkandha")
                followUpAction = "TriKarmaTick";
                followUpDelay = 0.15;
                followUpGauge = 1.0;
                internalCooldown = 2.50;
                eligibleClasses = ["Reaction"];
                foregroundOnly = false;
            end

        case 'xingqiu'
            if strcmp(effectTag, "RainSwords")
                followUpAction = "RainSwordWave";
                followUpDelay = 0.08;
                followUpGauge = 1.0;
                internalCooldown = 1.00;
                eligibleClasses = ["Normal"];
            end

        case 'yelan'
            if strcmp(effectTag, "ExquisiteThrow")
                followUpAction = "ExquisiteThrowWave";
                followUpDelay = 0.08;
                followUpGauge = 1.0;
                internalCooldown = 1.00;
                eligibleClasses = ["Normal"];
            end

        case 'raidenshogun'
            if strcmp(effectTag, "EyeOfStormyJudgment")
                followUpAction = "EyeCoordSlash";
                followUpDelay = 0.05;
                followUpGauge = 0.5;
                internalCooldown = 0.90;
                eligibleClasses = ["Normal", "Charged", "Plunge", "Skill", "Burst"];
            end

        case 'beidou'
            if strcmp(effectTag, "Stormbreaker")
                followUpAction = "StormbreakerArc";
                followUpDelay = 0.10;
                followUpGauge = 1.0;
                internalCooldown = 1.00;
                eligibleClasses = ["Normal", "Charged", "Plunge", "Skill", "Burst"];
            end

        case 'thoma'
            if strcmp(effectTag, "CrimsonOoyoroi")
                followUpAction = "FieryCollapse";
                followUpDelay = 0.08;
                followUpGauge = 1.0;
                internalCooldown = 1.00;
                eligibleClasses = ["Normal"];
            end

        case 'dehya'
            if strcmp(effectTag, "FierySanctum")
                followUpAction = "FierySanctumStrike";
                followUpDelay = 0.05;
                followUpGauge = 1.0;
                internalCooldown = 2.50;
                eligibleClasses = ["Normal", "Charged", "Plunge", "Skill", "Burst", "FollowUp"];
                foregroundOnly = false;
            end

        case 'albedo'
            if strcmp(effectTag, "SolarIsotoma")
                followUpAction = "TransientBlossom";
                followUpDelay = 0.05;
                followUpGauge = 1.0;
                internalCooldown = 2.00;
                eligibleClasses = ["Normal", "Charged", "Plunge", "Skill", "Burst", "FollowUp"];
                foregroundOnly = false;
            end

        case 'fischl'
            if strcmp(effectTag, "Oz") && constellation >= 6
                followUpAction = "OzJointAttack";
                followUpDelay = 0.05;
                followUpGauge = 0.4;
                internalCooldown = 0.10;
                eligibleClasses = ["Normal", "Charged", "Plunge"];
            end

        case 'xianyun'
            if strcmp(effectTag, "Starwicker")
                followUpAction = "Starwicker";
                followUpDelay = 0.05;
                followUpGauge = 1.0;
                internalCooldown = 0.0;
                eligibleClasses = ["Plunge"];
                maxTriggerCount = 8;
            end

        case 'qiqi'
            if strcmp(effectTag, "HeraldOfFrost")
                followUpAction = "HeraldCoord";
                followUpDelay = 0.05;
                followUpGauge = 1.0;
                internalCooldown = 2.20;
                eligibleClasses = ["Normal", "Charged"];
            end
    end
end

function expectedReaction = localInferExpectedReaction(hitElement, preferredAura, archetypeInfo)
    expectedReaction = "";
    if strlength(string(hitElement)) == 0 || strlength(string(preferredAura)) == 0
        return;
    end

    primary = lower(char(string(getFieldOrDefault(archetypeInfo, 'PrimaryArchetype', ""))));
    if strcmp(primary, 'plunge')
        primary = lower(char(string(getFieldOrDefault(archetypeInfo, 'SecondaryArchetype', ""))));
    end

    switch primary
        case 'freeze'
            expectedReaction = "Frozen";
        case 'vaporize'
            expectedReaction = "Vaporize";
        case 'melt'
            expectedReaction = "Melt";
        case 'bloom'
            expectedReaction = "Bloom";
        case 'hyperbloom'
            if strcmpi(char(hitElement), 'electro')
                expectedReaction = "Hyperbloom";
            else
                expectedReaction = "Bloom";
            end
        case 'burgeon'
            if strcmpi(char(hitElement), 'pyro')
                expectedReaction = "Burgeon";
            else
                expectedReaction = "Bloom";
            end
        case 'aggravate'
            if strcmpi(char(hitElement), 'electro')
                expectedReaction = "Aggravate";
            elseif strcmpi(char(hitElement), 'dendro')
                expectedReaction = "Quicken";
            end
        case 'spread'
            if strcmpi(char(hitElement), 'dendro')
                expectedReaction = "Spread";
            elseif strcmpi(char(hitElement), 'electro')
                expectedReaction = "Quicken";
            end
        case 'overload'
            expectedReaction = "Overload";
    end
end

function tf = localIsPersistentToken(lowerAction)
    patterns = {'rain', 'throw', 'chain', 'radish', 'spirit', 'pyronado', 'doll', ...
        'projection', 'phantom', 'pathfinder', 'moon', 'star', 'skull', 'usher', ...
        'cheval', 'crab', 'loop', 'field', 'wave', 'slash', 'connector', 'spring', ...
        'song', 'bolt', 'arkhe', 'summon', 'mark', 'dice', 'spore', 'blossom', 'debt', ...
        'sanctuary', 'phantasm', 'bloom', 'herald', 'stellar', 'icicle', 'blade', ...
        'ducky', 'waterball', 'meowball', 'robotstrike', 'robot', ...
        'glacialwaltz', 'yuegui', 'turbotwirly', 'drill', ...
        'oz', 'eye', 'pillar', 'ring', 'source', 'trikarma', 'starwicker', ...
        'collapse', 'geowave', 'qdot', 'qinfuse', 'qoz', 'mirror'};
    tf = false;
    for i = 1:numel(patterns)
        if contains(lowerAction, patterns{i})
            tf = true;
            return;
        end
    end
end

function duration = localGenericPersistentDuration(lowerAction)
    duration = 8.0;
    if contains(lowerAction, 'rain') || contains(lowerAction, 'throw')
        duration = 15.0;
    elseif contains(lowerAction, 'pyronado')
        duration = 10.0;
    elseif contains(lowerAction, 'radish')
        duration = 10.0;
    elseif contains(lowerAction, 'spirit')
        duration = 12.0;
    elseif contains(lowerAction, 'glacialwaltz')
        duration = 8.0;
    elseif contains(lowerAction, 'yuegui')
        duration = 10.0;
    elseif contains(lowerAction, 'turbotwirly')
        duration = 20.0;
    elseif contains(lowerAction, 'projection')
        duration = 10.0;
    elseif contains(lowerAction, 'usher') || contains(lowerAction, 'cheval') || contains(lowerAction, 'crab')
        duration = 6.0;
    elseif contains(lowerAction, 'field')
        duration = 12.0;
    end
end

function normalized = localNormalizeName(name)
    normalized = string(regexprep(lower(char(string(name))), '[^a-z0-9]', ''));
end
