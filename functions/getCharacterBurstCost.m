function cost = getCharacterBurstCost(characterName, talentLevel, constellation)
    % 读取角色元素爆发能量成本。
    %
    % 约定：
    % 1. 优先从 data/<Character>/talents_*.csv 的 Burst / EnergyCost 行读取；
    % 2. 如果数据缺失，则回退到一个保守的 60 点默认值；
    % 3. 命座和天赋等级会影响查表列选择，但绝大多数 EnergyCost 行本身是常数。
    if nargin < 2 || isempty(talentLevel)
        talentLevel = 10;
    end
    if nargin < 3 || isempty(constellation)
        constellation = 0;
    end

    cost = 60;
    talentPath = resolveCharacterDataFile(characterName, 'talents');
    if strlength(talentPath) == 0 || exist(char(talentPath), 'file') ~= 2
        return;
    end

    try
        talentTable = readtable(char(talentPath));
    catch
        return;
    end

    if isempty(talentTable) ...
            || ~ismember('Skill', talentTable.Properties.VariableNames) ...
            || ~ismember('Param', talentTable.Properties.VariableNames)
        return;
    end

    rowMask = strcmp(string(talentTable.Skill), "Burst") ...
        & strcmp(string(talentTable.Param), "EnergyCost");
    if ~any(rowMask)
        return;
    end

    rowIndex = find(rowMask, 1, 'first');
    burstLevel = talentLevel + 3 * double(constellation >= 5);
    burstLevel = max(1, min(15, round(burstLevel)));
    levelField = sprintf('Level%d', burstLevel);

    if ismember(levelField, talentTable.Properties.VariableNames)
        candidate = talentTable.(levelField)(rowIndex);
        if ~isnan(candidate)
            cost = double(candidate);
            return;
        end
    end

    levelVars = talentTable.Properties.VariableNames(startsWith(talentTable.Properties.VariableNames, 'Level'));
    for i = 1:numel(levelVars)
        candidate = talentTable.(levelVars{i})(rowIndex);
        if ~isnan(candidate)
            cost = double(candidate);
            return;
        end
    end
end
