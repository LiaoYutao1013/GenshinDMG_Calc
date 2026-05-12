function teamContext = buildTeamContext(members, rotationDuration, sharedBuffs)
    % Build a reusable team-level context so every character simulator can
    % read the same counts, shared buffs, and lightweight team assumptions.
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

    anemoMask = memberElements == "Anemo";
    hydroMask = memberElements == "Hydro";
    cryoMask = memberElements == "Cryo";
    pyroMask = memberElements == "Pyro";
    dendroMask = memberElements == "Dendro";
    electroMask = memberElements == "Electro";
    geoMask = memberElements == "Geo";

    anemoCount = sum(anemoMask);
    hydroCount = sum(hydroMask);
    cryoCount = sum(cryoMask);
    pyroCount = sum(pyroMask);
    dendroCount = sum(dendroMask);
    electroCount = sum(electroMask);
    geoCount = sum(geoMask);
    hydroCryoCount = sum(hydroMask | cryoMask);

    sharedAllDMGBonus = getFieldOrDefault(sharedBuffs, 'AllDMGBonus', 0);
    furinaApproxBonus = getFieldOrDefault(sharedBuffs, 'ApproxFurinaBonus', []);
    furinaIndex = find(memberNames == "Furina", 1, 'first');
    if isempty(furinaApproxBonus)
        if ~isempty(furinaIndex)
            furinaApproxBonus = localApproxFurinaBonus(memberConstellations(furinaIndex));
        else
            furinaApproxBonus = 0;
        end
    end
    allDMGBonus = sharedAllDMGBonus + furinaApproxBonus;

    hydroResShred = getFieldOrDefault(sharedBuffs, 'HydroResShred', 0);
    cryoResShred = getFieldOrDefault(sharedBuffs, 'CryoResShred', 0);
    pyroResShred = getFieldOrDefault(sharedBuffs, 'PyroResShred', 0);
    dendroResShred = getFieldOrDefault(sharedBuffs, 'DendroResShred', 0);
    electroResShred = getFieldOrDefault(sharedBuffs, 'ElectroResShred', 0);
    geoResShred = getFieldOrDefault(sharedBuffs, 'GeoResShred', 0);
    cryoCritDMGBonus = getFieldOrDefault(sharedBuffs, 'CryoCritDMGBonus', 0);
    geoCritDMGBonus = getFieldOrDefault(sharedBuffs, 'GeoCritDMGBonus', 0);

    if any(memberNames == "Escoffier")
        resSchedule = [0.00, 0.05, 0.10, 0.15, 0.55];
        resBonus = resSchedule(min(hydroCryoCount, 4) + 1);
        hydroResShred = hydroResShred + resBonus;
        cryoResShred = cryoResShred + resBonus;

        escoffierIndex = find(memberNames == "Escoffier", 1, 'first');
        if ~isempty(escoffierIndex) && memberConstellations(escoffierIndex) >= 1 ...
                && memberCount == 4 && hydroCryoCount == 4
            cryoCritDMGBonus = cryoCritDMGBonus + 0.60;
        end
    end

    hasSkirk = any(memberNames == "Skirk");
    hasLauma = any(memberNames == "Lauma");
    hasIneffa = any(memberNames == "Ineffa");
    hasLinnea = any(memberNames == "Linnea");
    hasNilou = any(memberNames == "Nilou");
    hasNefer = any(memberNames == "Nefer");
    hasFlins = any(memberNames == "Flins");
    hasZibai = any(memberNames == "Zibai");
    hasCitlali = any(memberNames == "Citlali");
    hasXilonen = any(memberNames == "Xilonen");
    hasNeuvillette = any(memberNames == "Neuvillette");
    hasColumbina = any(memberNames == "Columbina");
    hasChevreuse = any(memberNames == "Chevreuse");
    hasIansan = any(memberNames == "Iansan");
    hasVaresa = any(memberNames == "Varesa");
    hasDurin = any(memberNames == "Durin");

    lunarBloomEnabled = hasLauma || hasNefer || (hasColumbina && hydroCount >= 1 && dendroCount >= 1);
    lunarChargedEnabled = (hasIneffa || hasFlins || hasColumbina) && hydroCount >= 1 && electroCount >= 1;
    lunarCrystallizeEnabled = (hasLinnea || hasZibai || hasColumbina) && hydroCount >= 1 && geoCount >= 1;
    nilouPureBloomTeam = hasNilou && (hydroCount + dendroCount == memberCount) ...
        && hydroCount >= 1 && dendroCount >= 1;
    burningReady = pyroCount >= 1 && dendroCount >= 1;
    pyroSwirlReady = pyroCount >= 1 && anemoCount >= 1;
    pyroCrystallizeReady = pyroCount >= 1 && geoCount >= 1;
    pyroElectroOnlyTeam = pyroCount + electroCount == memberCount && pyroCount >= 1 && electroCount >= 1;
    chevreuseOverloadReady = hasChevreuse && pyroElectroOnlyTeam;
    overloadReady = pyroCount >= 1 && electroCount >= 1;
    durinWhiteSupportReady = burningReady || overloadReady || pyroSwirlReady || pyroCrystallizeReady;
    durinDarkAmpReady = hydroCount >= 1 || cryoCount >= 1;

    sharedLunarBloomBonus = getFieldOrDefault(sharedBuffs, 'LunarBloomBonus', 0);
    sharedLunarChargedBonus = getFieldOrDefault(sharedBuffs, 'LunarChargedBonus', 0);
    sharedLunarCrystallizeBonus = getFieldOrDefault(sharedBuffs, 'LunarCrystallizeBonus', 0);
    sharedNilouBloomBonus = getFieldOrDefault(sharedBuffs, 'NilouBloomBonus', 0);
    sharedOverloadBonus = getFieldOrDefault(sharedBuffs, 'OverloadBonus', 0);

    columbinaSupportBonus = 0;
    if hasColumbina
        columbinaIndex = find(memberNames == "Columbina", 1, 'first');
        columbinaSupportBonus = localApproxColumbinaReactionBonus(memberConstellations(columbinaIndex));
    end

    lunarBloomBaseBonus = 0.40 * double(lunarBloomEnabled);
    lunarChargedBaseBonus = max(0.30 * double(lunarChargedEnabled), 0.40 * double(hasColumbina && lunarChargedEnabled));
    lunarCrystallizeBaseBonus = max(0.30 * double(lunarCrystallizeEnabled), 0.40 * double(hasColumbina && lunarCrystallizeEnabled));

    lunarBloomBonus = sharedLunarBloomBonus + lunarBloomBaseBonus + columbinaSupportBonus * double(hasColumbina);
    lunarChargedBonus = sharedLunarChargedBonus + lunarChargedBaseBonus + columbinaSupportBonus * double(hasColumbina);
    lunarCrystallizeBonus = sharedLunarCrystallizeBonus + lunarCrystallizeBaseBonus + columbinaSupportBonus * double(hasColumbina);
    nilouBloomBonus = sharedNilouBloomBonus + 0.20 * double(nilouPureBloomTeam);

    reactionCritRate = getFieldOrDefault(sharedBuffs, 'ReactionCritRate', 0);
    reactionCritDMG = getFieldOrDefault(sharedBuffs, 'ReactionCritDMG', 0);
    if lunarBloomEnabled || lunarChargedEnabled || lunarCrystallizeEnabled
        reactionCritRate = max(reactionCritRate, 0.10);
        reactionCritDMG = max(reactionCritDMG, 0.20);
    end

    if hasCitlali
        pyroResShred = pyroResShred + 0.20;
        hydroResShred = hydroResShred + 0.20;
    end

    if hasXilonen
        pyroResShred = pyroResShred + 0.36 * double(pyroCount >= 1);
        hydroResShred = hydroResShred + 0.36 * double(hydroCount >= 1);
        cryoResShred = cryoResShred + 0.36 * double(cryoCount >= 1);
        electroResShred = electroResShred + 0.36 * double(electroCount >= 1);
        geoResShred = geoResShred + 0.36 * double(geoCount >= 1);
    end

    chevreuseATKBonus = 0;
    chevreuseConstellation = 0;
    if hasChevreuse
        chevreuseIndex = find(memberNames == "Chevreuse", 1, 'first');
        chevreuseConstellation = memberConstellations(chevreuseIndex);
        if chevreuseOverloadReady
            pyroResShred = pyroResShred + 0.40;
            electroResShred = electroResShred + 0.40;
            chevreuseATKBonus = 0.40 + 0.20 * double(chevreuseConstellation >= 6);
        end
    end

    iansanBurstATKBonus = 0;
    iansanConstellation = 0;
    if hasIansan
        iansanIndex = find(memberNames == "Iansan", 1, 'first');
        iansanConstellation = memberConstellations(iansanIndex);
        iansanBurstATKBonus = 0.28 + 0.06 * double(iansanConstellation >= 1) ...
            + 0.08 * double(iansanConstellation >= 6);
    end

    durinPreferredMode = localResolveDurinMode(sharedBuffs, durinWhiteSupportReady, durinDarkAmpReady);
    if hasDurin && durinPreferredMode == "White"
        pyroResShred = pyroResShred + 0.20 * double(durinWhiteSupportReady);
        dendroResShred = dendroResShred + 0.20 * double(burningReady);
        electroResShred = electroResShred + 0.20 * double(overloadReady);
        geoResShred = geoResShred + 0.20 * double(pyroCrystallizeReady);
    end

    flatATK = getFieldOrDefault(sharedBuffs, 'FlatATK', 0);
    atkBonus = getFieldOrDefault(sharedBuffs, 'ATKBonus', 0) + chevreuseATKBonus + iansanBurstATKBonus;
    overloadBonus = sharedOverloadBonus + 0.35 * double(chevreuseOverloadReady) + 0.08 * double(hasVaresa && overloadReady);

    hydroBeamBonus = 0.00;
    if hasNeuvillette
        hydroBeamBonus = hydroBeamBonus + 0.10 * min(3, pyroCount + electroCount + cryoCount);
    end

    nonHydroReactionCount = pyroCount + electroCount + cryoCount;
    elementalDiversity = sum([hydroCount >= 1, cryoCount >= 1, pyroCount >= 1, ...
        dendroCount >= 1, electroCount >= 1, geoCount >= 1]);
    xilonenSampleCount = double(pyroCount >= 1) + double(hydroCount >= 1) ...
        + double(cryoCount >= 1) + double(electroCount >= 1);
    dominantLunarReaction = localResolveDominantLunarReaction( ...
        memberNames, hasLauma, hasNefer, hasNilou, hasIneffa, hasFlins, ...
        hasLinnea, hasZibai, lunarBloomEnabled, lunarChargedEnabled, ...
        lunarCrystallizeEnabled, sharedBuffs);

    teamContext = struct( ...
        'MemberNames', memberNames, ...
        'MemberElements', memberElements, ...
        'MemberConstellations', memberConstellations, ...
        'MemberCount', memberCount, ...
        'RotationDuration', rotationDuration, ...
        'SharedAllDMGBonus', sharedAllDMGBonus, ...
        'ApproxFurinaBonus', furinaApproxBonus, ...
        'AllDMGBonus', allDMGBonus, ...
        'FlatATK', flatATK, ...
        'ATKBonus', atkBonus, ...
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
        'AnemoCount', anemoCount, ...
        'HydroCount', hydroCount, ...
        'CryoCount', cryoCount, ...
        'PyroCount', pyroCount, ...
        'DendroCount', dendroCount, ...
        'ElectroCount', electroCount, ...
        'GeoCount', geoCount, ...
        'LunarBloomEnabled', lunarBloomEnabled, ...
        'LunarChargedEnabled', lunarChargedEnabled, ...
        'LunarCrystallizeEnabled', lunarCrystallizeEnabled, ...
        'DominantLunarReaction', dominantLunarReaction, ...
        'NilouPureBloomTeam', nilouPureBloomTeam, ...
        'SharedLunarBloomBonus', sharedLunarBloomBonus, ...
        'SharedLunarChargedBonus', sharedLunarChargedBonus, ...
        'SharedLunarCrystallizeBonus', sharedLunarCrystallizeBonus, ...
        'LunarBloomBonus', lunarBloomBonus, ...
        'LunarChargedBonus', lunarChargedBonus, ...
        'LunarCrystallizeBonus', lunarCrystallizeBonus, ...
        'NilouBloomBonus', nilouBloomBonus, ...
        'ReactionCritRate', reactionCritRate, ...
        'ReactionCritDMG', reactionCritDMG, ...
        'OverloadBonus', overloadBonus, ...
        'BurningReady', burningReady, ...
        'HydroBeamBonus', hydroBeamBonus, ...
        'VaporizeReady', pyroCount >= 1, ...
        'ElectroChargedReady', hydroCount >= 1 && electroCount >= 1, ...
        'OverloadReady', overloadReady, ...
        'PyroSwirlReady', pyroSwirlReady, ...
        'PyroCrystallizeReady', pyroCrystallizeReady, ...
        'DurinWhiteSupportReady', durinWhiteSupportReady, ...
        'DurinDarkAmpReady', durinDarkAmpReady, ...
        'DurinPreferredMode', durinPreferredMode, ...
        'PyroElectroOnlyTeam', pyroElectroOnlyTeam, ...
        'ChevreuseOverloadReady', chevreuseOverloadReady, ...
        'ChevreuseATKBonus', chevreuseATKBonus, ...
        'IansanBurstATKBonus', iansanBurstATKBonus, ...
        'BloomReady', hydroCount >= 1 && dendroCount >= 1, ...
        'GeoReactionReady', hydroCount >= 1 && geoCount >= 1, ...
        'ElementalDiversity', elementalDiversity + double(anemoCount >= 1), ...
        'XilonenSampleCount', xilonenSampleCount, ...
        'NeuvilletteDraconicStacks', min(3, nonHydroReactionCount), ...
        'SkirkSkillLevelBonus', double(hasSkirk && hydroCount >= 1 && cryoCount >= 1 && hydroCryoCount == memberCount), ...
        'SkirkDeathCrossingStacks', double(hasSkirk) * min(3, hydroCount + max(cryoCount - 1, 0)), ...
        'SkirkVoidRifts', double(hasSkirk && hydroCount >= 1 && cryoCount >= 1) * 3);
end

function dominantReaction = localResolveDominantLunarReaction(memberNames, hasLauma, hasNefer, hasNilou, ...
        hasIneffa, hasFlins, hasLinnea, hasZibai, lunarBloomEnabled, lunarChargedEnabled, ...
        lunarCrystallizeEnabled, sharedBuffs)
    override = string(getFieldOrDefault(sharedBuffs, 'DominantLunarReaction', ""));
    if strlength(override) > 0
        dominantReaction = override;
        return;
    end

    if lunarBloomEnabled && (hasNilou || hasLauma || hasNefer)
        dominantReaction = "Bloom";
    elseif lunarChargedEnabled && (hasIneffa || hasFlins)
        dominantReaction = "Charged";
    elseif lunarCrystallizeEnabled && (hasLinnea || hasZibai)
        dominantReaction = "Crystallize";
    elseif lunarBloomEnabled
        dominantReaction = "Bloom";
    elseif lunarChargedEnabled
        dominantReaction = "Charged";
    elseif lunarCrystallizeEnabled
        dominantReaction = "Crystallize";
    elseif any(memberNames == "Columbina")
        dominantReaction = "Bloom";
    else
        dominantReaction = "";
    end
end

function bonus = localApproxFurinaBonus(constellation)
    if constellation >= 2
        bonus = 1.00;
    elseif constellation >= 1
        bonus = 0.82;
    else
        bonus = 0.60;
    end
end

function bonus = localApproxColumbinaReactionBonus(constellation)
    bonus = 0.07;
    bonus = bonus + 0.015 * double(constellation >= 1);
    bonus = bonus + 0.040 * double(constellation >= 2);
    bonus = bonus + 0.015 * double(constellation >= 3);
    bonus = bonus + 0.015 * double(constellation >= 4);
    bonus = bonus + 0.015 * double(constellation >= 5);
    bonus = bonus + 0.070 * double(constellation >= 6);
end

function mode = localResolveDurinMode(sharedBuffs, whiteReady, darkReady)
    override = string(getFieldOrDefault(sharedBuffs, 'DurinMode', ""));
    if strlength(override) > 0
        mode = override;
        return;
    end

    if whiteReady
        mode = "White";
    elseif darkReady
        mode = "Dark";
    else
        mode = "White";
    end
end

function element = localGetElement(name)
    switch lower(char(name))
        case 'skirk'
            element = "Cryo";
        case 'escoffier'
            element = "Cryo";
        case 'arlecchino'
            element = "Pyro";
        case 'furina'
            element = "Hydro";
        case 'chasca'
            element = "Anemo";
        case 'columbina'
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
        case 'flins'
            element = "Electro";
        case 'zibai'
            element = "Geo";
        case 'mualani'
            element = "Hydro";
        case 'mavuika'
            element = "Pyro";
        case 'citlali'
            element = "Cryo";
        case 'xilonen'
            element = "Geo";
        case 'neuvillette'
            element = "Hydro";
        case 'chevreuse'
            element = "Pyro";
        case 'iansan'
            element = "Electro";
        case 'varesa'
            element = "Electro";
        case 'durin'
            element = "Pyro";
        otherwise
            element = "Physical";
    end
end
