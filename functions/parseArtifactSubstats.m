function contribution = parseArtifactSubstats(raw)
    % Parse one artifact piece substat payload into the shared build field format.
    contribution = localEmptyStatStruct();
    if nargin < 1 || isempty(raw)
        return;
    end

    if isstruct(raw)
        fields = fieldnames(raw);
        for i = 1:numel(fields)
            fieldName = fields{i};
            contribution = localAccumulateStat(contribution, fieldName, raw.(fieldName));
        end
        return;
    end

    if iscell(raw)
        raw = string(raw);
        raw = strjoin(raw, ";");
    end

    if isstring(raw)
        raw = char(join(raw, ";"));
    end

    if ~ischar(raw)
        return;
    end

    raw = strtrim(raw);
    if isempty(raw)
        return;
    end

    raw = strrep(raw, sprintf('\r\n'), ';');
    raw = strrep(raw, sprintf('\n'), ';');
    raw = strrep(raw, sprintf('\r'), ';');
    tokens = regexp(raw, '[;|]+', 'split');
    for i = 1:numel(tokens)
        token = strtrim(tokens{i});
        if isempty(token)
            continue;
        end

        parts = regexp(token, ...
            '^\s*([A-Za-z][A-Za-z0-9_%]*)\s*[:=]\s*([-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)\s*$', ...
            'tokens', 'once');
        if isempty(parts)
            continue;
        end

        statType = parts{1};
        statValue = str2double(parts{2});
        if isnan(statValue)
            continue;
        end
        contribution = localAccumulateStat(contribution, statType, statValue);
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
        case {'atkpct', 'atkbonus', 'atk%'}
            contribution.AtkBonus = contribution.AtkBonus + statValue;
        case {'hppct', 'hpbonus', 'hp%'}
            contribution.HPBonus = contribution.HPBonus + statValue;
        case {'defpct', 'defbonus', 'def%'}
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
        case {'normaldmgbonus'}
            contribution.NormalDMGBonus = contribution.NormalDMGBonus + statValue;
        case {'chargedmgbonus'}
            contribution.ChargeDMGBonus = contribution.ChargeDMGBonus + statValue;
        case {'chargeddmgbonus'}
            contribution.ChargedDMGBonus = contribution.ChargedDMGBonus + statValue;
        case {'plungedmgbonus'}
            contribution.PlungeDMGBonus = contribution.PlungeDMGBonus + statValue;
        case {'skilldmgbonus'}
            contribution.SkillDMGBonus = contribution.SkillDMGBonus + statValue;
        case {'burstdmgbonus'}
            contribution.BurstDMGBonus = contribution.BurstDMGBonus + statValue;
        case {'resshred'}
            contribution.ResShred = contribution.ResShred + statValue;
    end
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
