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
        case {'kamisatoayaka', 'kamisato ayaka', 'ayaka'}
            element = "Cryo";
        case 'jean'
            element = "Anemo";
        case 'lisa'
            element = "Electro";
        case 'barbara'
            element = "Hydro";
        case 'kaeya'
            element = "Cryo";
        case 'diluc'
            element = "Pyro";
        case 'razor'
            element = "Electro";
        case 'amber'
            element = "Pyro";
        case 'venti'
            element = "Anemo";
        case 'xiangling'
            element = "Pyro";
        case {'hutao', 'hu tao'}
            element = "Pyro";
        case 'charlotte'
            element = "Cryo";
        case 'wriothesley'
            element = "Cryo";
        case 'freminet'
            element = "Cryo";
        case {'lyney', 'liney'}
            element = "Pyro";
        case {'lynette', 'linette'}
            element = "Anemo";
        case {'baizhu', 'baizhuer'}
            element = "Dendro";
        case 'kaveh'
            element = "Dendro";
        case 'mika'
            element = "Cryo";
        case 'dehya'
            element = "Pyro";
        case 'alhaitham'
            element = "Dendro";
        case 'yaoyao'
            element = "Dendro";
        case 'faruzan'
            element = "Anemo";
        case 'wanderer'
            element = "Anemo";
        case 'layla'
            element = "Cryo";
        case 'nahida'
            element = "Dendro";
        case 'candace'
            element = "Hydro";
        case 'cyno'
            element = "Electro";
        case 'dori'
            element = "Electro";
        case 'collei'
            element = "Dendro";
        case 'tighnari'
            element = "Dendro";
        case {'kamisatoayato', 'kamisato ayato', 'ayato'}
            element = "Hydro";
        case {'kukishinobu', 'kuki shinobu', 'shinobu'}
            element = "Electro";
        case {'yunjin', 'yun jin'}
            element = "Geo";
        case 'shenhe'
            element = "Cryo";
        case 'yelan'
            element = "Hydro";
        case {'shikanoinheizou', 'shikanoin heizou', 'heizou'}
            element = "Anemo";
        case {'yaemiko', 'yae miko', 'yae'}
            element = "Electro";
        case {'aratakiitto', 'arataki itto', 'itto'}
            element = "Geo";
        case 'gorou'
            element = "Geo";
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
        case {'mizuki', 'yumemizuki mizuki'}
            element = "Anemo";
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
        case 'lohen'
            element = "Cryo";
        case 'illuga'
            element = "Geo";
        case 'prune'
            element = "Anemo";
        case {'lanyan', 'lan yan'}
            element = "Anemo";
        otherwise
            element = "Physical";
    end
end
