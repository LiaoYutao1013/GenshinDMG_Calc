function result = simulateCharacterDPS(memberCfg, enemy, teamContext)
    % Unified single-character dispatch entry used by both standalone
    % analysis scripts and the team simulator.
    initProjectPaths();

    if nargin < 3 || isempty(teamContext)
        teamContext = struct('RotationDuration', 20);
    end

    name = lower(strtrim(char(string(memberCfg.Name))));
    compiledBuild = compileArtifactSetBonuses(memberCfg.Name, memberCfg.Build, teamContext);
    if nargin >= 3 && ~isempty(teamContext)
        memberCfg.EnemyState = createEnemyState(enemy, teamContext, getCharacterElement(memberCfg.Name));
    elseif ~isfield(memberCfg, 'EnemyState') || isempty(memberCfg.EnemyState)
        memberCfg.EnemyState = createEnemyState(enemy, teamContext, getCharacterElement(memberCfg.Name));
    end
    memberTeamContext = teamContext;
    memberTeamContext = localApplyElementSpecificTeamBonuses(memberTeamContext, memberCfg.Name);
    memberTeamContext.EnemyState = memberCfg.EnemyState;

    switch name
        case 'skirk'
            [totalDMG, dps, breakdown, rotationTime] = simulateSkirkDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'escoffier'
            [totalDMG, dps, breakdown, rotationTime] = simulateEscoffierDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'arlecchino'
            [totalDMG, dps, breakdown, rotationTime] = simulateArlecchinoDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'furina'
            [totalDMG, dps, breakdown, rotationTime] = simulateFurinaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'columbina'
            [totalDMG, dps, breakdown, rotationTime] = simulateColumbinaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'chasca'
            [totalDMG, dps, breakdown, rotationTime] = simulateChascaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'lauma'
            [totalDMG, dps, breakdown, rotationTime] = simulateLaumaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'ineffa'
            [totalDMG, dps, breakdown, rotationTime] = simulateIneffaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'linnea'
            [totalDMG, dps, breakdown, rotationTime] = simulateLinneaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'nilou'
            [totalDMG, dps, breakdown, rotationTime] = simulateNilouDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'nefer'
            [totalDMG, dps, breakdown, rotationTime] = simulateNeferDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'flins'
            [totalDMG, dps, breakdown, rotationTime] = simulateFlinsDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'zibai'
            [totalDMG, dps, breakdown, rotationTime] = simulateZibaiDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'mualani'
            [totalDMG, dps, breakdown, rotationTime] = simulateMualaniDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'mavuika'
            [totalDMG, dps, breakdown, rotationTime] = simulateMavuikaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'citlali'
            [totalDMG, dps, breakdown, rotationTime] = simulateCitlaliDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'xilonen'
            [totalDMG, dps, breakdown, rotationTime] = simulateXilonenDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'neuvillette'
            [totalDMG, dps, breakdown, rotationTime] = simulateNeuvilletteDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'chevreuse'
            [totalDMG, dps, breakdown, rotationTime] = simulateChevreuseDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'iansan'
            [totalDMG, dps, breakdown, rotationTime] = simulateIansanDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'varesa'
            [totalDMG, dps, breakdown, rotationTime] = simulateVaresaDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'durin'
            [totalDMG, dps, breakdown, rotationTime] = simulateDurinDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'nicole'
            [totalDMG, dps, breakdown, rotationTime] = simulateNicoleDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        case 'xianyun'
            [totalDMG, dps, breakdown, rotationTime] = simulateXianyunDPS( ...
                compiledBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, memberTeamContext);

        otherwise
            error('No simulator registered for %s', memberCfg.Name);
    end

    result = struct( ...
        'Name', string(memberCfg.Name), ...
        'DisplayName', string(memberCfg.DisplayName), ...
        'TotalDMG', totalDMG, ...
        'DPS', dps, ...
        'RotationTime', rotationTime, ...
        'Breakdown', breakdown);
end

function teamContext = localApplyElementSpecificTeamBonuses(teamContext, characterName)
    % 大多数角色模拟器当前只读取 teamContext.AllDMGBonus。
    % 为了让元素专属团队增伤在不重写全部角色公式的前提下立即生效，
    % 这里按角色元素把对应的共享增伤统一折算进成员视角的 AllDMGBonus。
    if isempty(teamContext)
        return;
    end

    element = lower(char(string(getCharacterElement(characterName))));
    elementBonus = 0;
    switch element
        case 'pyro'
            elementBonus = getFieldOrDefault(teamContext, 'PyroDMGBonus', 0);
        case 'hydro'
            elementBonus = getFieldOrDefault(teamContext, 'HydroDMGBonus', 0);
        case 'cryo'
            elementBonus = getFieldOrDefault(teamContext, 'CryoDMGBonus', 0);
        case 'electro'
            elementBonus = getFieldOrDefault(teamContext, 'ElectroDMGBonus', 0);
        case 'anemo'
            elementBonus = getFieldOrDefault(teamContext, 'AnemoDMGBonus', 0);
        case 'geo'
            elementBonus = getFieldOrDefault(teamContext, 'GeoDMGBonus', 0);
        case 'dendro'
            elementBonus = getFieldOrDefault(teamContext, 'DendroDMGBonus', 0);
    end

    teamContext.ElementSpecificDMGBonus = elementBonus;
    teamContext.AllDMGBonus = getFieldOrDefault(teamContext, 'AllDMGBonus', 0) + elementBonus;
end
