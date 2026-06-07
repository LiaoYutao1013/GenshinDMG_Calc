function rows = queryCombatEvents(teamContext, filters)
    % Query explicit combat events carried in teamContext/sharedBuffs.
    %
    % Supported filters:
    %   Character: string / char / string array
    %   EventKind: string / char / string array
    %   EventName: string / char / string array
    %   SourceAction: string / char / string array
    %   TimeRange: [startTime, endTime]
    %
    % Missing columns are normalized to empty/default values so callers can
    % safely provide partial event tables in targeted regressions.
    if nargin < 1 || isempty(teamContext)
        teamContext = struct();
    end
    if nargin < 2 || isempty(filters)
        filters = struct();
    end

    rows = localNormalizeCombatEventTable(getFieldOrDefault(teamContext, 'CombatEventTable', table()));
    if isempty(rows)
        return;
    end

    mask = true(height(rows), 1);
    mask = mask & localMatchStringColumn(rows.Character, getFieldOrDefault(filters, 'Character', []));
    mask = mask & localMatchStringColumn(rows.EventKind, getFieldOrDefault(filters, 'EventKind', []));
    mask = mask & localMatchStringColumn(rows.EventName, getFieldOrDefault(filters, 'EventName', []));
    mask = mask & localMatchStringColumn(rows.SourceAction, getFieldOrDefault(filters, 'SourceAction', []));

    timeRange = getFieldOrDefault(filters, 'TimeRange', []);
    if isnumeric(timeRange) && numel(timeRange) >= 2
        startTime = double(timeRange(1));
        endTime = double(timeRange(2));
        if isfinite(startTime)
            mask = mask & double(rows.Time) >= startTime - 1e-9;
        end
        if isfinite(endTime)
            mask = mask & double(rows.Time) <= endTime + 1e-9;
        end
    end

    rows = rows(mask, :);
end

function tableOut = localNormalizeCombatEventTable(tableIn)
    tableOut = table();
    if isempty(tableIn) || ~istable(tableIn) || height(tableIn) == 0
        return;
    end

    rowCount = height(tableIn);
    tableOut = table( ...
        zeros(rowCount, 1), ...
        strings(rowCount, 1), ...
        strings(rowCount, 1), ...
        strings(rowCount, 1), ...
        strings(rowCount, 1), ...
        zeros(rowCount, 1), ...
        'VariableNames', {'Time', 'Character', 'EventKind', 'EventName', 'SourceAction', 'Value'});

    if ismember('Time', string(tableIn.Properties.VariableNames))
        tableOut.Time = double(tableIn.Time);
    end
    if ismember('Character', string(tableIn.Properties.VariableNames))
        tableOut.Character = string(tableIn.Character);
    end
    if ismember('EventKind', string(tableIn.Properties.VariableNames))
        tableOut.EventKind = string(tableIn.EventKind);
    end
    if ismember('EventName', string(tableIn.Properties.VariableNames))
        tableOut.EventName = string(tableIn.EventName);
    end
    if ismember('SourceAction', string(tableIn.Properties.VariableNames))
        tableOut.SourceAction = string(tableIn.SourceAction);
    end
    if ismember('Value', string(tableIn.Properties.VariableNames))
        tableOut.Value = double(tableIn.Value);
    end

    sortOrder = (1:rowCount).';
    if any(isfinite(tableOut.Time))
        [~, sortOrder] = sortrows([double(tableOut.Time), sortOrder], [1 2]);
    end
    tableOut = tableOut(sortOrder, :);
end

function mask = localMatchStringColumn(values, filterValue)
    mask = true(numel(values), 1);
    if isempty(filterValue)
        return;
    end

    targets = string(filterValue);
    targets = strtrim(targets(:));
    targets = targets(strlength(targets) > 0);
    if isempty(targets)
        return;
    end

    mask = false(numel(values), 1);
    for i = 1:numel(targets)
        mask = mask | strcmpi(strtrim(string(values)), targets(i));
    end
end
