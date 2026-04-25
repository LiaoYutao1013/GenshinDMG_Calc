clear; clc; close all;
% Standalone entry for validating one default Arlecchino build and rotation.
% This mirrors the unified dispatcher path, but stays convenient for
% quick single-character sanity checks inside MATLAB.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

% Keep the enemy model explicit so standalone and team tests stay comparable.
enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
% Reuse the shared default config instead of duplicating build values here.
constellation = 0;
cfg = getDefaultCharacterConfig('Arlecchino', struct('Constellation', constellation));

[totalDMG, dps, breakdown, rotationTime] = simulateArlecchinoDPS( ...
    cfg.Build, enemy, cfg.RotationFile, cfg.TalentLevel, cfg.Constellation, []);

fprintf('==================== Arlecchino ====================\n');
fprintf('Constellation: C%d\n', cfg.Constellation);
fprintf('Total Damage: %.0f\n', totalDMG);
fprintf('DPS: %.0f\n', dps);
fprintf('Rotation Time: %.2f s\n', rotationTime);
disp(breakdown);
