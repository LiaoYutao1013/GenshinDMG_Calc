clear; clc; close all;
% 菲林斯单角色验证入口。
% 用于单独检查幻灯持续、共鸣状态和月感电派生伤害的实现。

% 初始化工程路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 敌人默认配置。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
constellation = 0;
cfg = getDefaultCharacterConfig('Flins', struct('Constellation', constellation));

% 执行默认轮转。
[totalDMG, dps, breakdown, rotationTime] = simulateFlinsDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 输出摘要与分段表。
fprintf('==================== Flins ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
