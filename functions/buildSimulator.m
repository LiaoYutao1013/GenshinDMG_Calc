function dps = simulateDPS(charName, build, enemy, rotation)
    % build: struct(ATK, CritRate, CritDMG, DMGBonus, ResShred, ScalingType...)
    % rotation: table(Hits, TalentMV, Time)
    
    charBase = loadCharacter(charName);
    build.Level = charBase.Level;
    build.ScalingType = charBase.ScalingType;
    build.ATK = calcATK(charBase.BaseATK, build.WeaponATK, build.AtkBonus, build.FlatATK);
    
    totalDMG = 0;
    totalTime = 0;
    
    for i = 1:height(rotation)
        dmg = calcDamage(build, rotation.TalentMV(i), enemy, true);  % 期望暴击
        totalDMG = totalDMG + dmg * rotation.Hits(i);
        totalTime = totalTime + rotation.Time(i);
    end
    
    dps = totalDMG / totalTime;
    fprintf('%s DPS = %.0f (总伤害 %.0f / %.1f秒)\n', charName, dps, totalDMG, totalTime);
end