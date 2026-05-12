% ========================================================
% mainFurinaFull.m
% 芙宁娜旧版完整模拟入口
%
% 该脚本保留了项目早期 Furina 专用工作流：
% 1. 检查并解析天赋倍率表；
% 2. 生成默认构筑；
% 3. 读取手写轮转脚本；
% 4. 调用旧版 Furina 专用模拟器；
% 5. 输出总伤与分段明细。
% ========================================================

clear; clc; close all;

% 旧版 Furina 入口仍使用独立函数目录，因此需要单独加路径。
addpath('../functions');
addpath('../functions/Furina/');

%% 1. 天赋数据准备
% 若扁平化天赋表不存在，则先从原始技能 JSON 重新解析一次。
talentFile = '../data/Furina/talents_Furina_VerL.csv';
if ~exist(talentFile, 'file')
    fprintf('正在解析芙宁娜天赋倍率...\n');
    parseTalentJS('../data/Furina/Furina_skill.json', 'Furina', 'L');
    fprintf('解析完成。\n\n');
end

%% 2. 默认构筑准备
% 生成旧版 Furina 默认构筑，并同步写回 artifacts_Furina.csv。
build = customArtifact_Furina();

%% 3. 敌人配置
enemy = struct( ...
    'Level', 90, ...
    'Res', 0.10, ...
    'DefReduct', 0 ...
);

%% 4. 轮转文件
% 旧版 Furina 使用纯文本动作脚本描述轮转。
rotationFile = '../data/Furina/rotation_Furina.txt';

%% 5. 执行模拟
fprintf('开始芙宁娜模拟...\n');
fprintf('配置：%s | 天赋 %d | C%d\n\n', build.Weapon, 10, 6);

[totalDMG, dps, breakdown] = simulateFurinaDPS( ...
    build, ...
    enemy, ...
    rotationFile, ...
    10, ...
    6 ...
);

%% 6. 输出结果
fprintf('\n==================== 最终结果 ====================\n');
fprintf('总伤害：%.0f\n', totalDMG);
fprintf('DPS：%.0f\n', dps);
fprintf('循环时长：20 秒\n');
fprintf('==================================================\n\n');

% 只预览前几行明细，避免控制台输出过长。
disp(breakdown(1:min(10, height(breakdown)), :));

% 如需导出为 Excel，可打开下面两行注释。
% writetable(breakdown, 'output/Furina_DPS_Breakdown.xlsx');
% fprintf('明细已导出到 output/Furina_DPS_Breakdown.xlsx\n');
