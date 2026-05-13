function actions = parseRotationTextTokens(rotationText)
    % 从 GUI 文本框内容中提取动作 token。
    % 规则与 readRotationTokens 保持一致：忽略空行和以 # 开头的注释行，
    % 每一行只取第一个非空白 token。
    if isstring(rotationText)
        rotationText = char(join(rotationText, newline));
    end

    lines = regexp(char(rotationText), '\r\n|\n|\r', 'split');
    actions = {};
    for i = 1:numel(lines)
        line = strtrim(lines{i});
        if isempty(line) || startsWith(line, '#')
            continue;
        end

        token = regexp(line, '^\S+', 'match', 'once');
        if ~isempty(token)
            actions{end + 1, 1} = token; %#ok<AGROW>
        end
    end
end
