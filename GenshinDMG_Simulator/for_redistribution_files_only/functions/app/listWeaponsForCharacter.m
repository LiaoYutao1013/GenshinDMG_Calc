function weaponList = listWeaponsForCharacter(characterName)
    % 根据角色武器类型过滤 data/weapons.csv，供 GUI 下拉框使用。
    initProjectPaths();

    registry = getCharacterRegistry();
    keys = string({registry.Key});
    idx = find(keys == string(characterName), 1, 'first');
    if isempty(idx)
        weaponList = table();
        return;
    end

    typeCode = getWeaponTypeMap(registry(idx).WeaponType);
    weaponPath = fullfile(fileparts(fileparts(mfilename('fullpath'))), '..', 'data', 'weapons.csv');
    weaponPath = char(java.io.File(weaponPath).getCanonicalPath());
    weapons = readtable(weaponPath, 'TextType', 'string');

    if isempty(typeCode)
        weaponList = weapons;
    else
        weaponList = weapons(weapons.Type == typeCode, :);
    end

    weaponList = sortrows(weaponList, {'Rank', 'BaseATK'}, {'descend', 'descend'});
end
