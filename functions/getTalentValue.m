function value = getTalentValue(talentTable, skillName, paramName, talentLevel)
    % Resolve one Skill + Param row from a talent table and read the value
    % for the requested level. If later levels are blank in the CSV, walk
    % backward to the nearest populated level column.
    rowMask = strcmp(talentTable.Skill, skillName) & strcmp(talentTable.Param, paramName);

    if ~any(rowMask)
        error('Talent row not found: %s / %s', skillName, paramName);
    end

    rowIndex = find(rowMask, 1, 'first');
    maxLevel = min(max(round(talentLevel), 1), 15);

    value = NaN;
    for level = maxLevel:-1:1
        levelName = sprintf('Level%d', level);
        if ismember(levelName, talentTable.Properties.VariableNames)
            candidate = talentTable.(levelName)(rowIndex);
            if ~isnan(candidate)
                value = candidate;
                return;
            end
        end
    end

    % Some simplified tables only provide a subset of level columns
    % (for example, only Level10). Fall back to the nearest available
    % populated level so the simulator can still run.
    levelColumns = talentTable.Properties.VariableNames(startsWith(talentTable.Properties.VariableNames, 'Level'));
    if ~isempty(levelColumns)
        availableLevels = zeros(1, numel(levelColumns));
        for i = 1:numel(levelColumns)
            availableLevels(i) = str2double(extractAfter(levelColumns{i}, "Level"));
        end

        [~, order] = sort(abs(availableLevels - maxLevel), 'ascend');
        for idx = order
            candidate = talentTable.(levelColumns{idx})(rowIndex);
            if ~isnan(candidate)
                value = candidate;
                return;
            end
        end
    end

    error('No numeric talent value found: %s / %s', skillName, paramName);
end
