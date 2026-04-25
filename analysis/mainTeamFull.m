clear; clc; close all;
% Unified team entry. Edit teamMembers below to choose which characters
% participate in the shared team simulation.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% Unified member selection plus constellation control in one place.
% Each member can be a plain name or a struct with overrides such as:
% struct('Name', 'Nilou', 'Constellation', 2, 'TalentLevel', 10)
teamMembers = { ...
    struct('Name', 'Skirk', 'Constellation', 0), ...
    struct('Name', 'Escoffier', 'Constellation', 0), ...
    struct('Name', 'Furina', 'Constellation', 6), ...
    struct('Name', 'Arlecchino', 'Constellation', 0) ...
};

% Example:
% teamMembers = { ...
%     struct('Name', 'Lauma', 'Constellation', 2), ...
%     struct('Name', 'Nilou', 'Constellation', 2), ...
%     struct('Name', 'Nefer', 'Constellation', 0), ...
%     struct('Name', 'Furina', 'Constellation', 1) ...
% };

[teamResult, memberResults] = simulateTeamDPS(teamMembers, enemy); %#ok<NASGU>

fprintf('==================== 配队模拟 ====================\n');
fprintf('队伍总伤害: %.0f\n', teamResult.TotalDMG);
fprintf('队伍DPS: %.0f\n', teamResult.DPS);
fprintf('循环时长: %.2f s\n', teamResult.RotationDuration);
disp(teamResult.Summary);

if ~isempty(teamResult.Breakdown)
    disp(teamResult.Breakdown(1:min(20, height(teamResult.Breakdown)), :));
end
