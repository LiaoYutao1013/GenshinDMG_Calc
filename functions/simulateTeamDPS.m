function [teamResult, memberResults] = simulateTeamDPS(teamSpec, enemy)
    % 统一的配队伤害模拟入口。
    % teamSpec 支持：
    % 1. 角色名字符串数组；
    % 2. 角色名 / 覆盖配置的 cell；
    % 3. 包含 Members / RotationDuration / SharedBuffs 的结构体。
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

    % 先构造一次共享团队上下文，再复用给每个角色。
    % 这样可保证减抗、元素计数、共享增益和反应开关在全队内部一致。
    teamContext = buildTeamContext(members, rotationDuration, sharedBuffs);
    memberCells = cell(1, numel(members));
    combinedBreakdown = table();

    for i = 1:numel(members)
        memberCells{i} = simulateCharacterDPS(members{i}, enemy, teamContext);
        if ~isempty(memberCells{i}.Breakdown)
            currentBreakdown = memberCells{i}.Breakdown;
            % 为合并后的明细补上来源角色列，方便后续筛选或画图。
            currentBreakdown.Character = repmat(memberCells{i}.DisplayName, height(currentBreakdown), 1);
            combinedBreakdown = [combinedBreakdown; currentBreakdown]; %#ok<AGROW>
        end
    end

    memberResults = [memberCells{:}];

    % 队伍总伤害按整轮循环求和，队伍 DPS 使用统一循环时长作分母。
    totalDMG = sum([memberResults.TotalDMG]);
    teamDPS = totalDMG / rotationDuration;

    % 同时保留“整队循环贡献”和“角色自身口径 DPS”。
    % 对于后台角色，只看 standalone DPS 容易高估其实际队伍贡献。
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
    % 将各种成员输入形式统一解析成完整角色配置结构。
    if isstring(spec) || ischar(spec)
        member = getDefaultCharacterConfig(spec);
        return;
    end

    if isstruct(spec)
        if ~isfield(spec, 'Name')
            error('Member override structs must include a Name field.');
        end
        % 允许调用方覆盖命座、天赋等级、轮转文件或构筑局部字段。
        member = getDefaultCharacterConfig(spec.Name, spec);
        return;
    end

    error('Unsupported member specification in unified team entry.');
end
