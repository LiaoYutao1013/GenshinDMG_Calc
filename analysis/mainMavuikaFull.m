clear; clc; close all;
% 玛薇卡单角色验证入口。
% 适合单独调试战意积累、领域持续时间和爆发终结段伤害。

% 初始化工程路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 敌人默认配置。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
constellation = 0;
cfg = getDefaultCharacterConfig('Mavuika', struct('Constellation', constellation));

% 执行默认轮转模拟。
[totalDMG, dps, breakdown, rotationTime] = simulateMavuikaDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 输出角色轮转结果。
fprintf('==================== Mavuika ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
