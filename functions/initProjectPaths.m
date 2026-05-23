function initProjectPaths()
    % 初始化工程函数搜索路径。
    % 统一入口、GUI、分析脚本都会通过这里完成路径注册，因此直接对
    % functions 目录做递归 addpath，避免新增角色目录后漏配路径。
    persistent initialized;
    if ~isempty(initialized) && initialized
        return;
    end

    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(fullfile(root, 'functions')));
    addpath(genpath(fullfile(root, 'tests')));

    initialized = true;
end
