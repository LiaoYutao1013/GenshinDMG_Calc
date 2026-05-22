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
        normalizedName, lowerAction, meta.ActionClass);

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
            || startsWith(lowerAction, 'skill') || strcmp(lowerAction, 'exq') ...
            || contains(lowerAction, 'dance')
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
    if contains(lowerAction, 'plunge') || contains(lowerAction, 'plung')
        actionClass = "Plunge";
        return;
    end
    if any(strcmp(lowerAction, {'blade', 'herald', 'heraldcoord', 'qstellar'})) ...
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

    if any(strcmpi(lowerAction, {'beam', 'drain', 'droplet', 'bite', 'missile', 'loadedshot'})) ...
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
            || contains(lowerAction, 'bite') || contains(lowerAction, 'missile') ...
            || contains(lowerAction, 'loadedshot')
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
    elseif normalizedName == "fischl" && strcmp(lowerAction, 'e')
        particles = 4;
    elseif normalizedName == "yaemiko" && strcmp(lowerAction, 'e')
        particles = 1;
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

function [duration, tag, firstTickDelay, tickInterval, tickCount, tickAction, tickGauge] = localResolveEffectDuration(normalizedName, lowerAction, actionClass)
    duration = 0;
    tag = "";
    firstTickDelay = 0;
    tickInterval = 0;
    tickCount = 0;
    tickAction = "";
    tickGauge = 0;

    if any(strcmp(lowerAction, {'oz', 'qoz', 'eye', 'pillar', 'ring', 'source', ...
            'trikarma', 'bursttrikarma', 'starwicker', 'rain1', 'rain2', ...
            'throw', 'qdot', 'qinfuse', 'geowave', 'collapse'}))
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
            if strcmp(lowerAction, 'e')
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
        case 'xianyun'
            if strcmp(lowerAction, 'q')
                duration = 16.0;
                tag = "Starwicker";
            end
        case 'qiqi'
            if strcmp(lowerAction, 'herald')
                duration = 15.0;
                tag = "HeraldOfFrost";
            elseif strcmp(lowerAction, 'q')
                duration = 15.0;
                tag = "FortunePreservingTalisman";
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
    end

    if duration <= 0 && localIsPersistentToken(lowerAction)
        duration = localGenericPersistentDuration(lowerAction);
        tag = "Persistent";
    end

    [firstTickDelay, tickInterval, tickCount, tickAction, tickGauge] = ...
        localResolveEffectTickProfile(normalizedName, lowerAction, tag, duration);
end

function [firstTickDelay, tickInterval, tickCount, tickAction, tickGauge] = localResolveEffectTickProfile(normalizedName, lowerAction, effectTag, duration)
    firstTickDelay = 0;
    tickInterval = 0;
    tickCount = 0;
    tickAction = "";
    tickGauge = 0;

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

        case 'nahida'
            if strcmp(effectTag, "SeedOfSkandha")
                tickAction = "TriKarmaTick";
                tickInterval = 2.50;
                tickGauge = 1.0;
            end

        case 'qiqi'
            if strcmp(effectTag, "HeraldOfFrost")
                tickAction = "HeraldTick";
                tickInterval = 2.00;
                tickGauge = 1.0;
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

    end

    if tickInterval <= 0 || strlength(tickAction) == 0
        return;
    end

    firstTickDelay = tickInterval;
    tickCount = max(0, floor((duration - firstTickDelay + 1e-9) / tickInterval) + 1);
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
