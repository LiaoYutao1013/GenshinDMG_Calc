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

    error('No numeric talent value found: %s / %s', skillName, paramName);
end
