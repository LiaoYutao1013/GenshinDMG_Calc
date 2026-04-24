function critMult = calcExpectedCritMultiplier(critRate, critDMG)
    critMult = 1 + min(max(critRate, 0), 1) * max(critDMG, 0);
end
