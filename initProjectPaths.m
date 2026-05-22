function initProjectPaths()
    % Root-level bootstrap so `matlab -batch "initProjectPaths; ..."` works
    % directly from the project directory without requiring a manual addpath.
    persistent initialized;
    if ~isempty(initialized) && initialized
        return;
    end

    root = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(root, 'functions')));
    initialized = true;
end
