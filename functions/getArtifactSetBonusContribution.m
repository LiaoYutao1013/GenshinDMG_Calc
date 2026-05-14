function bonus = getArtifactSetBonusContribution(characterName, build, teamContext)
    % 根据当前圣遗物件数和条件化假设，返回应加到 build 面板上的套装增益。
    if nargin < 3 || isempty(teamContext)
        teamContext = struct();
    end

    bonus = localEmptyStatStruct();
    setPieces = localCollectSetPieces(build);
    setNames = fieldnames(setPieces);

    for i = 1:numel(setNames)
        setId = setNames{i};
        pieces = min(5, setPieces.(setId));
        if pieces >= 2
            bonus = localAddStatStruct(bonus, localTwoPieceBonus(setId, characterName));
        end
        if pieces >= 4 && logical(getFieldOrDefault(build, 'ArtifactSet4Active', 1))
            bonus = localAddStatStruct(bonus, localFourPieceBonus(setId, characterName, build, teamContext));
        end
    end
end

function setPieces = localCollectSetPieces(build)
    slots = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
    setPieces = struct();

    for i = 1:numel(slots)
        fieldName = sprintf('Artifact%sSet', slots{i});
        setId = string(getFieldOrDefault(build, fieldName, ""));
        if strlength(setId) == 0 || setId == "None"
            continue;
        end
        key = char(setId);
        if ~isfield(setPieces, key)
            setPieces.(key) = 0;
        end
        setPieces.(key) = setPieces.(key) + 1;
    end

    if isempty(fieldnames(setPieces))
        legacyEntries = { ...
            char(string(getFieldOrDefault(build, 'ArtifactSet1', 'None'))), getFieldOrDefault(build, 'ArtifactSet1Pieces', 0); ...
            char(string(getFieldOrDefault(build, 'ArtifactSet2', 'None'))), getFieldOrDefault(build, 'ArtifactSet2Pieces', 0)};
        for i = 1:size(legacyEntries, 1)
            setId = string(legacyEntries{i, 1});
            pieces = legacyEntries{i, 2};
            if setId == "None" || pieces <= 0
                continue;
            end
            key = char(setId);
            if ~isfield(setPieces, key)
                setPieces.(key) = 0;
            end
            setPieces.(key) = setPieces.(key) + pieces;
        end
    end
end

function bonus = localTwoPieceBonus(setId, characterName)
    bonus = localEmptyStatStruct();
    element = getCharacterElement(characterName);

    switch char(string(setId))
        case {'ATK18', 'FragmentOfHarmonicWhimsy'}
            bonus.AtkBonus = 0.18;
        case 'HP20'
            bonus.HPBonus = 0.20;
        case {'EM80', 'WanderersTroupe'}
            bonus.EM = 80;
        case 'ER20'
            bonus.ER = 0.20;
        case 'Healing15'
            bonus.HealingBonus = 0.15;
        case 'GoldenTroupe'
            bonus.SkillDMGBonus = 0.20;
        case 'MarechausseeHunter'
            bonus.NormalDMGBonus = 0.15;
            bonus.ChargeDMGBonus = 0.15;
            bonus.ChargedDMGBonus = 0.15;
        case 'ObsidianCodex'
            bonus.NormalDMGBonus = 0.15;
            bonus.ChargeDMGBonus = 0.15;
            bonus.ChargedDMGBonus = 0.15;
            bonus.SkillDMGBonus = 0.15;
            bonus.BurstDMGBonus = 0.15;
        case 'BlizzardStrayer'
            bonus = localAddElementBonus(bonus, element, 0.15);
        case 'DeepwoodMemories'
            bonus.DendroDMGBonus = 0.15;
        case 'NoblesseOblige'
            bonus.BurstDMGBonus = 0.20;
        case 'TenacityOfTheMillelith'
            bonus.HPBonus = 0.20;
        case 'HuskOfOpulentDreams'
            bonus.DEFBonus = 0.30;
        case 'HeartOfDepth'
            bonus.HydroDMGBonus = 0.15;
    end
end

function bonus = localFourPieceBonus(setId, characterName, build, teamContext)
    bonus = localEmptyStatStruct();

    switch char(string(setId))
        case 'GoldenTroupe'
            bonus.SkillDMGBonus = 0.25;
            if logical(getFieldOrDefault(build, 'ArtifactAssumeOffFieldSkill', localIsMostlyOffFieldSkillUser(characterName)))
                bonus.SkillDMGBonus = bonus.SkillDMGBonus + 0.25;
            end

        case 'MarechausseeHunter'
            stackCount = min(3, max(0, getFieldOrDefault(build, 'ArtifactAssumeMarechausseeStacks', 3)));
            bonus.CritRate = 0.12 * stackCount;

        case 'FragmentOfHarmonicWhimsy'
            stackCount = max(0, getFieldOrDefault(build, 'ArtifactAssumeBondOfLifeStacks', double(localUsesBondOfLife(characterName))));
            stackCount = max(stackCount, double(localUsesBondOfLife(characterName)));
            bonus = localAddCommonActionBonus(bonus, 0.18 * max(1, stackCount));

        case 'ObsidianCodex'
            if logical(getFieldOrDefault(build, 'ArtifactAssumeObsidianActive', false))
                bonus.CritRate = 0.40;
            end

        case 'BlizzardStrayer'
            cryoAura = logical(getFieldOrDefault(build, 'ArtifactAssumeCryoAura', false));
            frozen = logical(getFieldOrDefault(build, 'ArtifactAssumeFrozen', false)) ...
                || getFieldOrDefault(teamContext, 'HydroCount', 0) >= 1;
            if cryoAura || frozen
                bonus.CritRate = bonus.CritRate + 0.20;
            end
            if frozen
                bonus.CritRate = bonus.CritRate + 0.20;
            end

        case 'HeartOfDepth'
            bonus.NormalDMGBonus = 0.30;
            bonus.ChargeDMGBonus = 0.30;
            bonus.ChargedDMGBonus = 0.30;

        case 'HuskOfOpulentDreams'
            stackCount = min(4, max(0, getFieldOrDefault(build, 'ArtifactAssumeHuskStacks', 0)));
            bonus.DEFBonus = 0.06 * stackCount;
            bonus.GeoDMGBonus = 0.06 * stackCount;

        case 'WanderersTroupe'
            bonus.ChargeDMGBonus = 0.35;
            bonus.ChargedDMGBonus = 0.35;
    end
end

function bonus = localAddCommonActionBonus(bonus, value)
    bonus.NormalDMGBonus = bonus.NormalDMGBonus + value;
    bonus.ChargeDMGBonus = bonus.ChargeDMGBonus + value;
    bonus.ChargedDMGBonus = bonus.ChargedDMGBonus + value;
    bonus.SkillDMGBonus = bonus.SkillDMGBonus + value;
    bonus.BurstDMGBonus = bonus.BurstDMGBonus + value;
end

function bonus = localAddElementBonus(bonus, element, value)
    switch lower(char(string(element)))
        case 'pyro'
            bonus.PyroDMGBonus = bonus.PyroDMGBonus + value;
        case 'hydro'
            bonus.HydroDMGBonus = bonus.HydroDMGBonus + value;
        case 'cryo'
            bonus.CryoDMGBonus = bonus.CryoDMGBonus + value;
        case 'electro'
            bonus.ElectroDMGBonus = bonus.ElectroDMGBonus + value;
        case 'anemo'
            bonus.AnemoDMGBonus = bonus.AnemoDMGBonus + value;
        case 'geo'
            bonus.GeoDMGBonus = bonus.GeoDMGBonus + value;
        case 'dendro'
            bonus.DendroDMGBonus = bonus.DendroDMGBonus + value;
    end
end

function merged = localAddStatStruct(merged, incoming)
    fields = fieldnames(incoming);
    for i = 1:numel(fields)
        fieldName = fields{i};
        merged.(fieldName) = getFieldOrDefault(merged, fieldName, 0) + getFieldOrDefault(incoming, fieldName, 0);
    end
end

function tf = localUsesBondOfLife(characterName)
    tf = any(strcmpi(char(string(characterName)), {'Arlecchino'}));
end

function tf = localIsMostlyOffFieldSkillUser(characterName)
    tf = any(strcmpi(char(string(characterName)), { ...
        'Furina', 'Escoffier', 'Citlali', 'Chevreuse', 'Iansan', ...
        'Nicole', 'Lauma', 'Linnea', 'Nefer', 'Flins', 'Zibai'}));
end

function stats = localEmptyStatStruct()
    stats = struct( ...
        'AtkBonus', 0, ...
        'FlatATK', 0, ...
        'HPBonus', 0, ...
        'FlatHP', 0, ...
        'DEFBonus', 0, ...
        'FlatDEF', 0, ...
        'ER', 0, ...
        'EM', 0, ...
        'CritRate', 0, ...
        'CritDMG', 0, ...
        'PyroDMGBonus', 0, ...
        'HydroDMGBonus', 0, ...
        'CryoDMGBonus', 0, ...
        'ElectroDMGBonus', 0, ...
        'AnemoDMGBonus', 0, ...
        'GeoDMGBonus', 0, ...
        'DendroDMGBonus', 0, ...
        'NormalDMGBonus', 0, ...
        'ChargeDMGBonus', 0, ...
        'ChargedDMGBonus', 0, ...
        'PlungeDMGBonus', 0, ...
        'SkillDMGBonus', 0, ...
        'BurstDMGBonus', 0, ...
        'HealingBonus', 0, ...
        'ResShred', 0);
end
