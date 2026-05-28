function value = getArtifactMainStatValue(slotName, statType)
    % 返回五星圣遗物在指定部位、指定主词条下的主词条数值。
    % 工程内部统一使用“最终可直接相加到 build 字段上的数值口径”：
    % 1. 攻击/生命/防御百分比直接返回 0.466；
    % 2. 暴击率/暴击伤害/充能/治疗加成返回其面板小数值；
    % 3. 花和羽固定返回平坦生命/攻击；
    % 4. 传入空字符串或 None 时返回 0，便于做兜底处理。
    slotName = string(slotName);
    statType = string(statType);

    if strlength(statType) == 0 || any(strcmpi(char(statType), {'None', 'Off'}))
        value = 0;
        return;
    end

    switch lower(char(slotName))
        case 'flower'
            value = 4780;
            return;

        case 'feather'
            value = 311;
            return;
    end

    switch lower(char(statType))
        case {'atkpct', 'atkbonus'}
            value = 0.466;
        case {'hppct', 'hpbonus'}
            value = 0.466;
        case {'defpct', 'defbonus'}
            value = 0.466;
        case {'er', 'energyrecharge'}
            value = 0.518;
        case {'em', 'elementalmastery'}
            value = 187;
        case {'critrate', 'cr'}
            value = 0.311;
        case {'critdmg', 'cd'}
            value = 0.622;
        case {'healingbonus', 'heal'}
            value = 0.359;
        case {'pyrodmgbonus', 'hydrodmgbonus', 'cryodmgbonus', 'electrodmgbonus', ...
                'anemodmgbonus', 'geodmgbonus', 'dendrodmgbonus'}
            value = 0.466;
        case {'physicaldmgbonus'}
            value = 0.583;
        case {'flatatk'}
            value = 311;
        case {'flathp'}
            value = 4780;
        otherwise
            value = 0;
    end
end
