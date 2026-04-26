function charTable = parseBaseStatsJS(filePath, targetName)
    % 从原始 AvatarExcelConfigData.js 中提取单个角色的基础面板数据。
    % 输出结果会写入 data/characters_<角色名>.csv，供后续模拟器、
    % 构筑脚本或数据校验脚本直接读取。

    % 这里固定以当前函数所在目录为锚点推导 data 路径，避免调用时
    % 受当前工作目录影响。filePath 参数目前主要保留给旧接口兼容。
    funcFolder = fileparts(mfilename('fullpath'));
    dataFolder = fullfile(funcFolder, '..', 'data');
    filePath = fullfile(dataFolder, 'AvatarExcelConfigData.js');

    % 读取原始 JS 文本。原文件不是纯 JSON，后面会先做文本清洗。
    txt = fileread(filePath);

    % 去掉变量赋值前缀和尾部分号，整理为可被 jsondecode 解析的数组。
    txt = regexprep(txt, 'var __AvatarInfoConfig = ', '');
    txt = regexprep(txt, 'var _MaterialConfig = .*?var index_avatar = .*?;', '', 'once');
    txt = regexprep(txt, ';$', '');
    data = jsondecode(txt);

    % 遍历查找目标角色，允许大小写宽松匹配。
    obj = [];
    for i = 1:length(data)
        if strcmp(data{i}.Name, targetName) || contains(data{i}.Name, targetName, 'IgnoreCase', true)
            obj = data{i};
            break;
        end
    end

    % 若未命中，直接报错，提醒维护者检查角色英文键名是否正确。
    if isempty(obj)
        error('未在 AvatarExcelConfigData.js 中找到角色 %s。', targetName);
    end

    % 提取工程当前会用到的基础字段：
    % ShowStats 视作 90 级基础参考面板，CustomPromote 与 Custom 用于
    % 记录突破附加属性类型及数值。
    baseHP = obj.ShowStats.HP;
    baseATK = obj.ShowStats.ATK;
    baseDEF = obj.ShowStats.DEF;
    customVal = obj.ShowStats.Custom;
    customType = obj.CustomPromote;

    % 统一写成一行表结构，字段名与项目内其它角色基础表保持一致。
    charTable = table( ...
        string(obj.Name), baseHP, baseATK, baseDEF, 90, ...
        string(customType), customVal, string(obj.Weapon), string(obj.Element), ...
        'VariableNames', {'Name','BaseHP','BaseATK','BaseDEF','Level', ...
        'AscensionType','AscensionValue','Weapon','Element'});

    % 导出到工程 data 目录，供模拟器和构筑脚本读取。
    outputPath = fullfile(funcFolder, '..', 'data', ['characters_', targetName, '.csv']);
    writetable(charTable, outputPath);

    fprintf('基础面板解析完成：%s\n', targetName);
    disp(charTable);
end
