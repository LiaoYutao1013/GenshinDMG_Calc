function value = getTalentValue(talentTable, skillName, paramName, talentLevel)
    % 从扁平化天赋表中读取某个 Skill / Param 在指定天赋等级下的值。
    % 这个函数除了做普通查表，还承担了“等级列不完整时的兜底回退”
    % 逻辑，保证简化版 CSV 仍然能够被统一模拟器正常消费。
    rowMask = strcmp(talentTable.Skill, skillName) & strcmp(talentTable.Param, paramName);

    if ~any(rowMask)
        error('Talent row not found: %s / %s', skillName, paramName);
    end

    % 将输入等级约束到 1~15 区间，兼容普通天赋与命座提升后的场景。
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

    % 某些角色的简化表可能只保留了少量等级列，例如只有 Level10。
    % 这时改为寻找“离目标等级最近且非空”的列，尽量给出可运行结果。
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
