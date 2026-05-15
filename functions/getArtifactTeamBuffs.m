function buffs = getArtifactTeamBuffs(characterName, build)
    % 返回会影响队伍共享状态或敌人抗性的圣遗物套装效果。
    % 这里不重复处理角色自己的直伤增益，只处理：
    % 1. 全队攻击力等共享增益；
    % 2. 敌人元素抗性削减；
    % 3. 当前工程里已明确建模的套装团队效果。
    if nargin < 1
        characterName = "";
    end

    build = normalizeArtifactBuild(build, characterName);
    buffs = struct( ...
        'ATKBonus', 0, ...
        'EMBonus', 0, ...
        'DendroResShred', 0, ...
        'PyroResShred', 0, ...
        'HydroResShred', 0, ...
        'CryoResShred', 0, ...
        'ElectroResShred', 0);

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

            case 'instructor'
                buffs.EMBonus = max(buffs.EMBonus, 120);

            case 'viridescentvenerer'
                if localLikelySwirlSupport(characterName)
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

function tf = localLikelySwirlSupport(characterName)
    tf = any(strcmpi(char(string(characterName)), {'Xianyun', 'Chasca'}));
end
