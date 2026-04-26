clear; clc; close all;
% 统一配队模拟入口。
% 该脚本负责：
% 1. 指定参与配队的角色与命座；
% 2. 构造统一敌人环境；
% 3. 调用 simulateTeamDPS 生成整队总伤、角色贡献和合并明细。

% 初始化工程路径，保证统一入口从任意工作目录都可运行。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% 队伍模拟默认敌人配置。
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% 在这里统一指定队伍成员和命座。
% 每个成员既可以直接写角色名，也可以写带覆盖项的结构体，例如：
% struct('Name', 'Nilou', 'Constellation', 2, 'TalentLevel', 10)
teamMembers = { ...
    struct('Name', 'Skirk', 'Constellation', 0), ...
    struct('Name', 'Escoffier', 'Constellation', 0), ...
    struct('Name', 'Furina', 'Constellation', 6), ...
    struct('Name', 'Arlecchino', 'Constellation', 0) ...
};

% 下面给出另一个可直接切换的队伍示例：
% teamMembers = { ...
%     struct('Name', 'Lauma', 'Constellation', 2), ...
%     struct('Name', 'Nilou', 'Constellation', 2), ...
%     struct('Name', 'Nefer', 'Constellation', 0), ...
%     struct('Name', 'Furina', 'Constellation', 1) ...
% };

% 统一配队入口会自动构建 teamContext，并逐个调用角色模拟器。
[teamResult, memberResults] = simulateTeamDPS(teamMembers, enemy); %#ok<NASGU>

% 输出整队总伤、队伍 DPS、循环时长与角色贡献汇总表。
fprintf('==================== 閰嶉槦妯℃嫙 ====================\n');
fprintf('闃熶紞鎬讳激瀹? %.0f\n', teamResult.TotalDMG);
fprintf('闃熶紞DPS: %.0f\n', teamResult.DPS);
fprintf('寰幆鏃堕暱: %.2f s\n', teamResult.RotationDuration);
disp(teamResult.Summary);

% 合并后的 breakdown 会附带 Character 列，便于后续筛选或导出。
if ~isempty(teamResult.Breakdown)
    disp(teamResult.Breakdown(1:min(20, height(teamResult.Breakdown)), :));
end
