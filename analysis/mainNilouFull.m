clear; clc; close all;
% 妮露单角色验证入口。
% 主要用于观察舞步轮转、金杯状态、水环脉冲和丰穰之核在默认
% 构筑与默认轮转下的整体占比。

% 初始化工程路径，保证脚本从任意目录运行时都能找到依赖函数。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 敌人假设与统一配队入口保持一致，方便比较单人和整队口径。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% 命座开关集中放在入口处，便于快速做 C0/C2/C6 对比。
constellation = 0;
cfg = getDefaultCharacterConfig('Nilou', struct('Constellation', constellation));

% 执行妮露默认轮转，返回总伤、DPS、分段表和动作时长。
[totalDMG, dps, breakdown, rotationTime] = simulateNilouDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 输出当前命座下的模拟结果。
fprintf('==================== Nilou ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);

% 若需分析丰穰之核与水环脉冲占比，可直接查看明细表。
disp(breakdown);
