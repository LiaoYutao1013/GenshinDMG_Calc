function charBase = loadCharacter(name)
    % Legacy helper that loads one character row and its matching talent
    % CSV by name. Newer code paths prefer getDefaultCharacterConfig.
    % 未来扩展：直接加 case 'HuTao' / 'Neuvillette' 等
    chars = readtable('data/characters.csv');
    row = chars(strcmp(chars.Name, name), :);
    
    if isempty(row)
        error('角色 %s 未找到，请在characters.csv中添加', name);
    end
    
    charBase = struct(...
        'Name', name, ...
        'Level', row.Level, ...
        'BaseHP', row.BaseHP, ...
        'BaseATK', row.BaseATK, ...
        'ScalingType', 'ATK', 'MaxHP',...        % 默认攻击力缩放（芙宁娜以后改成'HP'）
        'TalentTable', readtable(['data/talents_', name, '.csv']) ...  % 自动加载倍率表
    );
end
