function result = simulateCharacterDPS(memberCfg, enemy, teamContext)
    % 统一的单角色调度入口。
    % 配队模拟只依赖这一层分发，不直接关心每个角色的具体实现文件。
    initProjectPaths();
    if nargin < 3 || isempty(teamContext)
        teamContext = struct('RotationDuration', 20);
    end

    name = char(string(memberCfg.Name));
    % 统一要求所有角色模拟器遵循相同签名，便于团队入口无差别调用。
    switch lower(name)
        case 'skirk'
            [totalDMG, dps, breakdown, rotationTime] = simulateSkirkDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'escoffier'
            [totalDMG, dps, breakdown, rotationTime] = simulateEscoffierDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'arlecchino'
            [totalDMG, dps, breakdown, rotationTime] = simulateArlecchinoDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'furina'
            teamAdjustedBuild = memberCfg.Build;
            teamAdjustedBuild.HydroDMGBonus = teamAdjustedBuild.HydroDMGBonus + getFieldOrDefault(teamContext, 'AllDMGBonus', 0);
            teamAdjustedBuild.ResShred = teamAdjustedBuild.ResShred + getFieldOrDefault(teamContext, 'HydroResShred', 0);
            [totalDMG, dps, breakdown, rotationTime] = simulateFurinaDPS(teamAdjustedBuild, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation);
        case 'lauma'
            [totalDMG, dps, breakdown, rotationTime] = simulateLaumaDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'ineffa'
            [totalDMG, dps, breakdown, rotationTime] = simulateIneffaDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'linnea'
            [totalDMG, dps, breakdown, rotationTime] = simulateLinneaDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'nilou'
            [totalDMG, dps, breakdown, rotationTime] = simulateNilouDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'nefer'
            [totalDMG, dps, breakdown, rotationTime] = simulateNeferDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'flins'
            [totalDMG, dps, breakdown, rotationTime] = simulateFlinsDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'zibai'
            [totalDMG, dps, breakdown, rotationTime] = simulateZibaiDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'mualani'
            [totalDMG, dps, breakdown, rotationTime] = simulateMualaniDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'mavuika'
            [totalDMG, dps, breakdown, rotationTime] = simulateMavuikaDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'citlali'
            [totalDMG, dps, breakdown, rotationTime] = simulateCitlaliDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'xilonen'
            [totalDMG, dps, breakdown, rotationTime] = simulateXilonenDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        case 'neuvillette'
            [totalDMG, dps, breakdown, rotationTime] = simulateNeuvilletteDPS(memberCfg.Build, enemy, memberCfg.RotationFile, memberCfg.TalentLevel, memberCfg.Constellation, teamContext);
        otherwise
            error('No simulator registered for %s', memberCfg.Name);
    end

    % 对所有角色统一封装输出字段，便于后续报表、GUI 和分析脚本复用。
    result = struct('Name', string(memberCfg.Name), 'DisplayName', string(memberCfg.DisplayName), 'TotalDMG', totalDMG, 'DPS', dps, 'RotationTime', rotationTime, 'Breakdown', breakdown);
end
