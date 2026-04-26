function charBase = loadCharacter(name)
    % 旧版角色加载入口。
    % 该函数保留给早期通用脚本使用：它从老式的 characters.csv 与
    % talents_*.csv 中读取角色基础信息，并返回一个简化结构体。
    % 新的统一入口更推荐使用 getDefaultCharacterConfig。

    % 读取旧版角色总表，并按照角色名筛选目标行。
    chars = readtable('data/characters.csv');
    row = chars(strcmp(chars.Name, name), :);

    % 如果找不到目标角色，直接报错提醒维护者补数据。
    if isempty(row)
        error('角色 %s 未找到，请在 characters.csv 中补充该角色。', name);
    end

    % 旧版结构体仅保留最基础的信息：
    % 1. 名称与等级；
    % 2. 基础生命 / 攻击；
    % 3. 默认缩放类型；
    % 4. 对应的天赋表。
    charBase = struct( ...
        'Name', name, ...
        'Level', row.Level, ...
        'BaseHP', row.BaseHP, ...
        'BaseATK', row.BaseATK, ...
        'ScalingType', 'ATK', ...
        'TalentTable', readtable(['data/talents_', name, '.csv']) ...
    );
end
