clear; clc; close all;
% Standalone entry for validating one default Escoffier build and rotation.
% The script is intentionally thin so the simulator remains the single
% source of truth for actual damage logic.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% Match the baseline enemy assumptions used by the shared team entry.
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
% Pull the reusable default build/rotation bundle from common config.
cfg = getDefaultCharacterConfig('Escoffier');

[totalDMG, dps, breakdown, rotationTime] = simulateEscoffierDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

fprintf('==================== 爱可菲 ====================\n');
fprintf('总伤害: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('循环时长: %.2f s\n', rotationTime);
disp(breakdown);
