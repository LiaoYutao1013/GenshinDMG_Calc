function buffs = getArtifactTeamBuffs(characterName, build)
    % 返回会影响整队或敌人抗性的套装效果。
    % 这里只放入真正的“共享态”效果，角色自身的直伤加成仍在 compileArtifactSetBonuses 中处理。
    build = normalizeArtifactBuild(build, characterName);

    buffs = struct( ...
        'ATKBonus', 0, ...
        'DendroResShred', 0);

    if ~logical(getFieldOrDefault(build, 'ArtifactApplySetBonuses', 0))
        return;
    end

    setPieces = localCollectSetPieces(build);
    setNames = fieldnames(setPieces);
    for i = 1:numel(setNames)
        setId = setNames{i};
        pieces = min(5, setPieces.(setId));
        if pieces < 4 || ~logical(getFieldOrDefault(build, 'ArtifactSet4Active', 1))
            continue;
        end

        switch setId
            case 'DeepwoodMemories'
                buffs.DendroResShred = max(buffs.DendroResShred, 0.30);
            case {'NoblesseOblige', 'TenacityOfTheMillelith'}
                buffs.ATKBonus = max(buffs.ATKBonus, 0.20);
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
