function teamContext = buildTeamContext(members, rotationDuration, sharedBuffs)
    % 构造队伍级共享上下文。
    % 这里统一整理成员身份、元素数量、共享 Buff、近似被动条件和
    % 反应开关，避免每个角色模拟器重复做同样的队伍分析。
    if nargin < 2 || isempty(rotationDuration)
        rotationDuration = 20;
    end
    if nargin < 3 || isempty(sharedBuffs)
        sharedBuffs = struct();
    end

    % 先抽取角色名、元素和命座。后续所有队伍逻辑都基于这些基础信息。
    memberCount = numel(members);
    memberNames = strings(1, memberCount);
    memberElements = strings(1, memberCount);
    memberConstellations = zeros(1, memberCount);

    for i = 1:memberCount
        memberNames(i) = string(members{i}.Name);
        memberElements(i) = localGetElement(memberNames(i));
        memberConstellations(i) = getFieldOrDefault(members{i}, 'Constellation', 0);
    end

    % 元素掩码与数量统计会被多个角色被动和反应近似共同使用。
    hydroMask = memberElements == "Hydro";
    cryoMask = memberElements == "Cryo";
    pyroMask = memberElements == "Pyro";
    dendroMask = memberElements == "Dendro";
    electroMask = memberElements == "Electro";
    geoMask = memberElements == "Geo";
    hydroCryoCount = sum(hydroMask | cryoMask);

    % sharedBuffs 用于额外传入环境增益，例如调试时手动指定全伤、
    % 精通或额外减抗。
    allDMGBonus = getFieldOrDefault(sharedBuffs, 'AllDMGBonus', 0);
    allDMGBonus = allDMGBonus + getFieldOrDefault(sharedBuffs, 'ApproxFurinaBonus', 0) * double(any(memberNames == "Furina"));
    if any(memberNames == "Furina") && ~isfield(sharedBuffs, 'ApproxFurinaBonus')
        allDMGBonus = allDMGBonus + 0.60;
    end

    % 先读取调用方显式传入的抗性修正，再叠加角色自带的队伍效果。
    hydroResShred = getFieldOrDefault(sharedBuffs, 'HydroResShred', 0);
    cryoResShred = getFieldOrDefault(sharedBuffs, 'CryoResShred', 0);
    pyroResShred = getFieldOrDefault(sharedBuffs, 'PyroResShred', 0);
    dendroResShred = getFieldOrDefault(sharedBuffs, 'DendroResShred', 0);
    electroResShred = getFieldOrDefault(sharedBuffs, 'ElectroResShred', 0);
    geoResShred = getFieldOrDefault(sharedBuffs, 'GeoResShred', 0);
    cryoCritDMGBonus = getFieldOrDefault(sharedBuffs, 'CryoCritDMGBonus', 0);
    geoCritDMGBonus = getFieldOrDefault(sharedBuffs, 'GeoCritDMGBonus', 0);

    if any(memberNames == "Escoffier")
        % 爱可菲的减抗强度取决于队伍中的水/冰角色数量。
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
    % 这些布尔量用于快速判断队内是否存在某个“定义反应机制”的角色。
    hasSkirk = any(memberNames == "Skirk");
    hasLauma = any(memberNames == "Lauma");
    hasIneffa = any(memberNames == "Ineffa");
    hasLinnea = any(memberNames == "Linnea");
    hasNilou = any(memberNames == "Nilou");
    hasNefer = any(memberNames == "Nefer");
    hasFlins = any(memberNames == "Flins");
    hasCitlali = any(memberNames == "Citlali");
    hasXilonen = any(memberNames == "Xilonen");
    hasNeuvillette = any(memberNames == "Neuvillette");

    % 月系列反应在工程中采用“角色在队 + 满足基础元素条件”的轻量开关。
    lunarBloomEnabled = hasLauma || hasNefer;
    lunarChargedEnabled = (hasIneffa || hasFlins) && hydroCount >= 1;
    lunarCrystallizeEnabled = (hasLinnea || any(memberNames == "Zibai")) && hydroCount >= 1;
    nilouPureBloomTeam = hasNilou && (hydroCount + dendroCount == memberCount) && hydroCount >= 1 && dendroCount >= 1;

    lunarBloomBonus = getFieldOrDefault(sharedBuffs, 'LunarBloomBonus', 0) + 0.40 * double(lunarBloomEnabled);
    lunarChargedBonus = getFieldOrDefault(sharedBuffs, 'LunarChargedBonus', 0) + 0.30 * double(lunarChargedEnabled);
    lunarCrystallizeBonus = getFieldOrDefault(sharedBuffs, 'LunarCrystallizeBonus', 0) + 0.30 * double(lunarCrystallizeEnabled);
    nilouBloomBonus = getFieldOrDefault(sharedBuffs, 'NilouBloomBonus', 0) + 0.20 * double(nilouPureBloomTeam);

    % 队伍级反应暴击参数也在这里统一处理，便于月系列反应复用。
    reactionCritRate = getFieldOrDefault(sharedBuffs, 'ReactionCritRate', 0);
    reactionCritDMG = getFieldOrDefault(sharedBuffs, 'ReactionCritDMG', 0);
    if lunarBloomEnabled
        reactionCritRate = max(reactionCritRate, 0.10);
        reactionCritDMG = max(reactionCritDMG, 0.20);
    end

    if hasCitlali
        % 茜特菈莉默认视作提供火/水双减抗环境。
        pyroResShred = pyroResShred + 0.20;
        hydroResShred = hydroResShred + 0.20;
    end

    if hasXilonen
        % 希诺宁的采样减抗在这里按队内元素是否存在进行近似建模。
        pyroResShred = pyroResShred + 0.36 * double(pyroCount >= 1);
        hydroResShred = hydroResShred + 0.36 * double(hydroCount >= 1);
        cryoResShred = cryoResShred + 0.36 * double(cryoCount >= 1);
        electroResShred = electroResShred + 0.36 * double(electroCount >= 1);
        geoResShred = geoResShred + 0.36 * double(geoCount >= 1);
    end

    hydroBeamBonus = 0.00;
    if hasNeuvillette
        % 那维莱特的水柱额外倍率依赖异色反应层数，这里先在队伍侧估一个上限。
        hydroBeamBonus = hydroBeamBonus + 0.10 * min(3, pyroCount + electroCount + cryoCount);
    end

    % 这些派生字段专门服务于新增的状态化模拟器。
    nonHydroReactionCount = pyroCount + electroCount + cryoCount;
    elementalDiversity = sum([hydroCount >= 1, cryoCount >= 1, pyroCount >= 1, dendroCount >= 1, electroCount >= 1, geoCount >= 1]);
    xilonenSampleCount = double(pyroCount >= 1) + double(hydroCount >= 1) + double(cryoCount >= 1) + double(electroCount >= 1);

    teamContext = struct( ...
        'MemberNames', memberNames, ...
        'MemberElements', memberElements, ...
        'MemberConstellations', memberConstellations, ...
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
        'HydroBeamBonus', hydroBeamBonus, ...
        'VaporizeReady', pyroCount >= 1, ...
        'ElectroChargedReady', hydroCount >= 1 && electroCount >= 1, ...
        'BloomReady', hydroCount >= 1 && dendroCount >= 1, ...
        'GeoReactionReady', hydroCount >= 1 && geoCount >= 1, ...
        'ElementalDiversity', elementalDiversity, ...
        'XilonenSampleCount', xilonenSampleCount, ...
        'NeuvilletteDraconicStacks', min(3, nonHydroReactionCount), ...
        'SkirkSkillLevelBonus', double(hasSkirk && hydroCount >= 1 && cryoCount >= 1 && hydroCryoCount == memberCount), ...
        'SkirkDeathCrossingStacks', double(hasSkirk) * min(3, hydroCount + max(cryoCount - 1, 0)), ...
        'SkirkVoidRifts', double(hasSkirk && hydroCount >= 1 && cryoCount >= 1) * 3 ...
    );
end

function element = localGetElement(name)
    % 统一维护角色键名到元素类型的映射，供 teamContext 建模使用。
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
        otherwise
            element = "Physical";
    end
end
