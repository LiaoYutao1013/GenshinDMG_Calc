projectRoot = 'c:/Users/ASUS/MATLAB/Projects/GenshinDMG_Calc';
addpath(genpath(projectRoot));
chars = {'Kaveh','Wanderer','ShikanoinHeizou','KamisatoAyato','Hutao','Xiangling','Nahida','Alhaitham','Kaeya','Jean','Diluc','Gaming','Tighnari','Venti'};
for i = 1:numel(chars)
    c = chars{i};
    fprintf('### %s\n', c);
    attacks = loadLunarisAttackMetadata(c);
    if isempty(attacks)
        fprintf('  <no metadata>\n');
        continue;
    end
    for j = 1:min(numel(attacks), 24)
        fprintf('%2d | %-32s | %-48s | %4.2fU | %-18s | %-20s | %s\n', j, char(attacks(j).Name), char(attacks(j).DamageParam), attacks(j).GaugeUnits, char(attacks(j).ICDRule), char(attacks(j).ICDSource), char(attacks(j).Element));
    end
end
