% ========================================================
% mainColumbinaFull.m
% 哥伦比娅完整模拟入口（最还原实战版）
% 
% 功能：
% 1. 自动检查并解析天赋倍率（如果不存在）
% 2. 自定义武器 + 圣遗物配置（可直接修改）
% 3. 从 TXT 读入自定义手法排轴
% 4. 模拟重击切换形态、三海鲜各自伤害、芒性普攻强化、气氛值、C1/C2/C6
% 5. 输出详细 breakdown + 总结
% ========================================================
clear; clc; 
addpath('../functions');
addpath('../functions/Columbina');

%% ================== 1. 自动解析天赋（如果不存在） ==================
talentFile = '../data/Columbina/talents_Columbina.csv';
if ~exist(talentFile, 'file')
    fprintf('正在解析哥伦比娅天賦倍率...\n');
    parseTalentColumbina('../data/Columbina/Columbina_skill.json', 'Columbina', 'L');
    fprintf('解析完成！\n\n');
end

%% ================== 2. 自定义武器 + 圣遗物配置 ==================
% ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←
% 自动载入最新圣遗物配置
customArtifact_Columbina('帷间夜曲');   
build = readtable('../data/artifacts_Columbina.csv');  % 读取自定义

% 可选：如果你有多套圣遗物预设，可在这里切换
% build = loadPreset('Columbina_Build1');   % 未來可擴展

%% ================== 3. 敌人设定 ==================
enemy = struct(...
    'Level',     90, ...
    'Res',       0.10, ...      % 抗性
    'DefReduct', 0 ...
);

%% ================== 4. 手法排轴设定 ==================
rotationFile = '../data/Columbina/sequence_Columbina.txt';   % ← 你的自定义排轴
% === 一键执行全部步骤 ===
%parseBaseStatsJS('../data/AvatarExcelConfigData.js', '哥伦比娅');   % 基础属性
parseTalentColumbina('../data/Columbina_skill.json', 'Columbina','L');     % 天赋倍率（新）
buildRotation_Columbina();                                      % 战斗循环


enemy = struct('Level',90,'Res',0.10,'DefReduct',0);

[talentLevel, constellation] = deal(10, 0);   % ← 指定天赋等级和命座

[total, dps] = simulateColumbinaDPS(table2struct(build), enemy,talentLevel, constellation,rotationFile);    % 自动循环 + 伤害计算
 