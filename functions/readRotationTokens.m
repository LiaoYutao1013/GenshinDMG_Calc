function actions = readRotationTokens(filePath)
    % Read a plain-text rotation file where each non-comment line starts
    % with one action token such as E / Q / N1 / Summon.
    fid = fopen(filePath, 'r');
    if fid == -1
        error('Unable to open rotation file: %s', filePath);
    end

    cleaner = onCleanup(@() fclose(fid));
    actions = {};

    while ~feof(fid)
        line = strtrim(fgetl(fid));
        % Allow blank lines and comments so rotation files stay editable by
        % hand without breaking the parser.
        if ~ischar(line) || isempty(line) || startsWith(line, '#')
            continue;
        end
        token = regexp(line, '^\S+', 'match', 'once');
        if ~isempty(token)
            actions{end+1, 1} = token; %#ok<AGROW>
        end
    end
end
