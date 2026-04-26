clear; clc; close all;
% 莉奈娅单角色验证入口。
% 用于观察 Lumi、场志目录层数、月结晶和重击终结段的整体表现。

% 初始化工程路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 统一敌人配置。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
constellation = 0;
cfg = getDefaultCharacterConfig('Linnea', struct('Constellation', constellation));

% 执行默认轮转。
[totalDMG, dps, breakdown, rotationTime] = simulateLinneaDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 输出结果与动作明细。
fprintf('==================== Linnea ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
