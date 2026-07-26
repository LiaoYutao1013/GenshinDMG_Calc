function build = optimizeEffectiveArtifactSubstats(characterName, build, teamContext)
% Materialize the optimal artifact substat allocation for an input roll count.
    if nargin < 3 || isempty(teamContext)
        teamContext = struct();
    end
    build = normalizeArtifactBuild(build, characterName);
    count = localCount(getFieldOrDefault(build, 'ArtifactEffectiveSubstatCount', 30));
    [fields, weights, profileName] = localProfile(characterName, build);
    rolls = localAllocateRolls(count, weights);

    build = localClearSubstats(build);
    [build, allocation] = localWriteSubstats(build, fields, rolls);
    build.ArtifactEffectiveSubstatCount = count;
    build.ArtifactEffectiveSubstatProfile = profileName;
    build.ArtifactEffectiveSubstatAllocation = allocation;

    main = localMainContribution(build);
    substats = localSubstatContribution(fields, rolls);
    ascension = getCharacterAscensionBonus(characterName);
    weapon = getWeaponSubstatBonus(build);
    legacySet = localEmptyStats();
    if logical(getFieldOrDefault(build, 'ArtifactApplySetBonuses', 0))
        legacySet = getArtifactLegacySetContribution(characterName, build, teamContext);
    end
    for fieldName = localTrackedFields()
        fieldName = fieldName{1};
        fixed = getFieldOrDefault(build, ['ArtifactBase_' fieldName], 0);
        value = fixed + localGet(main, fieldName) + localGet(substats, fieldName) ...
            + localGet(ascension, fieldName) + localGet(weapon, fieldName) + localGet(legacySet, fieldName);
        if strcmp(fieldName, 'ER')
            value = max(1, value);
        end
        build.(fieldName) = value;
    end
end

function [fields, weights, profileName] = localProfile(characterName, build)
    key = lower(char(string(characterName)));
    profileName = "ATK Crit";
    fields = {'CritRate', 'CritDMG', 'AtkBonus', 'ER'};
    weights = [0.27 0.48 0.20 0.05];
    if any(strcmp(key, {'kaedeharakazuha', 'sucrose', 'nahida', 'mizuki', 'sayu', 'venti', 'lauma', 'citlali'}))
        profileName = "Elemental Mastery";
        fields = {'EM', 'ER', 'CritRate', 'CritDMG'};
        weights = [0.72 0.18 0.04 0.06];
    elseif any(strcmp(key, {'furina', 'neuvillette', 'yelan', 'hutao', 'nilou', 'mualani', 'sigewinne', 'kokomi', 'sangonomiyakokomi', 'zhongli', 'layla', 'kirara', 'diona'}))
        profileName = "HP Crit";
        fields = {'CritRate', 'CritDMG', 'HPBonus', 'ER'};
        weights = [0.25 0.45 0.23 0.07];
    elseif any(strcmp(key, {'albedo', 'aratakiitto', 'itto', 'chiori', 'noelle', 'gorou', 'yunjin', 'xilonen', 'zibai', 'linnea'}))
        profileName = "DEF Crit";
        fields = {'CritRate', 'CritDMG', 'DEFBonus', 'ER'};
        weights = [0.24 0.43 0.28 0.05];
    elseif any(strcmp(key, {'bennett', 'xingqiu', 'xiangling', 'faruzan', 'kujousara', 'mona', 'dori', 'charlotte', 'mika', 'chevreuse', 'dahlia'}))
        profileName = "Energy Recharge";
        fields = {'ER', 'CritRate', 'CritDMG', 'AtkBonus'};
        weights = [0.35 0.20 0.35 0.10];
    elseif string(getFieldOrDefault(build, 'ArtifactSandsMainStat', '')) == "EM"
        profileName = "Reaction Hybrid";
        fields = {'EM', 'CritRate', 'CritDMG', 'ER'};
        weights = [0.42 0.20 0.33 0.05];
    end
end

function rolls = localAllocateRolls(count, weights)
    exact = count * weights / sum(weights);
    rolls = floor(exact);
    remainder = count - sum(rolls);
    [~, order] = sort(exact - rolls, 'descend');
    rolls(order(1:remainder)) = rolls(order(1:remainder)) + 1;
end

function build = localClearSubstats(build)
    slots = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
    suffixes = {'FlatATK', 'FlatHP', 'FlatDEF', 'AtkBonus', 'HPBonus', 'DEFBonus', 'ER', 'EM', 'CritRate', 'CritDMG'};
    for i = 1:numel(slots)
        build.(sprintf('Artifact%sSubstats', slots{i})) = '';
        for j = 1:numel(suffixes)
            build.(sprintf('Artifact%sSubstat%s', slots{i}, suffixes{j})) = 0;
        end
    end
end

function [build, allocation] = localWriteSubstats(build, fields, rolls)
    slots = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
    values = struct('CritRate', 0.039, 'CritDMG', 0.078, 'AtkBonus', 0.058, ...
        'HPBonus', 0.058, 'DEFBonus', 0.073, 'ER', 0.065, 'EM', 23.31);
    entries = repmat({strings(1, 0)}, 1, numel(slots));
    counts = zeros(1, numel(slots));
    allocationParts = strings(1, 0);
    for i = 1:numel(fields)
        fieldName = fields{i};
        if rolls(i) == 0
            continue;
        end
        perSlot = zeros(1, numel(slots));
        for rollIndex = 1:rolls(i)
            slotIndex = localBestSlot(build, slots, fieldName, counts, perSlot);
            perSlot(slotIndex) = perSlot(slotIndex) + 1;
            counts(slotIndex) = counts(slotIndex) + 1;
        end
        for slotIndex = find(perSlot > 0)
            total = perSlot(slotIndex) * values.(fieldName);
            numericField = sprintf('Artifact%sSubstat%s', slots{slotIndex}, fieldName);
            build.(numericField) = total;
            entries{slotIndex}(end + 1) = sprintf('%s=%.6g', fieldName, total); %#ok<AGROW>
        end
        allocationParts(end + 1) = sprintf('%s x%d', fieldName, rolls(i)); %#ok<AGROW>
    end
    for i = 1:numel(slots)
        if ~isempty(entries{i})
            build.(sprintf('Artifact%sSubstats', slots{i})) = char(strjoin(entries{i}, '; '));
        end
    end
    allocation = char(strjoin(allocationParts, ', '));
end

function index = localBestSlot(build, slots, fieldName, counts, perSlot)
    candidates = zeros(1, 0);
    for i = 1:numel(slots)
        main = string(getFieldOrDefault(build, sprintf('Artifact%sMainStat', slots{i}), ''));
        if ~localMainMatches(main, fieldName) && counts(i) < 4
            candidates(end + 1) = i; %#ok<AGROW>
        end
    end
    if isempty(candidates)
        candidates = 1:numel(slots);
    end
    score = counts(candidates) * 10 + perSlot(candidates);
    [~, localIndex] = min(score);
    index = candidates(localIndex);
end

function tf = localMainMatches(main, fieldName)
    main = lower(char(main));
    tf = any(strcmpi(main, {fieldName, strrep(fieldName, 'Bonus', 'Pct')}));
    if strcmp(fieldName, 'ER'), tf = tf || strcmp(main, 'energyrecharge'); end
    if strcmp(fieldName, 'EM'), tf = tf || strcmp(main, 'elementalmastery'); end
end

function contribution = localMainContribution(build)
    contribution = localEmptyStats();
    slots = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
    for i = 1:numel(slots)
        contribution = localAdd(contribution, string(getFieldOrDefault(build, sprintf('Artifact%sMainStat', slots{i}), '')), ...
            getFieldOrDefault(build, sprintf('Artifact%sMainValue', slots{i}), 0));
    end
end

function contribution = localSubstatContribution(fields, rolls)
    contribution = localEmptyStats();
    values = struct('CritRate', 0.039, 'CritDMG', 0.078, 'AtkBonus', 0.058, ...
        'HPBonus', 0.058, 'DEFBonus', 0.073, 'ER', 0.065, 'EM', 23.31);
    for i = 1:numel(fields)
        contribution.(fields{i}) = contribution.(fields{i}) + rolls(i) * values.(fields{i});
    end
end

function stats = localEmptyStats()
    stats = struct();
    for fieldName = localTrackedFields()
        stats.(fieldName{1}) = 0;
    end
end

function stats = localAdd(stats, type, value)
    key = lower(char(type));
    switch key
        case 'flatatk', stats.FlatATK = stats.FlatATK + value;
        case 'flathp', stats.FlatHP = stats.FlatHP + value;
        case 'flatdef', stats.FlatDEF = stats.FlatDEF + value;
        case {'atkbonus', 'atkpct'}, stats.AtkBonus = stats.AtkBonus + value;
        case {'hpbonus', 'hppct'}, stats.HPBonus = stats.HPBonus + value;
        case {'defbonus', 'defpct'}, stats.DEFBonus = stats.DEFBonus + value;
        case {'er', 'energyrecharge'}, stats.ER = stats.ER + value;
        case {'em', 'elementalmastery'}, stats.EM = stats.EM + value;
        case {'critrate', 'cr'}, stats.CritRate = stats.CritRate + value;
        case {'critdmg', 'cd'}, stats.CritDMG = stats.CritDMG + value;
        case 'pyrodmgbonus', stats.PyroDMGBonus = stats.PyroDMGBonus + value;
        case 'hydrodmgbonus', stats.HydroDMGBonus = stats.HydroDMGBonus + value;
        case 'cryodmgbonus', stats.CryoDMGBonus = stats.CryoDMGBonus + value;
        case 'electrodmgbonus', stats.ElectroDMGBonus = stats.ElectroDMGBonus + value;
        case 'anemodmgbonus', stats.AnemoDMGBonus = stats.AnemoDMGBonus + value;
        case 'geodmgbonus', stats.GeoDMGBonus = stats.GeoDMGBonus + value;
        case 'dendrodmgbonus', stats.DendroDMGBonus = stats.DendroDMGBonus + value;
    end
end

function value = localGet(stats, fieldName)
    value = getFieldOrDefault(stats, fieldName, 0);
end

function count = localCount(value)
    if isstring(value) || ischar(value)
        value = str2double(value);
    end
    count = double(value);
    if ~isscalar(count) || ~isfinite(count), count = 30; end
    count = max(0, min(45, round(count)));
end

function fields = localTrackedFields()
    fields = {'AtkBonus', 'FlatATK', 'HPBonus', 'FlatHP', 'DEFBonus', 'FlatDEF', ...
        'ER', 'EM', 'CritRate', 'CritDMG', 'PhysicalDMGBonus', 'PyroDMGBonus', ...
        'HydroDMGBonus', 'CryoDMGBonus', 'ElectroDMGBonus', 'AnemoDMGBonus', ...
        'GeoDMGBonus', 'DendroDMGBonus', 'LunarChargedBonus', 'NormalDMGBonus', ...
        'ChargeDMGBonus', 'ChargedDMGBonus', 'PlungeDMGBonus', 'SkillDMGBonus', ...
        'BurstDMGBonus', 'HealingBonus', 'ReactionDMGBonus', 'ShieldBonus', 'ResShred'};
end
