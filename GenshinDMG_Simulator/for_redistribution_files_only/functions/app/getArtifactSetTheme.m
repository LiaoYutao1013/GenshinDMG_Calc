function [displayName, shortLabel, themeColor] = getArtifactSetTheme(setId)
    % 按套装 ID 返回显示名、简称与主题色。
    registry = getArtifactSetRegistry();
    displayName = string(setId);
    shortLabel = string(setId);
    themeColor = [0.55 0.58 0.64];
    for i = 1:numel(registry)
        if string(registry(i).Id) == string(setId)
            displayName = string(registry(i).DisplayName);
            shortLabel = string(registry(i).ShortLabel);
            themeColor = registry(i).ThemeColor;
            return;
        end
    end
end
