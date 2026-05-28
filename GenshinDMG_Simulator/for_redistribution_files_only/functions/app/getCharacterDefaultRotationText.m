function rotationText = getCharacterDefaultRotationText(characterName)
    % 读取角色默认 rotation 文本，直接供 GUI 文本框编辑。
    cfg = getDefaultCharacterConfig(characterName);
    if ~isfile(cfg.RotationFile)
        rotationText = "AUTO";
        return;
    end

    rawText = fileread(cfg.RotationFile);
    if isempty(rawText)
        rotationText = "AUTO";
    else
        rotationText = string(rawText);
    end
end
