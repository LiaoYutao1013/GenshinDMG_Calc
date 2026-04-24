clear; clc; close all;
% Standalone entry for validating one default Skirk build and rotation.
% It mainly serves as a lightweight harness for iterating on Skirk logic
% without going through team-level aggregation.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% Keep standalone validation on the same enemy baseline as team simulation.
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
% Centralized defaults keep standalone and unified entry behavior aligned.
cfg = getDefaultCharacterConfig('Skirk');

[totalDMG, dps, breakdown, rotationTime] = simulateSkirkDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

fprintf('==================== 丝柯克 ====================\n');
fprintf('总伤害: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('循环时长: %.2f s\n', rotationTime);
disp(breakdown);
