function validateSimulationLogInterface()
    % Regression coverage for the write/query contract consumed by future views.
    logDirectory = tempname;
    cleanup = onCleanup(@() localCleanup(logDirectory)); %#ok<NASGU>
    character = struct('DisplayName', "测试角色", 'CharacterKey', "Test", 'Build', struct());
    record = struct( ...
        'Mode', "team", ...
        'Configuration', struct('Characters', character), ...
        'Metrics', struct('SimulationHorizon', 120, 'TotalDMG', 1000, ...
            'TeamDPS', 200, 'MemberDPSSum', 200));

    logInfo = writeSimulationLog(record, logDirectory);
    assert(logInfo.Saved && isfile(logInfo.FilePath));

    [summary, records] = querySimulationLogs(struct( ...
        'LogDirectory', logDirectory, 'Character', "测试角色", 'Limit', 1));
    assert(height(summary) == 1 && numel(records) == 1);
    assert(records{1}.Metrics.TeamDPS == 200);
end

function localCleanup(logDirectory)
    if exist(logDirectory, 'dir') == 7
        rmdir(logDirectory, 's');
    end
end
