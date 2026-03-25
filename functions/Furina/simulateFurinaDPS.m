function [totalDMG, dps, breakdown] = simulateFurinaDPS(build, enemy, seqFile, talentLevel, constellation)
% simulateFurinaDPS - 芙寧娜傷害模擬器（基於 artifacts_Furina.csv 字段）
% build 來自 artifacts_Furina.csv 的結構


seqFile = '../data/Furina/rotation_Furina.txt';

% ====================== 載入天賦數據 ======================
talent = readtable('../data/Furina/talents_Furina_VerL.csv');

% ====================== 技能映射表 ======================
mapping = struct(...
    'N1',     struct('Skill','独舞之邀','Param','一段伤害'), ...
    'N2',     struct('Skill','独舞之邀','Param','二段伤害'), ...
    'N3',     struct('Skill','独舞之邀','Param','三段伤害'), ...
    'N4',     struct('Skill','独舞之邀','Param','四段伤害'), ...
    'Heavy',  struct('Skill','独舞之邀','Param','重击伤害'), ...
    'SwitchAr', struct('Skill','独舞之邀','Param','重击伤害','Mode','荒性'), ...
    'SwitchMa', struct('Skill','独舞之邀','Param','重击伤害','Mode','芒性'), ...
    'E',      struct('Skill','孤心沙龙','Param','荒性泡沫伤害'), ...
    'Usher',  struct('Skill','孤心沙龙','Param','乌瑟勋爵伤害','IsPeriodic',true,'TickInterval',6), ...
    'Chev',   struct('Skill','孤心沙龙','Param','海薇玛夫人伤害','IsPeriodic',true,'TickInterval',6), ...
    'Crab',   struct('Skill','孤心沙龙','Param','谢贝蕾妲小姐伤害','IsPeriodic',true,'TickInterval',6), ...
    'Singer', struct('Skill','孤心沙龙','Param','众水的歌者治疗量','IsPeriodic',true,'TickInterval',6), ...
    'Q',      struct('Skill','万众狂欢','Param','技能伤害'), ...
    'Thorn',  struct('Skill','独舞之邀','Param','灵息之刺/流涌之刃伤害','IsPeriodic',true,'TickInterval',6), ...
    'Plunge', struct('Skill','独舞之邀','Param','低空/高空坠地冲击伤害') ...
);

% ====================== 讀取自定義排軸 ======================
actions = readFurinaSequence(seqFile);

% ====================== 計算最終屬性 ======================
MaxHP =  ...           % 芙寧娜為生命值主C，這裡簡化
        (build.HPBonus * 10000 + 15000);    % 假設基礎 + 聖遺物加成，實際請替換為正確基礎生命

if isfield(build, 'FlatHP')
    MaxHP = MaxHP + build.FlatHP;
end

CritMult = 1 + build.CritRate * build.CritDMG;
HydroMult = 1 + build.HydroDMGBonus;

% ====================== 初始化 ======================
totalDMG = 0;
breakdown = table('Size',[0 3], 'VariableTypes',{'string','double','string'}, ...
                  'VariableNames',{'Action','Damage','Note'});

currentMode = '荒性';      % 預設荒性輸出
atmosphere = 0;            % 氛圍值

fprintf('芙寧娜模擬開始 | 天賦%d | C%d | 模式：%s | MaxHP ≈ %.0f\n', ...
    talentLevel, constellation, currentMode, MaxHP);

% ====================== 主模擬循環 ======================
for i = 1:length(actions)
    actKey = actions{i};
    
    if ~isfield(mapping, actKey)
        warning('未知動作：%s', actKey);
        continue;
    end
    
    info = mapping.(actKey);
    
    % 取得倍率
    rowIdx = strcmp(talent.Skill, info.Skill) & strcmp(talent.Param, info.Param);
    if ~any(rowIdx)
        continue;
    end
    row = talent(rowIdx,:);
    
    mv = row.(['Level' num2str(talentLevel)]) * MaxHP;
    
    % 基礎傷害
    dmg = mv * HydroMult * CritMult * ...
          (1 + build.ResShred) * 0.9;   % 簡化防禦與抗性乘區
    
    note = '';
    
    % ==================== 芙寧娜專屬機制 ====================
    if strcmp(actKey, 'Usher') || strcmp(actKey, 'Chev') || strcmp(actKey, 'Crab')
        if strcmp(currentMode, '荒性')
            teamMult = build.TeamHPAbove50Mult;     % 直接使用 csv 中的字段
            dmg = dmg * teamMult;
            note = sprintf('沙龍成員 x%.2f', teamMult);
        else
            dmg = 0;
        end
        
    elseif strcmp(actKey, 'Singer')
        if strcmp(currentMode, '芒性')
            note = '歌者治療（不計入傷害）';
            dmg = 0;
        else
            dmg = 0;
        end
        
    elseif strcmp(actKey, 'Q')
        atmosphere = 300;                       % 可根據命座調整
        note = '萬眾狂歡 + 氛圍值堆疊';
        
    elseif strcmp(actKey, 'SwitchAr')
        currentMode = '荒性';
        note = '切換 → 荒性';
    elseif strcmp(actKey, 'SwitchMa')
        currentMode = '芒性';
        note = '切換 → 芒性';
    end
    
    % 命座簡單加成
    if constellation >= 2
        dmg = dmg * 1.25;
    end
    if constellation >= 6
        dmg = dmg * 1.18;
    end
    
    if dmg > 0
        totalDMG = totalDMG + dmg;
        breakdown = [breakdown; {actKey, dmg, note}];
    end
end

dps = totalDMG / 20;   % 假設20秒循環

fprintf('\n=== 芙寧娜傷害結果 ===\n');
fprintf('總傷害: %.0f\n', totalDMG);
fprintf('DPS:    %.0f\n', dps);
disp(breakdown);

end


% ====================== 輔助函數 ======================
function actions = readFurinaSequence(seqFile)
    fid = fopen(seqFile, 'r');
    if fid == -1
        error('無法打開排軸檔案：%s', seqFile);
    end
    actions = {};
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line), continue; end
        line = strtrim(line);
        if isempty(line) || startsWith(line, '#')
            continue;
        end
        [token, ~] = sscanf(line, '%s', 1);
        if ~isempty(token)
            actions{end+1} = token;
        end
    end
    fclose(fid);
    fprintf('讀取排軸成功：%d 個動作\n', length(actions));
end