function dmg = calcReactionDamage(baseDamage, em, enemy, resShred, bonusMultiplier, critRate, critDMG)
    % Simplified reaction helper shared by Bloom/Lunar-like simulators.
    % The project intentionally keeps reaction modeling lightweight, so the
    % same enemy multiplier helper is reused here for consistency.
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

    emMultiplier = 1 + 16 * em / (em + 2000);
    dmg = baseDamage * emMultiplier * bonusMultiplier * calcDamageMultiplier(90, enemy, resShred);

    if ~isempty(critRate) && ~isempty(critDMG)
        dmg = dmg * calcExpectedCritMultiplier(critRate, critDMG);
    end
end
