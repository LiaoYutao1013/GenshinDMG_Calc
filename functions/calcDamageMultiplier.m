function totalMult = calcDamageMultiplier(characterLevel, enemy, resShred)
    % Combine defense and resistance handling into one final multiplier so
    % character simulators only need to care about talent-side mechanics.
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

    % Standard defense term with optional enemy DEF reduction / ignore.
    effectiveEnemyDef = (enemyLevel + 100) * max(0, 1 - defReduct) * max(0, 1 - defIgnore);
    defMult = (characterLevel + 100) / ((characterLevel + 100) + effectiveEnemyDef);

    % Resistance uses different formulas below zero, in the normal range,
    % and above 75%, so handle the three regions explicitly.
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
