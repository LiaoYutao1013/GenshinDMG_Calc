clear; clc; close all;
% 丝柯克单角色验证入口。
% 该脚本用于单独调试七相一闪姿态、虚境裂隙吸收、巧思点数衰减
% 以及命座派生段伤，无需每次都通过配队入口间接观察。

% 初始化工程路径，使入口脚本不依赖当前工作目录。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 敌人面板与整队模拟一致，保证结果横向可比。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% 命座切换集中在此，便于验证各命座分支逻辑。
constellation = 0;
cfg = getDefaultCharacterConfig('Skirk', struct('Constellation', constellation));

% 调用单角色模拟器，得到完整轮转结果。
[totalDMG, dps, breakdown, rotationTime] = simulateSkirkDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

% 控制台打印用于日常回归验证。
fprintf('==================== Skirk ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);

% 明细表可以帮助定位姿态内普攻、爆发和额外段伤的贡献。
disp(breakdown);
