clear; clc; close all;
% 奈芙尔单角色验证入口。
% 用于快速检查影舞时长、青露消耗、幕纱层数和月绽放段伤。

% 初始化工程路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 统一敌人配置。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
constellation = 0;
cfg = getDefaultCharacterConfig('Nefer', struct('Constellation', constellation));

% 执行默认轮转模拟。
[totalDMG, dps, breakdown, rotationTime] = simulateNeferDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 输出总伤、DPS 与动作明细。
fprintf('==================== Nefer ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
