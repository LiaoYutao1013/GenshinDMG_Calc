function dmg = calcReactionDamage(baseDamage, em, enemy, resShred, bonusMultiplier, critRate, critDMG)
    % 统一的反应伤害辅助函数。
    % 当前工程对绽放、月绽放、月感电、月结晶等反应采取轻量建模：
    % 基础反应伤害 * 精通乘区 * 额外反应增益 * 敌方乘区。
    % 如某些反应被设计为可暴击，则额外再乘期望暴击乘区。
    if nargin < 2 || isempty(em)
        em = 0;
    end
    if nargin < 3 || isempty(enemy)
        enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
    end
    if nargin < 4 || isempty(resShred)
        resShred = 0;
    end
    if nargin < 5 || isempty(bonusMultiplier)
        bonusMultiplier = 1;
    end
    if nargin < 6
        critRate = [];
    end
    if nargin < 7
        critDMG = [];
    end

    % 采用统一的精通收益近似公式，保证不同反应模拟器口径一致。
    emMultiplier = 1 + 16 * em / (em + 2000);
    dmg = baseDamage * emMultiplier * bonusMultiplier * calcDamageMultiplier(90, enemy, resShred);

    % 只有上层明确传入暴击信息时，才把该反应视为可暴击反应。
    if ~isempty(critRate) && ~isempty(critDMG)
        dmg = dmg * calcExpectedCritMultiplier(critRate, critDMG);
    end
end
