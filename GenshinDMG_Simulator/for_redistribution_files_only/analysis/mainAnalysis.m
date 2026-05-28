clear; clc; close all;
% 旧版通用 DPS 分析示例。
% 该脚本展示了项目最初的“通用 build + 通用 rotation 表”计算流，
% 主要用于保留早期原型思路；当前主流程已迁移到分角色模拟器。

% 手动加入 functions 目录，使旧版 simulateDPS 可被调用。
addpath('../functions');

% 示例敌人数据：90 级，10% 基础抗性，无减防。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% 示例构筑数据。
% 这里仍采用最初的通用字段命名方式，并未接入按角色区分的 Build。
build = struct( ...
    'WeaponATK', 608, ...
    'AtkBonus', 0.50 + 0.466, ...
    'FlatATK', 300, ...
    'CritRate', 0.70, ...
    'CritDMG', 1.80 + 0.88, ...
    'DMGBonus', 0.466 + 0.20, ...
    'ResShred', 0.30, ...
    'ScalingType', 'ATK');

% 示例轮转表：每行描述一个动作段的命中数、倍率和耗时。
rotation = table([3; 5; 2], [1.5; 2.0; 3.0], [1.0; 0.8; 1.5], ...
    'VariableNames', {'Hits','TalentMV','Time'});

% 运行旧版通用 DPS 计算流程。
dps = simulateDPS('SampleATKChar', build, enemy, rotation);

% 输出简单报表到 output/reports，方便原型期比对结果。
mkdir('output/reports');
writetable(table({'SampleATKChar'}, dps, 'VariableNames', {'Character','DPS'}), ...
    'output/reports/report.xlsx');
