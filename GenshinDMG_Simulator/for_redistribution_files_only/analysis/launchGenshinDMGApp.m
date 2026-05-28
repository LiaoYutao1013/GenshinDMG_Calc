clear; clc;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

app = GenshinDMGApp(); %#ok<NASGU>
