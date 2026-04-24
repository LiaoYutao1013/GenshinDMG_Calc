clear; clc; close all;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
cfg = getDefaultCharacterConfig('Arlecchino');

[totalDMG, dps, breakdown, rotationTime] = simulateArlecchinoDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

fprintf('==================== 阿蕾奇诺 ====================\n');
fprintf('总伤害: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('循环时长: %.2f s\n', rotationTime);
disp(breakdown);
