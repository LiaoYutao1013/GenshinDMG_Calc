function buffs = getArtifactTeamBuffs(characterName, build)
    % 返回会影响队伍共享状态或敌人抗性的圣遗物套装效果。
    % 这里只处理：
    % 1. 全队攻击力、元素精通、元素增伤等共享增益；
    % 2. 敌人元素抗性削减；
    % 3. 当前工程中显式建模的月感反应加成。
    if nargin < 1
        characterName = "";
    end

    build = normalizeArtifactBuild(build, characterName);
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

    if ~logical(getFieldOrDefault(build, 'ArtifactApplySetBonuses', 0))
        return;
    end

    setPieces = localCollectSetPieces(build);
    setNames = fieldnames(setPieces);
    for i = 1:numel(setNames)
        setId = lower(char(string(setNames{i})));
        pieces = min(5, setPieces.(setNames{i}));
        if pieces < 4 || ~logical(getFieldOrDefault(build, 'ArtifactSet4Active', 1))
            continue;
        end

        switch setId
            case 'deepwoodmemories'
                buffs.DendroResShred = max(buffs.DendroResShred, 0.30);

            case 'noblesseoblige'
                buffs.ATKBonus = max(buffs.ATKBonus, 0.20);

            case 'tenacityofthemillelith'
                buffs.ATKBonus = max(buffs.ATKBonus, 0.20);
                buffs.ShieldBonus = max(buffs.ShieldBonus, 0.30);

            case 'instructor'
                buffs.EMBonus = max(buffs.EMBonus, 120);

            case 'viridescentvenerer'
                element = getCharacterElement(characterName);
                switch lower(char(element))
                    case 'pyro'
                        buffs.PyroResShred = max(buffs.PyroResShred, 0.40);
                    case 'hydro'
                        buffs.HydroResShred = max(buffs.HydroResShred, 0.40);
                    case 'cryo'
                        buffs.CryoResShred = max(buffs.CryoResShred, 0.40);
                    case 'electro'
                        buffs.ElectroResShred = max(buffs.ElectroResShred, 0.40);
                end

            case 'archaicpetra'
                preferred = string(getFieldOrDefault(build, 'ArtifactAssumePetraElement', getCharacterElement(characterName)));
                buffs = localAddElementTeamBonus(buffs, preferred, 0.35);

            case 'songofdayspast'
                % Song of Days Past records healing and converts it into
                % a flat additive damage instance with hit-count limits.
                % The current engine does not track this per-hit flat packet,
                % so keep the set present in the catalog but do not fake it
                % as a generic damage multiplier.

            case 'silkenmoonsserenade'
                moonPhase = min(1, max(0, getFieldOrDefault(build, 'ArtifactAssumeMoonPhase', 1)));
                buffs.EMBonus = max(buffs.EMBonus, 60 + 60 * double(moonPhase >= 1));
                buffs.LunarBloomBonus = max(buffs.LunarBloomBonus, 0.10);
                buffs.LunarChargedBonus = max(buffs.LunarChargedBonus, 0.10);
                buffs.LunarCrystallizeBonus = max(buffs.LunarCrystallizeBonus, 0.10);

            case 'nightoftheskysunveiling'
                moonPhase = min(1, max(0, getFieldOrDefault(build, 'ArtifactAssumeMoonPhase', 1)));
                buffs.ReactionCritRate = max(buffs.ReactionCritRate, 0.15 + 0.15 * double(moonPhase >= 1));
                buffs.LunarBloomBonus = max(buffs.LunarBloomBonus, 0.10);
                buffs.LunarChargedBonus = max(buffs.LunarChargedBonus, 0.10);
                buffs.LunarCrystallizeBonus = max(buffs.LunarCrystallizeBonus, 0.10);

            case 'aubadeofmorningstarandmoon'
                moonPhase = min(1, max(0, getFieldOrDefault(build, 'ArtifactAssumeMoonPhase', 1)));
                buffs.LunarBloomBonus = max(buffs.LunarBloomBonus, 0.20 + 0.40 * double(moonPhase >= 1));
                buffs.LunarChargedBonus = max(buffs.LunarChargedBonus, 0.20 + 0.40 * double(moonPhase >= 1));
                buffs.LunarCrystallizeBonus = max(buffs.LunarCrystallizeBonus, 0.20 + 0.40 * double(moonPhase >= 1));

            case 'scrolloftheheroofcindercity'
                nightsoulBoost = 0.12 + 0.28 * double(logical(getFieldOrDefault(build, 'ArtifactAssumeNightsoulBlessing', true)));
                preferredElements = localResolveReactionElements(characterName, build);
                for k = 1:numel(preferredElements)
                    buffs = localAddElementTeamBonus(buffs, preferredElements(k), nightsoulBoost);
                end

            case 'celestialgift'
                bonusValue = 0.20;
                if logical(getFieldOrDefault(build, 'ArtifactAssumeMortalHymn', false))
                    bonusValue = 0.40;
                end
                ownerElement = getCharacterElement(characterName);
                buffs = localAddElementTeamBonus(buffs, ownerElement, bonusValue);
                activeElement = string(getFieldOrDefault(build, 'ArtifactAssumeActiveElement', ""));
                if strlength(activeElement) > 0
                    buffs = localAddElementTeamBonus(buffs, activeElement, bonusValue);
                end
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
        key = matlab.lang.makeValidName(char(setId));
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
            key = matlab.lang.makeValidName(char(setId));
            if ~isfield(setPieces, key)
                setPieces.(key) = 0;
            end
            setPieces.(key) = setPieces.(key) + pieces;
        end
    end
end

function buffs = localAddElementTeamBonus(buffs, element, value)
    switch lower(char(string(element)))
        case 'pyro'
            buffs.PyroDMGBonus = max(getFieldOrDefault(buffs, 'PyroDMGBonus', 0), value);
        case 'hydro'
            buffs.HydroDMGBonus = max(getFieldOrDefault(buffs, 'HydroDMGBonus', 0), value);
        case 'cryo'
            buffs.CryoDMGBonus = max(getFieldOrDefault(buffs, 'CryoDMGBonus', 0), value);
        case 'electro'
            buffs.ElectroDMGBonus = max(getFieldOrDefault(buffs, 'ElectroDMGBonus', 0), value);
        case 'anemo'
            buffs.AnemoDMGBonus = max(getFieldOrDefault(buffs, 'AnemoDMGBonus', 0), value);
        case 'geo'
            buffs.GeoDMGBonus = max(getFieldOrDefault(buffs, 'GeoDMGBonus', 0), value);
        case 'dendro'
            buffs.DendroDMGBonus = max(getFieldOrDefault(buffs, 'DendroDMGBonus', 0), value);
    end
end

function elements = localResolveReactionElements(characterName, build)
    override = string(getFieldOrDefault(build, 'ArtifactAssumeReactionElements', ""));
    if strlength(override) > 0
        parts = split(override, ',');
        elements = strip(parts(parts ~= ""));
        return;
    end

    selfElement = string(getCharacterElement(characterName));
    switch lower(char(selfElement))
        case 'pyro'
            elements = ["Pyro", "Electro", "Hydro", "Dendro"];
        case 'hydro'
            elements = ["Hydro", "Cryo", "Electro", "Dendro"];
        case 'cryo'
            elements = ["Cryo", "Hydro", "Pyro"];
        case 'electro'
            elements = ["Electro", "Hydro", "Dendro", "Pyro"];
        case 'dendro'
            elements = ["Dendro", "Hydro", "Electro", "Pyro"];
        case 'geo'
            elements = ["Geo", "Pyro", "Hydro", "Cryo", "Electro"];
        otherwise
            elements = selfElement;
    end
end
