clear; clc; addpath('../functions');

% === 一键执行全部步骤 ===
parseBaseStatsJS('../data/AvatarExcelConfigData.js', '哥伦比娅');   % 基础属性
parseTalentJS('../data/Columbina_skill.json', 'Columbina','L');     % 天赋倍率（新）
%parseWeaponJS('../data/WeaponExcelConfigData.js');   % 武器解析（运行一次即可）
customArtifact('帷间夜曲');                   % 改成想用的武器,自定义圣遗物
buildRotation_Columbina();                                      % 战斗循环

build = readtable('../data/artifacts_Columbina.csv');  % 读取自定义
enemy = struct('Level',90,'Res',0.10,'DefReduct',0);

[total, dps] = simulateColumbinaDPS(table2struct(build), enemy,'VarName12');    % 自动循环 + 伤害计算
 