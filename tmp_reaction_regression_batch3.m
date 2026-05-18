projectRoot = 'c:/Users/ASUS/MATLAB/Projects/GenshinDMG_Calc';
addpath(genpath(projectRoot));
enemy = struct('Level',93,'Res',0.10,'DefReduct',0,'DefIgnore',0,'EnableElementalAura',true,'AutoSupportAura',true);
chars = {'Barbara','Gaming','Kaeya','Nahida','Freminet','Jean','Xiangling','Kaveh','Alhaitham','Wanderer','ShikanoinHeizou','KamisatoAyato','Hutao','Diluc','Tighnari','Venti','Wriothesley'};
for i = 1:numel(chars)
    name = chars{i};
    cfg = getDefaultCharacterConfig(name);
    teamContext = buildTeamContext({cfg}, 20, struct(), enemy);
    result = simulateCharacterDPS(cfg, enemy, teamContext);
    fprintf('%s\t%.2f\t%.2f\t%.2f\n', name, result.TotalDMG, result.DPS, result.RotationTime);
end
