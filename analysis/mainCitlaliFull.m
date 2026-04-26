clear; clc; close all;
% 茜特菈莉单角色验证入口。
% 用于检查护盾快照、星体追击、爆发头骨段伤及相关命座分支。

% 初始化工程路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 敌人配置沿用统一默认值。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
constellation = 0;
cfg = getDefaultCharacterConfig('Citlali', struct('Constellation', constellation));

% 执行单角色轮转。
[totalDMG, dps, breakdown, rotationTime] = simulateCitlaliDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 输出角色轮转结果。
fprintf('==================== Citlali ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
