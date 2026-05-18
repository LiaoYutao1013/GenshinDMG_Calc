function [totalDMG, dps, breakdown, rotationTime] = simulateSayuDPS(build, enemy, seqFile, talentLevel, constellation, teamContext)
    % 通用导入角色 DPS 包装器。
    % 当前先接入统一通用模拟主干，后续逐角色细抠后再替换为专用实现。
    [totalDMG, dps, breakdown, rotationTime] = simulateImportedCharacterDPS( ...
        'Sayu', build, enemy, seqFile, talentLevel, constellation, teamContext);
end
