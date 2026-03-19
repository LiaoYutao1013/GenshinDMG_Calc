nSim = 10000;
dmgList = zeros(nSim,1);
base = 50000;  % 示例基础伤害
for i = 1:nSim
    isCrit = rand < build.CritRate;
    critM = isCrit * build.CritDMG + 1;
    dmgList(i) = base * critM;
end
histogram(dmgList, 50); xlabel('单次伤害'); title('暴击蒙特卡洛分布');