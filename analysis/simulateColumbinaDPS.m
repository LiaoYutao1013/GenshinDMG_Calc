function [totalDMG, dps] = simulateColumbinaDPS(build, enemy, talentLevel,cLevel)
    % talentLevel = 天赋等级 (1~15，默认10)
    % cLevel = 命座等级 (0~6，默认0)
    if nargin < 3, talentLevel = 10; end
    if nargin < 4, cLevel = 0; end

    base = readtable('../data/characters_哥伦比娅.csv');
    talent = readtable('../data/talents_Columbina.csv', 'VariableNamingRule', 'preserve');   % 来自解析文件
    rot = readtable('../data/rotation_Columbina.csv');
    
    build.MaxHP = base.BaseHP * (1 + build.HPBonus) + 5000;
    build.ATK = build.WeaponATK * 1.0 + 300;   % 可改成完整calcATK

    totalDMG = 0; time = 0;gravity = 0;   % 引力值模拟
    
    for i = 1:height(rot)
        % 根据指定天赋等级取值
        lvlCol = ['Level' num2str(talentLevel)];
        mv = talent.(lvlCol)(strcmp(talent.Skill, rot.Action{i})) * build.MaxHP;
        if strcmp(talent.ScalingType{1}, 'MaxHP')
            mv = mv * talent.Multiplier(1);   % 处理 ×3 等
        end
        
        % === 基础乘区 ===
        dmg = mv ...
            * (1 + build.HydroDMGBonus + build.SkillDMGBonus * contains(rot.Action{i},'E') ...
               + build.BurstDMGBonus * contains(rot.Action{i},'Q')) ...
            * (1 + build.ReactionDMGBonus + build.Set4_MoonPromote) ...
            * calcCrit(build) * calcDefRes(enemy) * (1 + build.PromoteBonus);
        
        % === 命座专属乘区（开关控制）===
        if cLevel >= 1
            dmg = dmg * 1.03;                    % C1: 擢升3%
        end
        if cLevel >= 2
            gravity = gravity + 20 * 1.34;       % C2: 引力积攒+34%
            if gravity >= 60
                dmg = dmg * (1 + 0.3);           % C2 皎辉生命加成间接提升
            end
        end
        if cLevel >= 3
            % C3: 战技等级+3 
        end
        if cLevel >= 4
            dmg = dmg * 1.125;                   % C4: 矩波干涉额外提升
        end
        if cLevel >= 6
            dmg = dmg * (1 + 0.80);              % C6: 对应元素暴击伤害+80%
        end
        
        % === 月曜反应 & 引力值 ===
        if contains(rot.Reaction{i}, 'Bloom')
            dmg = dmg * 3.0 * (1 + 2.78*build.EM/(1400+build.EM)) * (1 + build.Set4_GravityBonus);
            gravity = gravity + 20;
        elseif contains(rot.Reaction{i}, 'Interfere')
            dmg = dmg * 4.5 * (1 + build.Set4_InterfereBonus);
        end
        
        if gravity >= 60
            dmg = dmg * 2.8;
            gravity = 0;
        end
        
        totalDMG = totalDMG + dmg * rot.Hits(i);
        time = time + rot.Time(i);
    end
    
    dps = totalDMG / time;
    fprintf('🎯 天赋等级%d | 命座C%d | DPS %.0f（总伤害 %.0f）\n', talentLevel, cLevel, dps, totalDMG);
end

function c = calcCrit(b) , c = 1 + min(b.CritRate,1)*b.CritDMG; end
function d = calcDefRes(~) , d = 0.5; end  