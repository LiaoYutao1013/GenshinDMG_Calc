clear; clc; close all;
% 那维莱特单角色验证入口。
% 该脚本用于快速验证默认构筑和默认轮转下的个人输出表现，
% 重点观察源水之滴生成、古海孑遗层数近似和重击水柱段伤。

% 初始化工程路径，使脚本可以从任意工作目录直接运行。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 敌人参数保持与统一配队入口一致，方便横向对比结果。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% 在入口处切换命座，便于快速比较不同命座下的收益。
constellation = 0;

% 默认构筑、轮转文件和天赋等级都从统一配置入口读取。
cfg = getDefaultCharacterConfig('Neuvillette', struct('Constellation', constellation));

% 执行默认轮转，并返回总伤、DPS、动作明细和动作总时长。
[totalDMG, dps, breakdown, rotationTime] = simulateNeuvilletteDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 在控制台打印摘要，便于日常验证和回归测试。
fprintf('==================== Neuvillette ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);

% 明细表可进一步查看每个动作和派生段伤的占比。
disp(breakdown);
