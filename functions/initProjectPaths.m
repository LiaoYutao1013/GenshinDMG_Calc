function initProjectPaths()
    % Add function folders once per MATLAB session so entry scripts can be
    % run from different working directories without manual path setup.
    persistent initialized;
    if ~isempty(initialized) && initialized
        return;
    end

    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root, 'functions'));
    addpath(fullfile(root, 'functions', 'Furina'));
    addpath(fullfile(root, 'functions', 'Columbina'));
    addpath(fullfile(root, 'functions', 'Skirk'));
    addpath(fullfile(root, 'functions', 'Escoffier'));
    addpath(fullfile(root, 'functions', 'Arlecchino'));

    initialized = true;
end
