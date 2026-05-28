clear; clc; close all;
% 菈乌玛单角色验证入口。
% 主要用于检查圣域持续、露滴积累、古歌层数和月绽放段伤的实现。

% 初始化工程路径。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 敌人默认配置。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
constellation = 0;
cfg = getDefaultCharacterConfig('Lauma', struct('Constellation', constellation));

% 执行默认轮转。
[totalDMG, dps, breakdown, rotationTime] = simulateLaumaDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 输出总伤、DPS 与明细表。
fprintf('==================== Lauma ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
