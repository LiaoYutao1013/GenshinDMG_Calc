% ========================================================
% mainColunbinaFull.m
% 哥伦比娅旧版完整模拟入口
%
% 该脚本保留了项目早期哥伦比娅专用工作流：
% 1. 解析天赋倍率；
% 2. 生成默认构筑；
% 3. 读取文本轮转；
% 4. 生成旧版 rotation_Columbina.csv；
% 5. 调用旧版调试型模拟器。
% ========================================================

clear; clc;

% 旧版哥伦比娅入口依赖单独目录中的若干工具函数。
addpath('../functions');
addpath('../functions/Columbina');

%% 1. 天赋数据准备
talentFile = '../data/Columbina/talents_Columbina.csv';
if ~exist(talentFile, 'file')
    fprintf('正在解析哥伦比娅天赋倍率...\n');
    parseTalentColumbina('../data/Columbina/Columbina_skill.json', 'Columbina', 'L');
    fprintf('解析完成。\n\n');
end

%% 2. 默认构筑准备
% 这里沿用旧版接口：先生成 CSV，再读表格回到工作区。
customArtifact_Columbina('帆间夜曲');
build = readtable('../data/artifacts_Columbina.csv');

%% 3. 敌人配置
enemy = struct( ...
    'Level', 90, ...
    'Res', 0.10, ...
    'DefReduct', 0 ...
);

%% 4. 轮转与配套数据
rotationFile = '../data/Columbina/sequence_Columbina.txt';
parseTalentColumbina('../data/Columbina_skill.json', 'Columbina', 'L');
buildRotation_Columbina();

%% 5. 执行模拟
[talentLevel, constellation] = deal(10, 0);
[totalDMG, dps] = simulateColumbinaDPS( ...
    table2struct(build), enemy, talentLevel, constellation, rotationFile);

%% 6. 输出结果
fprintf('==================== Columbina ====================\n');
fprintf('Constellation: C%d\n', constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
