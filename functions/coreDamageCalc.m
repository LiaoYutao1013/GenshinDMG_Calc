function coreDamageCalc
    % 这个文件不直接运行，仅提供函数（MATLAB会自动识别）
end

function baseDMG = calcBaseDamage(talentPct, scalingStat)
    baseDMG = talentPct * scalingStat;
end

function atk = calcATK(baseATK, weaponATK, atkBonus, flatATK)
    atk = (baseATK + weaponATK) * (1 + atkBonus) + flatATK;
end

function defMult = calcDefMult(charLvl, enemyLvl, defReduct, defIgnore)
    k = (1 - defReduct) * (1 - defIgnore);
    defMult = (charLvl + 100) / ((charLvl + 100) + (enemyLvl + 100) * k);
end

function resMult = calcResMult(res)
    if res < 0
        resMult = 1 - res / 2;
    elseif res < 0.75
        resMult = 1 - res;
    else
        resMult = 1 / (4 * res + 1);
    end
end

function critMult = calcCritMult(critRate, critDMG)
    critMult = 1 + min(max(critRate, 0), 1) * critDMG;
end

function finalDMG = calcDamage(charBuild, talentMV, enemy, isCritExpected)
    % charBuild 是struct，包含当前build的所有属性
    if strcmp(charBuild.ScalingType, 'MaxHP')
        scalingStat = charBuild.MaxHP;   % charBuild.MaxHP = BaseHP*(1+HPBonus) + FlatHP
    else
        scalingStat = charBuild.ATK;  % 未来支持HP/DEF等
    end
    
    base = calcBaseDamage(talentMV, scalingStat);
    dmgBonus = 1 + charBuild.DMGBonus;
    defM = calcDefMult(charBuild.Level, enemy.Level, enemy.DefReduct, 0);
    resM = calcResMult(enemy.Res - charBuild.ResShred);
    critM = isCritExpected ? calcCritMult(charBuild.CritRate, charBuild.CritDMG) : 1;
    
    finalDMG = base * dmgBonus * critM * defM * resM;
end