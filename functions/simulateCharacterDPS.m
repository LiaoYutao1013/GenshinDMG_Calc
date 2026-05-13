function result = simulateCharacterDPS(memberCfg, enemy, teamContext)
    % Unified single-character dispatch entry used by both standalone
    % analysis scripts and the team simulator.
    initProjectPaths();

    if nargin < 3 || isempty(teamContext)
        teamContext = struct('RotationDuration', 20);
    end

    name = lower(strtrim(char(string(memberCfg.Name))));

    switch name
        case 'skirk'
            [totalDMG, dps, breakdown, rotationTime] = simulateSkirkDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'escoffier'
            [totalDMG, dps, breakdown, rotationTime] = simulateEscoffierDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'arlecchino'
            [totalDMG, dps, breakdown, rotationTime] = simulateArlecchinoDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'furina'
            [totalDMG, dps, breakdown, rotationTime] = simulateFurinaDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'columbina'
            [totalDMG, dps, breakdown, rotationTime] = simulateColumbinaDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'chasca'
            [totalDMG, dps, breakdown, rotationTime] = simulateChascaDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'lauma'
            [totalDMG, dps, breakdown, rotationTime] = simulateLaumaDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'ineffa'
            [totalDMG, dps, breakdown, rotationTime] = simulateIneffaDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'linnea'
            [totalDMG, dps, breakdown, rotationTime] = simulateLinneaDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'nilou'
            [totalDMG, dps, breakdown, rotationTime] = simulateNilouDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'nefer'
            [totalDMG, dps, breakdown, rotationTime] = simulateNeferDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'flins'
            [totalDMG, dps, breakdown, rotationTime] = simulateFlinsDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'zibai'
            [totalDMG, dps, breakdown, rotationTime] = simulateZibaiDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'mualani'
            [totalDMG, dps, breakdown, rotationTime] = simulateMualaniDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'mavuika'
            [totalDMG, dps, breakdown, rotationTime] = simulateMavuikaDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'citlali'
            [totalDMG, dps, breakdown, rotationTime] = simulateCitlaliDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'xilonen'
            [totalDMG, dps, breakdown, rotationTime] = simulateXilonenDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'neuvillette'
            [totalDMG, dps, breakdown, rotationTime] = simulateNeuvilletteDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'chevreuse'
            [totalDMG, dps, breakdown, rotationTime] = simulateChevreuseDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'iansan'
            [totalDMG, dps, breakdown, rotationTime] = simulateIansanDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'varesa'
            [totalDMG, dps, breakdown, rotationTime] = simulateVaresaDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'durin'
            [totalDMG, dps, breakdown, rotationTime] = simulateDurinDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

        case 'nicole'
            [totalDMG, dps, breakdown, rotationTime] = simulateNicoleDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);

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
