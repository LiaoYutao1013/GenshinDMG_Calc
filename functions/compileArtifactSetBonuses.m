function build = compileArtifactSetBonuses(characterName, build, teamContext)
    % 将“默认构筑/GUI 构筑”统一编译为角色模拟器直接消费的最终 build。
    % 新的编译链分三层：
    % 1. 规范化：补齐五件分件、套装条件与兼容字段；
    % 2. 去预烘焙：从旧 aggregate build 中扣除主词条/突破/武器副词条/可显式识别的套装收益；
    % 3. 重组面板：基线残差 + 主词条 + 显式套装收益。
    if nargin < 3 || isempty(teamContext)
        teamContext = struct();
    end

    normalized = materializeArtifactPieceModel(characterName, build, teamContext);
    if ~logical(getFieldOrDefault(normalized, 'ArtifactUsePieceModel', 1))
        build = localApplySetBonusOnly(characterName, normalized, teamContext);
        return;
    end

    pieceContribution = localCollectArtifactPieceContribution(normalized);
    ascensionContribution = getCharacterAscensionBonus(characterName);
    weaponContribution = getWeaponSubstatBonus(normalized);

    setContribution = localEmptyStatStruct();
    legacySetContribution = localEmptyStatStruct();
    if logical(getFieldOrDefault(normalized, 'ArtifactApplySetBonuses', 0))
        setContribution = getArtifactSetBonusContribution(characterName, normalized, teamContext);
        legacySetContribution = getArtifactLegacySetContribution(characterName, normalized, teamContext);
    end

    baselineFields = localTrackedFields();
    compiled = normalized;

    for i = 1:numel(baselineFields)
        fieldName = baselineFields{i};
        if strcmp(fieldName, 'ER')
            legacyValue = getFieldOrDefault(normalized, fieldName, 1.0);
        else
            legacyValue = getFieldOrDefault(normalized, fieldName, 0);
        end
        baselineValue = legacyValue ...
            - getFieldOrDefault(pieceContribution, fieldName, 0) ...
            - getFieldOrDefault(ascensionContribution, fieldName, 0) ...
            - getFieldOrDefault(weaponContribution, fieldName, 0) ...
            - getFieldOrDefault(legacySetContribution, fieldName, 0);

        baselineValue = max(0, baselineValue);

        compiled.(fieldName) = baselineValue ...
            + getFieldOrDefault(pieceContribution, fieldName, 0) ...
            + getFieldOrDefault(ascensionContribution, fieldName, 0) ...
            + getFieldOrDefault(weaponContribution, fieldName, 0) ...
            + getFieldOrDefault(setContribution, fieldName, 0);
        if strcmp(fieldName, 'ER')
            compiled.(fieldName) = max(1.0, compiled.(fieldName));
        end
        compiled.(['ArtifactBaseline_' fieldName]) = baselineValue;
    end

    build = compiled;
end

function build = localApplySetBonusOnly(characterName, build, teamContext)
    setContribution = getArtifactSetBonusContribution(characterName, build, teamContext);
    fields = fieldnames(setContribution);
    for i = 1:numel(fields)
        fieldName = fields{i};
        build.(fieldName) = getFieldOrDefault(build, fieldName, 0) + setContribution.(fieldName);
    end
end

function contribution = localCollectArtifactPieceContribution(build)
    contribution = localEmptyStatStruct();
    slotNames = {'Flower', 'Feather', 'Sands', 'Goblet', 'Circlet'};
    suffixes = {'FlatATK', 'FlatHP', 'FlatDEF', 'AtkBonus', 'HPBonus', 'DEFBonus', ...
        'ER', 'EM', 'CritRate', 'CritDMG', 'HealingBonus', 'PyroDMGBonus', ...
        'HydroDMGBonus', 'CryoDMGBonus', 'ElectroDMGBonus', 'AnemoDMGBonus', ...
        'GeoDMGBonus', 'DendroDMGBonus', 'NormalDMGBonus', 'ChargeDMGBonus', ...
        'ChargedDMGBonus', 'PlungeDMGBonus', 'SkillDMGBonus', 'BurstDMGBonus', 'ResShred'};
    for i = 1:numel(slotNames)
        mainTypeField = sprintf('Artifact%sMainStat', slotNames{i});
        mainValueField = sprintf('Artifact%sMainValue', slotNames{i});
        statType = string(getFieldOrDefault(build, mainTypeField, ""));
        statValue = double(getFieldOrDefault(build, mainValueField, 0));
        contribution = localAccumulateStat(contribution, statType, statValue);

        hasExplicitNumericSubstats = false;
        for j = 1:numel(suffixes)
            valueField = sprintf('Artifact%sSubstat%s', slotNames{i}, suffixes{j});
            statValue = double(getFieldOrDefault(build, valueField, 0));
            if abs(statValue) <= 1e-9
                continue;
            end
            hasExplicitNumericSubstats = true;
            contribution = localAccumulateStat(contribution, suffixes{j}, statValue);
        end

        if ~hasExplicitNumericSubstats
            summaryField = sprintf('Artifact%sSubstats', slotNames{i});
            summaryContribution = parseArtifactSubstats(getFieldOrDefault(build, summaryField, ""));
            contribution = localAddStatStruct(contribution, summaryContribution);
        end
    end
end

function contribution = localAccumulateStat(contribution, statType, statValue)
    statType = string(statType);
    switch lower(char(statType))
        case {'flatatk'}
            contribution.FlatATK = contribution.FlatATK + statValue;
        case {'flathp'}
            contribution.FlatHP = contribution.FlatHP + statValue;
        case {'flatdef'}
            contribution.FlatDEF = contribution.FlatDEF + statValue;
        case {'atkpct', 'atkbonus'}
            contribution.AtkBonus = contribution.AtkBonus + statValue;
        case {'hppct', 'hpbonus'}
            contribution.HPBonus = contribution.HPBonus + statValue;
        case {'defpct', 'defbonus'}
            contribution.DEFBonus = contribution.DEFBonus + statValue;
        case {'er', 'energyrecharge'}
            contribution.ER = contribution.ER + statValue;
        case {'em', 'elementalmastery'}
            contribution.EM = contribution.EM + statValue;
        case {'critrate', 'cr'}
            contribution.CritRate = contribution.CritRate + statValue;
        case {'critdmg', 'cd'}
            contribution.CritDMG = contribution.CritDMG + statValue;
        case {'healingbonus', 'heal'}
            contribution.HealingBonus = contribution.HealingBonus + statValue;
        case {'pyrodmgbonus'}
            contribution.PyroDMGBonus = contribution.PyroDMGBonus + statValue;
        case {'hydrodmgbonus'}
            contribution.HydroDMGBonus = contribution.HydroDMGBonus + statValue;
        case {'cryodmgbonus'}
            contribution.CryoDMGBonus = contribution.CryoDMGBonus + statValue;
        case {'electrodmgbonus'}
            contribution.ElectroDMGBonus = contribution.ElectroDMGBonus + statValue;
        case {'anemodmgbonus'}
            contribution.AnemoDMGBonus = contribution.AnemoDMGBonus + statValue;
        case {'geodmgbonus'}
            contribution.GeoDMGBonus = contribution.GeoDMGBonus + statValue;
        case {'dendrodmgbonus'}
            contribution.DendroDMGBonus = contribution.DendroDMGBonus + statValue;
    end
end

function fields = localTrackedFields()
    fields = { ...
        'AtkBonus', 'FlatATK', ...
        'HPBonus', 'FlatHP', ...
        'DEFBonus', 'FlatDEF', ...
        'ER', 'EM', ...
        'CritRate', 'CritDMG', ...
        'PyroDMGBonus', 'HydroDMGBonus', 'CryoDMGBonus', ...
        'ElectroDMGBonus', 'AnemoDMGBonus', 'GeoDMGBonus', 'DendroDMGBonus', ...
        'NormalDMGBonus', 'ChargeDMGBonus', 'ChargedDMGBonus', 'PlungeDMGBonus', ...
        'SkillDMGBonus', 'BurstDMGBonus', 'HealingBonus', 'ResShred'};
end

function stats = localEmptyStatStruct()
    stats = struct( ...
        'AtkBonus', 0, ...
        'FlatATK', 0, ...
        'HPBonus', 0, ...
        'FlatHP', 0, ...
        'DEFBonus', 0, ...
        'FlatDEF', 0, ...
        'ER', 0, ...
        'EM', 0, ...
        'CritRate', 0, ...
        'CritDMG', 0, ...
        'PyroDMGBonus', 0, ...
        'HydroDMGBonus', 0, ...
        'CryoDMGBonus', 0, ...
        'ElectroDMGBonus', 0, ...
        'AnemoDMGBonus', 0, ...
        'GeoDMGBonus', 0, ...
        'DendroDMGBonus', 0, ...
        'NormalDMGBonus', 0, ...
        'ChargeDMGBonus', 0, ...
        'ChargedDMGBonus', 0, ...
        'PlungeDMGBonus', 0, ...
        'SkillDMGBonus', 0, ...
        'BurstDMGBonus', 0, ...
        'HealingBonus', 0, ...
        'ResShred', 0);
end

function merged = localAddStatStruct(merged, incoming)
    fields = fieldnames(incoming);
    for i = 1:numel(fields)
        fieldName = fields{i};
        merged.(fieldName) = getFieldOrDefault(merged, fieldName, 0) + getFieldOrDefault(incoming, fieldName, 0);
    end
end
