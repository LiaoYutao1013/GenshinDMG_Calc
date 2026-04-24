% ========================================================
% mainFurinaFull.m
% 芙寧娜完整模擬入口（最還原實戰版）
% 
% 功能：
% 1. 自動檢查並解析天賦倍率（如果不存在）
% 2. 自定義武器 + 聖遺物配置（可直接修改）
% 3. 從 TXT 讀入自定義手法排軸
% 4. 嚴格模擬重擊切換形態、三海鮮各自傷害、芒性普攻強化、氛圍值、C1/C2/C6
% 5. 輸出詳細 breakdown + 總結
% ========================================================

clear; clc; close all;
% Legacy standalone Furina entry that wires together build generation,
% enemy setup, rotation selection, and final result printing.
addpath('../functions')
addpath('../functions/Furina/')

%% ================== 1. 自動解析天賦（如果不存在） ==================
talentFile = '../data/Furina/talents_Furina_VerL.csv';
if ~exist(talentFile, 'file')
    fprintf('正在解析芙宁娜天赋倍率...\n');
    parseTalentJS('../data/Furina/Furina_skill.json', 'Furina', 'L');
    fprintf('解析完成！\n\n');
end

%% ================== 2. 自定義武器 + 聖遺物配置 ==================
% ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←
% 自動載入最新聖遺物配置
build = customArtifact_Furina();   % 或直接 readtable

% 可選：如果你有多套聖遺物預設，可在這裡切換
% build = loadPreset('Furina_Build1');   % 未來可擴展

%% ================== 3. 敵人設定 ==================
enemy = struct(...
    'Level',     90, ...
    'Res',       0.10, ...      % 抗性
    'DefReduct', 0 ...
);

%% ================== 4. 手法排軸檔案 ==================
rotationFile = '../data/Furina/rotation_Furina.txt';   % ← 你的自定義排軸

%% ================== 5. 執行完整模擬 ==================
fprintf('开始芙宁娜模拟...\n');
fprintf('配置：%s | 天赋%d | C%d\n\n', build.Weapon, 10, 6);

[totalDMG, dps, breakdown] = simulateFurinaDPS(...
    build, ...
    enemy, ...
    rotationFile, ...
    10, ...      % 天賦等級（可改）
    6 ...        % 命座等級（可改 0~6）
);

%% ================== 6. 結果輸出與保存 ==================
fprintf('\n==================== 最終結果 ====================\n');
fprintf('总伤害：%.0f\n', totalDMG);
fprintf('DPS：%.0f\n', dps);
fprintf('循环时间：120 秒\n');
fprintf('====================================================\n\n');

% 顯示前10段詳細 breakdown
disp(breakdown(1:min(10,height(breakdown)),:));

% 保存到 Excel（方便後續分析）
%writetable(breakdown, 'output/Furina_DPS_Breakdown.xlsx');
%fprintf('詳細 breakdown 已保存至 output/Furina_DPS_Breakdown.xlsx\n');

% 可選：自動開啟 Excel（Windows）
% winopen('output/Furina_DPS_Breakdown.xlsx');
