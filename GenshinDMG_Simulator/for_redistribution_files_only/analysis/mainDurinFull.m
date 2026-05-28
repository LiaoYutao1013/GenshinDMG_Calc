clear; clc; close all;
% 杜林单角色验证入口。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
constellation = 0;
cfg = getDefaultCharacterConfig('Durin', struct('Constellation', constellation));

[totalDMG, dps, breakdown, rotationTime] = simulateDurinDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

fprintf('==================== Durin ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
