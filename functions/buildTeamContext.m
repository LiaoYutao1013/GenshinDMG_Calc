function teamContext = buildTeamContext(members, rotationDuration, sharedBuffs, enemy)
    % Build a reusable team-level context so every character simulator can
    % read the same counts, shared buffs, and lightweight team assumptions.
    initProjectPaths();
    if nargin < 2 || isempty(rotationDuration)
        rotationDuration = 20;
    end
    if nargin < 3 || isempty(sharedBuffs)
        sharedBuffs = struct();
    end
    if nargin < 4 || isempty(enemy)
        enemy = struct();
    end
    reactionMode = localResolveReactionMode(sharedBuffs, enemy);

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
    sharedArtifactBuffs = localCollectArtifactTeamBuffs(members);
    baseAllDMGBonus = sharedAllDMGBonus + getFieldOrDefault(sharedArtifactBuffs, 'AllDMGBonus', 0);
    furinaApproxBonus = getFieldOrDefault(sharedBuffs, 'ApproxFurinaBonus', []);
    furinaIndex = find(memberNames == "Furina", 1, 'first');
    if isempty(furinaApproxBonus)
        if ~isempty(furinaIndex)
            furinaApproxBonus = localApproxFurinaBonus( ...
                members, rotationDuration, sharedBuffs, enemy, furinaIndex, baseAllDMGBonus);
        else
            furinaApproxBonus = 0;
        end
    end
    allDMGBonus = baseAllDMGBonus + furinaApproxBonus;
    pyroDMGBonus = getFieldOrDefault(sharedBuffs, 'PyroDMGBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'PyroDMGBonus', 0);
    hydroDMGBonus = getFieldOrDefault(sharedBuffs, 'HydroDMGBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'HydroDMGBonus', 0);
    cryoDMGBonus = getFieldOrDefault(sharedBuffs, 'CryoDMGBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'CryoDMGBonus', 0);
    electroDMGBonus = getFieldOrDefault(sharedBuffs, 'ElectroDMGBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'ElectroDMGBonus', 0);
    anemoDMGBonus = getFieldOrDefault(sharedBuffs, 'AnemoDMGBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'AnemoDMGBonus', 0);
    geoDMGBonus = getFieldOrDefault(sharedBuffs, 'GeoDMGBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'GeoDMGBonus', 0);
    dendroDMGBonus = getFieldOrDefault(sharedBuffs, 'DendroDMGBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'DendroDMGBonus', 0);
    physicalDMGBonus = getFieldOrDefault(sharedBuffs, 'PhysicalDMGBonus', 0);
    shieldBonus = getFieldOrDefault(sharedBuffs, 'ShieldBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'ShieldBonus', 0);

    hydroResShred = getFieldOrDefault(sharedBuffs, 'HydroResShred', 0) + getFieldOrDefault(sharedArtifactBuffs, 'HydroResShred', 0);
    cryoResShred = getFieldOrDefault(sharedBuffs, 'CryoResShred', 0) + getFieldOrDefault(sharedArtifactBuffs, 'CryoResShred', 0);
    pyroResShred = getFieldOrDefault(sharedBuffs, 'PyroResShred', 0) + getFieldOrDefault(sharedArtifactBuffs, 'PyroResShred', 0);
    dendroResShred = getFieldOrDefault(sharedBuffs, 'DendroResShred', 0) + getFieldOrDefault(sharedArtifactBuffs, 'DendroResShred', 0);
    electroResShred = getFieldOrDefault(sharedBuffs, 'ElectroResShred', 0) + getFieldOrDefault(sharedArtifactBuffs, 'ElectroResShred', 0);
    geoResShred = getFieldOrDefault(sharedBuffs, 'GeoResShred', 0) + getFieldOrDefault(sharedArtifactBuffs, 'GeoResShred', 0);
    physicalResShred = getFieldOrDefault(sharedBuffs, 'PhysicalResShred', 0);
    anemoResShred = getFieldOrDefault(sharedBuffs, 'AnemoResShred', 0) + getFieldOrDefault(sharedArtifactBuffs, 'AnemoResShred', 0);
    cryoCritDMGBonus = getFieldOrDefault(sharedBuffs, 'CryoCritDMGBonus', 0);
    anemoCritDMGBonus = getFieldOrDefault(sharedBuffs, 'AnemoCritDMGBonus', 0);
    geoCritDMGBonus = getFieldOrDefault(sharedBuffs, 'GeoCritDMGBonus', 0);
    geoCritRateBonus = getFieldOrDefault(sharedBuffs, 'GeoCritRateBonus', 0);
    physicalCritRateBonus = getFieldOrDefault(sharedBuffs, 'PhysicalCritRateBonus', 0);
    physicalCritDMGBonus = getFieldOrDefault(sharedBuffs, 'PhysicalCritDMGBonus', 0);
    mikaATKSpeedBonus = 0;

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
    hasNicole = any(memberNames == "Nicole");
    hasXianyun = any(memberNames == "Xianyun");
    hasMizuki = any(memberNames == "Mizuki");
    hasQiqi = any(memberNames == "Qiqi");
    hasDiona = any(memberNames == "Diona");
    hasBeidou = any(memberNames == "Beidou");
    hasYaeMiko = any(memberNames == "YaeMiko");
    hasPrune = any(memberNames == "Prune");
    hasMika = any(memberNames == "Mika");
    hasFaruzan = any(memberNames == "Faruzan");
    hasNahida = any(memberNames == "Nahida");
    hasSandrone = any(memberNames == "Sandrone");
    hasIlluga = any(memberNames == "Illuga");
    ascendantMoonsign = hasAscendantMoonsign(struct('MemberNames', memberNames));

    lunarBloomEnabled = hasLauma || hasNefer || (hasColumbina && hydroCount >= 1 && dendroCount >= 1);
    lunarChargedEnabled = (hasIneffa || hasFlins || hasColumbina) && hydroCount >= 1 && electroCount >= 1;
    lunarCrystallizeEnabled = (hasLinnea || hasZibai || hasColumbina) && hydroCount >= 1 && geoCount >= 1;
    stellarConductEnabled = hasSandrone && electroCount >= 1 && cryoCount >= 1;
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
    hexereiCount = localCountHexerei(memberNames);

    sharedLunarBloomBonus = getFieldOrDefault(sharedBuffs, 'LunarBloomBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'LunarBloomBonus', 0);
    sharedLunarChargedBonus = getFieldOrDefault(sharedBuffs, 'LunarChargedBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'LunarChargedBonus', 0);
    sharedLunarCrystallizeBonus = getFieldOrDefault(sharedBuffs, 'LunarCrystallizeBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'LunarCrystallizeBonus', 0);
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
    % Stellar-Conduct 在工程里拆为三层：
    % 1. StellarConductBonus: 只用于统一反应引擎里的“星超导反应”基础增伤；
    % 2. SandroneStellarConductBonus: 只用于桑多涅本人“视为星超导伤害”的直伤标签增伤；
    % 3. SandroneStellarConductC1Bonus + Active: C1 的“解码期间全队星超导增伤”动态窗口。
    superconductBonus = getFieldOrDefault(sharedBuffs, 'SuperconductBonus', 0);
    cryoSwirlBonus = getFieldOrDefault(sharedBuffs, 'CryoSwirlBonus', 0);
    stellarConductBonus = getFieldOrDefault(sharedBuffs, 'StellarConductBonus', 0);
    qiqiC6StellarConductFlatDamage = getFieldOrDefault(sharedBuffs, 'QiqiC6StellarConductFlatDamage', 0);
    stellarConductTaggedDMGBonus = getFieldOrDefault(sharedBuffs, 'StellarConductTaggedDMGBonus', 0);
    sandroneStellarConductBonus = getFieldOrDefault(sharedBuffs, 'SandroneStellarConductBonus', 0);
    sandroneStellarConductC1Bonus = getFieldOrDefault(sharedBuffs, 'SandroneStellarConductC1Bonus', 0);
    nilouBloomBonus = sharedNilouBloomBonus + 0.20 * double(nilouPureBloomTeam);

    reactionCritRate = getFieldOrDefault(sharedBuffs, 'ReactionCritRate', 0) + getFieldOrDefault(sharedArtifactBuffs, 'ReactionCritRate', 0);
    reactionCritDMG = getFieldOrDefault(sharedBuffs, 'ReactionCritDMG', 0);
    if lunarBloomEnabled || lunarChargedEnabled || lunarCrystallizeEnabled
        reactionCritRate = max(reactionCritRate, 0.10);
        reactionCritDMG = max(reactionCritDMG, 0.20);
    end

    if hasCitlali
        pyroResShred = pyroResShred + 0.20;
        hydroResShred = hydroResShred + 0.20;
    end

    if hasQiqi
        qiqiIndex = find(memberNames == "Qiqi", 1, 'first');
        qiqiConstellation = memberConstellations(qiqiIndex);
        if stellarConductEnabled
            superconductBonus = superconductBonus + 0.50;
            cryoSwirlBonus = cryoSwirlBonus + 0.50;
            stellarConductBonus = stellarConductBonus + 0.50;
            if qiqiConstellation >= 6
                qiqiC6StellarConductFlatDamage = qiqiC6StellarConductFlatDamage ...
                    + 6.0 * localApproxMemberATK(members{qiqiIndex}, 287);
            end
        end
    end

    if hasFaruzan
        faruzanIndex = find(memberNames == "Faruzan", 1, 'first');
        faruzanConstellation = memberConstellations(faruzanIndex);
        anemoResShred = anemoResShred + 0.30;
        faruzanTalentLevel = getFieldOrDefault(members{faruzanIndex}, 'TalentLevel', 10);
        faruzanBurstLevel = faruzanTalentLevel + 3 * double(faruzanConstellation >= 5);
        faruzanTalentPath = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'Faruzan', 'talents_Faruzan.csv');
        if exist(faruzanTalentPath, 'file') == 2
            faruzanTalent = readtable(faruzanTalentPath);
            anemoDMGBonus = anemoDMGBonus + getTalentValue(faruzanTalent, 'Burst', 'AnemoDMGBonus', faruzanBurstLevel);
        else
            anemoDMGBonus = anemoDMGBonus + 0.32;
        end
        if faruzanConstellation >= 6
            anemoCritDMGBonus = anemoCritDMGBonus + 0.40;
        end
    end

    if hasNahida
        nahidaIndex = find(memberNames == "Nahida", 1, 'first');
        nahidaBuild = getFieldOrDefault(members{nahidaIndex}, 'Build', struct());
        nahidaEM = getFieldOrDefault(nahidaBuild, 'EM', 0);
        emBonus = getFieldOrDefault(sharedBuffs, 'EMBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'EMBonus', 0) ...
            + min(250, 0.25 * nahidaEM);
    else
        emBonus = getFieldOrDefault(sharedBuffs, 'EMBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'EMBonus', 0);
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
        iansanBurstATKBonus = localResolveIansanSupportShare() + 0.06 * double(iansanConstellation >= 1) ...
            + 0.08 * double(iansanConstellation >= 6);
    end

    durinPreferredMode = localResolveDurinMode(sharedBuffs, durinWhiteSupportReady, durinDarkAmpReady);
    if hasDurin && durinPreferredMode == "White"
        pyroResShred = pyroResShred + 0.20 * double(durinWhiteSupportReady);
        dendroResShred = dendroResShred + 0.20 * double(burningReady);
        electroResShred = electroResShred + 0.20 * double(overloadReady);
        geoResShred = geoResShred + 0.20 * double(pyroCrystallizeReady);
    end

    nicoleSupport = localDefaultNicoleSupport();
    if hasNicole
        nicoleIndex = find(memberNames == "Nicole", 1, 'first');
        nicoleSupport = localBuildNicoleSupport( ...
            members{nicoleIndex}, members, memberNames, memberElements, hexereiCount, sharedBuffs);
        pyroResShred = pyroResShred + nicoleSupport.SharedPyroResShred;
        hydroResShred = hydroResShred + nicoleSupport.SharedHydroResShred;
        cryoResShred = cryoResShred + nicoleSupport.SharedCryoResShred;
        electroResShred = electroResShred + nicoleSupport.SharedElectroResShred;
        dendroResShred = dendroResShred + nicoleSupport.SharedDendroResShred;
        geoResShred = geoResShred + nicoleSupport.SharedGeoResShred;
        allDMGBonus = allDMGBonus + nicoleSupport.SharedAllDMGBonus;
    end
    nicoleTeamFlatATK = nicoleSupport.SharedFlatATK;
    nicoleHexereiFlatATK = nicoleSupport.HexereiProjectionFlatBase;
    nicoleProjectionBonus = 0;
    nicoleProjectionElement = nicoleSupport.ProjectionOwnerElement;
    nicoleHexereiProjectionReady = nicoleSupport.HasHexereiSecretRite;

    xianyunSupport = localDefaultXianyunSupport();
    if hasXianyun
        xianyunIndex = find(memberNames == "Xianyun", 1, 'first');
        xianyunSupport = localBuildXianyunSupport(members{xianyunIndex});
    end

    illugaSupport = localDefaultIllugaSupport();
    if hasIlluga
        illugaIndex = find(memberNames == "Illuga", 1, 'first');
        illugaSupport = localBuildIllugaSupport(members{illugaIndex}, ascendantMoonsign);
        geoCritRateBonus = geoCritRateBonus + illugaSupport.GeoCritRateBonus;
        geoCritDMGBonus = geoCritDMGBonus + illugaSupport.GeoCritDMGBonus;
        emBonus = emBonus + illugaSupport.SharedEMBonus;
    end

    flatATK = getFieldOrDefault(sharedBuffs, 'FlatATK', 0) + nicoleTeamFlatATK;
    atkBonus = getFieldOrDefault(sharedBuffs, 'ATKBonus', 0) + getFieldOrDefault(sharedArtifactBuffs, 'ATKBonus', 0) ...
        + chevreuseATKBonus + iansanBurstATKBonus;
    overloadBonus = sharedOverloadBonus + 0.35 * double(chevreuseOverloadReady) + 0.08 * double(hasVaresa && overloadReady);
    plungeDMGBonus = getFieldOrDefault(sharedBuffs, 'PlungeDMGBonus', 0) + xianyunSupport.WeaponPlungeDMGBonus;
    plungeCritRateBonus = getFieldOrDefault(sharedBuffs, 'PlungeCritRateBonus', 0) + xianyunSupport.PlungeCritRateBonus;
    physicalResShred = physicalResShred + 0.40 * double(cryoCount >= 1 && electroCount >= 1);

    if hasMizuki
        mizukiIndex = find(memberNames == "Mizuki", 1, 'first');
        mizukiBuild = getFieldOrDefault(members{mizukiIndex}, 'Build', struct());
        mizukiEM = getFieldOrDefault(mizukiBuild, 'EM', 0);
        emBonus = emBonus + 0.10 * mizukiEM;
        if getFieldOrDefault(members{mizukiIndex}, 'Constellation', 0) >= 2
            elementalShare = 0.0004 * mizukiEM;
            pyroDMGBonus = pyroDMGBonus + elementalShare;
            hydroDMGBonus = hydroDMGBonus + elementalShare;
            cryoDMGBonus = cryoDMGBonus + elementalShare;
            electroDMGBonus = electroDMGBonus + elementalShare;
            pyroResShred = pyroResShred + 0.20;
            hydroResShred = hydroResShred + 0.20;
            cryoResShred = cryoResShred + 0.20;
            electroResShred = electroResShred + 0.20;
            anemoResShred = anemoResShred + 0.20;
        end
        if getFieldOrDefault(members{mizukiIndex}, 'Constellation', 0) >= 6
            bonusCritRate = min(0.20, max(0, mizukiEM - 500) * 0.0004);
            bonusCritDMG = min(0.80, max(0, mizukiEM - 500) * 0.0016);
            reactionCritRate = max(reactionCritRate, 0.30 + bonusCritRate);
            reactionCritDMG = max(reactionCritDMG, 1.00 + bonusCritDMG);
        end
    end

    if hasDiona
        dionaIndex = find(memberNames == "Diona", 1, 'first');
        dionaConstellation = memberConstellations(dionaIndex);
        if dionaConstellation >= 6
            emBonus = emBonus + 200;
            superconductBonus = superconductBonus + 0.40;
            cryoSwirlBonus = cryoSwirlBonus + 0.40;
            stellarConductBonus = stellarConductBonus + 0.40;
        end
    end

    if hasBeidou
        beidouIndex = find(memberNames == "Beidou", 1, 'first');
        beidouConstellation = memberConstellations(beidouIndex);
        if beidouConstellation >= 6
            electroResShred = electroResShred + 0.15;
            if stellarConductEnabled
                cryoResShred = cryoResShred + 0.15;
                emBonus = emBonus + 200;
            end
        end
    end

    if hasYaeMiko
        yaeIndex = find(memberNames == "YaeMiko", 1, 'first');
        yaeConstellation = memberConstellations(yaeIndex);
        if yaeConstellation >= 1 && cryoCount >= 1 && electroCount >= 1
            electroDMGBonus = electroDMGBonus + 0.40;
            stellarConductBonus = stellarConductBonus + 0.40 * double(stellarConductEnabled);
            stellarConductTaggedDMGBonus = stellarConductTaggedDMGBonus + 0.40 * double(stellarConductEnabled);
        end
    end

    if hasPrune
        pruneIndex = find(memberNames == "Prune", 1, 'first');
        pruneATK = localApproxMemberATK(members{pruneIndex}, 221);
        pruneSharedBonus = min(0.50, max(0, 0.00025 * max(0, pruneATK - 2000)));
        allDMGBonus = allDMGBonus + pruneSharedBonus;
    end

    sandroneStellarConductActive = logical(getFieldOrDefault(sharedBuffs, ...
        'SandroneStellarConductActive', hasSandrone && (memberCount == 1 || stellarConductEnabled)));
    if hasSandrone
        sandroneIndex = find(memberNames == "Sandrone", 1, 'first');
        sandroneATK = localApproxMemberATK(members{sandroneIndex}, 342);
        sandroneConstellation = memberConstellations(sandroneIndex);
        stellarConductBonus = stellarConductBonus + min(0.14, 0.00007 * max(0, sandroneATK));
        sandroneStellarConductBonus = sandroneStellarConductBonus + 0.20;
        if sandroneConstellation >= 1
            sandroneStellarConductC1Bonus = sandroneStellarConductC1Bonus + 0.30 * double(sandroneStellarConductActive);
        end
    end

    if hasMika
        mikaIndex = find(memberNames == "Mika", 1, 'first');
        mikaConstellation = memberConstellations(mikaIndex);
        mikaTalentLevel = getFieldOrDefault(members{mikaIndex}, 'TalentLevel', 10);
        skillTalentLevel = mikaTalentLevel + 3 * double(mikaConstellation >= 3);
        mikaTalentPath = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'Mika', 'talents_Mika.csv');
        if exist(mikaTalentPath, 'file') == 2
            mikaTalent = readtable(mikaTalentPath);
            mikaATKSpeedBonus = getTalentValue(mikaTalent, 'Skill', 'ATKSPDBonus', skillTalentLevel);
        else
            mikaATKSpeedBonus = 0.22;
        end
        if mikaConstellation >= 6
            physicalCritDMGBonus = physicalCritDMGBonus + 0.60;
        end
    end

    hydroBeamBonus = 0.00;
    if hasNeuvillette
        hydroBeamBonus = hydroBeamBonus + 0.10 * min(3, pyroCount + electroCount + cryoCount);
    end

    archetypeInfo = identifyTeamArchetype(members, sharedBuffs);
    nonHydroReactionCount = pyroCount + electroCount + cryoCount;
    elementalDiversity = sum([hydroCount >= 1, cryoCount >= 1, pyroCount >= 1, ...
        dendroCount >= 1, electroCount >= 1, geoCount >= 1]);
    xilonenSampleCount = double(pyroCount >= 1) + double(hydroCount >= 1) ...
        + double(cryoCount >= 1) + double(electroCount >= 1);
    dominantLunarReaction = localResolveDominantLunarReaction( ...
        memberNames, hasLauma, hasNefer, hasNilou, hasIneffa, hasFlins, ...
        hasLinnea, hasZibai, lunarBloomEnabled, lunarChargedEnabled, ...
        lunarCrystallizeEnabled, sharedBuffs);
    enemy = localInjectReactionMode(enemy, reactionMode);
    enemyState = createEnemyState(enemy, struct( ...
        'PyroCount', pyroCount, ...
        'HydroCount', hydroCount, ...
        'CryoCount', cryoCount, ...
        'ElectroCount', electroCount, ...
        'DendroCount', dendroCount, ...
        'ReactionMode', reactionMode), localResolveDefaultTriggerElement(memberNames, memberElements));

    teamContext = struct( ...
        'MemberNames', memberNames, ...
        'MemberElements', memberElements, ...
        'MemberConstellations', memberConstellations, ...
        'MemberCount', memberCount, ...
        'ArchetypeInfo', archetypeInfo, ...
        'RotationDuration', rotationDuration, ...
        'TimelineTable', getFieldOrDefault(sharedBuffs, 'TimelineTable', table()), ...
        'TimelineSummary', getFieldOrDefault(sharedBuffs, 'TimelineSummary', struct()), ...
        'MemberTimelineSummary', getFieldOrDefault(sharedBuffs, 'MemberTimelineSummary', table()), ...
        'EnergySummary', getFieldOrDefault(sharedBuffs, 'EnergySummary', table()), ...
        'EnergyTimeline', getFieldOrDefault(sharedBuffs, 'EnergyTimeline', table()), ...
        'ActiveEffectsTable', getFieldOrDefault(sharedBuffs, 'ActiveEffectsTable', table()), ...
        'FinalEnemyState', getFieldOrDefault(sharedBuffs, 'FinalEnemyState', struct()), ...
        'CanLoopNextCycle', logical(getFieldOrDefault(sharedBuffs, 'CanLoopNextCycle', false)), ...
        'LoopReadiness', double(getFieldOrDefault(sharedBuffs, 'LoopReadiness', 0)), ...
        'NightsoulCount', sum(ismember(memberNames, [ ...
            "Chasca", "Citlali", "Iansan", "Ifa", "Kachina", "Kinich", "Mavuika", "Ororon", "Xilonen"])), ...
        'NightsoulPointPool', getFieldOrDefault(sharedBuffs, 'NightsoulPointPool', 0), ...
        'ReactionMode', reactionMode, ...
        'EnemyState', enemyState, ...
        'SharedAllDMGBonus', sharedAllDMGBonus, ...
        'ArtifactTeamBuffs', sharedArtifactBuffs, ...
        'ApproxFurinaBonus', furinaApproxBonus, ...
        'AllDMGBonus', allDMGBonus, ...
        'PyroDMGBonus', pyroDMGBonus, ...
        'HydroDMGBonus', hydroDMGBonus, ...
        'CryoDMGBonus', cryoDMGBonus, ...
        'ElectroDMGBonus', electroDMGBonus, ...
        'AnemoDMGBonus', anemoDMGBonus, ...
        'GeoDMGBonus', geoDMGBonus, ...
        'DendroDMGBonus', dendroDMGBonus, ...
        'PhysicalDMGBonus', physicalDMGBonus, ...
        'ShieldBonus', shieldBonus, ...
        'FlatATK', flatATK, ...
        'ATKBonus', atkBonus, ...
        'EMBonus', emBonus, ...
        'PlungeDMGBonus', plungeDMGBonus, ...
        'PlungeCritRateBonus', plungeCritRateBonus, ...
        'XianyunFlatPlungeBonus', xianyunSupport.FlatPlungeDamage, ...
        'XianyunSupportATK', xianyunSupport.ATK, ...
        'XianyunBurstSupportActive', xianyunSupport.StarwickerActive, ...
        'HydroResShred', hydroResShred, ...
        'CryoResShred', cryoResShred, ...
        'PyroResShred', pyroResShred, ...
        'DendroResShred', dendroResShred, ...
        'ElectroResShred', electroResShred, ...
        'GeoResShred', geoResShred, ...
        'PhysicalResShred', physicalResShred, ...
        'AnemoResShred', anemoResShred, ...
        'CryoCritDMGBonus', cryoCritDMGBonus, ...
        'AnemoCritDMGBonus', anemoCritDMGBonus, ...
        'GeoCritDMGBonus', geoCritDMGBonus, ...
        'GeoCritRateBonus', geoCritRateBonus, ...
        'IllugaSupport', illugaSupport, ...
        'PhysicalCritRateBonus', physicalCritRateBonus, ...
        'PhysicalCritDMGBonus', physicalCritDMGBonus, ...
        'MikaATKSpeedBonus', mikaATKSpeedBonus, ...
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
        'StellarConductEnabled', stellarConductEnabled, ...
        'DominantLunarReaction', dominantLunarReaction, ...
        'NilouPureBloomTeam', nilouPureBloomTeam, ...
        'SharedLunarBloomBonus', sharedLunarBloomBonus, ...
        'SharedLunarChargedBonus', sharedLunarChargedBonus, ...
        'SharedLunarCrystallizeBonus', sharedLunarCrystallizeBonus, ...
        'LunarBloomBonus', lunarBloomBonus, ...
        'LunarChargedBonus', lunarChargedBonus, ...
        'LunarCrystallizeBonus', lunarCrystallizeBonus, ...
        'SuperconductBonus', superconductBonus, ...
        'CryoSwirlBonus', cryoSwirlBonus, ...
        'StellarConductBonus', stellarConductBonus, ...
        'QiqiC6StellarConductFlatDamage', qiqiC6StellarConductFlatDamage, ...
        'StellarConductTaggedDMGBonus', stellarConductTaggedDMGBonus, ...
        'SandroneStellarConductBonus', sandroneStellarConductBonus, ...
        'SandroneStellarConductC1Bonus', sandroneStellarConductC1Bonus, ...
        'SandroneStellarConductActive', sandroneStellarConductActive, ...
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
        'HexereiCount', hexereiCount, ...
        'NicoleTeamFlatATK', nicoleTeamFlatATK, ...
        'NicoleHexereiFlatATK', nicoleHexereiFlatATK, ...
        'NicoleProjectionBonus', nicoleProjectionBonus, ...
        'NicoleProjectionElement', nicoleProjectionElement, ...
        'NicoleHexereiProjectionReady', nicoleHexereiProjectionReady, ...
        'NicoleATK', nicoleSupport.NicoleATK, ...
        'NicoleSkillLevel', nicoleSupport.SkillLevel, ...
        'NicoleBurstLevel', nicoleSupport.BurstLevel, ...
        'NicoleGraceFlatATK', nicoleSupport.GraceFlatATK, ...
        'NicoleGuidanceFlatATK', nicoleSupport.GuidanceFlatATK, ...
        'NicoleGuidanceResShred', nicoleSupport.GuidanceResShred, ...
        'NicoleC6DefIgnore', nicoleSupport.C6DefIgnore, ...
        'NicolePathfinderFlatDamage', nicoleSupport.PathfinderFlatDamage, ...
        'NicolePathfinderMaxHits', nicoleSupport.PathfinderMaxHits, ...
        'NicoleProjectionMultiplier', nicoleSupport.ProjectionMultiplier, ...
        'NicoleProjectionCooldown', nicoleSupport.ProjectionCooldown, ...
        'NicoleProjectionMaxCount', nicoleSupport.ProjectionMaxCount, ...
        'NicoleProjectionOwnerName', nicoleSupport.ProjectionOwnerName, ...
        'NicoleProjectionOwnerElement', nicoleSupport.ProjectionOwnerElement, ...
        'NicoleProjectionOwnerIsHexerei', nicoleSupport.ProjectionOwnerIsHexerei, ...
        'NicoleProjectionOwnerConfig', nicoleSupport.ProjectionOwnerConfig, ...
        'NicoleProjectionOwnerBaseATK', nicoleSupport.ProjectionOwnerBaseATK, ...
        'NicoleHexereiProjectionFlatBase', nicoleSupport.HexereiProjectionFlatBase, ...
        'NicoleUnityMultiplier', nicoleSupport.UnityMultiplier, ...
        'NicoleUnityCooldown', nicoleSupport.UnityCooldown, ...
        'NicoleWeaponActiveDMGBonus', nicoleSupport.WeaponActiveDMGBonus, ...
        'NicoleWeaponHexereiOffFieldDMGBonus', nicoleSupport.WeaponHexereiOffFieldDMGBonus, ...
        'NicoleWeaponEnergyRestore', nicoleSupport.WeaponEnergyRestore, ...
        'NicoleSharedAllDMGBonus', nicoleSupport.SharedAllDMGBonus, ...
        'NicoleSharedFlatATK', nicoleSupport.SharedFlatATK, ...
        'NicoleSharedPyroResShred', nicoleSupport.SharedPyroResShred, ...
        'NicoleSharedHydroResShred', nicoleSupport.SharedHydroResShred, ...
        'NicoleSharedCryoResShred', nicoleSupport.SharedCryoResShred, ...
        'NicoleSharedElectroResShred', nicoleSupport.SharedElectroResShred, ...
        'NicoleSharedDendroResShred', nicoleSupport.SharedDendroResShred, ...
        'NicoleSharedGeoResShred', nicoleSupport.SharedGeoResShred, ...
        'NicoleApproxSharedAllDMGBonus', nicoleSupport.SharedAllDMGBonus, ...
        'NicoleApproxSharedFlatATK', nicoleSupport.SharedFlatATK, ...
        'NicoleApproxSharedPyroResShred', nicoleSupport.SharedPyroResShred, ...
        'NicoleApproxSharedHydroResShred', nicoleSupport.SharedHydroResShred, ...
        'NicoleApproxSharedCryoResShred', nicoleSupport.SharedCryoResShred, ...
        'NicoleApproxSharedElectroResShred', nicoleSupport.SharedElectroResShred, ...
        'NicoleApproxSharedDendroResShred', nicoleSupport.SharedDendroResShred, ...
        'NicoleApproxSharedGeoResShred', nicoleSupport.SharedGeoResShred, ...
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

function reactionMode = localResolveReactionMode(sharedBuffs, enemy)
    reactionMode = string(getFieldOrDefault(enemy, 'ReactionMode', ""));
    if strlength(reactionMode) == 0
        reactionMode = string(getFieldOrDefault(sharedBuffs, 'ReactionMode', ""));
    end
    token = lower(char(reactionMode));
    switch token
        case {'approximate', 'approx', 'supportaura', 'legacy'}
            reactionMode = "Approximate";
        case {'realistic', 'real', 'explicit', 'sequence'}
            reactionMode = "Realistic";
        otherwise
            reactionMode = "Approximate";
    end
end

function enemy = localInjectReactionMode(enemy, reactionMode)
    enemy.ReactionMode = reactionMode;
    if ~isfield(enemy, 'AutoSupportAura')
        enemy.AutoSupportAura = strcmpi(char(reactionMode), 'Approximate');
    end
end

function buffs = localCollectArtifactTeamBuffs(members)
    buffs = localEmptyArtifactTeamBuffs();
    setBuckets = struct();
    for i = 1:numel(members)
        if ~isfield(members{i}, 'Build')
            continue;
        end
        build = normalizeArtifactBuild(members{i}.Build, members{i}.Name);
        memberBuffs = getArtifactTeamBuffs(members{i}.Name, build);
        activeSetId = localGetActiveArtifactFourPieceSet(build);
        bucketKey = matlab.lang.makeValidName(char(activeSetId));
        if strlength(activeSetId) == 0
            bucketKey = sprintf('Member%d', i);
        end
        if ~isfield(setBuckets, bucketKey)
            setBuckets.(bucketKey) = localEmptyArtifactTeamBuffs();
        end
        setBuckets.(bucketKey) = localMergeArtifactTeamBuffsMax(setBuckets.(bucketKey), memberBuffs);
    end

    bucketNames = fieldnames(setBuckets);
    for i = 1:numel(bucketNames)
        buffs = localAddArtifactTeamBuffs(buffs, setBuckets.(bucketNames{i}));
    end
end

function setId = localGetActiveArtifactFourPieceSet(build)
    setId = "";
    if ~logical(getFieldOrDefault(build, 'ArtifactSet4Active', 1))
        return;
    end

    slots = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
    setPieces = struct();
    for i = 1:numel(slots)
        fieldName = sprintf('Artifact%sSet', slots{i});
        currentSet = string(getFieldOrDefault(build, fieldName, ""));
        if strlength(currentSet) == 0 || currentSet == "None"
            continue;
        end
        key = matlab.lang.makeValidName(char(currentSet));
        if ~isfield(setPieces, key)
            setPieces.(key) = 0;
        end
        setPieces.(key) = setPieces.(key) + 1;
        if setPieces.(key) >= 4
            setId = currentSet;
            return;
        end
    end

    legacySet1 = string(getFieldOrDefault(build, 'ArtifactSet1', ""));
    legacySet1Pieces = getFieldOrDefault(build, 'ArtifactSet1Pieces', 0);
    if legacySet1 ~= "None" && legacySet1Pieces >= 4
        setId = legacySet1;
    end
end

function buffs = localEmptyArtifactTeamBuffs()
    buffs = struct( ...
        'ATKBonus', 0, ...
        'EMBonus', 0, ...
        'AllDMGBonus', 0, ...
        'PyroDMGBonus', 0, ...
        'HydroDMGBonus', 0, ...
        'CryoDMGBonus', 0, ...
        'ElectroDMGBonus', 0, ...
        'AnemoDMGBonus', 0, ...
        'GeoDMGBonus', 0, ...
        'DendroDMGBonus', 0, ...
        'ShieldBonus', 0, ...
        'LunarBloomBonus', 0, ...
        'LunarChargedBonus', 0, ...
        'LunarCrystallizeBonus', 0, ...
        'ReactionCritRate', 0, ...
        'DendroResShred', 0, ...
        'PyroResShred', 0, ...
        'HydroResShred', 0, ...
        'CryoResShred', 0, ...
        'ElectroResShred', 0, ...
        'GeoResShred', 0);
end

function support = localDefaultIllugaSupport()
    support = struct( ...
        'GeoCritRateBonus', 0, ...
        'GeoCritDMGBonus', 0, ...
        'SharedEMBonus', 0);
end

function support = localBuildIllugaSupport(illugaMember, moonsignActive)
    support = localDefaultIllugaSupport();
    constellation = getFieldOrDefault(illugaMember, 'Constellation', 0);

    % Torchforger's Covenant is modeled as a shared team buff here.
    % Illuga's own simulator removes these bonuses from his personal view.
    if constellation >= 6
        support.GeoCritRateBonus = 0.10;
        support.GeoCritDMGBonus = 0.30;
    else
        support.GeoCritRateBonus = 0.05;
        support.GeoCritDMGBonus = 0.10;
    end

    if moonsignActive
        if constellation >= 6
            support.SharedEMBonus = 80;
        else
            support.SharedEMBonus = 50;
        end
    end
end

function merged = localMergeArtifactTeamBuffsMax(baseBuffs, incomingBuffs)
    merged = baseBuffs;
    fields = fieldnames(baseBuffs);
    for i = 1:numel(fields)
        fieldName = fields{i};
        merged.(fieldName) = max(getFieldOrDefault(baseBuffs, fieldName, 0), getFieldOrDefault(incomingBuffs, fieldName, 0));
    end
end

function merged = localAddArtifactTeamBuffs(baseBuffs, incomingBuffs)
    merged = baseBuffs;
    fields = fieldnames(baseBuffs);
    for i = 1:numel(fields)
        fieldName = fields{i};
        merged.(fieldName) = getFieldOrDefault(baseBuffs, fieldName, 0) + getFieldOrDefault(incomingBuffs, fieldName, 0);
    end
end

function triggerElement = localResolveDefaultTriggerElement(memberNames, memberElements)
    triggerElement = "";
    priority = ["Pyro", "Hydro", "Cryo", "Electro", "Dendro"];
    for i = 1:numel(priority)
        matchIndex = find(memberElements == priority(i), 1, 'first');
        if ~isempty(matchIndex)
            if memberNames(matchIndex) == "Nicole"
                continue;
            end
            triggerElement = priority(i);
            return;
        end
    end
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

function bonus = localApproxFurinaBonus(members, rotationDuration, sharedBuffs, enemy, furinaIndex, baseAllDMGBonus)
    if nargin < 6 || isempty(baseAllDMGBonus)
        baseAllDMGBonus = 0;
    end
    if nargin < 5 || isempty(furinaIndex) || furinaIndex < 1 || furinaIndex > numel(members)
        bonus = 0;
        return;
    end
    if nargin < 4 || isempty(enemy)
        enemy = struct();
    end
    if nargin < 3 || isempty(sharedBuffs)
        sharedBuffs = struct();
    end
    if nargin < 2 || isempty(rotationDuration) || ~isfinite(rotationDuration) || rotationDuration <= 0
        rotationDuration = 20;
    end

    furinaMember = members{furinaIndex};
    constellation = getFieldOrDefault(furinaMember, 'Constellation', 0);

    timelineSummary = getFieldOrDefault(sharedBuffs, 'TimelineSummary', struct());
    energySummary = getFieldOrDefault(sharedBuffs, 'EnergySummary', table());
    memberTimeline = getFieldOrDefault(sharedBuffs, 'MemberTimelineSummary', table());
    activeEffects = getFieldOrDefault(sharedBuffs, 'ActiveEffectsTable', table());

    if isempty(memberTimeline) || ~istable(memberTimeline)
        bonus = localHeuristicFurinaBonus(members, rotationDuration, constellation);
        return;
    end

    furinaName = string(getFieldOrDefault(furinaMember, 'DisplayName', furinaMember.Name));
    furinaTimelineRow = memberTimeline(string(memberTimeline.Character) == furinaName, :);
    if isempty(furinaTimelineRow)
        furinaTimelineRow = memberTimeline(string(memberTimeline.Character) == "Furina", :);
    end

    if isempty(furinaTimelineRow)
        bonus = localHeuristicFurinaBonus(members, rotationDuration, constellation);
        return;
    end

    furinaScheduledTime = max(0, double(furinaTimelineRow.ScheduledActionTime(1)));
    furinaBackgroundTime = max(0, double(furinaTimelineRow.BackgroundEventTime(1)));
    partyOccupancy = max(0, double(getFieldOrDefault(timelineSummary, 'MemberOccupiedTime', 0)));
    swapTime = max(0, double(getFieldOrDefault(timelineSummary, 'SwapTime', 0)));
    [fanfareCoverage, salonWindowCoverage] = localResolveFurinaEffectCoverage(activeEffects, furinaName, rotationDuration);
    onFieldShare = min(1, furinaScheduledTime / max(rotationDuration, 1e-6));
    supportShare = min(1, max(furinaBackgroundTime / max(rotationDuration, 1e-6), salonWindowCoverage));
    actionDensity = min(1, (partyOccupancy + swapTime) / max(rotationDuration, 1e-6));

    if isempty(energySummary) || ~istable(energySummary)
        furinaLoopReady = min(1, double(getFieldOrDefault(sharedBuffs, 'LoopReadiness', 0)));
    else
        furinaEnergyRow = energySummary(string(energySummary.Character) == furinaName, :);
        if isempty(furinaEnergyRow)
            furinaEnergyRow = energySummary(string(energySummary.Character) == "Furina", :);
        end
        if isempty(furinaEnergyRow)
            furinaLoopReady = min(1, double(getFieldOrDefault(sharedBuffs, 'LoopReadiness', 0)));
        else
            furinaLoopReady = min(1, double(furinaEnergyRow.EndEnergy(1)) / max(1, double(furinaEnergyRow.BurstCost(1))));
        end
    end

    rotationCoverage = min(1, 0.50 + 0.20 * actionDensity + 0.15 * furinaLoopReady + 0.15 * fanfareCoverage);
    salonCoverage = min(1, 0.25 + 0.60 * supportShare + 0.25 * fanfareCoverage + 0.15 * onFieldShare);
    teamHPRhythm = min(1, 0.50 + 0.20 * fanfareCoverage + 0.20 * supportShare ...
        + 0.10 * actionDensity + 0.10 * min(1, max(0, numel(members) - 1) / 3));
    baseCap = 0.75 + 0.15 * double(constellation >= 1) + 0.18 * double(constellation >= 2);
    bonus = baseCap * rotationCoverage * salonCoverage * teamHPRhythm;
    bonus = max(0.20, bonus);
end

function [fanfareCoverage, salonCoverage] = localResolveFurinaEffectCoverage(activeEffects, furinaName, rotationDuration)
    fanfareCoverage = 0;
    salonCoverage = 0;
    if isempty(activeEffects) || ~istable(activeEffects) || height(activeEffects) == 0
        return;
    end

    if ~ismember('Character', string(activeEffects.Properties.VariableNames)) ...
            || ~ismember('EffectTag', string(activeEffects.Properties.VariableNames))
        return;
    end

    characterMask = string(activeEffects.Character) == furinaName | string(activeEffects.Character) == "Furina";
    if ~any(characterMask)
        return;
    end

    furinaRows = activeEffects(characterMask, :);
    fanfareCoverage = localResolveEffectTagCoverage(furinaRows, "Fanfare", rotationDuration);
    salonCoverage = localResolveEffectTagCoverage(furinaRows, "SalonMembers", rotationDuration);
end

function coverage = localResolveEffectTagCoverage(effectRows, effectTag, rotationDuration)
    coverage = 0;
    if isempty(effectRows) || ~istable(effectRows) || height(effectRows) == 0
        return;
    end

    tagRows = effectRows(string(effectRows.EffectTag) == string(effectTag), :);
    if isempty(tagRows)
        return;
    end

    starts = double(tagRows.StartTime);
    ends = double(tagRows.EndTime);
    validMask = isfinite(starts) & isfinite(ends) & ends > starts;
    starts = starts(validMask);
    ends = ends(validMask);
    if isempty(starts)
        return;
    end

    intervals = sortrows([starts(:), ends(:)], [1 2]);
    coveredDuration = 0;
    currentStart = intervals(1, 1);
    currentEnd = intervals(1, 2);
    for i = 2:size(intervals, 1)
        nextStart = intervals(i, 1);
        nextEnd = intervals(i, 2);
        if nextStart <= currentEnd + 1e-9
            currentEnd = max(currentEnd, nextEnd);
        else
            coveredDuration = coveredDuration + max(0, currentEnd - currentStart);
            currentStart = nextStart;
            currentEnd = nextEnd;
        end
    end
    coveredDuration = coveredDuration + max(0, currentEnd - currentStart);
    coverage = min(1, coveredDuration / max(rotationDuration, 1e-6));
end

function bonus = localHeuristicFurinaBonus(members, rotationDuration, constellation)
    memberCount = numel(members);
    normalizedNames = strings(1, memberCount);
    for i = 1:memberCount
        normalizedNames(i) = lower(regexprep(char(string(getFieldOrDefault(members{i}, 'Name', ""))), '[^a-z0-9]', ''));
    end

    supportCount = max(0, memberCount - 1);
    healerNames = [ ...
        "barbara", "jean", "xianyun", "charlotte", "baizhu", "yaoyao", ...
        "diona", "mika", "qiqi", "sigewinne", "sangonomiyakokomi"];
    offFieldNames = [ ...
        "yelan", "xingqiu", "fischl", "xiangling", "nahida", "escoffier", "citlali", "nicole"];
    hasHealer = any(ismember(normalizedNames, healerNames));
    hasBusyOffField = any(ismember(normalizedNames, offFieldNames));

    actionDensity = min(1, 0.50 + 0.10 * supportCount + 0.08 * double(rotationDuration >= 18) + 0.06 * double(hasBusyOffField));
    onFieldShare = min(1, 0.12 + 0.03 * supportCount);
    supportShare = min(1, 0.32 + 0.18 * supportCount + 0.08 * double(hasBusyOffField));
    furinaLoopReady = min(1, 0.46 + 0.10 * supportCount + 0.12 * double(hasHealer));

    rotationCoverage = 0.50 + 0.25 * actionDensity + 0.25 * furinaLoopReady;
    salonCoverage = min(1, 0.32 + 0.82 * supportShare + 0.20 * onFieldShare);
    teamHPRhythm = min(1, 0.50 + 0.16 * supportCount + 0.12 * double(hasHealer));
    baseCap = 0.75 + 0.15 * double(constellation >= 1) + 0.18 * double(constellation >= 2);
    bonus = baseCap * rotationCoverage * salonCoverage * teamHPRhythm;
    bonus = max(0.20, bonus);
end

function bonus = localFallbackFurinaBonus(constellation)
    if constellation >= 2
        bonus = 0.92;
    elseif constellation >= 1
        bonus = 0.76;
    else
        bonus = 0.56;
    end
end

function share = localResolveIansanSupportShare()
    share = 0;
    talentPath = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'Iansan', 'talents_Iansan.csv');
    if exist(talentPath, 'file') ~= 2
        share = 0.28;
        return;
    end

    try
        talent = readtable(talentPath, 'TextType', 'string');
        row = talent(strcmp(string(talent.Skill), "Support") & strcmp(string(talent.Param), "ATKShare"), :);
        if ~isempty(row)
            share = double(row.Level10(1));
            return;
        end
    catch
    end

    share = 0.28;
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

function count = localCountHexerei(memberNames)
    count = 0;
    for i = 1:numel(memberNames)
        if localIsHexerei(memberNames(i))
            count = count + 1;
        end
    end
end

function tf = localIsHexerei(name)
    switch lower(char(name))
        case {'nicole', 'alice', 'prune'}
            tf = true;
        otherwise
            tf = false;
    end
end

function atk = localApproxMemberATK(member, fallbackBaseATK)
    build = getFieldOrDefault(member, 'Build', struct());
    atk = (fallbackBaseATK + getFieldOrDefault(build, 'WeaponATK', 0)) ...
        * (1 + getFieldOrDefault(build, 'AtkBonus', 0)) + getFieldOrDefault(build, 'FlatATK', 0);
end

function support = localDefaultXianyunSupport()
    support = struct( ...
        'ATK', 0, ...
        'FlatPlungeDamage', 0, ...
        'PlungeCritRateBonus', 0, ...
        'WeaponPlungeDMGBonus', 0, ...
        'StarwickerActive', false);
end

function support = localBuildXianyunSupport(xianyunMember)
    support = localDefaultXianyunSupport();
    constellation = getFieldOrDefault(xianyunMember, 'Constellation', 0);
    build = getFieldOrDefault(xianyunMember, 'Build', struct());
    atk = localApproxMemberATK(xianyunMember, 335);
    support.ATK = atk;
    support.StarwickerActive = true;
    support.PlungeCritRateBonus = 0.10;
    support.FlatPlungeDamage = min(9000, 2.0 * atk);
    if constellation >= 2
        support.FlatPlungeDamage = min(18000, 4.0 * atk);
    end

    refine = max(1, min(5, getFieldOrDefault(build, 'WeaponRefinement', 1)));
    weaponName = lower(char(string(getFieldOrDefault(build, 'Weapon', ""))));
    if contains(weaponName, 'crane')
        plungeBonusByRefine = [0.28, 0.41, 0.54, 0.67, 0.80];
        support.WeaponPlungeDMGBonus = plungeBonusByRefine(refine);
    end
end

function support = localDefaultNicoleSupport()
    support = struct( ...
        'NicoleATK', 0, ...
        'SkillLevel', 10, ...
        'BurstLevel', 10, ...
        'GraceFlatATK', 0, ...
        'GuidanceFlatATK', 300, ...
        'GuidanceResShred', 0, ...
        'C6DefIgnore', 0, ...
        'PathfinderFlatDamage', 0, ...
        'PathfinderMaxHits', 0, ...
        'ProjectionMultiplier', 0, ...
        'ProjectionCooldown', 3.0, ...
        'ProjectionMaxCount', 4, ...
        'ProjectionOwnerName', "Nicole", ...
        'ProjectionOwnerElement', "Pyro", ...
        'ProjectionOwnerIsHexerei', false, ...
        'ProjectionOwnerConfig', struct(), ...
        'ProjectionOwnerBaseATK', 0, ...
        'HasHexereiSecretRite', false, ...
        'HexereiProjectionFlatBase', 0, ...
        'SharedAllDMGBonus', 0, ...
        'UnityMultiplier', 0, ...
        'UnityCooldown', 6.0, ...
        'WeaponActiveDMGBonus', 0, ...
        'WeaponHexereiOffFieldDMGBonus', 0, ...
        'WeaponEnergyRestore', 0, ...
        'SharedFlatATK', 0, ...
        'SharedPyroResShred', 0, ...
        'SharedHydroResShred', 0, ...
        'SharedCryoResShred', 0, ...
        'SharedElectroResShred', 0, ...
        'SharedDendroResShred', 0, ...
        'SharedGeoResShred', 0);
end

function support = localBuildNicoleSupport(nicoleMember, members, memberNames, memberElements, hexereiCount, sharedBuffs)
    support = localDefaultNicoleSupport();
    constellation = getFieldOrDefault(nicoleMember, 'Constellation', 0);
    talentLevel = getFieldOrDefault(nicoleMember, 'TalentLevel', 10);
    build = getFieldOrDefault(nicoleMember, 'Build', struct());
    nicoleATK = localApproxMemberATK(nicoleMember, 342);
    skillLevel = talentLevel + 3 * double(constellation >= 3);
    burstLevel = talentLevel + 3 * double(constellation >= 5);
    refine = max(1, min(5, getFieldOrDefault(build, 'WeaponRefinement', 1)));

    talentPath = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'Nicole', 'talents_Nicole.csv');
    talent = readtable(talentPath);

    support.NicoleATK = nicoleATK;
    support.SkillLevel = skillLevel;
    support.BurstLevel = burstLevel;
    support.GraceFlatATK = min( ...
        getTalentValue(talent, 'Skill', 'GraceATKCap', skillLevel), ...
        nicoleATK * getTalentValue(talent, 'Skill', 'GraceATKRatio', skillLevel));
    support.GuidanceFlatATK = 300;
    support.GuidanceResShred = 0.25 * double(constellation >= 2);
    support.C6DefIgnore = 0.40 * double(constellation >= 6);
    support.PathfinderFlatDamage = 0.70 * nicoleATK * double(constellation >= 4);
    support.PathfinderMaxHits = 8 * double(constellation >= 4);
    support.ProjectionMultiplier = getTalentValue(talent, 'Burst', 'ProjectionATK', burstLevel);
    support.ProjectionCooldown = 3.0;
    support.ProjectionMaxCount = 4;
    support.UnityMultiplier = 6.0 * double(constellation >= 1);
    support.UnityCooldown = 6.0;
    support.HasHexereiSecretRite = hexereiCount >= 2 || numel(memberNames) == 1;
    support.HexereiProjectionFlatBase = 3.0 * nicoleATK * double(support.HasHexereiSecretRite);

    [ownerName, ownerElement, ownerIsHexerei, ownerConfig] = localResolveNicoleProjectionOwner( ...
        members, memberNames, memberElements, sharedBuffs);
    support.ProjectionOwnerName = ownerName;
    support.ProjectionOwnerElement = ownerElement;
    support.ProjectionOwnerIsHexerei = ownerIsHexerei;
    support.ProjectionOwnerConfig = ownerConfig;
    support.ProjectionOwnerBaseATK = localResolveNicoleOwnerBaseATK(ownerConfig);

    % 专武「尘光七谕」在 Nicole 身上是高优先默认武器，其团队增伤可近似
    % 进共享 DMG 区；更精细的“仅前台生效/Hexerei 后台吃半额”会在 Nicole
    % 自身模拟器里继续单独使用。
    support.WeaponActiveDMGBonus = localNicoleWeaponActiveBonus(nicoleATK, refine);
    support.WeaponHexereiOffFieldDMGBonus = 0.50 * support.WeaponActiveDMGBonus;
    support.WeaponEnergyRestore = 13 + refine;
    support.SharedAllDMGBonus = support.WeaponActiveDMGBonus;

    support.SharedFlatATK = support.GraceFlatATK + support.GuidanceFlatATK;
    if constellation >= 2
        support.SharedFlatATK = support.SharedFlatATK + 300;
        [pyroShred, hydroShred, cryoShred, electroShred, dendroShred, geoShred] = ...
            localNicoleSharedResShred(memberNames, memberElements);
        support.SharedPyroResShred = pyroShred;
        support.SharedHydroResShred = hydroShred;
        support.SharedCryoResShred = cryoShred;
        support.SharedElectroResShred = electroShred;
        support.SharedDendroResShred = dendroShred;
        support.SharedGeoResShred = geoShred;
    end
end

function [ownerName, ownerElement, ownerIsHexerei, ownerConfig] = localResolveNicoleProjectionOwner(members, memberNames, memberElements, sharedBuffs)
    overrideName = string(getFieldOrDefault(sharedBuffs, 'NicoleProjectionOwner', ""));
    ownerIndex = [];
    if strlength(overrideName) > 0
        ownerIndex = find(memberNames == overrideName, 1, 'first');
    end

    if isempty(ownerIndex)
        ownerIndex = localResolveNicoleProjectionOwnerIndex(memberNames, memberElements);
    end

    ownerName = memberNames(ownerIndex);
    ownerElement = memberElements(ownerIndex);
    ownerIsHexerei = localIsHexerei(ownerName);
    ownerConfig = members{ownerIndex};
end

function baseATK = localResolveNicoleOwnerBaseATK(ownerConfig)
    baseATK = 0;
    ownerName = string(getFieldOrDefault(ownerConfig, 'Name', ""));
    if strlength(ownerName) == 0
        return;
    end

    filePath = resolveCharacterDataFile(ownerName, 'characters');
    if strlength(filePath) == 0 || exist(char(filePath), 'file') ~= 2
        return;
    end

    try
        tbl = readtable(char(filePath), 'TextType', 'string');
    catch
        return;
    end
    baseATK = double(getFieldOrDefault(tbl, 'BaseATK', 0));
end

function ownerIndex = localResolveNicoleProjectionOwnerIndex(memberNames, memberElements)
    filteredIndices = zeros(1, 0);
    filteredElements = strings(1, 0);
    for i = 1:numel(memberNames)
        if memberNames(i) ~= "Nicole"
            filteredIndices(end + 1) = i; %#ok<AGROW>
            filteredElements(end + 1) = memberElements(i); %#ok<AGROW>
        end
    end

    if isempty(filteredIndices)
        ownerIndex = find(memberNames == "Nicole", 1, 'first');
        return;
    end

    priority = ["Hydro", "Cryo", "Electro", "Anemo", "Geo", "Dendro", "Pyro"];
    for i = 1:numel(priority)
        matchIndex = find(filteredElements == priority(i), 1, 'first');
        if ~isempty(matchIndex)
            ownerIndex = filteredIndices(matchIndex);
            return;
        end
    end

    ownerIndex = filteredIndices(1);
end

function [pyroShred, hydroShred, cryoShred, electroShred, dendroShred, geoShred] = localNicoleSharedResShred(memberNames, memberElements)
    pyroShred = 0;
    hydroShred = 0;
    cryoShred = 0;
    electroShred = 0;
    dendroShred = 0;
    geoShred = 0;

    uniqueElements = unique(memberElements(memberNames ~= "Nicole"));
    for i = 1:numel(uniqueElements)
        switch lower(char(uniqueElements(i)))
            case 'pyro'
                pyroShred = 0.25;
            case 'hydro'
                hydroShred = 0.25;
            case 'cryo'
                cryoShred = 0.25;
            case 'electro'
                electroShred = 0.25;
            case 'dendro'
                dendroShred = 0.25;
            case 'geo'
                geoShred = 0.25;
        end
    end
end

function bonus = localNicoleWeaponActiveBonus(nicoleATK, refinement)
    perThousand = [0.10, 0.13, 0.16, 0.19, 0.22];
    cap = [0.26, 0.34, 0.42, 0.50, 0.58];
    bonus = min(cap(refinement), perThousand(refinement) * nicoleATK / 1000);
end

function element = localResolveNicoleProjectionElement(memberNames, memberElements)
    ownerIndex = localResolveNicoleProjectionOwnerIndex(memberNames, memberElements);
    element = memberElements(ownerIndex);
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
        case 'nicole'
            element = "Pyro";
        case 'hutao'
            element = "Pyro";
        case 'charlotte'
            element = "Cryo";
        case 'wriothesley'
            element = "Cryo";
        case 'freminet'
            element = "Cryo";
        case 'lyney'
            element = "Pyro";
        case 'lynette'
            element = "Anemo";
        case 'baizhu'
            element = "Dendro";
        case 'kaveh'
            element = "Dendro";
        case 'mika'
            element = "Cryo";
        case 'dehya'
            element = "Pyro";
        case 'alhaitham'
            element = "Dendro";
        case 'yaoyao'
            element = "Dendro";
        case 'faruzan'
            element = "Anemo";
        case 'wanderer'
            element = "Anemo";
        case 'layla'
            element = "Cryo";
        case 'nahida'
            element = "Dendro";
        case 'candace'
            element = "Hydro";
        case 'cyno'
            element = "Electro";
        case 'dori'
            element = "Electro";
        case 'collei'
            element = "Dendro";
        case 'xianyun'
            element = "Anemo";
        case 'navia'
            element = "Geo";
        case 'gaming'
            element = "Pyro";
        case 'chiori'
            element = "Geo";
        case 'sigewinne'
            element = "Hydro";
        case 'clorinde'
            element = "Electro";
        case 'emilie'
            element = "Dendro";
        case 'kachina'
            element = "Geo";
        case 'kinich'
            element = "Dendro";
        case 'sethos'
            element = "Electro";
        case 'ororon'
            element = "Electro";
        case {'mizuki', 'yumemizuki mizuki'}
            element = "Anemo";
        case 'ifa'
            element = "Anemo";
        case 'dahlia'
            element = "Hydro";
        case 'jahoda'
            element = "Anemo";
        case 'aino'
            element = "Hydro";
        case 'varka'
            element = "Anemo";
        case 'lohen'
            element = "Cryo";
        case 'illuga'
            element = "Geo";
        case 'prune'
            element = "Anemo";
        case {'lanyan', 'lanyan '}
            element = "Anemo";
        otherwise
            element = getCharacterElement(name);
    end
end
