clear; clc; close all;
% 玛拉妮单角色验证入口。
% 用于检查默认轮转中冲浪姿态、动量层数、咬击段和导弹终结段
% 的伤害构成，便于单独调试角色状态机。

% 初始化工程路径，确保函数目录和角色子目录都已加入 MATLAB 路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 敌人配置沿用工程统一默认值，方便和配队结果直接对照。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% 在这里切换命座等级，其余默认项由公共配置自动补全。
constellation = 0;
cfg = getDefaultCharacterConfig('Mualani', struct('Constellation', constellation));

% 执行单角色模拟，得到总伤、DPS、动作分解和轮转时长。
[totalDMG, dps, breakdown, rotationTime] = simulateMualaniDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 打印简要结果，供日常调试与回归检查使用。
fprintf('==================== Mualani ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);

% 查看每段咬击与终结段占比时，直接观察 breakdown 即可。
disp(breakdown);
