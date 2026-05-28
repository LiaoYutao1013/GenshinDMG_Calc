clear; clc; close all;
% 希诺宁单角色验证入口。
% 用于观察滑行状态、采样层数和爆发治疗段在默认轮转中的总占比。

% 初始化工程路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 统一敌人配置。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
constellation = 0;
cfg = getDefaultCharacterConfig('Xilonen', struct('Constellation', constellation));

% 执行角色模拟器。
[totalDMG, dps, breakdown, rotationTime] = simulateXilonenDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 输出模拟结果与动作明细。
fprintf('==================== Xilonen ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
