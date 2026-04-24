function result = simulateCharacterDPS(memberCfg, enemy, teamContext)
    % Unified per-character dispatch used by the team-level simulator.
    initProjectPaths();
    if nargin < 3 || isempty(teamContext)
        teamContext = struct('RotationDuration', 20);
    end

    name = char(string(memberCfg.Name));
    switch lower(name)
        case 'skirk'
            % All character simulators return the same four outputs so the
            % aggregation layer can stay generic.
            [totalDMG, dps, breakdown, rotationTime] = simulateSkirkDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'escoffier'
            [totalDMG, dps, breakdown, rotationTime] = simulateEscoffierDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'arlecchino'
            [totalDMG, dps, breakdown, rotationTime] = simulateArlecchinoDPS( ...
                memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'furina'
            % Furina currently consumes team buffs through her build struct
            % rather than an explicit context input, so patch the build
            % before dispatching her simulator.
            teamAdjustedBuild = memberCfg.Build;
            teamAdjustedBuild.HydroDMGBonus = teamAdjustedBuild.HydroDMGBonus + getFieldOrDefault(teamContext, 'AllDMGBonus', 0);
            teamAdjustedBuild.ResShred = teamAdjustedBuild.ResShred + getFieldOrDefault(teamContext, 'HydroResShred', 0);
            [totalDMG, dps, breakdown, rotationTime] = simulateFurinaDPS( ...
                teamAdjustedBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation);
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
