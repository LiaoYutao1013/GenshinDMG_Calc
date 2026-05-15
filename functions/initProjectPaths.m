function initProjectPaths()
    % 初始化工程函数搜索路径。
    % 该函数会在 MATLAB 会话内只执行一次，避免重复 addpath。
    persistent initialized;
    if ~isempty(initialized) && initialized
        return;
    end

    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root, 'functions'));
    addpath(fullfile(root, 'functions', 'app'));
    addpath(fullfile(root, 'functions', 'Furina'));
    addpath(fullfile(root, 'functions', 'Columbina'));
    addpath(fullfile(root, 'functions', 'Chasca'));
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
    addpath(fullfile(root, 'functions', 'Chevreuse'));
    addpath(fullfile(root, 'functions', 'Iansan'));
    addpath(fullfile(root, 'functions', 'Varesa'));
    addpath(fullfile(root, 'functions', 'Durin'));
    addpath(fullfile(root, 'functions', 'Nicole'));
    addpath(fullfile(root, 'functions', 'Xianyun'));

    initialized = true;
end
