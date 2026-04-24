function value = getTalentValue(talentTable, skillName, paramName, talentLevel)
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
