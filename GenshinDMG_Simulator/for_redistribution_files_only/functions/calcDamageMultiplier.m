function totalMult = calcDamageMultiplier(characterLevel, enemy, resShred)
    % 统一计算敌方防御区和抗性区乘区。
    % 角色模拟器只需要提供角色等级、敌方面板和抗性削减量，这里
    % 就会返回一个可直接乘到伤害上的总乘区。
    if nargin < 1 || isempty(characterLevel)
        characterLevel = 90;
    end
    if nargin < 2 || isempty(enemy)
        enemy = struct();
    end
    if nargin < 3 || isempty(resShred)
        resShred = 0;
    end

    enemyLevel = getFieldOrDefault(enemy, 'Level', 90);
    defReduct = getFieldOrDefault(enemy, 'DefReduct', 0);
    defIgnore = getFieldOrDefault(enemy, 'DefIgnore', 0);

    % 防御区：支持敌方减防与防御无视两类修正。
    effectiveEnemyDef = (enemyLevel + 100) * max(0, 1 - defReduct) * max(0, 1 - defIgnore);
    defMult = (characterLevel + 100) / ((characterLevel + 100) + effectiveEnemyDef);

    % 抗性区按三段公式处理：
    % 1. 负抗时收益递增但斜率减半；
    % 2. 常规抗性区间使用 1 - 抗性；
    % 3. 高抗区间使用官方高抗衰减公式。
    enemyRes = getFieldOrDefault(enemy, 'Res', 0.10) - resShred;
    if enemyRes < 0
        resMult = 1 - enemyRes / 2;
    elseif enemyRes < 0.75
        resMult = 1 - enemyRes;
    else
        resMult = 1 / (1 + 4 * enemyRes);
    end

    totalMult = defMult * resMult;
end
