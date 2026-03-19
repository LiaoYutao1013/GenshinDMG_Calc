atkRange = 1500:50:3500;
dpsList = zeros(size(atkRange));
for i = 1:length(atkRange)
    tempBuild = build; tempBuild.ATK = atkRange(i);
    dpsList(i) = simulateDPS('SampleATKChar', tempBuild, enemy, rotation);
end
plot(atkRange, dpsList); xlabel('攻击力'); ylabel('DPS'); grid on;
title('攻击力对DPS的影响');
saveas(gcf, 'output/reports/atk_sensitivity.png');