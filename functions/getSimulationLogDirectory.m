function logDirectory = getSimulationLogDirectory()
    % Canonical storage location for simulation records and their query index.
    functionsDirectory = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(functionsDirectory);
    logDirectory = fullfile(projectRoot, 'output', 'logs');
end
