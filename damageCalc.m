function dmg = calcBaseDamage(talentPct, scalingStat, baseDMGMult)
    dmg = talentPct * scalingStat * baseDMGMult;
end

function atk = calcATK(baseATK, weaponATK, atkBonusPct, flatATK)
    atk = (baseATK + weaponATK) * (1 + atkBonusPct) + flatATK;
end

function defMult = calcDefMult(charLvl, enemyLvl, defReduct, defIgnore)
    k = (1 - defReduct) * (1 - defIgnore);
    defMult = (charLvl + 100) / ((charLvl + 100) + (enemyLvl + 100) * k);
end

function resMult = calcResMult(res)
    if res < 0
        resMult = 1 - res/2;
    elseif res < 0.75
        resMult = 1 - res;
    else
        resMult = 1 / (4*res + 1);
    end
end

function critMult = calcCritMult(critRate, critDMG)  % 期望值
    critMult = 1 + min(max(critRate,0),1) * critDMG;
end

function ampMult = calcAmplifyingMult(EM, reactionBonus, isVaporizeHydro)  % 示例蒸发
    reactMult = isVaporizeHydro ? 2 : 1.5;
    emBonus = 2.78 * EM / (1400 + EM);
    ampMult = reactMult * (1 + emBonus + reactionBonus);
end

function finalDMG = calcDamage(charBuild, talentMV, element, enemy, isCritExpected)
    % charBuild：struct包含ATK, DEF, HP, EM, CritRate, CritDMG, DMGBonus等
    base = calcBaseDamage(talentMV, charBuild.ATK, 1);  % 假设攻击力缩放
    dmgBonus = 1 + charBuild.DMGBonus;  % 元素/普攻/造成伤害加成
    defM = calcDefMult(charBuild.Level, enemy.Level, enemy.DefReduct, 0);
    resM = calcResMult(enemy.Res - charBuild.ResShred);
    critM = isCritExpected ? calcCritMult(charBuild.CritRate, charBuild.CritDMG) : 1;  % 单次用随机
    ampM = 1;  % 若有反应则调用calcAmplifyingMult
    finalDMG = base * dmgBonus * critM * defM * resM * ampM;
end