function critMult = calcExpectedCritMultiplier(critRate, critDMG)
    % Expected-value crit multiplier used by all simulators:
    % baseDamage * (1 + critRate * critDMG).
    critMult = 1 + min(max(critRate, 0), 1) * max(critDMG, 0);
end
