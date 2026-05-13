clear; clc;

% MATLAB 可视化模拟 APP 启动脚本。
% 该脚本只负责初始化工程路径并实例化程序化 APP 主类。
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot, 'functions')));
initProjectPaths();

app = GenshinDMGApp(); %#ok<NASGU>
