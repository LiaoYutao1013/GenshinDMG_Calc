function teamContext = buildTeamContext(members, rotationDuration, sharedBuffs)
    % Collect all team-wide state in one place: member identity, elemental
    % counts, simplified buffs, and passive assumptions shared by several
    % character simulators.
    if nargin < 2 || isempty(rotationDuration)
        rotationDuration = 20;
    end
    if nargin < 3 || isempty(sharedBuffs)
        sharedBuffs = struct();
    end

    memberCount = numel(members);
    memberNames = strings(1, memberCount);
    memberElements = strings(1, memberCount);
    memberConstellations = zeros(1, memberCount);

    for i = 1:memberCount
        memberNames(i) = string(members{i}.Name);
        memberElements(i) = localGetElement(memberNames(i));
        memberConstellations(i) = getFieldOrDefault(members{i}, 'Constellation', 0);
    end

    hydroMask = memberElements == "Hydro";
    cryoMask = memberElements == "Cryo";
    pyroMask = memberElements == "Pyro";
    dendroMask = memberElements == "Dendro";
    electroMask = memberElements == "Electro";
    geoMask = memberElements == "Geo";
    hydroCryoCount = sum(hydroMask | cryoMask);

    allDMGBonus = getFieldOrDefault(sharedBuffs, 'AllDMGBonus', 0);
    allDMGBonus = allDMGBonus + getFieldOrDefault(sharedBuffs, 'ApproxFurinaBonus', 0) * double(any(memberNames == "Furina"));
    if any(memberNames == "Furina") && ~isfield(sharedBuffs, 'ApproxFurinaBonus')
        allDMGBonus = allDMGBonus + 0.60;
    end

    hydroResShred = getFieldOrDefault(sharedBuffs, 'HydroResShred', 0);
    cryoResShred = getFieldOrDefault(sharedBuffs, 'CryoResShred', 0);
    pyroResShred = getFieldOrDefault(sharedBuffs, 'PyroResShred', 0);
    dendroResShred = getFieldOrDefault(sharedBuffs, 'DendroResShred', 0);
    electroResShred = getFieldOrDefault(sharedBuffs, 'ElectroResShred', 0);
    geoResShred = getFieldOrDefault(sharedBuffs, 'GeoResShred', 0);
    cryoCritDMGBonus = getFieldOrDefault(sharedBuffs, 'CryoCritDMGBonus', 0);
    geoCritDMGBonus = getFieldOrDefault(sharedBuffs, 'GeoCritDMGBonus', 0);

    if any(memberNames == "Escoffier")
        resSchedule = [0, 0.05, 0.10, 0.15, 0.55];
        resBonus = resSchedule(min(hydroCryoCount, 4) + 1);
        hydroResShred = hydroResShred + resBonus;
        cryoResShred = cryoResShred + resBonus;

        escoffierIndex = find(memberNames == "Escoffier", 1, 'first');
        if ~isempty(escoffierIndex) && memberConstellations(escoffierIndex) >= 1 && memberCount == 4 && hydroCryoCount == 4
            cryoCritDMGBonus = cryoCritDMGBonus + 0.60;
        end
    end

    hydroCount = sum(hydroMask);
    cryoCount = sum(cryoMask);
    pyroCount = sum(pyroMask);
    dendroCount = sum(dendroMask);
    electroCount = sum(electroMask);
    geoCount = sum(geoMask);
    hasSkirk = any(memberNames == "Skirk");
    hasLauma = any(memberNames == "Lauma");
    hasIneffa = any(memberNames == "Ineffa");
    hasLinnea = any(memberNames == "Linnea");
    hasNilou = any(memberNames == "Nilou");
    hasNefer = any(memberNames == "Nefer");

    lunarBloomEnabled = hasLauma || hasNefer;
    lunarChargedEnabled = hasIneffa && hydroCount >= 1;
    lunarCrystallizeEnabled = hasLinnea && hydroCount >= 1;
    nilouPureBloomTeam = hasNilou && (hydroCount + dendroCount == memberCount) && hydroCount >= 1 && dendroCount >= 1;

    lunarBloomBonus = getFieldOrDefault(sharedBuffs, 'LunarBloomBonus', 0) + 0.40 * double(lunarBloomEnabled);
    lunarChargedBonus = getFieldOrDefault(sharedBuffs, 'LunarChargedBonus', 0) + 0.30 * double(lunarChargedEnabled);
    lunarCrystallizeBonus = getFieldOrDefault(sharedBuffs, 'LunarCrystallizeBonus', 0) + 0.30 * double(lunarCrystallizeEnabled);
    nilouBloomBonus = getFieldOrDefault(sharedBuffs, 'NilouBloomBonus', 0) + 0.20 * double(nilouPureBloomTeam);

    reactionCritRate = getFieldOrDefault(sharedBuffs, 'ReactionCritRate', 0);
    reactionCritDMG = getFieldOrDefault(sharedBuffs, 'ReactionCritDMG', 0);
    if lunarBloomEnabled
        reactionCritRate = max(reactionCritRate, 0.10);
        reactionCritDMG = max(reactionCritDMG, 0.20);
    end

    teamContext = struct( ...
        'MemberNames', memberNames, ...
        'MemberElements', memberElements, ...
        'RotationDuration', rotationDuration, ...
        'AllDMGBonus', allDMGBonus, ...
        'FlatATK', getFieldOrDefault(sharedBuffs, 'FlatATK', 0), ...
        'ATKBonus', getFieldOrDefault(sharedBuffs, 'ATKBonus', 0), ...
        'EMBonus', getFieldOrDefault(sharedBuffs, 'EMBonus', 0), ...
        'HydroResShred', hydroResShred, ...
        'CryoResShred', cryoResShred, ...
        'PyroResShred', pyroResShred, ...
        'DendroResShred', dendroResShred, ...
        'ElectroResShred', electroResShred, ...
        'GeoResShred', geoResShred, ...
        'CryoCritDMGBonus', cryoCritDMGBonus, ...
        'GeoCritDMGBonus', geoCritDMGBonus, ...
        'HydroCryoCount', hydroCryoCount, ...
        'HydroCount', hydroCount, ...
        'CryoCount', cryoCount, ...
        'PyroCount', pyroCount, ...
        'DendroCount', dendroCount, ...
        'ElectroCount', electroCount, ...
        'GeoCount', geoCount, ...
        'LunarBloomEnabled', lunarBloomEnabled, ...
        'LunarChargedEnabled', lunarChargedEnabled, ...
        'LunarCrystallizeEnabled', lunarCrystallizeEnabled, ...
        'NilouPureBloomTeam', nilouPureBloomTeam, ...
        'LunarBloomBonus', lunarBloomBonus, ...
        'LunarChargedBonus', lunarChargedBonus, ...
        'LunarCrystallizeBonus', lunarCrystallizeBonus, ...
        'NilouBloomBonus', nilouBloomBonus, ...
        'ReactionCritRate', reactionCritRate, ...
        'ReactionCritDMG', reactionCritDMG, ...
        'SkirkSkillLevelBonus', double(hasSkirk && hydroCount >= 1 && cryoCount >= 1 && hydroCryoCount == memberCount), ...
        'SkirkDeathCrossingStacks', double(hasSkirk) * min(3, hydroCount + max(cryoCount - 1, 0)), ...
        'SkirkVoidRifts', double(hasSkirk && hydroCount >= 1 && cryoCount >= 1) * 3 ...
    );
end

function element = localGetElement(name)
    % Local registry for the unified team entry.
    switch lower(char(name))
        case 'skirk'
            element = "Cryo";
        case 'escoffier'
            element = "Cryo";
        case 'arlecchino'
            element = "Pyro";
        case 'furina'
            element = "Hydro";
        case 'lauma'
            element = "Dendro";
        case 'ineffa'
            element = "Electro";
        case 'linnea'
            element = "Geo";
        case 'nilou'
            element = "Hydro";
        case 'nefer'
            element = "Dendro";
        otherwise
            element = "Physical";
    end
end
