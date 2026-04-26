clear; clc; close all;
% 伊涅芙单角色验证入口。
% 用于单独检查召唤物持续时间、护盾快照和月感电追击逻辑。

% 初始化工程路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 统一敌人配置。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
constellation = 0;
cfg = getDefaultCharacterConfig('Ineffa', struct('Constellation', constellation));

% 执行默认轮转模拟。
[totalDMG, dps, breakdown, rotationTime] = simulateIneffaDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 输出摘要与分段表。
fprintf('==================== Ineffa ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
