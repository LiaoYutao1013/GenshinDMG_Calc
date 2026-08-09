function logInfo = writeSimulationLog(logRecord, logDirectory)
    % Persist one simulation record and update the lightweight query index.
    if nargin < 1 || ~isstruct(logRecord)
        error('writeSimulationLog requires a struct record.');
    end
    if nargin < 2 || isempty(logDirectory)
        logDirectory = getSimulationLogDirectory();
    end
    if exist(logDirectory, 'dir') ~= 7
        mkdir(logDirectory);
    end

    timestamp = datetime('now');
    baseLogId = "sim_" + string(timestamp, 'yyyyMMdd_HHmmss_SSS');
    logId = baseLogId;
    filePath = fullfile(logDirectory, char(logId + ".mat"));
    sequence = 1;
    while isfile(filePath)
        logId = baseLogId + "_" + string(sprintf('%02d', sequence));
        filePath = fullfile(logDirectory, char(logId + ".mat"));
        sequence = sequence + 1;
    end

    logRecord.SchemaVersion = 1;
    logRecord.LogId = logId;
    logRecord.Timestamp = timestamp;
    save(filePath, 'logRecord', '-v7');

    indexTable = localLoadIndex(logDirectory);
    summaryRow = table( ...
        logId, timestamp, ...
        string(localField(logRecord, 'Mode', "team")), ...
        localNumeric(localField(logRecord, 'Metrics', struct()), 'SimulationHorizon'), ...
        localNumeric(localField(logRecord, 'Metrics', struct()), 'TotalDMG'), ...
        localNumeric(localField(logRecord, 'Metrics', struct()), 'TeamDPS'), ...
        localNumeric(localField(logRecord, 'Metrics', struct()), 'MemberDPSSum'), ...
        localCharacterNames(logRecord), string(filePath), ...
        'VariableNames', {'LogId', 'Timestamp', 'Mode', 'SimulationHorizon', ...
        'TotalDMG', 'TeamDPS', 'MemberDPSSum', 'Characters', 'FilePath'});
    indexTable = [indexTable; summaryRow]; %#ok<AGROW>
    save(fullfile(logDirectory, 'simulation_log_index.mat'), 'indexTable', '-v7');

    logInfo = struct('Saved', true, 'LogId', logId, 'FilePath', string(filePath));
end

function indexTable = localLoadIndex(logDirectory)
    indexPath = fullfile(logDirectory, 'simulation_log_index.mat');
    if isfile(indexPath)
        loaded = load(indexPath, 'indexTable');
        if isfield(loaded, 'indexTable') && istable(loaded.indexTable)
            indexTable = loaded.indexTable;
            return;
        end
    end
    indexTable = table( ...
        strings(0, 1), datetime.empty(0, 1), strings(0, 1), zeros(0, 1), ...
        zeros(0, 1), zeros(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', {'LogId', 'Timestamp', 'Mode', 'SimulationHorizon', ...
        'TotalDMG', 'TeamDPS', 'MemberDPSSum', 'Characters', 'FilePath'});
end

function value = localField(source, fieldName, fallback)
    if isfield(source, fieldName)
        value = source.(fieldName);
    else
        value = fallback;
    end
end

function value = localNumeric(source, fieldName)
    value = 0;
    if isstruct(source) && isfield(source, fieldName)
        candidate = source.(fieldName);
        if isnumeric(candidate) || islogical(candidate)
            value = double(candidate(1));
        end
    end
end

function names = localCharacterNames(logRecord)
    names = "";
    configuration = localField(logRecord, 'Configuration', struct());
    characters = localField(configuration, 'Characters', struct([]));
    if isempty(characters) || ~isstruct(characters)
        return;
    end
    values = strings(numel(characters), 1);
    for i = 1:numel(characters)
        values(i) = string(localField(characters(i), 'DisplayName', localField(characters(i), 'CharacterKey', "")));
    end
    names = strjoin(values(strlength(values) > 0), ", ");
end
