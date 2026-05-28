clear; clc; close all;
% 阿蕾奇诺单角色验证入口。
% 主要用于独立观察生命之契、血偿勒令、重击回收和命座追加段伤
% 在默认轮转中的表现。

% 初始化工程路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 使用统一敌人参数，便于与其他角色和整队结果比较。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% 在入口处切换命座等级。
constellation = 0;
cfg = getDefaultCharacterConfig('Arlecchino', struct('Constellation', constellation));

% 执行角色模拟器。
[totalDMG, dps, breakdown, rotationTime] = simulateArlecchinoDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 控制台输出总伤、DPS 和分段表。
fprintf('==================== Arlecchino ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
