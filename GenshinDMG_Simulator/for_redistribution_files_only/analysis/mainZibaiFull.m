clear; clc; close all;
% 兹白单角色验证入口。
% 该脚本用于快速观察泉场持续、蓄压层数和重击终结段的占比。

% 初始化工程路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 统一敌人配置。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
constellation = 0;
cfg = getDefaultCharacterConfig('Zibai', struct('Constellation', constellation));

% 执行默认轮转模拟。
[totalDMG, dps, breakdown, rotationTime] = simulateZibaiDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 输出总伤、DPS 与明细表。
fprintf('==================== Zibai ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
