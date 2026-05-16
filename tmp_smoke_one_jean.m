projectRoot = 'c:/Users/ASUS/MATLAB/Projects/GenshinDMG_Calc';
addpath(genpath(projectRoot));
enemy = struct('Level',93,'Res',0.10,'DefReduct',0,'DefIgnore',0);
name = 'Jean';
cfg = getDefaultCharacterConfig(name);
teamContext = buildTeamContext({cfg}, 20, struct(), enemy);
result = simulateCharacterDPS(cfg, enemy, teamContext);
fprintf('OK %s DPS=%.2f ROT=%.2f\n', name, result.DPS, result.RotationTime);
