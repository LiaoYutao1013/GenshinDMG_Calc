clear; clc; close all;
% 爱可菲单角色验证入口。
% 该脚本用于快速验证默认构筑与默认轮转下的个人伤害、后台召唤物
% 伤害和治疗快照，方便独立调试角色模拟器。

% 初始化工程路径，避免脚本受当前工作目录影响。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 敌人默认面板与统一配队入口保持一致。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% 命座开关集中在脚本顶部，便于快速回归测试。
constellation = 0;
cfg = getDefaultCharacterConfig('Escoffier', struct('Constellation', constellation));

% 执行单角色轮转模拟。
[totalDMG, dps, breakdown, rotationTime] = simulateEscoffierDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 打印摘要结果，明细表用于查看每个动作段的贡献。
fprintf('==================== Escoffier ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
