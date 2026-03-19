function dps = simulateDPS(charBuild, enemy, rotation)
    % rotation: table [Hits, TalentType, MV, Element, Reaction]
    totalDMG = 0; time = 0;
    for i = 1:height(rotation)
        dmg = calcDamage(charBuild, rotation.MV(i), rotation.Element(i), enemy, true);  % 期望
        if rotation.Reaction(i) == "Vaporize"
            dmg = dmg * calcAmplifyingMult(charBuild.EM, 0, true);
        end
        totalDMG = totalDMG + dmg * rotation.Hits(i);
        time = time + rotation.Time(i);
    end
    dps = totalDMG / time;
end