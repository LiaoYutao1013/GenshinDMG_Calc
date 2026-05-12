function initProjectPaths()
    % Initialize function search paths once per MATLAB session.
    persistent initialized;
    if ~isempty(initialized) && initialized
        return;
    end

    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root, 'functions'));
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

    initialized = true;
end
