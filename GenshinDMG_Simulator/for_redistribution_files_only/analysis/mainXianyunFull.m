clear; clc; close all;
% Xianyun standalone validation entry.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
cfg = getDefaultCharacterConfig('Xianyun', struct('Constellation', 0));

[totalDMG, dps, breakdown, rotationTime] = simulateXianyunDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

fprintf('==================== Xianyun ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
