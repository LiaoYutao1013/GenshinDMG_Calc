function actions = readRotationTokens(filePath)
    fid = fopen(filePath, 'r');
    if fid == -1
        error('Unable to open rotation file: %s', filePath);
    end

    cleaner = onCleanup(@() fclose(fid));
    actions = {};

    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if ~ischar(line) || isempty(line) || startsWith(line, '#')
            continue;
        end
        token = regexp(line, '^\S+', 'match', 'once');
        if ~isempty(token)
            actions{end+1, 1} = token; %#ok<AGROW>
        end
    end
end
