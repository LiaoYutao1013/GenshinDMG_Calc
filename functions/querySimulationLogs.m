function [summary, records] = querySimulationLogs(criteria)
    % Query saved simulation logs by ID, mode, character, time range, and limit.
    if nargin < 1 || isempty(criteria)
        criteria = struct();
    end
    logDirectory = localField(criteria, 'LogDirectory', getSimulationLogDirectory());
    indexPath = fullfile(char(logDirectory), 'simulation_log_index.mat');
    if ~isfile(indexPath)
        summary = localEmptyIndex();
        records = cell(0, 1);
        return;
    end

    loaded = load(indexPath, 'indexTable');
    if ~isfield(loaded, 'indexTable') || ~istable(loaded.indexTable)
        summary = localEmptyIndex();
        records = cell(0, 1);
        return;
    end
    summary = loaded.indexTable;
    summary = localFilter(summary, criteria);
    summary = sortrows(summary, 'Timestamp', 'descend');

    limit = double(localField(criteria, 'Limit', 50));
    if isfinite(limit) && limit > 0
        summary = summary(1:min(height(summary), floor(limit)), :);
    end

    loadRecords = logical(localField(criteria, 'LoadRecords', true));
    records = cell(height(summary), 1);
    if ~loadRecords
        return;
    end
    for i = 1:height(summary)
        if isfile(summary.FilePath(i))
            loadedRecord = load(summary.FilePath(i), 'logRecord');
            if isfield(loadedRecord, 'logRecord')
                records{i} = loadedRecord.logRecord;
            end
        end
    end
end

function summary = localFilter(summary, criteria)
    if isempty(summary)
        return;
    end
    logId = string(localField(criteria, 'LogId', ""));
    if strlength(logId) > 0
        summary = summary(summary.LogId == logId, :);
    end
    mode = string(localField(criteria, 'Mode', ""));
    if strlength(mode) > 0
        summary = summary(strcmpi(summary.Mode, mode), :);
    end
    character = string(localField(criteria, 'Character', ""));
    if strlength(character) > 0
        summary = summary(contains(summary.Characters, character, 'IgnoreCase', true), :);
    end
    since = localDateTime(localField(criteria, 'Since', []));
    if ~isnat(since)
        summary = summary(summary.Timestamp >= since, :);
    end
    until = localDateTime(localField(criteria, 'Until', []));
    if ~isnat(until)
        summary = summary(summary.Timestamp <= until, :);
    end
end

function value = localDateTime(inputValue)
    value = NaT;
    if isempty(inputValue)
        return;
    end
    if isdatetime(inputValue)
        value = inputValue(1);
        return;
    end
    try
        value = datetime(inputValue);
    catch
        value = NaT;
    end
end

function value = localField(source, fieldName, fallback)
    if isstruct(source) && isfield(source, fieldName)
        value = source.(fieldName);
    else
        value = fallback;
    end
end

function summary = localEmptyIndex()
    summary = table( ...
        strings(0, 1), datetime.empty(0, 1), strings(0, 1), zeros(0, 1), ...
        zeros(0, 1), zeros(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', {'LogId', 'Timestamp', 'Mode', 'SimulationHorizon', ...
        'TotalDMG', 'TeamDPS', 'MemberDPSSum', 'Characters', 'FilePath'});
end
