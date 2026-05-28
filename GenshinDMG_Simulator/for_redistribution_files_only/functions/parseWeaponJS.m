function weaponTable = parseWeaponJS(filePath)
    % 解析原始武器 JS 数据，并导出项目使用的 weapons.csv。
    % 该函数的目标不是完整保留原始配置，而是抽取构筑与优化流程
    % 真正依赖的字段：名称、基础攻击、词条类型、词条数值、星级。

    % 固定以当前函数文件为锚点寻找工程 data 目录。
    funcFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(funcFolder, '..', 'data');
    filePath = fullfile(dataFolder, 'AvatarExcelConfigData.js');

    % 输出实际读取路径，方便排查原始数据文件缺失问题。
    fprintf('读取武器原始数据：\n%s\n', filePath);
    if ~exist(filePath, 'file')
        error('找不到原始武器数据文件：%s', filePath);
    end

    % 读取文本后，尽量清洗成 jsondecode 可接受的纯 JSON 数组。
    txt = fileread(filePath);
    txt = regexprep(txt, 'var __WeaponConfig\s*=\s*', '');
    txt = regexprep(txt, 'var .*?=\s*', '');
    txt = regexprep(txt, ';$', '');
    txt = strtrim(txt);

    % 兼容旧格式：若文本不是以数组开头，则手动包一层数组括号。
    if ~startsWith(txt, '[')
        txt = ['[' txt ']'];
    end

    data = jsondecode(txt);

    % 将原始结构数组压平成工程统一的表格式。
    rows = table();
    for i = 1:length(data)
        obj = data(i);
        row = table( ...
            string(obj.name), ...
            obj.Stat, ...
            string(obj.Custom), ...
            obj.CustomStat, ...
            obj.Rank, ...
            obj.Type, ...
            'VariableNames', {'Name','BaseATK','SubstatType','SubstatValue','Rank','Type'});
        rows = [rows; row]; %#ok<AGROW>
    end

    weaponTable = rows;

    % 默认过滤到四星及以上武器，贴合当前工程主要使用场景。
    weaponTable = weaponTable(weaponTable.Rank >= 4, :);

    % 导出到 data/weapons.csv，作为后续构筑脚本的静态输入。
    outputPath = fullfile(funcFolder, '..', 'data', 'weapons.csv');
    writetable(weaponTable, outputPath);

    fprintf('武器数据提取完成，共 %d 把武器。\n', height(weaponTable));
    disp(weaponTable(1:min(8, height(weaponTable)), [1 3 4 5]));
end
