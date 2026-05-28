function optimizedBuild = buildOptimizer(charName, enemy, rotation)
    % 旧版构筑优化入口。
    % 当前实现假设外部存在通用 simulateDPS 与模板 build 变量，
    % 更接近早期原型验证脚本，而不是现在的统一角色入口体系。
    % 因此此文件的主要维护价值在于记录最初的优化思路。

    % 目标函数取 DPS 相反数，交给 fmincon 做最大化搜索。
    fun = @(x) -simulateDPS_optim(x, charName, enemy, rotation);

    % 变量向量定义：
    % x(1) = CritRate，x(2) = CritDMG，x(3) = AtkBonus。
    x0 = [0.6; 1.5; 0.4];
    lb = [0; 0.5; 0];
    ub = [1; 3; 1];

    % 使用 MATLAB 自带约束优化器迭代搜索最优解。
    options = optimoptions('fmincon', 'Display', 'iter');
    xOpt = fmincon(fun, x0, [], [], [], [], lb, ub, [], options);

    % 将优化结果重新组织回构筑字段。
    optimizedBuild.CritRate = xOpt(1);
    optimizedBuild.CritDMG = xOpt(2);
    optimizedBuild.AtkBonus = xOpt(3);

    fprintf('优化完成：暴击率 %.1f%%，暴击伤害 %.1f%%，攻击加成 %.1f%%\n', ...
        xOpt(1) * 100, xOpt(2) * 100, xOpt(3) * 100);
end

function dps = simulateDPS_optim(x, charName, enemy, rotation)
    % 优化器内部包装函数。
    % 这里假设工作区中存在名为 build 的模板结构，并只替换参与搜索
    % 的三个字段。若未来需要接入统一入口，应将这里改造成显式传参。
    tempBuild = build; %#ok<NASGU>
    tempBuild.CritRate = x(1);
    tempBuild.CritDMG = x(2);
    tempBuild.AtkBonus = x(3);
    dps = simulateDPS(charName, tempBuild, enemy, rotation);
end
