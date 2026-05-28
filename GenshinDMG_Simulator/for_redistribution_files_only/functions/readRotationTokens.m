function actions = readRotationTokens(filePath)
    % 读取纯文本轮转脚本中的动作 token。
    % 每个非注释行的第一个非空白字段会被视为动作名，例如 E、Q、
    % N1、Summon；同一行后面的文字默认视作说明，不参与解析。
    fid = fopen(filePath, 'r');
    if fid == -1
        error('Unable to open rotation file: %s', filePath);
    end

    % onCleanup 用于保证函数异常退出时文件也会自动关闭。
    cleaner = onCleanup(@() fclose(fid));
    actions = {};

    while ~feof(fid)
        line = strtrim(fgetl(fid));
        % 允许空行和注释行，便于手动维护轮转脚本。
        if ~ischar(line) || isempty(line) || startsWith(line, '#')
            continue;
        end
        % 只提取首个 token，避免后续中文说明破坏解析。
        token = regexp(line, '^\S+', 'match', 'once');
        if ~isempty(token)
            actions{end+1, 1} = token; %#ok<AGROW>
        end
    end
end
