function initProjectPaths()
    % 初始化工程函数路径。
    % 由于分析脚本、优化脚本和临时验证脚本可能在不同工作目录下
    % 运行，这里统一把公共函数和各角色子目录加入 MATLAB 路径。
    persistent initialized;
    if ~isempty(initialized) && initialized
        % 同一 MATLAB 会话内只初始化一次，避免重复 addpath。
        return;
    end

    root = fileparts(fileparts(mfilename('fullpath')));
    % 显式列出角色子目录，兼容旧脚本直接调用分角色函数的用法。
    addpath(fullfile(root, 'functions'));
    addpath(fullfile(root, 'functions', 'Furina'));
    addpath(fullfile(root, 'functions', 'Columbina'));
    addpath(fullfile(root, 'functions', 'Skirk'));
    addpath(fullfile(root, 'functions', 'Escoffier'));
    addpath(fullfile(root, 'functions', 'Arlecchino'));
    addpath(fullfile(root, 'functions', 'Lauma'));
    addpath(fullfile(root, 'functions', 'Ineffa'));
    addpath(fullfile(root, 'functions', 'Linnea'));
    addpath(fullfile(root, 'functions', 'Nilou'));
    addpath(fullfile(root, 'functions', 'Nefer'));
    addpath(fullfile(root, 'functions', 'Flins'));
    addpath(fullfile(root, 'functions', 'Zibai'));
    addpath(fullfile(root, 'functions', 'Mualani'));
    addpath(fullfile(root, 'functions', 'Mavuika'));
    addpath(fullfile(root, 'functions', 'Citlali'));
    addpath(fullfile(root, 'functions', 'Xilonen'));
    addpath(fullfile(root, 'functions', 'Neuvillette'));

    initialized = true;
end
