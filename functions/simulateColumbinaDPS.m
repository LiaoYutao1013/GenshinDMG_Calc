function [totalDMG, dps] = simulateColumbinaDPS(build, enemy)
    build.MaxHP = 14695 * (1 + build.HPBonus) + build.HPBonus;   % 来自解析文件

    base = readtable('data/characters_Columbina.csv');
    talent = readtable('data/talents_Columbina.csv');
    rot = readtable('data/rotation_Columbina.csv');
    
    build.MaxHP = base.BaseHP * (1 + build.HPBonus) + 5000;
    totalDMG = 0; time = 0;
    gravity = 0;   % 引力值模拟
    
    for i = 1:height(rot)
        % 精确匹配天赋倍率（支持多级）
        mvRow = talent(strcmp(talent.Skill, rot.Action{i}), :);
        mv = mvRow.MV_List(1) * build.MaxHP;   % 第1级示例，可改 min(10, level)
        dmg = mv * (1 + build.DMGBonus) ...
            * calcCrit(build) ...
            * calcDefRes(enemy) ...
            * (1 + build.PromoteBonus);   % 擢升独立乘区
        
        % 月曜反应 & 引力值
        if contains(rot.Reaction{i}, 'Bloom')
            dmg = dmg * 3.0 * (1 + 2.78*build.EM/(1400+build.EM));
            gravity = gravity + 20;
        elseif contains(rot.Reaction{i}, 'Interfere')
                dmg = dmg * 4.5;  % 矩波干涉
        end
        
        if gravity >= 60
            dmg = dmg * 2.8; gravity = 0;  % 满引力爆炸
            fprintf('【矩波干涉！】+%.0f伤害\n', dmg*0.8);
        end
        
        totalDMG = totalDMG + dmg * rot.Hits(i);
        time = time + rot.Time(i);
    end
    
    dps = totalDMG / time;
    fprintf('🎯 精确DPS报告 → 总伤害 %.0f | DPS %.0f（%.1f秒）\n', totalDMG, dps, time);
end

function c = calcCrit(b), c = 1 + min(b.CritRate,1)*b.CritDMG; end
function d = calcDefRes(~), d = 0.5; end   % 可替换为之前coreDamageCalc