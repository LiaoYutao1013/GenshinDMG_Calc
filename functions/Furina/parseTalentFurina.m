function talentTable = parseTalentFurina(skillFile, charName, version)
    % parseTalentJS - 芙寧娜特化版：保留所有 ParamDesc（含非傷害字段）
    % 輸出 CSV 包含所有等級列 + SubType（召喚物分類） + IsDamage（是否傷害相關）
    
    if nargin < 3
        version = 'L';
    end
    
    txt = fileread(skillFile);
    txt = strtrim(txt);
    txt = regexprep(txt, '^var\s+.*?\=\s*', '');
    txt = regexprep(txt, ';$', '');
    
    data = jsondecode(txt);
    
    if ~isfield(data, charName) || ~isfield(data.(charName).Ver, version)
        error('找不到 %s Ver%s', charName, version);
    end
    
    skills = data.(charName).Ver.(version).BattleSkills;
    rows = table();
    
    for si = 1:numel(skills)
        skill = skills(si);
        skillName = skill.Name;
        
        for pi = 1:numel(skill.ParamDesc)
            param = skill.ParamDesc(pi);
            desc = param.Desc;
            levelList = param.ParamLevelList;
            
            % 判斷縮放類型
            scalingType = 'None';  % 預設
            if contains(desc, {'生命值上限','Max HP','HP上限'})
                scalingType = 'MaxHP';
            elseif contains(desc, {'攻擊力','ATK'})
                scalingType = 'ATK';
            elseif contains(desc, {'防御力','DEF'})
                scalingType = 'DEF';
            elseif contains(desc, {'精通','EM'})
                scalingType = 'EM';
            end
            
            % 提取 ×N
            multiplier = 1;
            multMatch = regexp(desc, '[×x](\d+)', 'tokens');
            if ~isempty(multMatch) && ~isempty(multMatch{1})
                multiplier = str2double(multMatch{1}{1});
            end
            
            % ------------------ 芙寧娜特化：召喚物分類 ------------------
            subType = '';
            if contains(skillName, {'孤心沙龙','Salon Members','孤心沙龍'})
                if contains(desc, {'烏瑟勳爵','Usher','球球章魚'})
                    subType = 'Usher';
                elseif contains(desc, {'海薇瑪夫人','Chevalmarin','泡泡海馬'})
                    subType = 'Chevalmarin';
                elseif contains(desc, {'謝貝蕾妲小姐','Crabaletta','重甲蟹'})
                    subType = 'Crabaletta';
                elseif contains(desc, {'眾水的歌者','Singer','歌者'})
                    subType = 'Singer';
                elseif contains(desc, {'泡沫','Foam','荒性泡沫'})
                    subType = 'Foam';
                elseif contains(desc, {'治療','回復','治療量'})
                    subType = 'Healing';
                end
            end
            
            % 判斷是否為傷害/治療相關（用於後續過濾）
            isDamage = contains(desc, {'伤害','傷害','治疗','治療','回復','恢复','回復量'}) || ...
                       ~isempty(subType) && ~strcmp(subType, '');
            
            % 解析每一級數值（如果有數字）
            values = nan(1,15);
            for li = 1:min(15, numel(levelList))
                str = levelList{li};
                numMatch = regexp(str, '[\d\.]+', 'match', 'once');
                if ~isempty(numMatch)
                    values(li) = str2double(numMatch) / 100;  % 轉小數
                else
                    % 非純數字的保留原始字串（例如 "20秒"）
                    values(li) = NaN;
                end
            end
            
            % 建立一行（所有字段都保留）
            rowStruct = struct(...
                'Skill', skillName, ...
                'Param', desc, ...
                'ScalingType', scalingType, ...
                'Multiplier', multiplier, ...
                'SubType', subType, ...
                'IsDamage', isDamage, ...           % 是否傷害/治療相關
                'Level1', values(1), ...
                'Level2', values(2), ...
                'Level3', values(3), ...
                'Level4', values(4), ...
                'Level5', values(5), ...
                'Level6', values(6), ...
                'Level7', values(7), ...
                'Level8', values(8), ...
                'Level9', values(9), ...
                'Level10', values(10), ...
                'Level11', values(11), ...
                'Level12', values(12), ...
                'Level13', values(13), ...
                'Level14', values(14), ...
                'Level15', values(15), ...
                'RawLevel1', levelList{min(1,numel(levelList))}, ...   % 原始字串備份
                'RawLevel10', levelList{min(10,numel(levelList))}, ...
                'RawLevel15', levelList{min(15,numel(levelList))} ...
            );
            newRow = struct2table(rowStruct, 'AsArray', true);  % ← 關鍵：加上 'AsArray', true
            rows = [rows; newRow];
        end
    end
    
    outputFile = sprintf('../../data/Furina/talents_%s_Ver%s.csv', charName, version);
    writetable(rows, outputFile);
    
    fprintf('芙寧娜天賦解析完成（Ver %s）：共 %d 行（包含所有參數），已保存至 %s\n', ...
        version, height(rows), outputFile);
    
    % 預覽所有行（特別標注召喚物與非傷害行）
    fprintf('\n預覽（前10行 + 召喚物相關行）:\n');
    disp(rows(1:min(10,height(rows)), {'Skill','Param','SubType','IsDamage','ScalingType','Level10'}));
    
    summonRows = rows(~cellfun(@isempty, rows.SubType), :);
    if ~isempty(summonRows)
        fprintf('\n召喚物相關行：\n');
        disp(summonRows(:, {'Skill','Param','SubType','ScalingType','Level10'}));
    end
    
    talentTable = rows;
end