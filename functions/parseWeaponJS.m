function weaponTable = parseWeaponJS(filePath)
    % 获取「本函数文件自己所在的文件夹」 → functions/
    funcFolder = fileparts(mfilename('fullpath'));
    
    % 往上一级到项目根目录，再进入 data
    dataFolder = fullfile(funcFolder, '..', 'data');
    filePath   = fullfile(dataFolder, 'AvatarExcelConfigData.js');
    
    % 调试用：建议先保留这几行，确认路径正确后再注释掉
    fprintf('期望的文件完整路径：\n%s\n', filePath);
    if ~exist(filePath, 'file')
        error('找不到文件：\n%s\n当前工作目录是：%s', filePath, pwd);
    end
    % 支持两种常见格式：var __WeaponConfig = [ ... ] 或直接 [{...}, {...}]
    txt = fileread(filePath);
    
    % 清理成纯JSON数组
    txt = regexprep(txt, 'var __WeaponConfig\s*=\s*', '');
    txt = regexprep(txt, 'var .*?=\s*', '');   % 移除其他var
    txt = regexprep(txt, ';$', '');
    txt = strtrim(txt);
    
    % 如果不是以[开头，强制包裹成数组
    if ~startsWith(txt, '[')
        txt = ['[' txt ']'];
    end
    
    data = jsondecode(txt);   % MATLAB R2019b+ 支持
    
    % 转为table
    rows = [];
    for i = 1:length(data)
        obj = data(i);
        baseATK = obj.Stat;                  % 基础攻击力
        subType = obj.Custom;                % "CD" / "CR" / "ATK%" 等
        subValue = obj.CustomStat;           % 数值（如0.441024）
        rank = obj.Rank;                     % 星级
        weaponType = obj.Type;               % 5=弓 等
        
        row = table(string(obj.name), baseATK, {subType}, subValue, rank, weaponType, ...
            'VariableNames', {'Name','BaseATK','SubstatType','SubstatValue','Rank','Type'});
        rows = [rows; row];
    end
    
    weaponTable = rows;
    
    % 自动筛选哥伦比娅常用（法器 + 高星），你可手动删除这行
    weaponTable = weaponTable(weaponTable.Rank >= 4, :);
    
    writetable(weaponTable, '../data/weapons.csv');
    fprintf('✅ 武器数据提取完成！共 %d 把武器，已保存到 data/weapons.csv\n', height(weaponTable));
    disp(weaponTable(1:min(8,height(weaponTable)), [1 3 4 5]));  % 预览前8把
end