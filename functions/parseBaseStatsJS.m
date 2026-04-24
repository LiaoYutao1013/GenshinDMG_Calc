function charTable = parseBaseStatsJS(filePath, targetName)
    % Extract one character's base stat block from the raw JS dump and
    % export the subset needed by the simulators into a compact CSV.
    
    % 获取「本函数文件自己所在的文件夹」 → functions/
    funcFolder = fileparts(mfilename('fullpath'));
    
    % 往上一级到项目根目录，再进入 data
    dataFolder = fullfile(funcFolder, '..', 'data');
    filePath   = fullfile(dataFolder, 'AvatarExcelConfigData.js');
    
    % 调试用：建议先保留这几行，确认路径正确后再注释掉
    %fprintf('期望的文件完整路径：\n%s\n', filePath);
    %if ~exist(filePath, 'file')
    %    error('文件找不到：\n%s\n请确认文件是否存在，以及脚本是否在正确的位置运行', filePath);
    %end
    txt = fileread(filePath);
    % 清理成可解析的JSON数组
    txt = regexprep(txt, 'var __AvatarInfoConfig = ', '');
    txt = regexprep(txt, 'var _MaterialConfig = .*?var index_avatar = .*?;', '', 'once');
    txt = regexprep(txt, ';$', '');
    data = jsondecode(txt);   % MATLAB R2019b+
    
    n = length(data);


    % 遍历找到目标角色
    for i = 1:length(data)
        if strcmp(data{i}.Name, targetName) || contains(data{i}.Name, targetName, 'IgnoreCase',true)
            obj = data{i};
            break;
        end
    end

    % 提取关键属性（ShowStats 为90级基础，ShowStats2 为突破后参考）
    baseHP  = obj.ShowStats.HP;
    baseATK = obj.ShowStats.ATK;
    baseDEF = obj.ShowStats.DEF;
    customVal = obj.ShowStats.Custom;          % 突破属性数值
    customType = obj.CustomPromote;            % CR / CD / HP / EM 等

    charTable = table(string(obj.Name), baseHP, baseATK, baseDEF, 90, ...
        num2cell(customType), num2cell(customVal), string(obj.Weapon), string(obj.Element), ...
        'VariableNames', {'Name','BaseHP','BaseATK','BaseDEF','Level', ...
                          'AscensionType','AscensionValue','Weapon','Element'});

    writetable(charTable, ['../data/characters_', targetName, '.csv']);
    fprintf('✅ 解析完成！%s 已保存\n', targetName);
    disp(charTable);
end
