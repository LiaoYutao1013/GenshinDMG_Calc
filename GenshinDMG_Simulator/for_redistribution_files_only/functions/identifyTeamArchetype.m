function info = identifyTeamArchetype(members, sharedBuffs)
    % 识别队伍 archetype（冻结 / 蒸发 / 激绽 / 绽放 / 过载 / 下落等），
    % 并给出主 C 候选、反应优先级和队伍角色倾向。
    %
    % 这层的目标不是替代逐角色高精度模拟，而是为“统一队伍入口”的
    % 排轴与时间线提供更稳定的先验：
    % 1. 先判断这支队伍想打什么体系；
    % 2. 再决定谁更应该被视为站场核心；
    % 3. 再把这个结果传给自动排轴器和能量/时间线模拟器。
    if nargin < 1 || isempty(members)
        members = {};
    end
    if nargin < 2 || isempty(sharedBuffs)
        sharedBuffs = struct();
    end

    memberCount = numel(members);
    names = strings(1, memberCount);
    normalizedNames = strings(1, memberCount);
    elements = strings(1, memberCount);
    weaponTypes = strings(1, memberCount);

    for i = 1:memberCount
        names(i) = string(getFieldOrDefault(members{i}, 'Name', ""));
        normalizedNames(i) = localNormalizeName(names(i));
        elements(i) = string(getCharacterElement(names(i)));
        entry = getCharacterRegistryEntry(names(i));
        weaponTypes(i) = string(getFieldOrDefault(entry, 'WeaponType', ""));
    end

    counts = struct( ...
        'Anemo', sum(elements == "Anemo"), ...
        'Hydro', sum(elements == "Hydro"), ...
        'Cryo', sum(elements == "Cryo"), ...
        'Pyro', sum(elements == "Pyro"), ...
        'Dendro', sum(elements == "Dendro"), ...
        'Electro', sum(elements == "Electro"), ...
        'Geo', sum(elements == "Geo"));

    hasXianyun = any(normalizedNames == "xianyun");
    hasFaruzan = any(normalizedNames == "faruzan");
    hasChevreuse = any(normalizedNames == "chevreuse");
    hasNilou = any(normalizedNames == "nilou");
    hasFurina = any(normalizedNames == "furina");
    hasEscoffier = any(normalizedNames == "escoffier");
    hasShenhe = any(normalizedNames == "shenhe");
    hasNahida = any(normalizedNames == "nahida");
    hasGorou = any(normalizedNames == "gorou");
    hasGeoCarry = any(ismember(normalizedNames, ["navia", "ningguang", "noelle", "aratakiitto", "chiori", "albedo", "kachina"]));

    pyroElectroOnly = counts.Pyro + counts.Electro == memberCount ...
        && counts.Pyro >= 1 && counts.Electro >= 1;
    nilouPureBloom = hasNilou ...
        && counts.Hydro >= 1 && counts.Dendro >= 1 ...
        && counts.Hydro + counts.Dendro == memberCount;
    plungeReady = hasXianyun && any(ismember(normalizedNames, ...
        ["xiao", "gaming", "hutao", "diluc", "navia", "varesa", ...
        "wanderer", "arlecchino"]));

    primary = "Hypercarry";
    secondary = "";
    confidence = 0.45;
    reactionPriority = strings(0, 1);
    notes = strings(0, 1);

    if plungeReady
        primary = "Plunge";
        confidence = 0.95;
        if counts.Pyro >= 1 && counts.Hydro >= 1
            secondary = "Vaporize";
            reactionPriority = ["Plunge"; "Vaporize"];
        elseif counts.Pyro >= 1 && counts.Cryo >= 1
            secondary = "Melt";
            reactionPriority = ["Plunge"; "Melt"];
        else
            reactionPriority = "Plunge";
        end
        notes(end + 1, 1) = "闲云队优先按下落站场核心处理。"; %#ok<AGROW>

    elseif nilouPureBloom
        primary = "Bloom";
        secondary = "NilouBloom";
        confidence = 0.98;
        reactionPriority = ["Bloom"; "LunarBloom"];
        notes(end + 1, 1) = "检测到纯水草妮露体系，优先按绽放/丰穰之核队处理。"; %#ok<AGROW>

    elseif counts.Hydro >= 1 && counts.Dendro >= 1 && counts.Electro >= 1
        primary = "Hyperbloom";
        secondary = "Quicken";
        confidence = 0.92;
        reactionPriority = ["Bloom"; "Hyperbloom"; "Quicken"; "Aggravate"; "Spread"];

    elseif counts.Hydro >= 1 && counts.Dendro >= 1 && counts.Pyro >= 1 && counts.Electro == 0
        primary = "Burgeon";
        secondary = "Bloom";
        confidence = 0.90;
        reactionPriority = ["Bloom"; "Burgeon"; "Burning"];

    elseif counts.Pyro >= 1 && counts.Dendro >= 1 && counts.Hydro == 0 && counts.Electro == 0
        primary = "Burning";
        confidence = 0.84;
        reactionPriority = ["Burning"; "Spread"];
        if any(normalizedNames == "emilie")
            confidence = 0.94;
            notes(end + 1, 1) = "Detected Emilie in a Pyro-Dendro team; prioritize Burning routing."; %#ok<AGROW>
        end

    elseif counts.Hydro >= 1 && counts.Cryo >= 1 ...
            && (counts.Anemo >= 1 || hasEscoffier || hasShenhe ...
            || any(ismember(normalizedNames, ["kamisatoayaka", "wriothesley", "skirk", "ganyu"])))
        primary = "Freeze";
        confidence = 0.94;
        reactionPriority = ["Freeze"; "Swirl"];

    elseif hasChevreuse && pyroElectroOnly
        primary = "Overload";
        secondary = "Chevreuse";
        confidence = 0.97;
        reactionPriority = ["Overload"; "ElectroCharged"];

    elseif counts.Pyro >= 1 && counts.Electro >= 1 && counts.Hydro == 0 && counts.Dendro == 0
        primary = "Overload";
        confidence = 0.83;
        reactionPriority = ["Overload"; "Superconduct"];

    elseif counts.Geo >= 2 && (hasGorou || hasGeoCarry)
        primary = "GeoHypercarry";
        secondary = "Crystallize";
        confidence = 0.91;
        reactionPriority = ["Geo"; "Crystallize"];

    elseif counts.Pyro >= 1 && counts.Hydro >= 1
        primary = "Vaporize";
        confidence = 0.90;
        reactionPriority = ["Vaporize"; "Swirl"];
        if hasFurina
            notes(end + 1, 1) = "检测到芙宁娜，默认优先按增伤蒸发队处理。"; %#ok<AGROW>
        end

    elseif counts.Pyro >= 1 && counts.Cryo >= 1 && counts.Hydro == 0
        primary = "Melt";
        confidence = 0.84;
        reactionPriority = ["Melt"; "Swirl"];

    elseif counts.Electro >= 1 && counts.Dendro >= 1 && counts.Hydro == 0
        if any(ismember(normalizedNames, ["alhaitham", "nahida", "tighnari", "kinich", "emilie"]))
            primary = "Spread";
            secondary = "Quicken";
            reactionPriority = ["Spread"; "Quicken"; "Aggravate"];
        else
            primary = "Aggravate";
            secondary = "Quicken";
            reactionPriority = ["Aggravate"; "Quicken"; "Spread"];
        end
        confidence = 0.88;

    elseif hasFaruzan && counts.Anemo >= 1
        primary = "AnemoHypercarry";
        confidence = 0.78;
        reactionPriority = ["Swirl"; "Anemo"];

    elseif hasGorou && counts.Geo >= 2
        primary = "GeoHypercarry";
        confidence = 0.78;
        reactionPriority = ["Geo"; "Crystallize"];

    elseif counts.Hydro == memberCount || counts.Pyro == memberCount || counts.Cryo == memberCount ...
            || counts.Electro == memberCount || counts.Geo == memberCount || counts.Anemo == memberCount ...
            || counts.Dendro == memberCount
        primary = "Mono";
        confidence = 0.70;
        reactionPriority = "Mono";
    end

    if isempty(reactionPriority)
        reactionPriority = primary;
    end

    carryWeights = zeros(1, memberCount);
    supportWeights = zeros(1, memberCount);
    openerWeights = zeros(1, memberCount);

    for i = 1:memberCount
        carryWeights(i) = localCarryWeightForArchetype( ...
            normalizedNames(i), elements(i), weaponTypes(i), primary, secondary);
        supportWeights(i) = localSupportWeightForArchetype( ...
            normalizedNames(i), elements(i), primary, secondary);
        openerWeights(i) = localOpenerWeightForArchetype( ...
            normalizedNames(i), elements(i), primary, secondary);
    end

    [~, carryOrder] = sort(carryWeights, 'descend');
    carryOrder = carryOrder(carryWeights(carryOrder) > 0);
    if isempty(carryOrder)
        carryOrder = localFallbackCarryOrder(normalizedNames, elements);
    end

    preferredAuraPairs = localPreferredAuraPairs(primary, secondary);
    if isfield(sharedBuffs, 'ForceArchetype') && strlength(string(sharedBuffs.ForceArchetype)) > 0
        primary = string(sharedBuffs.ForceArchetype);
        notes(end + 1, 1) = "ForceArchetype 覆盖了自动识别结果。"; %#ok<AGROW>
    end

    carryMode = localCarryModeForArchetype(primary);
    preferredJobs = strings(1, memberCount);
    for i = 1:memberCount
        preferredJobs(i) = localPreferredJobForArchetype( ...
            normalizedNames(i), elements(i), primary, carryOrder, i, carryMode);
    end
    openerIndices = find(preferredJobs == "Opener");
    triggerIndices = find(preferredJobs == "Trigger");
    sustainIndices = find(preferredJobs == "Sustain");
    driverIndices = find(preferredJobs == "Driver");

    info = struct( ...
        'PrimaryArchetype', string(primary), ...
        'SecondaryArchetype', string(secondary), ...
        'Confidence', confidence, ...
        'ReactionPriority', reactionPriority(:), ...
        'MemberNames', names, ...
        'NormalizedNames', normalizedNames, ...
        'Elements', elements, ...
        'WeaponTypes', weaponTypes, ...
        'Counts', counts, ...
        'CarryWeights', carryWeights, ...
        'SupportWeights', supportWeights, ...
        'OpenerWeights', openerWeights, ...
        'RecommendedCarryIndices', carryOrder(:).', ...
        'RecommendedCarryNames', names(carryOrder), ...
        'CarryMode', carryMode, ...
        'PreferredJobs', preferredJobs, ...
        'RecommendedOpenerIndices', openerIndices(:).', ...
        'RecommendedTriggerIndices', triggerIndices(:).', ...
        'RecommendedSustainIndices', sustainIndices(:).', ...
        'RecommendedDriverIndices', driverIndices(:).', ...
        'PreferredAuraPairs', preferredAuraPairs, ...
        'NilouPureBloom', nilouPureBloom, ...
        'PyroElectroOnly', pyroElectroOnly, ...
        'Notes', notes(:));
end

function weight = localCarryWeightForArchetype(name, element, weaponType, primary, secondary)
    name = string(name);
    element = string(element);
    weaponType = string(weaponType); %#ok<NASGU>
    weight = 0;

    switch char(primary)
        case 'Plunge'
            if any(name == ["xiao", "gaming", "hutao", "diluc", "navia", "varesa", "wanderer", "arlecchino"])
                weight = weight + 4.0;
            elseif element == "Anemo"
                weight = weight + 1.5;
            end

        case 'Bloom'
            if any(name == ["nilou"])
                weight = weight - 2.0;
            elseif element == "Dendro"
                weight = weight + 3.2;
            elseif element == "Hydro"
                weight = weight + 1.0;
            end

        case 'Hyperbloom'
            if any(name == ["alhaitham", "cyno", "clorinde", "keqing", "nahida", "kamisatoayato", "tighnari"])
                weight = weight + 3.5;
            elseif element == "Dendro" || element == "Hydro"
                weight = weight + 1.2;
            elseif any(name == ["kukishinobu", "raidenshogun"])
                weight = weight + 0.5;
            end

        case 'Burgeon'
            if any(name == ["thoma", "dehya"])
                weight = weight + 0.8;
            elseif any(name == ["alhaitham", "nahida", "kaveh", "kinich"])
                weight = weight + 2.4;
            elseif element == "Hydro"
                weight = weight + 1.2;
            end

        case 'Freeze'
            if any(name == ["kamisatoayaka", "wriothesley", "skirk", "ganyu", "kaeya", "freminet"])
                weight = weight + 4.0;
            elseif element == "Cryo"
                weight = weight + 2.0;
            elseif any(name == ["neuvillette", "mualani"])
                weight = weight + 0.5;
            end

        case 'Vaporize'
            if any(name == ["arlecchino", "hutao", "diluc", "gaming", "lyney", "mavuika", "yoimiya", "yanfei"])
                weight = weight + 4.0;
            elseif any(name == ["neuvillette", "tartaglia", "mualani", "kamisatoayato"])
                weight = weight + 2.0;
            elseif element == "Pyro"
                weight = weight + 1.8;
            elseif element == "Hydro" && secondary ~= "Chevreuse"
                weight = weight + 1.0;
            end

        case 'Melt'
            if any(name == ["wriothesley", "kamisatoayaka", "ganyu", "skirk", "arlecchino", "diluc", "gaming"])
                weight = weight + 3.2;
            elseif element == "Pyro" || element == "Cryo"
                weight = weight + 1.5;
            end

        case 'Overload'
            if any(name == ["arlecchino", "clorinde", "raidenshogun", "yoimiya", "lyney", "varesa", "keqing", "mavuika"])
                weight = weight + 4.0;
            elseif element == "Pyro" || element == "Electro"
                weight = weight + 1.6;
            end

        case 'Aggravate'
            if any(name == ["clorinde", "cyno", "keqing", "yaemiko", "fischl", "raidenshogun", "sethos", "varesa"])
                weight = weight + 4.0;
            elseif element == "Electro"
                weight = weight + 1.8;
            end

        case 'Spread'
            if any(name == ["alhaitham", "nahida", "tighnari", "kinich", "emilie", "kaveh"])
                weight = weight + 4.0;
            elseif element == "Dendro"
                weight = weight + 1.8;
            end

        case 'Burning'
            if any(name == ["emilie", "thoma", "dehya", "xiangling", "bennett"])
                weight = weight + 3.2;
            elseif element == "Dendro" || element == "Pyro"
                weight = weight + 1.0;
            end

        case 'AnemoHypercarry'
            if any(name == ["wanderer", "xiao", "shikanoinheizou", "mizuki", "varka"])
                weight = weight + 3.8;
            elseif element == "Anemo"
                weight = weight + 1.5;
            end

        case 'GeoHypercarry'
            if any(name == ["navia", "aratakiitto", "noelle", "ningguang", "chiori"])
                weight = weight + 3.5;
            elseif element == "Geo"
                weight = weight + 1.2;
            end

        case 'Mono'
            if any(name == ["neuvillette", "arlecchino", "navia", "wanderer", "xiao", "lyney", "wriothesley"])
                weight = weight + 2.8;
            else
                weight = weight + 0.5;
            end

        otherwise
            if any(name == ["skirk", "arlecchino", "neuvillette", "alhaitham", "clorinde", "hutao", "xiao", "navia"])
                weight = weight + 2.5;
            end
    end
end

function weight = localSupportWeightForArchetype(name, element, primary, secondary) %#ok<INUSD>
    name = string(name);
    element = string(element);
    weight = 0;

    if any(name == ["furina", "xilonen", "escoffier", "citlali", "chevreuse", "xianyun", ...
            "faruzan", "bennett", "mona", "nahida", "yelan", "xingqiu", "fischl", ...
            "xiangling", "zhongli", "baizhu", "yaoyao", "collei", "gorou", "yunjin", ...
            "kujousara", "nicole", "kachina"])
        weight = weight + 1.5;
    end

    switch char(primary)
        case 'Plunge'
            if any(name == ["xianyun", "faruzan", "bennett", "furina"])
                weight = weight + 3.5;
            end

        case 'Bloom'
            if any(name == ["nilou", "nahida", "baizhu", "yaoyao", "furina", "sangonomiyakokomi", "barbara"])
                weight = weight + 3.0;
            end

        case 'Hyperbloom'
            if any(name == ["nahida", "kukishinobu", "raidenshogun", "xingqiu", "yelan", "baizhu", "furina"])
                weight = weight + 3.0;
            end

        case 'Burgeon'
            if any(name == ["thoma", "nahida", "xingqiu", "yelan", "baizhu"])
                weight = weight + 2.8;
            end

        case 'Freeze'
            if any(name == ["kaedeharakazuha", "sucrose", "mona", "furina", "escoffier", "shenhe", "charlotte", "layla", "diona"])
                weight = weight + 3.0;
            elseif element == "Anemo"
                weight = weight + 1.0;
            end

        case 'Vaporize'
            if any(name == ["xingqiu", "yelan", "furina", "bennett", "kaedeharakazuha", "sucrose", "xilonen", "zhongli", "xiangling"])
                weight = weight + 3.0;
            end

        case 'Melt'
            if any(name == ["bennett", "xiangling", "kaedeharakazuha", "sucrose", "shenhe", "charlotte"])
                weight = weight + 2.5;
            end

        case 'Overload'
            if any(name == ["chevreuse", "bennett", "fischl", "kujousara", "iansan"])
                weight = weight + 3.2;
            end

        case {'Aggravate', 'Spread'}
            if any(name == ["nahida", "baizhu", "yaoyao", "fischl", "yaemiko", "kukishinobu", "zhongli", "emilie"])
                weight = weight + 2.8;
            end

        case 'Burning'
            if any(name == ["emilie", "nahida", "baizhu", "yaoyao", "thoma", "dehya", "xiangling"])
                weight = weight + 2.6;
            end

        case 'AnemoHypercarry'
            if any(name == ["faruzan", "bennett", "furina", "zhongli"])
                weight = weight + 3.0;
            end

        case 'GeoHypercarry'
            if any(name == ["gorou", "zhongli", "albedo", "furina", "kachina"])
                weight = weight + 2.8;
            end
    end
end

function weight = localOpenerWeightForArchetype(name, element, primary, secondary) %#ok<INUSD>
    name = string(name);
    element = string(element);
    weight = 0;

    if any(name == ["zhongli", "xilonen", "citlali", "escoffier", "chevreuse", "bennett", ...
            "mona", "faruzan", "gorou", "kujousara", "yunjin", "nahida", "xianyun"])
        weight = weight + 1.5;
    end

    switch char(primary)
        case 'Freeze'
            if element == "Anemo" || any(name == ["mona", "furina", "shenhe", "escoffier"])
                weight = weight + 2.0;
            end
        case 'Bloom'
            if any(name == ["nahida", "nilou", "furina", "baizhu", "yaoyao"])
                weight = weight + 2.0;
            end
        case 'Hyperbloom'
            if any(name == ["nahida", "xingqiu", "yelan", "baizhu", "kukishinobu"])
                weight = weight + 2.0;
            end
        case 'Overload'
            if any(name == ["chevreuse", "bennett", "kujousara", "iansan"])
                weight = weight + 2.0;
            end
        case 'Burning'
            if any(name == ["emilie", "nahida", "baizhu", "yaoyao", "bennett"])
                weight = weight + 2.0;
            end
        case 'Plunge'
            if any(name == ["xianyun", "faruzan", "bennett", "furina"])
                weight = weight + 2.0;
            end
    end
end

function order = localFallbackCarryOrder(names, elements)
    weights = zeros(1, numel(names));
    for i = 1:numel(names)
        if any(names(i) == ["skirk", "arlecchino", "neuvillette", "alhaitham", "clorinde", "hutao", ...
                "diluc", "wanderer", "xiao", "kamisatoayaka", "gaming", "navia", "mualani", ...
                "mavuika", "chasca", "kinich", "varesa", "keqing", "yoimiya", "wriothesley"])
            weights(i) = weights(i) + 4.0;
        end
        if any(elements(i) == ["Pyro", "Hydro", "Cryo", "Electro", "Dendro", "Anemo", "Geo"])
            weights(i) = weights(i) + 0.5;
        end
    end
    [~, order] = sort(weights, 'descend');
end

function pairs = localPreferredAuraPairs(primary, secondary)
    pairs = struct( ...
        'Pyro', "", ...
        'Hydro', "", ...
        'Cryo', "", ...
        'Electro', "", ...
        'Dendro', "", ...
        'Anemo', "", ...
        'Geo', "");

    switch char(primary)
        case 'Freeze'
            pairs.Hydro = "Cryo";
            pairs.Cryo = "Hydro";
        case 'Vaporize'
            pairs.Pyro = "Hydro";
            pairs.Hydro = "Pyro";
        case 'Melt'
            pairs.Pyro = "Cryo";
            pairs.Cryo = "Pyro";
        case 'Bloom'
            pairs.Hydro = "Dendro";
            pairs.Dendro = "Hydro";
        case 'Hyperbloom'
            pairs.Hydro = "Dendro";
            pairs.Dendro = "Hydro";
            pairs.Electro = "Dendro";
        case 'Burgeon'
            pairs.Hydro = "Dendro";
            pairs.Dendro = "Hydro";
            pairs.Pyro = "Dendro";
        case 'Burning'
            pairs.Pyro = "Dendro";
            pairs.Dendro = "Pyro";
        case {'Aggravate', 'Spread'}
            pairs.Electro = "Dendro";
            pairs.Dendro = "Electro";
        case 'Overload'
            pairs.Pyro = "Electro";
            pairs.Electro = "Pyro";
        case 'Plunge'
            if secondary == "Vaporize"
                pairs.Pyro = "Hydro";
                pairs.Hydro = "Pyro";
            elseif secondary == "Melt"
                pairs.Pyro = "Cryo";
                pairs.Cryo = "Pyro";
            end
    end
end

function carryMode = localCarryModeForArchetype(primary)
    primary = string(primary);
    if any(primary == ["Hyperbloom", "Bloom", "Burgeon", "Aggravate", "Spread", "Burning"])
        carryMode = "DriverCore";
    elseif any(primary == ["Freeze", "Vaporize", "Melt", "Plunge", "GeoHypercarry", "AnemoHypercarry", "Mono"])
        carryMode = "FrontloadHypercarry";
    else
        carryMode = "Balanced";
    end
end

function job = localPreferredJobForArchetype(name, element, primary, carryOrder, memberIndex, carryMode)
    name = string(name);
    element = string(element);
    primary = string(primary);
    carryMode = string(carryMode);
    job = "";

    if ~isempty(carryOrder) && memberIndex == carryOrder(1)
        if carryMode == "DriverCore"
            job = "Driver";
        else
            job = "Carry";
        end
        return;
    end

    sustainNames = ["baizhu", "yaoyao", "diona", "layla", "charlotte", "barbara", ...
        "sangonomiyakokomi", "qiqi", "jean", "kirara", "zhongli", "thoma"];
    openerNames = ["xianyun", "faruzan", "bennett", "furina", "mona", "nahida", ...
        "chevreuse", "xilonen", "citlali", "escoffier", "shenhe", "gorou", ...
        "kujousara", "yunjin", "kaedeharakazuha", "sucrose", "nicole"];
    triggerNames = ["fischl", "yaemiko", "kukishinobu", "raidenshogun", "xiangling", ...
        "thoma", "dehya", "xingqiu", "yelan", "ororon", "beidou"];

    switch char(primary)
        case 'Bloom'
            if name == "nilou" || any(name == ["nahida", "furina", "baizhu", "yaoyao"])
                job = "Opener";
            elseif element == "Hydro" || element == "Dendro"
                job = "Trigger";
            end
        case 'Hyperbloom'
            if any(name == ["kukishinobu", "raidenshogun", "yaemiko", "fischl"])
                job = "Trigger";
            elseif any(name == ["nahida", "baizhu", "yaoyao", "xingqiu", "yelan", "furina", ...
                    "sangonomiyakokomi", "barbara"])
                job = "Opener";
            end
        case 'Burgeon'
            if any(name == ["thoma", "dehya"])
                job = "Trigger";
            elseif any(name == ["nahida", "baizhu", "yaoyao", "xingqiu", "yelan", "furina", ...
                    "sangonomiyakokomi", "barbara"])
                job = "Opener";
            end
        case 'Freeze'
            if element == "Anemo" || any(name == ["mona", "furina", "shenhe", "escoffier"])
                job = "Opener";
            elseif element == "Hydro"
                job = "Trigger";
            elseif any(name == sustainNames)
                job = "Sustain";
            end
        case 'Vaporize'
            if any(name == ["xingqiu", "yelan", "furina", "mona"])
                job = "Trigger";
            elseif any(name == ["bennett", "kaedeharakazuha", "sucrose", "xilonen", "zhongli", ...
                    "citlali", "chevreuse"])
                job = "Opener";
            elseif any(name == sustainNames)
                job = "Sustain";
            end
        case 'Melt'
            if any(name == ["xiangling", "citlali", "rosaria"])
                job = "Trigger";
            elseif any(name == ["bennett", "kaedeharakazuha", "sucrose", "shenhe", "charlotte"])
                job = "Opener";
            elseif any(name == sustainNames)
                job = "Sustain";
            end
        case 'Overload'
            if any(name == ["chevreuse", "bennett", "kujousara", "iansan"])
                job = "Opener";
            elseif any(name == ["fischl", "yaemiko", "beidou", "ororon", "kukishinobu"])
                job = "Trigger";
            elseif any(name == sustainNames)
                job = "Sustain";
            end
        case {'Aggravate', 'Spread'}
            if any(name == ["nahida", "baizhu", "yaoyao", "zhongli", "emilie"])
                job = "Opener";
            elseif any(name == ["fischl", "yaemiko", "kukishinobu", "raidenshogun"])
                job = "Trigger";
            elseif any(name == sustainNames)
                job = "Sustain";
            end
        case 'Burning'
            if any(name == ["emilie", "nahida", "baizhu", "yaoyao"])
                job = "Opener";
            elseif any(name == ["thoma", "dehya", "xiangling"])
                job = "Trigger";
            elseif any(name == sustainNames)
                job = "Sustain";
            end
        case 'Plunge'
            if any(name == ["xianyun", "faruzan", "bennett", "furina"])
                job = "Opener";
            elseif any(name == sustainNames)
                job = "Sustain";
            end
        case 'AnemoHypercarry'
            if any(name == ["faruzan", "bennett", "furina", "zhongli"])
                job = "Opener";
            end
        case 'GeoHypercarry'
            if any(name == ["gorou", "zhongli", "albedo", "furina"])
                job = "Opener";
            elseif any(name == sustainNames)
                job = "Sustain";
            end
    end

    if strlength(job) == 0
        if any(name == sustainNames)
            job = "Sustain";
        elseif any(name == openerNames)
            job = "Opener";
        elseif any(name == triggerNames)
            job = "Trigger";
        else
            job = "Support";
        end
    end
end

function normalized = localNormalizeName(name)
    normalized = string(regexprep(lower(char(string(name))), '[^a-z0-9]', ''));
end
