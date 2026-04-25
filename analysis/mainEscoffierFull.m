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
constellation = 0;
cfg = getDefaultCharacterConfig('Escoffier', struct('Constellation', constellation));

[totalDMG, dps, breakdown, rotationTime] = simulateEscoffierDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

fprintf('==================== Escoffier ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
