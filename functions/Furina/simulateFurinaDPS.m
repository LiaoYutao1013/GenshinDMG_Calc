function [totalDMG, dps, breakdown] = simulateFurinaDPS(build, enemy, rotationFile, talentLevel, constellation)
    % 最還原實戰版芙寧娜模擬 - 重擊切換形態 + 三海鮮獨立傷害 + 芒性普攻強化
    
    if nargin < 4, talentLevel = 10; end
    if nargin < 5, constellation = 0; end
    
    talent = readtable('data/talents_Furina_VerL.csv');
    rotRaw = readtable(rotationFile, 'ReadVariableNames', false, 'Delimiter', '\t');
    
    rot = table();
    rot.Action = string(rotRaw{:,1});
    rot.Hits   = str2double(rotRaw{:,2});
    rot.Time   = str2double(rotRaw{:,3});
    rot.Note   = string(rotRaw{:,4});
    
    % 基礎數據
    charData = readtable('data/characters_Furina.csv');
    build.MaxHP = charData.BaseHP * (1 + build.HPBonus) + 5000;
    
    % ================== 狀態追蹤 ==================
    totalDMG = 0;
    time = 0;
    atmosphere = 0;
    atmosphereCap = 300 + 100*(constellation >= 1);
    currentState = 'Ousia';           % 預設荒性
    salonEndTime = 0;
    spotlightEndTime = 0;             % C6 萬眾瞩目
    
    breakdown = table('Size',[0 5],'VariableTypes',{'string','double','double','string','string'}, ...
        'VariableNames',{'Action','Damage','Time','Note','State'});
    
    % ================== 主循環 ==================
    for i = 1:height(rot)
        action = rot.Action(i);
        hits = rot.Hits(i);
        t = rot.Time(i);
        
        dmgThis = 0;
        
        % ================== 重擊切換形態 ==================
        if contains(action, {'Heavy','重击'})
            currentState = 'Pneuma';   % 重擊切芒性
            % 重擊本身傷害
            row = talent(strcmp(talent.Param,'重击伤害'),:);
            dmgThis = row.(['Level' num2str(talentLevel)]) * build.MaxHP;
        end
        
        % ================== 技能傷害 ==================
        switch action
            case {'E','孤心沙龙'}
                % 荒性泡沫主傷害
                row = talent(strcmp(talent.Param,'荒性泡沫伤害'),:);
                dmgThis = row.(['Level' num2str(talentLevel)]) * build.MaxHP;
                salonEndTime = time + 30;
                
            case {'Q','万众狂欢'}
                row = talent(strcmp(talent.Param,'技能伤害'),:);
                dmgThis = row.(['Level' num2str(talentLevel)]) * build.MaxHP;
                spotlightEndTime = time + 18;
                
            case {'Normal','普攻'}
                if strcmp(currentState, 'Ousia')
                    % ================== 荒性：三只海鮮各自計算 ==================
                    usher = getSummonDmg(talent, 'Usher', talentLevel, build.MaxHP);      % 球球章魚
                    cheval = getSummonDmg(talent, 'Chevalmarin', talentLevel, build.MaxHP); % 泡泡海馬
                    crab = getSummonDmg(talent, 'Crabaletta', talentLevel, build.MaxHP);   % 重甲蟹
                    dmgThis = usher + cheval + crab;
                else
                    % ================== 芒性：普攻強化（C6） ==================
                    row = talent(strcmp(talent.Param,'一段伤害'),:);
                    dmgThis = row.(['Level' num2str(talentLevel)]) * build.MaxHP;
                    
                    if constellation >= 6 && time <= spotlightEndTime
                        dmgThis = dmgThis * (1 + 0.18 * build.MaxHP/1000 + 0.25);  % C6 額外強化
                    end
                end
        end
        
        % ================== 乘區 ==================
        dmgThis = dmgThis ...
            * (1 + build.HydroDMGBonus) ...
            * (1 + atmosphere * 0.001) ...
            * calcCrit(build) ...
            * calcDefRes(enemy);
        
        totalDMG = totalDMG + dmgThis * hits;
        time = time + t;
        
        breakdown = [breakdown; {action, dmgThis*hits, t, rot.Note(i), currentState}];
    end
    
    dps = totalDMG / time;
    
    fprintf('芙寧娜最還原模擬完成 | 天賦%d | C%d | DPS: %.0f | 總傷害: %.0f (%.1f秒)\n', ...
        talentLevel, constellation, dps, totalDMG, time);
    disp(breakdown);
end

% ====================== 三海鮮各自傷害計算 ======================
function dmg = getSummonDmg(talent, summonType, lvl, maxHP)
    row = talent(strcmp(talent.SubType, summonType), :);
    if isempty(row), dmg = 0; return; end
    base = row.(['Level' num2str(lvl)]) * maxHP;
    
    switch summonType
        case 'Usher'      % 烏瑟勳爵（球球章魚）
            dmg = base * 9.375;   % 30秒內約9.375次攻擊（3.2s/次）
        case 'Chevalmarin' % 海薇瑪夫人（泡泡海馬）
            dmg = base * 20;      % 30秒內20次（1.5s/次）
        case 'Crabaletta' % 謝貝蕾妲小姐（重甲蟹）
            dmg = base * 5.88;    % 30秒內5.88次（5.1s/次）
    end
end

function c = calcCrit(b)
    c = 1 + min(b.CritRate,1) * b.CritDMG;
end

function d = calcDefRes(~)
    d = 0.5;
end