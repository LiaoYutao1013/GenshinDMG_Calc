function dmg = calcReactionDamage(baseDamage, em, enemy, resShred, bonusMultiplier, critRate, critDMG)
    % 统一计算独立反应伤害。
    %
    % 该函数用于剧变、绽放及项目内自定义月系反应等独立伤害：
    % 1. 吃反应基础值；
    % 2. 吃精通乘区；
    % 3. 吃反应增伤；
    % 4. 吃抗性区；
    % 5. 不吃防御乘区；
    % 6. 若上层显式传入暴击信息，则额外乘期望暴击乘区。
    if nargin < 2 || isempty(em)
        em = 0;
    end
    if nargin < 3 || isempty(enemy)
        enemy = struct('Res', 0.10);
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

    em = max(0, em);
    emMultiplier = 1 + 16 * em / (em + 2000);
    dmg = baseDamage * emMultiplier * bonusMultiplier * localCalcReactionResMultiplier(enemy, resShred);

    if ~isempty(critRate) && ~isempty(critDMG)
        dmg = dmg * calcExpectedCritMultiplier(critRate, critDMG);
    end
end

function resMult = localCalcReactionResMultiplier(enemy, resShred)
    enemyRes = getFieldOrDefault(enemy, 'Res', 0.10) - resShred;
    if enemyRes < 0
        resMult = 1 - enemyRes / 2;
    elseif enemyRes < 0.75
        resMult = 1 - enemyRes;
    else
        resMult = 1 / (1 + 4 * enemyRes);
    end
end
