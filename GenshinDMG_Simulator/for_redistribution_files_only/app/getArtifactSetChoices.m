function [labels, ids] = getArtifactSetChoices()
    % 返回圣遗物套装下拉框使用的显示文本和 ID。
    registry = getArtifactSetRegistry();
    labels = cell(1, numel(registry));
    ids = cell(1, numel(registry));
    for i = 1:numel(registry)
        labels{i} = sprintf('%s | %s', registry(i).DisplayName, registry(i).Id);
        ids{i} = registry(i).Id;
    end
end
