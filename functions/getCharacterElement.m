function element = getCharacterElement(name)
    % 将统一入口角色名映射为元素类型。
    switch lower(char(string(name)))
        case 'skirk'
            element = "Cryo";
        case 'escoffier'
            element = "Cryo";
        case 'arlecchino'
            element = "Pyro";
        case 'furina'
            element = "Hydro";
        case 'chasca'
            element = "Anemo";
        case 'columbina'
            element = "Hydro";
        case 'lauma'
            element = "Dendro";
        case 'ineffa'
            element = "Electro";
        case 'linnea'
            element = "Geo";
        case 'nilou'
            element = "Hydro";
        case 'nefer'
            element = "Dendro";
        case 'flins'
            element = "Electro";
        case 'zibai'
            element = "Geo";
        case 'mualani'
            element = "Hydro";
        case 'mavuika'
            element = "Pyro";
        case 'citlali'
            element = "Cryo";
        case 'xilonen'
            element = "Geo";
        case 'neuvillette'
            element = "Hydro";
        case 'chevreuse'
            element = "Pyro";
        case 'iansan'
            element = "Electro";
        case 'varesa'
            element = "Electro";
        case 'durin'
            element = "Pyro";
        case 'nicole'
            element = "Pyro";
        case 'xianyun'
            element = "Anemo";
        case 'navia'
            element = "Geo";
        case 'gaming'
            element = "Pyro";
        case 'chiori'
            element = "Geo";
        case 'sigewinne'
            element = "Hydro";
        case 'clorinde'
            element = "Electro";
        case 'emilie'
            element = "Dendro";
        case 'kachina'
            element = "Geo";
        case 'kinich'
            element = "Dendro";
        case 'sethos'
            element = "Electro";
        case 'ororon'
            element = "Electro";
        case 'ifa'
            element = "Anemo";
        case 'dahlia'
            element = "Hydro";
        case 'jahoda'
            element = "Anemo";
        case 'aino'
            element = "Hydro";
        case 'varka'
            element = "Anemo";
        case 'illuga'
            element = "Geo";
        case 'lanyan'
            element = "Anemo";
        otherwise
            element = "Physical";
    end
end
