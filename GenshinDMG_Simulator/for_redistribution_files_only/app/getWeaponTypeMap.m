function typeCode = getWeaponTypeMap(characterWeaponType)
    % 将角色面板中的武器类型映射到 weapons.csv 的 Type 编码。
    % data/weapons.csv 中：
    % 1 = 单手剑, 2 = 双手剑, 3 = 法器, 4 = 长柄武器, 5 = 弓
    switch lower(char(string(characterWeaponType)))
        case 'sword'
            typeCode = 1;
        case 'claymore'
            typeCode = 2;
        case {'pole', 'polearm'}
            typeCode = 4;
        case 'catalyst'
            typeCode = 3;
        case 'bow'
            typeCode = 5;
        otherwise
            typeCode = [];
    end
end
