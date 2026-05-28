function bonus = getWeaponSubstatBonus(build)
    % 将武器副词条转换为 build 统一字段。
    % 当前工程里很多旧默认 build 只有 WeaponATK，没有副词条类型；此时这里返回 0，
    % 由基线校准逻辑把缺失部分继续留在默认残差中，避免强行猜错。
    bonus = localEmptyStatStruct();

    subType = string(getFieldOrDefault(build, 'WeaponSubStatType', ""));
    subValue = double(getFieldOrDefault(build, 'WeaponSubStatValue', 0));
    if strlength(subType) == 0 || subValue == 0
        [subType, subValue] = localTryLookupWeaponSubstat(build);
    end

    if strlength(subType) == 0 || subValue == 0
        return;
    end

    switch upper(char(subType))
        case {'CR', 'CRITRATE'}
            bonus.CritRate = subValue;
        case {'CD', 'CRITDMG'}
            bonus.CritDMG = subValue;
        case {'ATK', 'ATK%'}
            bonus.AtkBonus = subValue;
        case {'HP', 'HP%'}
            bonus.HPBonus = subValue;
        case {'DEF', 'DEF%'}
            bonus.DEFBonus = subValue;
        case {'ER', 'ENERGYRECHARGE'}
            bonus.ER = subValue;
        case {'EM', 'ELEMENTALMASTERY'}
            bonus.EM = subValue;
        case {'HB', 'HEAL', 'HEALINGBONUS'}
            bonus.HealingBonus = subValue;
    end
end

function [subType, subValue] = localTryLookupWeaponSubstat(build)
    subType = "";
    subValue = 0;
    weaponName = string(getFieldOrDefault(build, 'Weapon', ""));
    if strlength(weaponName) == 0
        return;
    end

    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    weaponPath = fullfile(projectRoot, 'data', 'weapons.csv');
    if exist(weaponPath, 'file') ~= 2
        return;
    end

    weapons = readtable(weaponPath, 'TextType', 'string');
    idx = find(weapons.Name == weaponName, 1, 'first');
    if isempty(idx)
        return;
    end

    subType = weapons.SubstatType(idx);
    subValue = weapons.SubstatValue(idx);
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
