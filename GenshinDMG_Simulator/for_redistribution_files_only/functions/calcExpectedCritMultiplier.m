function critMult = calcExpectedCritMultiplier(critRate, critDMG)
    % 计算期望暴击乘区。
    % 工程内大部分模拟器都按“期望伤害”而不是逐次随机暴击建模，
    % 因此统一采用：基础伤害 * (1 + 暴击率 * 暴击伤害)。
    % 同时对输入做基础裁剪，避免非法输入造成异常放大。
    critMult = 1 + min(max(critRate, 0), 1) * max(critDMG, 0);
end
