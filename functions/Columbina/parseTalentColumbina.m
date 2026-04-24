function talentTable = parseTalentColumbina(skillFile, charName, version)
    % Parse Columbina's raw skill JSON into a flat CSV. Scaling type and
    % explicit multiplier suffixes are inferred from the Param text.
    % ================== 参数 ==================
    if nargin < 3, version = "1"; end   % 默认C0（Ver 1）
    
    % ================== 读取并解析纯JSON ==================
    txt = fileread(skillFile);
    txt = strtrim(txt);
    
    
    % 如果文件以 { 开头，直接decode；否则移除可能的var前缀
    if startsWith(txt, '{')
        data = jsondecode(txt);
    else
        txt = regexprep(txt, 'var .*?=\s*', '');
        txt = regexprep(txt, ';$', '');
        data = jsondecode(txt);
    end
    
    % ================== 提取目标版本 ==================
    if ~isfield(data, charName)
        error('未找到角色 %s', charName);
    end
    verData = data.(charName).Ver.(version);
    
    % ================== 提取 BattleSkills 中的所有倍率 ==================
    skills = verData.BattleSkills;
    rows = [];
    
    for s = 1:length(skills)
        skillName = skills{s}.Name;
        for p = 1:length(skills{s}.ParamDesc)
            param = skills{s}.ParamDesc(p);
            mvStr = param.ParamLevelList;                     % 原始字符串
            mvNum = zeros(1,15);
            scaling = 'ATK';
            multiplier = 1;
            
            % 自动识别缩放类型和倍率
            descLower = lower(param.Desc);
            if contains(descLower, '生命值上限')
                scaling = 'MaxHP';
            elseif contains(descLower, '防御力')
                scaling = 'DEF';
            end
            if contains(descLower, '×')
                multMatch = regexp(descLower, '×(\d+)', 'tokens');
                if ~isempty(multMatch)
                    multiplier = str2double(multMatch{1}{1});
                end
            end
            
            % 剥离百分号和汉字，只保留纯数值
            for lvl = 1:min(15, length(mvStr))
                str = mvStr{lvl};
                numStr = regexp(str, '[\d.]+', 'match', 'once');
                mvNum(lvl) = str2double(numStr) / 100;   % 转为小数
            end
            
            % 展开成 Level1~Level15 列
            rowData = table({skillName}, {param.Desc}, {scaling}, multiplier, ...
                mvNum(1), mvNum(2), mvNum(3), mvNum(4), mvNum(5), ...
                mvNum(6), mvNum(7), mvNum(8), mvNum(9), mvNum(10), ...
                mvNum(11), mvNum(12), mvNum(13), mvNum(14), mvNum(15), ...
                'VariableNames', {'Skill','Param','ScalingType','Multiplier', ...
                'Level1','Level2','Level3','Level4','Level5','Level6','Level7', ...
                'Level8','Level9','Level10','Level11','Level12','Level13','Level14','Level15'});
            rows = [rows; rowData];
        end
    end
    
    % ================== 保存并返回 ==================
    talentTable = rows;
    writetable(talentTable, '../data/talents_Furina.csv');
    
    fprintf('✅ 天赋倍率提取完成！（Ver %s）共 %d 条，已保存\n', version, height(talentTable));
    disp(talentTable(:, [1 2 3 4 5 6 7 8 9 10 11 12]));   % 预览 Skill / Param / ScalingType
end
