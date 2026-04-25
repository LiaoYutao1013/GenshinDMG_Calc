function [teamResult, memberResults] = simulateTeamDPS(teamSpec, enemy)
    % Unified team entry. teamSpec can be either:
    %   1. a cell list of names or name+override structs, or
    %   2. a struct with explicit Members / RotationDuration / SharedBuffs.
    if nargin < 2 || isempty(enemy)
        enemy = struct('Level', 90, 'Res', 0.10, 'DefReduct', 0);
    end

    if isstring(teamSpec)
        memberSpecs = cellstr(teamSpec);
        members = cell(1, numel(memberSpecs));
        for i = 1:numel(memberSpecs)
            members{i} = localResolveMemberSpec(memberSpecs{i});
        end
        rotationDuration = 20;
        sharedBuffs = struct();
    elseif iscell(teamSpec)
        memberSpecs = teamSpec;
        members = cell(1, numel(memberSpecs));
        for i = 1:numel(memberSpecs)
            members{i} = localResolveMemberSpec(memberSpecs{i});
        end
        rotationDuration = 20;
        sharedBuffs = struct();
    elseif isstruct(teamSpec) && isfield(teamSpec, 'Members')
        rawMembers = teamSpec.Members;
        members = cell(1, numel(rawMembers));
        for i = 1:numel(rawMembers)
            members{i} = localResolveMemberSpec(rawMembers{i});
        end
        rotationDuration = getFieldOrDefault(teamSpec, 'RotationDuration', 20);
        sharedBuffs = getFieldOrDefault(teamSpec, 'SharedBuffs', struct());
    else
        error('teamSpec must be a list of members or a struct with a Members field.');
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

function member = localResolveMemberSpec(spec)
    if isstring(spec) || ischar(spec)
        member = getDefaultCharacterConfig(spec);
        return;
    end

    if isstruct(spec)
        if ~isfield(spec, 'Name')
            error('Member override structs must include a Name field.');
        end
        member = getDefaultCharacterConfig(spec.Name, spec);
        return;
    end

    error('Unsupported member specification in unified team entry.');
end
