clear; clc; close all;
% Unified team entry. Edit teamMembers below to choose which characters
% participate in the shared team simulation.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% 统一入口：在此处指定配队角色
teamMembers = {'Skirk', 'Escoffier', 'Furina', 'Arlecchino'};

% 如需手动覆盖默认配置，可改为 struct 形式：
% teamSpec = struct('Members', { ...
%     {getDefaultCharacterConfig('Skirk'), getDefaultCharacterConfig('Escoffier')} ...
% }, 'RotationDuration', 20, 'SharedBuffs', struct('FlatATK', 0));

[teamResult, memberResults] = simulateTeamDPS(teamMembers, enemy); %#ok<NASGU>

fprintf('==================== 配队模拟 ====================\n');
fprintf('队伍总伤害: %.0f\n', teamResult.TotalDMG);
fprintf('队伍DPS: %.0f\n', teamResult.DPS);
fprintf('循环时长: %.2f s\n', teamResult.RotationDuration);
disp(teamResult.Summary);

if ~isempty(teamResult.Breakdown)
    disp(teamResult.Breakdown(1:min(20, height(teamResult.Breakdown)), :));
end
