projectRoot = 'c:/Users/ASUS/MATLAB/Projects/GenshinDMG_Calc';
addpath(genpath(projectRoot));
enemy = struct('Level', 93, 'Res', 0.10, 'DefReduct', 0, 'DefIgnore', 0);
chars = {'KamisatoAyaka','Jean','Lisa','Barbara','Kaeya','Diluc','Razor','Amber','Venti','Xiangling'};
for i = 1:numel(chars)
    name = chars{i};
    try
        cfg = getDefaultCharacterConfig(name);
        teamContext = buildTeamContext({cfg}, 20, struct(), enemy);
        result = simulateCharacterDPS(cfg, enemy, teamContext);
        fprintf('OK %s DPS=%.2f ROT=%.2f\n', name, result.DPS, result.RotationTime);
    catch ME
        fprintf(2, 'FAIL %s :: %s\n', name, ME.message);
        for k = 1:min(6, numel(ME.stack))
            fprintf(2, '  at %s:%d\n', ME.stack(k).name, ME.stack(k).line);
        end
    end
end
