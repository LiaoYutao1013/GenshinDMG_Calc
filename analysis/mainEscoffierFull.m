clear; clc; close all;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
cfg = getDefaultCharacterConfig('Escoffier');

[totalDMG, dps, breakdown, rotationTime] = simulateEscoffierDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

fprintf('==================== 爱可菲 ====================\n');
fprintf('总伤害: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('循环时长: %.2f s\n', rotationTime);
disp(breakdown);
