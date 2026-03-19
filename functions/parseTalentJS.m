function talentTable = parseTalentJS(skillFile, charName, version)
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
        for p = 1:length(skills{s}.ParamDesc)
            param = skills{s}.ParamDesc(p);
            mvStr = param.ParamLevelList;                    % cellstr 或 string
            mvNum = cellfun(@(x) str2double(regexp(x,'[\d.]+','match','once')), mvStr, 'UniformOutput',false);
            
            % 自动判断缩放类型（用于后续伤害计算）
            if contains(param.Desc, '生命值上限')
                scaling = 'MaxHP';
            elseif contains(param.Desc, '攻击力')
                scaling = 'ATK';
            elseif contains(param.Desc, '防御力')
                scaling = 'DEF';
            else
                scaling = 'ATK';   % 默认
            end
            
            row = table(string(skills{s}.Name), {param.Desc},{mvStr},{mvNum},{scaling} ,{version}...
                'VariableNames', {'Skill','Param','Multiplier1', 'Multiplier2', 'Multiplier3', 'Multiplier4','Multiplier5','Multiplier6','Multiplier7','Multiplier8','Multiplier9','Multiplier10','Multiplier11','Multiplier12','Multiplier13','Multiplier14','Multiplier15'});
            rows = [rows; row];
        end
    end
    
    % ================== 保存并返回 ==================
    talentTable = rows;
    writetable(talentTable, '../data/talents_Columbina.csv');
    
    fprintf('✅ 天赋倍率提取完成！（Ver %s）共 %d 条，已保存\n', version, height(talentTable));
    disp(talentTable(:, [1 2 3 4 5 6 7 8 9 10 11 12]));   % 预览 Skill / Param / ScalingType
end