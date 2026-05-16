function registry = getArtifactSetRegistry()
    % 返回工程统一使用的圣遗物套装注册表。
    % 注册表由两部分组成：
    % 1. 通用 2 件套占位 ID，用于兼容旧 build 与快速试配；
    % 2. Lunaris 本地数据包中的完整官方套装清单。
    %
    % 字段说明：
    % Id            工程内部稳定 ID，build 与 GUI 均使用该值。
    % DisplayName   GUI 显示名称。
    % ShortLabel    图标角标或简短缩写。
    % ThemeColor    GUI 主题色。
    % ApiSlug       预留的英文 slug，当前仅作兼容字段保留。
    % IconKey       Lunaris / 本地图包使用的原画图标 key。
    % Effect2Pc     2 件套说明。
    % Effect4Pc     4 件套说明。
    % IsImplemented 当前版本是否已在后端伤害链路中显式建模。
    persistent cachedRegistry
    if ~isempty(cachedRegistry)
        registry = cachedRegistry;
        return;
    end

    catalog = getLunarisArtifactCatalog();
    registry = [localBuildGenericEntries(), localBuildLunarisEntries(catalog)];
    cachedRegistry = registry;
end

function entries = localBuildGenericEntries()
    rows = { ...
        'None', '无套装', 'NONE', [0.55 0.58 0.64], '', '', '', '', true; ...
        'ATK18', '攻击力 18% 通用 2 件套', 'ATK', [0.76 0.52 0.28], '', 'UI_RelicIcon_15001_4', 'ATK +18%.', '仅作通用 2 件套占位。', true; ...
        'HP20', '生命值 20% 通用 2 件套', 'HP', [0.35 0.63 0.56], '', 'UI_RelicIcon_15017_4', 'HP +20%', '仅作通用 2 件套占位。', true; ...
        'EM80', '元素精通 80 通用 2 件套', 'EM', [0.54 0.46 0.72], '', 'UI_RelicIcon_15003_4', 'Increases Elemental Mastery by 80.', '仅作通用 2 件套占位。', true; ...
        'ER20', '元素充能 20% 通用 2 件套', 'ER', [0.44 0.55 0.78], '', 'UI_RelicIcon_15020_4', 'Energy Recharge +20%', '仅作通用 2 件套占位。', true; ...
        'Healing15', '治疗加成 15% 通用 2 件套', 'HEAL', [0.70 0.54 0.62], '', 'UI_RelicIcon_15033_4', 'Healing Bonus +15%.', '仅作通用 2 件套占位。', true; ...
        'Pyro15', '火元素伤害 15% 通用 2 件套', 'PYRO', [0.82 0.38 0.24], '', 'UI_RelicIcon_15006_4', 'Pyro DMG Bonus +15%', '仅作通用 2 件套占位。', true; ...
        'Hydro15', '水元素伤害 15% 通用 2 件套', 'HYDRO', [0.29 0.58 0.84], '', 'UI_RelicIcon_15016_4', 'Hydro DMG Bonus +15%', '仅作通用 2 件套占位。', true; ...
        'Cryo15', '冰元素伤害 15% 通用 2 件套', 'CRYO', [0.52 0.76 0.93], '', 'UI_RelicIcon_14001_4', 'Cryo DMG Bonus +15%', '仅作通用 2 件套占位。', true; ...
        'Electro15', '雷元素伤害 15% 通用 2 件套', 'ELEC', [0.49 0.41 0.83], '', 'UI_RelicIcon_15005_4', 'Electro DMG Bonus +15%', '仅作通用 2 件套占位。', true; ...
        'Anemo15', '风元素伤害 15% 通用 2 件套', 'ANEMO', [0.34 0.71 0.60], '', 'UI_RelicIcon_15002_4', 'Anemo DMG Bonus +15%', '仅作通用 2 件套占位。', true; ...
        'Geo15', '岩元素伤害 15% 通用 2 件套', 'GEO', [0.78 0.66 0.35], '', 'UI_RelicIcon_15014_4', 'Gain a 15% Geo DMG Bonus.', '仅作通用 2 件套占位。', true; ...
        'Dendro15', '草元素伤害 15% 通用 2 件套', 'DEND', [0.34 0.57 0.38], '', 'UI_RelicIcon_15025_4', 'Dendro DMG Bonus +15%.', '仅作通用 2 件套占位。', true ...
    };

    entries = repmat(localEmptyEntry(), 1, size(rows, 1));
    for i = 1:size(rows, 1)
        entries(i) = localMakeEntry(rows{i, :});
    end
end

function entries = localBuildLunarisEntries(catalog)
    aliasMap = localArtifactAliasMap();
    artifacts = getFieldOrDefault(catalog, 'Artifacts', []);
    entries = repmat(localEmptyEntry(), 1, 0);
    for i = 1:numel(artifacts)
        item = artifacts(i);
        numericId = string(getFieldOrDefault(item, 'SetId', getFieldOrDefault(item, 'Id', '')));
        enName = string(getFieldOrDefault(item, 'EnName', ''));
        if localShouldSkipArtifactEntry(numericId, enName)
            continue;
        end
        internalId = localAliasOrFallback(aliasMap, numericId, enName);
        displayName = localBestDisplayName(item, enName);
        shortLabel = localShortLabel(displayName, enName);
        themeColor = localThemeColorFromName(displayName, enName);
        apiSlug = lower(regexprep(char(enName), '[^a-zA-Z0-9]+', ''));
        iconKey = string(getFieldOrDefault(item, 'SetIcon', ''));
        effect2 = string(getFieldOrDefault(item, 'Effect2Pc', ''));
        effect4 = string(getFieldOrDefault(item, 'Effect4Pc', ''));
        isImplemented = localIsArtifactSetImplemented(internalId);
        entries(end + 1) = localMakeEntry(internalId, displayName, shortLabel, themeColor, apiSlug, iconKey, effect2, effect4, isImplemented); %#ok<AGROW>
    end
end

function tf = localShouldSkipArtifactEntry(numericId, enName)
    enName = strtrim(char(string(enName)));
    numericId = string(numericId);
    tf = false;
    if numericId == "15000"
        tf = true;
        return;
    end
    if isempty(enName) || strcmp(enName, '???')
        tf = true;
    end
end

function entry = localMakeEntry(id, displayName, shortLabel, themeColor, apiSlug, iconKey, effect2, effect4, isImplemented)
    entry = localEmptyEntry();
    entry.Id = string(id);
    entry.DisplayName = string(displayName);
    entry.ShortLabel = string(shortLabel);
    entry.ThemeColor = themeColor;
    entry.ApiSlug = string(apiSlug);
    entry.IconKey = string(iconKey);
    entry.Effect2Pc = string(effect2);
    entry.Effect4Pc = string(effect4);
    entry.IsImplemented = logical(isImplemented);
end

function entry = localEmptyEntry()
    entry = struct( ...
        'Id', "", ...
        'DisplayName', "", ...
        'ShortLabel', "", ...
        'ThemeColor', [0.55 0.58 0.64], ...
        'ApiSlug', "", ...
        'IconKey', "", ...
        'Effect2Pc', "", ...
        'Effect4Pc', "", ...
        'IsImplemented', false);
end

function aliasMap = localArtifactAliasMap()
    aliasMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    aliasMap('10001') = 'ResolutionOfSojourner';
    aliasMap('10002') = 'BraveHeart';
    aliasMap('10003') = 'DefendersWill';
    aliasMap('10004') = 'TinyMiracle';
    aliasMap('10005') = 'Berserker';
    aliasMap('10006') = 'MartialArtist';
    aliasMap('10007') = 'Instructor';
    aliasMap('10008') = 'Gambler';
    aliasMap('10009') = 'TheExile';
    aliasMap('10010') = 'Adventurer';
    aliasMap('10011') = 'LuckyDog';
    aliasMap('10012') = 'Scholar';
    aliasMap('10013') = 'TravelingDoctor';
    aliasMap('14001') = 'BlizzardStrayer';
    aliasMap('14002') = 'Thundersoother';
    aliasMap('14003') = 'Lavawalker';
    aliasMap('14004') = 'MaidenBeloved';
    aliasMap('15001') = 'GladiatorsFinale';
    aliasMap('15002') = 'ViridescentVenerer';
    aliasMap('15003') = 'WanderersTroupe';
    aliasMap('15004') = 'GlacierAndSnowfield';
    aliasMap('15005') = 'ThunderingFury';
    aliasMap('15006') = 'CrimsonWitchOfFlames';
    aliasMap('15007') = 'NoblesseOblige';
    aliasMap('15008') = 'BloodstainedChivalry';
    aliasMap('15009') = 'PrayersForIllumination';
    aliasMap('15010') = 'PrayersForDestiny';
    aliasMap('15011') = 'PrayersForWisdom';
    aliasMap('15012') = 'PrayersToTheFirmament';
    aliasMap('15013') = 'PrayersToSpringtime';
    aliasMap('15014') = 'ArchaicPetra';
    aliasMap('15015') = 'RetracingBolide';
    aliasMap('15016') = 'HeartOfDepth';
    aliasMap('15017') = 'TenacityOfTheMillelith';
    aliasMap('15018') = 'PaleFlame';
    aliasMap('15019') = 'ShimenawasReminiscence';
    aliasMap('15020') = 'EmblemOfSeveredFate';
    aliasMap('15021') = 'HuskOfOpulentDreams';
    aliasMap('15022') = 'OceanHuedClam';
    aliasMap('15023') = 'VermillionHereafter';
    aliasMap('15024') = 'EchoesOfAnOffering';
    aliasMap('15025') = 'DeepwoodMemories';
    aliasMap('15026') = 'GildedDreams';
    aliasMap('15027') = 'DesertPavilionChronicle';
    aliasMap('15028') = 'FlowerOfParadiseLost';
    aliasMap('15029') = 'NymphsDream';
    aliasMap('15030') = 'VourukashasGlow';
    aliasMap('15031') = 'MarechausseeHunter';
    aliasMap('15032') = 'GoldenTroupe';
    aliasMap('15033') = 'SongOfDaysPast';
    aliasMap('15034') = 'NighttimeWhispersInTheEchoingWoods';
    aliasMap('15035') = 'FragmentOfHarmonicWhimsy';
    aliasMap('15036') = 'UnfinishedReverie';
    aliasMap('15037') = 'ScrollOfTheHeroOfCinderCity';
    aliasMap('15038') = 'ObsidianCodex';
    aliasMap('15039') = 'LongNightsOath';
    aliasMap('15040') = 'FinaleOfTheDeepGalleries';
    aliasMap('15041') = 'NightOfTheSkysUnveiling';
    aliasMap('15042') = 'SilkenMoonsSerenade';
    aliasMap('15043') = 'AubadeOfMorningstarAndMoon';
    aliasMap('15044') = 'ADayCarvedFromRisingWinds';
    aliasMap('15045') = 'CelestialGift';
    aliasMap('15046') = 'DisenchantmentInDeepShadow';
end

function internalId = localAliasOrFallback(aliasMap, numericId, enName)
    key = char(string(numericId));
    if isKey(aliasMap, key)
        internalId = string(aliasMap(key));
    else
        internalId = string(regexprep(char(enName), '[^a-zA-Z0-9]+', ''));
        if strlength(internalId) == 0
            internalId = "ArtifactSet" + string(key);
        end
    end
end

function displayName = localBestDisplayName(item, fallbackName)
    displayName = string(getFieldOrDefault(item, 'DisplayName', ''));
    if strlength(displayName) == 0
        displayName = string(fallbackName);
    end
end

function shortLabel = localShortLabel(displayName, enName)
    displayName = string(displayName);
    if strlength(displayName) <= 5
        shortLabel = upper(displayName);
        return;
    end

    words = regexp(char(string(enName)), '[A-Za-z0-9]+', 'match');
    if isempty(words)
        shortLabel = upper(extractBefore(displayName, min(strlength(displayName), 4) + 1));
        return;
    end

    initials = strings(1, 0);
    for i = 1:min(3, numel(words))
        token = string(words{i});
        initials(end + 1) = upper(extractBefore(token, min(strlength(token), 1) + 1)); %#ok<AGROW>
    end
    shortLabel = strjoin(initials, '');
end

function color = localThemeColorFromName(displayName, enName)
    nameText = lower(char(displayName + " " + enName));
    color = [0.55 0.58 0.64];
    if contains(nameText, 'pyro') || contains(nameText, 'flame') || contains(nameText, 'lava') || contains(nameText, 'burn')
        color = [0.84 0.38 0.24];
    elseif contains(nameText, 'hydro') || contains(nameText, 'ocean') || contains(nameText, 'depth') || contains(nameText, 'nymph')
        color = [0.29 0.58 0.84];
    elseif contains(nameText, 'cryo') || contains(nameText, 'blizzard') || contains(nameText, 'glacier') || contains(nameText, 'snow')
        color = [0.52 0.76 0.93];
    elseif contains(nameText, 'electro') || contains(nameText, 'thunder') || contains(nameText, 'superconduct') || contains(nameText, 'sky')
        color = [0.49 0.41 0.83];
    elseif contains(nameText, 'anemo') || contains(nameText, 'viridescent') || contains(nameText, 'wind')
        color = [0.34 0.71 0.60];
    elseif contains(nameText, 'geo') || contains(nameText, 'petra') || contains(nameText, 'bolide') || contains(nameText, 'rock')
        color = [0.78 0.66 0.35];
    elseif contains(nameText, 'dendro') || contains(nameText, 'deepwood') || contains(nameText, 'reverie') || contains(nameText, 'shadow')
        color = [0.34 0.57 0.38];
    elseif contains(nameText, 'heal') || contains(nameText, 'song') || contains(nameText, 'maiden') || contains(nameText, 'clam')
        color = [0.70 0.54 0.62];
    elseif contains(nameText, 'emblem') || contains(nameText, 'serenade') || contains(nameText, 'gift')
        color = [0.44 0.55 0.78];
    elseif contains(nameText, 'hunter') || contains(nameText, 'troupe') || contains(nameText, 'dream') || contains(nameText, 'moon')
        color = [0.72 0.60 0.46];
    end
end

function tf = localIsArtifactSetImplemented(setId)
    fullyImplemented = string({ ...
        'ATK18', 'HP20', 'EM80', 'ER20', 'Healing15', ...
        'Pyro15', 'Hydro15', 'Cryo15', 'Electro15', 'Anemo15', 'Geo15', 'Dendro15', ...
        'ResolutionOfSojourner', 'BraveHeart', 'Berserker', ...
        'MartialArtist', 'Instructor', ...
        'BlizzardStrayer', 'Thundersoother', 'Lavawalker', ...
        'GladiatorsFinale', 'ViridescentVenerer', 'WanderersTroupe', 'GlacierAndSnowfield', ...
        'ThunderingFury', 'CrimsonWitchOfFlames', 'NoblesseOblige', 'BloodstainedChivalry', ...
        'ArchaicPetra', 'RetracingBolide', 'HeartOfDepth', 'TenacityOfTheMillelith', 'PaleFlame', ...
        'ShimenawasReminiscence', 'EmblemOfSeveredFate', ...
        'HuskOfOpulentDreams', 'DeepwoodMemories', 'GildedDreams', ...
        'DesertPavilionChronicle', 'FlowerOfParadiseLost', 'NymphsDream', 'VourukashasGlow', ...
        'VermillionHereafter', 'EchoesOfAnOffering', ...
        'MarechausseeHunter', 'GoldenTroupe', ...
        'NighttimeWhispersInTheEchoingWoods', 'FragmentOfHarmonicWhimsy', 'UnfinishedReverie', ...
        'ScrollOfTheHeroOfCinderCity', 'ObsidianCodex', 'LongNightsOath', 'FinaleOfTheDeepGalleries', ...
        'NightOfTheSkysUnveiling', 'SilkenMoonsSerenade', 'AubadeOfMorningstarAndMoon', ...
        'ADayCarvedFromRisingWinds', 'CelestialGift', 'DisenchantmentInDeepShadow' ...
    });
    tf = any(strcmpi(char(string(setId)), cellstr(fullyImplemented.')));
end
