function bonus = getCharacterAscensionBonus(characterName)
    % 读取角色突破词条，并转换成 build 的统一字段口径。
    % 同时补上工程内默认使用的面板基础值：
    % 1. 暴击率基础 5%；
    % 2. 暴击伤害基础 50%；
    % 3. 元素充能效率基础 100%。
    initProjectPaths();

    bonus = localEmptyStatStruct();
    bonus.CritRate = 0.05;
    bonus.CritDMG = 0.50;
    bonus.ER = 1.00;

    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    charFolder = fullfile(projectRoot, 'data', char(string(characterName)));
    files = dir(fullfile(charFolder, 'characters_*.csv'));
    if isempty(files)
        return;
    end

    tbl = readtable(fullfile(files(1).folder, files(1).name), 'TextType', 'string');
    if isempty(tbl)
        return;
    end

    row = tbl(1, :);
    typeCode = localResolveAscensionType(row);
    value = localResolveNumericField(row, 'AscensionValue', 0);
    value = localNormalizeAscensionValue(typeCode, value);

    switch upper(char(typeCode))
        case {'CR', 'CRITRATE'}
            bonus.CritRate = bonus.CritRate + value;
        case {'CD', 'CRITDMG'}
            bonus.CritDMG = bonus.CritDMG + value;
        case {'ATK', 'ATKPCT', 'ATKBONUS'}
            bonus.AtkBonus = bonus.AtkBonus + value;
        case {'HP', 'HPPCT', 'HPBONUS'}
            bonus.HPBonus = bonus.HPBonus + value;
        case {'DEF', 'DEFPCT', 'DEFBONUS'}
            bonus.DEFBonus = bonus.DEFBonus + value;
        case {'ER', 'ENERGYRECHARGE'}
            bonus.ER = bonus.ER + value;
        case {'EM', 'ELEMENTALMASTERY'}
            bonus.EM = bonus.EM + value;
        case {'HEAL', 'HEALINGBONUS', 'HB'}
            bonus.HealingBonus = bonus.HealingBonus + value;
        case {'PYRO', 'PYRODMG', 'PYRODMGBONUS'}
            bonus.PyroDMGBonus = bonus.PyroDMGBonus + value;
        case {'HYDRO', 'HYDRODMG', 'HYDRODMGBONUS'}
            bonus.HydroDMGBonus = bonus.HydroDMGBonus + value;
        case {'CRYO', 'CRYODMG', 'CRYODMGBONUS'}
            bonus.CryoDMGBonus = bonus.CryoDMGBonus + value;
        case {'ELECTRO', 'ELECTRODMG', 'ELECTRODMGBONUS'}
            bonus.ElectroDMGBonus = bonus.ElectroDMGBonus + value;
        case {'ANEMO', 'ANEMODMG', 'ANEMODMGBONUS'}
            bonus.AnemoDMGBonus = bonus.AnemoDMGBonus + value;
        case {'GEO', 'GEODMG', 'GEODMGBONUS'}
            bonus.GeoDMGBonus = bonus.GeoDMGBonus + value;
        case {'DENDRO', 'DENDRODMG', 'DENDRODMGBONUS'}
            bonus.DendroDMGBonus = bonus.DendroDMGBonus + value;
    end
end

function typeCode = localResolveAscensionType(row)
    vars = row.Properties.VariableNames;
    tokens = strings(1, 0);
    for i = 1:numel(vars)
        varName = vars{i};
        if startsWith(varName, 'AscensionType', 'IgnoreCase', true)
            token = localToToken(row.(varName));
            if strlength(token) > 0
                tokens(end + 1) = token; %#ok<AGROW>
            end
        end
    end

    if isempty(tokens) && any(strcmpi(vars, 'AscensionType'))
        tokens = localToToken(row.AscensionType);
    end

    typeCode = join(tokens, "");
end

function token = localToToken(value)
    if iscell(value)
        value = value{1};
    end
    if isstring(value)
        value = char(value);
    end
    if isnumeric(value)
        token = string(value);
        return;
    end

    token = upper(regexprep(string(strtrim(value)), '[^A-Za-z]', ''));
end

function value = localResolveNumericField(row, fieldName, defaultValue)
    if any(strcmpi(row.Properties.VariableNames, fieldName))
        raw = row.(fieldName);
        if iscell(raw)
            raw = raw{1};
        end
        if isstring(raw)
            raw = str2double(raw);
        end
        if isnumeric(raw) && isfinite(raw)
            value = double(raw);
            return;
        end
    end
    value = defaultValue;
end

function value = localNormalizeAscensionValue(typeCode, value)
    % 角色突破词条在 CSV 中通常按“百分数面板值”存储，例如：
    % 19.2 => 19.2% 暴击率，24 => 24% 元素伤害加成。
    % build 口径统一使用小数，因此这里需要做一次归一化。
    typeCode = upper(char(string(typeCode)));
    if ~isfinite(value)
        value = 0;
        return;
    end

    switch typeCode
        case {'CR', 'CRITRATE', 'CD', 'CRITDMG', ...
                'ATK', 'ATKPCT', 'ATKBONUS', ...
                'HP', 'HPPCT', 'HPBONUS', ...
                'DEF', 'DEFPCT', 'DEFBONUS', ...
                'ER', 'ENERGYRECHARGE', ...
                'HEAL', 'HEALINGBONUS', 'HB', ...
                'PYRO', 'PYRODMG', 'PYRODMGBONUS', ...
                'HYDRO', 'HYDRODMG', 'HYDRODMGBONUS', ...
                'CRYO', 'CRYODMG', 'CRYODMGBONUS', ...
                'ELECTRO', 'ELECTRODMG', 'ELECTRODMGBONUS', ...
                'ANEMO', 'ANEMODMG', 'ANEMODMGBONUS', ...
                'GEO', 'GEODMG', 'GEODMGBONUS', ...
                'DENDRO', 'DENDRODMG', 'DENDRODMGBONUS'}
            if abs(value) > 1
                value = value / 100;
            end
        otherwise
            % 元素精通等非百分比词条保持原值。
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
