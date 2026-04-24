function [teamResult, memberResults] = simulateTeamDPS(teamSpec, enemy)
    % Unified team entry. teamSpec can be either:
    %   1. a cell/string list of character names, or
    %   2. a struct with explicit Members / RotationDuration / SharedBuffs.
    if nargin < 2 || isempty(enemy)
        enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
    end

    if iscell(teamSpec) || isstring(teamSpec)
        % Name-only input uses each character's default build and rotation.
        names = cellstr(string(teamSpec));
        members = cell(1, numel(names));
        for i = 1:numel(names)
            members{i} = getDefaultCharacterConfig(names{i});
        end
        rotationDuration = 20;
        sharedBuffs = struct();
    elseif isstruct(teamSpec) && isfield(teamSpec, 'Members')
        members = teamSpec.Members;
        rotationDuration = getFieldOrDefault(teamSpec, 'RotationDuration', 20);
        sharedBuffs = getFieldOrDefault(teamSpec, 'SharedBuffs', struct());
    else
        error('teamSpec must be a list of names or a struct with a Members field.');
    end

    % Build the shared team state once, then reuse it for every member.
    teamContext = buildTeamContext(members, rotationDuration, sharedBuffs);
    memberCells = cell(1, numel(members));
    combinedBreakdown = table();

    for i = 1:numel(members)
        memberCells{i} = simulateCharacterDPS(members{i}, enemy, teamContext);
        if ~isempty(memberCells{i}.Breakdown)
            currentBreakdown = memberCells{i}.Breakdown;
            % Tag merged breakdown rows with the source character so later
            % exports or plots can split the table back apart.
            currentBreakdown.Character = repmat(memberCells{i}.DisplayName, height(currentBreakdown), 1);
            combinedBreakdown = [combinedBreakdown; currentBreakdown]; %#ok<AGROW>
        end
    end

    memberResults = [memberCells{:}];

    totalDMG = sum([memberResults.TotalDMG]);
    teamDPS = totalDMG / rotationDuration;

    % Keep both team-cycle contribution and standalone DPS because short
    % field-time units can look misleading if only one number is shown.
    memberSummary = table( ...
        [memberResults.DisplayName].', ...
        [memberResults.TotalDMG].', ...
        ([memberResults.TotalDMG].' ./ rotationDuration), ...
        [memberResults.RotationTime].', ...
        [memberResults.DPS].', ...
        'VariableNames', {'Character', 'TotalDMG', 'TeamCycleDPS', 'ActionTime', 'StandaloneDPS'});

    teamResult = struct( ...
        'RotationDuration', rotationDuration, ...
        'TotalDMG', totalDMG, ...
        'DPS', teamDPS, ...
        'Summary', memberSummary, ...
        'Breakdown', combinedBreakdown, ...
        'TeamContext', teamContext);
end
