function build = normalizeArtifactBuild(build, characterName)
    % 统一补齐圣遗物/构筑相关元数据，并兼容旧版 aggregate build。
    % 这里不直接做最终数值编译，只做三类准备：
    % 1. 补齐套装元数据、五件分件字段和条件开关；
    % 2. 为旧默认 build 自动生成一份可追溯的五件分件模型；
    % 3. 标记当前 build 是否应由“分件 + 套装”重新编译，或保留历史总面板。
    if nargin < 2
        characterName = "";
    end

    profile = getArtifactModelProfile(characterName, build);

    build = localSetDefault(build, 'ArtifactSet1', 'None');
    build = localSetDefault(build, 'ArtifactSet1Pieces', 0);
    build = localSetDefault(build, 'ArtifactSet2', 'None');
    build = localSetDefault(build, 'ArtifactSet2Pieces', 0);
    build = localSetDefault(build, 'ArtifactSet4Active', 1);
    build = localSetDefault(build, 'ArtifactSetNotes', '');
    build = localSetDefault(build, 'ArtifactUsePieceModel', double(profile.EnablePieceModel));
    build = localSetDefault(build, 'ArtifactApplySetBonuses', double(profile.ApplySetBonuses));
    build = localSetDefault(build, 'ArtifactLegacyTotalsIncludeSetBonuses', double(profile.LegacyTotalsIncludeSetBonuses));
    build = localSetDefault(build, 'ArtifactAssumeOffFieldSkill', double(profile.AssumeOffFieldSkill));
    build = localSetDefault(build, 'ArtifactAssumeBondOfLifeStacks', profile.AssumeBondOfLifeStacks);
    build = localSetDefault(build, 'ArtifactAssumeMarechausseeStacks', profile.AssumeMarechausseeStacks);
    build = localSetDefault(build, 'ArtifactAssumeObsidianActive', double(profile.AssumeObsidianActive));
    build = localSetDefault(build, 'ArtifactAssumeCryoAura', double(profile.AssumeCryoAura));
    build = localSetDefault(build, 'ArtifactAssumeFrozen', double(profile.AssumeFrozen));
    build = localSetDefault(build, 'ArtifactAssumeHuskStacks', profile.AssumeHuskStacks);
    build = localSetDefault(build, 'ArtifactCalibrationVersion', 2);
    build = localSetDefault(build, 'ArtifactAutoDistributeResidualSubstats', 1);

    if ~isfield(build, 'ArtifactRecommended')
        build.ArtifactRecommended = char(localRecommendedSet(characterName));
    end

    build = localNormalizeLegacySetPieces(build);
    build = localInjectArtifactPieces(build, characterName, profile);
end

function build = localNormalizeLegacySetPieces(build)
    % 保持旧版 ArtifactSet1/2 字段与五件分件统计一致，便于 GUI 和旧脚本继续展示。
    slotNames = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
    pieceSets = strings(1, numel(slotNames));
    for i = 1:numel(slotNames)
        fieldName = sprintf('Artifact%sSet', slotNames{i});
        pieceSets(i) = string(getFieldOrDefault(build, fieldName, ""));
    end

    nonEmpty = pieceSets(pieceSets ~= "" & pieceSets ~= "None");
    if isempty(nonEmpty)
        return;
    end

    uniqueSets = unique(nonEmpty, 'stable');
    counts = zeros(1, numel(uniqueSets));
    for i = 1:numel(uniqueSets)
        counts(i) = sum(nonEmpty == uniqueSets(i));
    end

    [counts, order] = sort(counts, 'descend');
    uniqueSets = uniqueSets(order);
    build.ArtifactSet1 = char(uniqueSets(1));
    build.ArtifactSet1Pieces = counts(1);

    if numel(uniqueSets) >= 2
        build.ArtifactSet2 = char(uniqueSets(2));
        build.ArtifactSet2Pieces = counts(2);
    else
        build.ArtifactSet2 = 'None';
        build.ArtifactSet2Pieces = 0;
    end
end

function build = localInjectArtifactPieces(build, characterName, profile)
    slotNames = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
    defaultMainStats = { ...
        "FlatHP", ...
        "FlatATK", ...
        string(profile.SandsMainStat), ...
        string(profile.GobletMainStat), ...
        string(profile.CircletMainStat)};

    hasAnyPiece = false;
    for i = 1:numel(slotNames)
        setField = sprintf('Artifact%sSet', slotNames{i});
        mainTypeField = sprintf('Artifact%sMainStat', slotNames{i});
        mainValueField = sprintf('Artifact%sMainValue', slotNames{i});
        substatsField = sprintf('Artifact%sSubstats', slotNames{i});
        suffixes = {'FlatATK', 'FlatHP', 'FlatDEF', 'AtkBonus', 'HPBonus', 'DEFBonus', ...
            'ER', 'EM', 'CritRate', 'CritDMG', 'HealingBonus', 'PyroDMGBonus', ...
            'HydroDMGBonus', 'CryoDMGBonus', 'ElectroDMGBonus', 'AnemoDMGBonus', ...
            'GeoDMGBonus', 'DendroDMGBonus', 'NormalDMGBonus', 'ChargeDMGBonus', ...
            'ChargedDMGBonus', 'PlungeDMGBonus', 'SkillDMGBonus', 'BurstDMGBonus', 'ResShred'};

        if isfield(build, setField) || isfield(build, mainTypeField) || isfield(build, mainValueField)
            hasAnyPiece = true;
        end

        build = localSetDefault(build, setField, '');
        build = localSetDefault(build, mainTypeField, char(defaultMainStats{i}));
        build = localSetDefault(build, mainValueField, getArtifactMainStatValue(slotNames{i}, build.(mainTypeField)));
        build = localSetDefault(build, substatsField, '');
        for j = 1:numel(suffixes)
            fieldName = sprintf('Artifact%sSubstat%s', slotNames{i}, suffixes{j});
            build = localSetDefault(build, fieldName, 0);
        end
    end

    if ~hasAnyPiece && logical(getFieldOrDefault(build, 'ArtifactUsePieceModel', 1))
        build = localPopulateDefaultPieces(build, characterName, profile);
    end
end

function build = localPopulateDefaultPieces(build, characterName, profile)
    % 针对旧总面板 build，自动构造一份默认五件分件。
    % 这份自动分件优先保证：
    % 1. 套装归属明确；
    % 2. 主词条明确；
    % 3. 剩余差值仍保留在 aggregate 面板，由 compile 阶段做去预烘焙校准。
    slotNames = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
    setLayout = localResolveSetLayout(build);
    defaultMainStats = { ...
        "FlatHP", ...
        "FlatATK", ...
        string(profile.SandsMainStat), ...
        string(profile.GobletMainStat), ...
        string(profile.CircletMainStat)};

    for i = 1:numel(slotNames)
        setField = sprintf('Artifact%sSet', slotNames{i});
        mainTypeField = sprintf('Artifact%sMainStat', slotNames{i});
        mainValueField = sprintf('Artifact%sMainValue', slotNames{i});
        substatsField = sprintf('Artifact%sSubstats', slotNames{i});

        build.(setField) = char(setLayout{i});
        build.(mainTypeField) = char(defaultMainStats{i});
        build.(mainValueField) = getArtifactMainStatValue(slotNames{i}, defaultMainStats{i});
        if strlength(string(getFieldOrDefault(build, substatsField, ""))) == 0
            build.(substatsField) = '';
        end
    end

    build.ArtifactSet1 = char(string(setLayout{1}));
    counts = countcats(categorical(string(setLayout), unique(string(setLayout), 'stable')));
    uniqueSets = unique(string(setLayout), 'stable');
    if ~isempty(uniqueSets)
        build.ArtifactSet1 = char(uniqueSets(1));
        build.ArtifactSet1Pieces = counts(1);
    end
    if numel(uniqueSets) >= 2
        build.ArtifactSet2 = char(uniqueSets(2));
        build.ArtifactSet2Pieces = counts(2);
    end

    notes = string(getFieldOrDefault(build, 'ArtifactSetNotes', ""));
    if strlength(notes) == 0
        notes = "auto-generated-piece-model";
    else
        notes = notes + "; auto-generated-piece-model";
    end
    build.ArtifactSetNotes = char(notes);
    build.ArtifactSourceCharacter = char(string(characterName));
end

function setLayout = localResolveSetLayout(build)
    set1 = string(getFieldOrDefault(build, 'ArtifactSet1', 'None'));
    set2 = string(getFieldOrDefault(build, 'ArtifactSet2', 'None'));
    set1Pieces = max(0, min(5, round(getFieldOrDefault(build, 'ArtifactSet1Pieces', 0))));
    set2Pieces = max(0, min(5, round(getFieldOrDefault(build, 'ArtifactSet2Pieces', 0))));

    setLayout = repmat({char(set1)}, 1, 5);
    if set1 == "None" || set1Pieces <= 0
        setLayout(:) = {'None'};
    end

    if set1Pieces >= 4
        setLayout = {char(set1), char(set1), char(set1), char(set1), 'None'};
    elseif set1Pieces == 2 && set2Pieces >= 2 && set2 ~= "None"
        setLayout = {char(set1), char(set1), char(set2), char(set2), 'None'};
    elseif set1Pieces == 2
        setLayout = {char(set1), char(set1), 'None', 'None', 'None'};
    elseif set1Pieces == 5
        setLayout = {char(set1), char(set1), char(set1), char(set1), char(set1)};
    end

    if set2Pieces >= 2 && set2 ~= "None" && set1Pieces >= 4
        setLayout{5} = char(set2);
    end
end

function build = localSetDefault(build, fieldName, defaultValue)
    if ~isfield(build, fieldName) || isempty(build.(fieldName))
        build.(fieldName) = defaultValue;
    end
end

function setId = localRecommendedSet(characterName)
    switch lower(char(string(characterName)))
        case 'arlecchino'
            setId = "FragmentOfHarmonicWhimsy";
        case 'furina'
            setId = "GoldenTroupe";
        case 'neuvillette'
            setId = "MarechausseeHunter";
        case {'chasca', 'mualani', 'varesa'}
            setId = "ObsidianCodex";
        case {'lauma', 'nefer'}
            setId = "DeepwoodMemories";
        case {'skirk', 'citlali'}
            setId = "BlizzardStrayer";
        case 'escoffier'
            setId = "GoldenTroupe";
        case {'xilonen', 'zibai', 'linnea'}
            setId = "HuskOfOpulentDreams";
        case 'nicole'
            setId = "GoldenTroupe";
        otherwise
            setId = "None";
    end
end
