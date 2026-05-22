clear; clc; close all;
% 统一队伍模拟示例入口。
%
% 本脚本用于：
% 1. 指定参与配队的角色及其命座；
% 2. 构造统一敌人环境；
% 3. 调用 simulateTeamDPS；
% 4. 查看自动生成的排轴、成员汇总与合并明细。

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);

% 在这里统一指定队伍成员。
% 每个成员既可以直接写角色名，也可以写带覆盖项的 struct，例如：
% struct('Name', 'Nilou', 'Constellation', 2, 'TalentLevel', 10)
%
% 下面给出一个当前用于检查自动排轴的示例队伍。
teamMembers = { ...
    struct('Name', 'Lauma', 'Constellation', 2), ...
    struct('Name', 'Nilou', 'Constellation', 2), ...
    struct('Name', 'Nefer', 'Constellation', 0), ...
    struct('Name', 'Furina', 'Constellation', 1) ...
};

[teamResult, memberResults] = simulateTeamDPS(teamMembers, enemy); %#ok<NASGU>

fprintf('==================== Team Simulation ====================\n');
fprintf('Total DMG: %.0f\n', teamResult.TotalDMG);
fprintf('Team DPS : %.0f\n', teamResult.DPS);
fprintf('Duration : %.2f s\n', teamResult.RotationDuration);
if isfield(teamResult, 'ArchetypeInfo') && ~isempty(fieldnames(teamResult.ArchetypeInfo))
    fprintf('Archetype: %s', char(string(teamResult.ArchetypeInfo.PrimaryArchetype)));
    if strlength(string(teamResult.ArchetypeInfo.SecondaryArchetype)) > 0
        fprintf(' / %s', char(string(teamResult.ArchetypeInfo.SecondaryArchetype)));
    end
    fprintf('  (Confidence %.2f)\n', teamResult.ArchetypeInfo.Confidence);
end

if isfield(teamResult, 'ExecutionTable') && ~isempty(teamResult.ExecutionTable)
    fprintf('\n---- Auto-Planned Rotation ----\n');
    disp(teamResult.ExecutionTable);
end

fprintf('\n---- Member Summary ----\n');
disp(teamResult.Summary);

if isfield(teamResult, 'EnergySummary') && ~isempty(teamResult.EnergySummary)
    fprintf('\n---- Energy Summary ----\n');
    disp(teamResult.EnergySummary);
    fprintf('Loop Next Cycle: %s (Readiness %.2f)\n', string(teamResult.CanLoopNextCycle), teamResult.LoopReadiness);
end

if isfield(teamResult, 'EnergyTimeline') && ~isempty(teamResult.EnergyTimeline)
    fprintf('\n---- Energy Timeline Preview ----\n');
    disp(teamResult.EnergyTimeline(1:min(24, height(teamResult.EnergyTimeline)), :));
end

if isfield(teamResult, 'TimelineTable') && ~isempty(teamResult.TimelineTable)
    fprintf('\n---- Shared Timeline Preview ----\n');
    disp(teamResult.TimelineTable(1:min(24, height(teamResult.TimelineTable)), :));
end

if isfield(teamResult, 'TimelineSummary') && ~isempty(fieldnames(teamResult.TimelineSummary))
    fprintf('\n---- Timeline Summary ----\n');
    disp(struct2table(teamResult.TimelineSummary));
end

if isfield(teamResult, 'PlanningWarnings') && ~isempty(teamResult.PlanningWarnings)
    fprintf('\n---- Planning Warnings ----\n');
    disp(teamResult.PlanningWarnings);
end

if isfield(teamResult, 'MemberTimelineSummary') && ~isempty(teamResult.MemberTimelineSummary)
    fprintf('\n---- Member Timeline Summary ----\n');
    disp(teamResult.MemberTimelineSummary);
end

if isfield(teamResult, 'ActiveEffectsTable') && ~isempty(teamResult.ActiveEffectsTable)
    fprintf('\n---- Active Effects ----\n');
    disp(teamResult.ActiveEffectsTable);
end

if ~isempty(teamResult.Breakdown)
    fprintf('\n---- Breakdown Preview ----\n');
    disp(teamResult.Breakdown(1:min(20, height(teamResult.Breakdown)), :));
end
