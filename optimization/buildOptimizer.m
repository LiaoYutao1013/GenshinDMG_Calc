function optimizedBuild = buildOptimizer(charName, enemy, rotation)
    % 优化目标：最大DPS（变量x = [CritRate, CritDMG, AtkBonus]）
    fun = @(x) -simulateDPS_optim(x, charName, enemy, rotation);  % 负号求最大
    x0 = [0.6; 1.5; 0.4];
    lb = [0; 0.5; 0]; ub = [1; 3; 1];
    options = optimoptions('fmincon','Display','iter');
    xOpt = fmincon(fun, x0, [], [], [], [], lb, ub, [], options);
    
    optimizedBuild.CritRate = xOpt(1);
    optimizedBuild.CritDMG = xOpt(2);
    optimizedBuild.AtkBonus = xOpt(3);
    fprintf('优化完成！最优暴击率 %.1f%%，爆伤 %.1f%%\n', xOpt(1)*100, xOpt(2)*100);
end

function dps = simulateDPS_optim(x, charName, enemy, rotation)
    tempBuild = build;  % 使用全局build作为模板
    tempBuild.CritRate = x(1);
    tempBuild.CritDMG = x(2);
    tempBuild.AtkBonus = x(3);
    dps = simulateDPS(charName, tempBuild, enemy, rotation);
end