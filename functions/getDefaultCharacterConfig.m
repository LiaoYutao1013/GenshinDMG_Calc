function cfg = getDefaultCharacterConfig(name, overrides)
    % Unified default config registry for standalone and team entries.
    initProjectPaths();
    if nargin < 2
        overrides = struct();
    end

    funcFolder = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(funcFolder);
    key = lower(strtrim(char(string(name))));

    switch key
        case {'odette'}
            cfg = localBaseConfig('Odette', customArtifact_Odette(), fullfile(projectRoot, 'data', 'Odette', 'rotation_Odette.txt'));

        case {'alyosha'}
            cfg = localBaseConfig('Alyosha', customArtifact_Alyosha(), fullfile(projectRoot, 'data', 'Alyosha', 'rotation_Alyosha.txt'));

        case {'skirk'}
            cfg = localBaseConfig('Skirk', customArtifact_Skirk(), fullfile(projectRoot, 'data', 'Skirk', 'rotation_Skirk.txt'));

        case {'escoffier'}
            cfg = localBaseConfig('Escoffier', customArtifact_Escoffier(), fullfile(projectRoot, 'data', 'Escoffier', 'rotation_Escoffier.txt'));

        case {'arlecchino'}
            cfg = localBaseConfig('Arlecchino', customArtifact_Arlecchino(), fullfile(projectRoot, 'data', 'Arlecchino', 'rotation_Arlecchino.txt'));

        case {'furina'}
            cfg = localBaseConfig('Furina', customArtifact_Furina(), fullfile(projectRoot, 'data', 'Furina', 'rotation_Furina.txt'));
            cfg.Constellation = 6;

        case {'columbina'}
            cfg = localBaseConfig('Columbina', customArtifact_Columbina(), fullfile(projectRoot, 'data', 'Columbina', 'rotation_Columbina.txt'));

        case {'chasca', 'qiasika'}
            cfg = localBaseConfig('Chasca', customArtifact_Chasca(), fullfile(projectRoot, 'data', 'Chasca', 'rotation_Chasca.txt'));

        case {'lauma'}
            cfg = localBaseConfig('Lauma', customArtifact_Lauma(), fullfile(projectRoot, 'data', 'Lauma', 'rotation_Lauma.txt'));

        case {'ineffa'}
            cfg = localBaseConfig('Ineffa', customArtifact_Ineffa(), fullfile(projectRoot, 'data', 'Ineffa', 'rotation_Ineffa.txt'));

        case {'linnea', 'linnia'}
            cfg = localBaseConfig('Linnea', customArtifact_Linnea(), fullfile(projectRoot, 'data', 'Linnea', 'rotation_Linnea.txt'));

        case {'nilou'}
            cfg = localBaseConfig('Nilou', customArtifact_Nilou(), fullfile(projectRoot, 'data', 'Nilou', 'rotation_Nilou.txt'));

        case {'nefer'}
            cfg = localBaseConfig('Nefer', customArtifact_Nefer(), fullfile(projectRoot, 'data', 'Nefer', 'rotation_Nefer.txt'));

        case {'flins'}
            cfg = localBaseConfig('Flins', customArtifact_Flins(), fullfile(projectRoot, 'data', 'Flins', 'rotation_Flins.txt'));

        case {'zibai'}
            cfg = localBaseConfig('Zibai', customArtifact_Zibai(), fullfile(projectRoot, 'data', 'Zibai', 'rotation_Zibai.txt'));

        case {'mualani'}
            cfg = localBaseConfig('Mualani', customArtifact_Mualani(), fullfile(projectRoot, 'data', 'Mualani', 'rotation_Mualani.txt'));

        case {'mavuika'}
            cfg = localBaseConfig('Mavuika', customArtifact_Mavuika(), fullfile(projectRoot, 'data', 'Mavuika', 'rotation_Mavuika.txt'));

        case {'citlali'}
            cfg = localBaseConfig('Citlali', customArtifact_Citlali(), fullfile(projectRoot, 'data', 'Citlali', 'rotation_Citlali.txt'));

        case {'xilonen'}
            cfg = localBaseConfig('Xilonen', customArtifact_Xilonen(), fullfile(projectRoot, 'data', 'Xilonen', 'rotation_Xilonen.txt'));

        case {'neuvillette'}
            cfg = localBaseConfig('Neuvillette', customArtifact_Neuvillette(), fullfile(projectRoot, 'data', 'Neuvillette', 'rotation_Neuvillette.txt'));

        case {'chevreuse'}
            cfg = localBaseConfig('Chevreuse', customArtifact_Chevreuse(), fullfile(projectRoot, 'data', 'Chevreuse', 'rotation_Chevreuse.txt'));

        case {'iansan'}
            cfg = localBaseConfig('Iansan', customArtifact_Iansan(), fullfile(projectRoot, 'data', 'Iansan', 'rotation_Iansan.txt'));

        case {'varesa'}
            cfg = localBaseConfig('Varesa', customArtifact_Varesa(), fullfile(projectRoot, 'data', 'Varesa', 'rotation_Varesa.txt'));

        case {'durin'}
            cfg = localBaseConfig('Durin', customArtifact_Durin(), fullfile(projectRoot, 'data', 'Durin', 'rotation_Durin.txt'));

        case {'nicole'}
            cfg = localBaseConfig('Nicole', customArtifact_Nicole(), fullfile(projectRoot, 'data', 'Nicole', 'rotation_Nicole.txt'));

        case {'sandrone', 'marionettenew'}
            cfg = localBaseConfig('Sandrone', customArtifact_Sandrone(), fullfile(projectRoot, 'data', 'Sandrone', 'rotation_Sandrone.txt'));

        case {'kamisato ayaka', 'ayaka', 'kamisatoayaka'}
            cfg = localBaseConfig('KamisatoAyaka', customArtifact_KamisatoAyaka(), fullfile(projectRoot, 'data', 'KamisatoAyaka', 'rotation_KamisatoAyaka.txt'));

        case {'jean'}
            cfg = localBaseConfig('Jean', customArtifact_Jean(), fullfile(projectRoot, 'data', 'Jean', 'rotation_Jean.txt'));

        case {'lisa'}
            cfg = localBaseConfig('Lisa', customArtifact_Lisa(), fullfile(projectRoot, 'data', 'Lisa', 'rotation_Lisa.txt'));

        case {'barbara'}
            cfg = localBaseConfig('Barbara', customArtifact_Barbara(), fullfile(projectRoot, 'data', 'Barbara', 'rotation_Barbara.txt'));

        case {'kaeya'}
            cfg = localBaseConfig('Kaeya', customArtifact_Kaeya(), fullfile(projectRoot, 'data', 'Kaeya', 'rotation_Kaeya.txt'));

        case {'diluc'}
            cfg = localBaseConfig('Diluc', customArtifact_Diluc(), fullfile(projectRoot, 'data', 'Diluc', 'rotation_Diluc.txt'));

        case {'razor'}
            cfg = localBaseConfig('Razor', customArtifact_Razor(), fullfile(projectRoot, 'data', 'Razor', 'rotation_Razor.txt'));

        case {'amber'}
            cfg = localBaseConfig('Amber', customArtifact_Amber(), fullfile(projectRoot, 'data', 'Amber', 'rotation_Amber.txt'));

        case {'venti'}
            cfg = localBaseConfig('Venti', customArtifact_Venti(), fullfile(projectRoot, 'data', 'Venti', 'rotation_Venti.txt'));

        case {'xiangling'}
            cfg = localBaseConfig('Xiangling', customArtifact_Xiangling(), fullfile(projectRoot, 'data', 'Xiangling', 'rotation_Xiangling.txt'));

        case {'fischl'}
            cfg = localBaseConfig('Fischl', customArtifact_Fischl(), fullfile(projectRoot, 'data', 'Fischl', 'rotation_Fischl.txt'));

        case {'beidou'}
            cfg = localBaseConfig('Beidou', customArtifact_Beidou(), fullfile(projectRoot, 'data', 'Beidou', 'rotation_Beidou.txt'));

        case {'hutao', 'hu tao'}
            cfg = localBaseConfig('Hutao', customArtifact_Hutao(), fullfile(projectRoot, 'data', 'Hutao', 'rotation_Hutao.txt'));
            cfg.DisplayName = "Hu Tao";

        case {'charlotte'}
            cfg = localBaseConfig('Charlotte', customArtifact_Charlotte(), fullfile(projectRoot, 'data', 'Charlotte', 'rotation_Charlotte.txt'));

        case {'wriothesley'}
            cfg = localBaseConfig('Wriothesley', customArtifact_Wriothesley(), fullfile(projectRoot, 'data', 'Wriothesley', 'rotation_Wriothesley.txt'));

        case {'freminet'}
            cfg = localBaseConfig('Freminet', customArtifact_Freminet(), fullfile(projectRoot, 'data', 'Freminet', 'rotation_Freminet.txt'));

        case {'lyney', 'liney'}
            cfg = localBaseConfig('Lyney', customArtifact_Lyney(), fullfile(projectRoot, 'data', 'Lyney', 'rotation_Lyney.txt'));

        case {'lynette', 'linette'}
            cfg = localBaseConfig('Lynette', customArtifact_Lynette(), fullfile(projectRoot, 'data', 'Lynette', 'rotation_Lynette.txt'));

        case {'baizhu', 'baizhuer'}
            cfg = localBaseConfig('Baizhu', customArtifact_Baizhu(), fullfile(projectRoot, 'data', 'Baizhu', 'rotation_Baizhu.txt'));

        case {'kaveh'}
            cfg = localBaseConfig('Kaveh', customArtifact_Kaveh(), fullfile(projectRoot, 'data', 'Kaveh', 'rotation_Kaveh.txt'));

        case {'mika'}
            cfg = localBaseConfig('Mika', customArtifact_Mika(), fullfile(projectRoot, 'data', 'Mika', 'rotation_Mika.txt'));

        case {'dehya'}
            cfg = localBaseConfig('Dehya', customArtifact_Dehya(), fullfile(projectRoot, 'data', 'Dehya', 'rotation_Dehya.txt'));

        case {'alhaitham'}
            cfg = localBaseConfig('Alhaitham', customArtifact_Alhaitham(), fullfile(projectRoot, 'data', 'Alhaitham', 'rotation_Alhaitham.txt'));

        case {'yaoyao'}
            cfg = localBaseConfig('Yaoyao', customArtifact_Yaoyao(), fullfile(projectRoot, 'data', 'Yaoyao', 'rotation_Yaoyao.txt'));

        case {'faruzan'}
            cfg = localBaseConfig('Faruzan', customArtifact_Faruzan(), fullfile(projectRoot, 'data', 'Faruzan', 'rotation_Faruzan.txt'));

        case {'wanderer'}
            cfg = localBaseConfig('Wanderer', customArtifact_Wanderer(), fullfile(projectRoot, 'data', 'Wanderer', 'rotation_Wanderer.txt'));

        case {'layla'}
            cfg = localBaseConfig('Layla', customArtifact_Layla(), fullfile(projectRoot, 'data', 'Layla', 'rotation_Layla.txt'));

        case {'nahida'}
            cfg = localBaseConfig('Nahida', customArtifact_Nahida(), fullfile(projectRoot, 'data', 'Nahida', 'rotation_Nahida.txt'));

        case {'candace'}
            cfg = localBaseConfig('Candace', customArtifact_Candace(), fullfile(projectRoot, 'data', 'Candace', 'rotation_Candace.txt'));

        case {'cyno'}
            cfg = localBaseConfig('Cyno', customArtifact_Cyno(), fullfile(projectRoot, 'data', 'Cyno', 'rotation_Cyno.txt'));

        case {'dori'}
            cfg = localBaseConfig('Dori', customArtifact_Dori(), fullfile(projectRoot, 'data', 'Dori', 'rotation_Dori.txt'));

        case {'collei'}
            cfg = localBaseConfig('Collei', customArtifact_Collei(), fullfile(projectRoot, 'data', 'Collei', 'rotation_Collei.txt'));

        case {'tighnari'}
            cfg = localBaseConfig('Tighnari', customArtifact_Tighnari(), fullfile(projectRoot, 'data', 'Tighnari', 'rotation_Tighnari.txt'));

        case {'kamisato ayato', 'ayato', 'kamisatoayato'}
            cfg = localBaseConfig('KamisatoAyato', customArtifact_KamisatoAyato(), fullfile(projectRoot, 'data', 'KamisatoAyato', 'rotation_KamisatoAyato.txt'));

        case {'kuki shinobu', 'shinobu', 'kukishinobu'}
            cfg = localBaseConfig('KukiShinobu', customArtifact_KukiShinobu(), fullfile(projectRoot, 'data', 'KukiShinobu', 'rotation_KukiShinobu.txt'));

        case {'yun jin', 'yunjin'}
            cfg = localBaseConfig('YunJin', customArtifact_YunJin(), fullfile(projectRoot, 'data', 'YunJin', 'rotation_YunJin.txt'));

        case {'shenhe'}
            cfg = localBaseConfig('Shenhe', customArtifact_Shenhe(), fullfile(projectRoot, 'data', 'Shenhe', 'rotation_Shenhe.txt'));

        case {'yelan'}
            cfg = localBaseConfig('Yelan', customArtifact_Yelan(), fullfile(projectRoot, 'data', 'Yelan', 'rotation_Yelan.txt'));

        case {'shikanoin heizou', 'heizou', 'shikanoinheizou'}
            cfg = localBaseConfig('ShikanoinHeizou', customArtifact_ShikanoinHeizou(), fullfile(projectRoot, 'data', 'ShikanoinHeizou', 'rotation_ShikanoinHeizou.txt'));

        case {'yae miko', 'yae', 'yaemiko'}
            cfg = localBaseConfig('YaeMiko', customArtifact_YaeMiko(), fullfile(projectRoot, 'data', 'YaeMiko', 'rotation_YaeMiko.txt'));

        case {'arataki itto', 'itto', 'aratakiitto'}
            cfg = localBaseConfig('AratakiItto', customArtifact_AratakiItto(), fullfile(projectRoot, 'data', 'AratakiItto', 'rotation_AratakiItto.txt'));

        case {'gorou'}
            cfg = localBaseConfig('Gorou', customArtifact_Gorou(), fullfile(projectRoot, 'data', 'Gorou', 'rotation_Gorou.txt'));

        case {'xianyun', 'liuyun'}
            cfg = localBaseConfig('Xianyun', customArtifact_Xianyun(), fullfile(projectRoot, 'data', 'Xianyun', 'rotation_Xianyun.txt'));

        case {'navia'}
            cfg = localBaseConfig('Navia', customArtifact_Navia(), fullfile(projectRoot, 'data', 'Navia', 'rotation_Navia.txt'));

        case {'gaming'}
            cfg = localBaseConfig('Gaming', customArtifact_Gaming(), fullfile(projectRoot, 'data', 'Gaming', 'rotation_Gaming.txt'));

        case {'chiori'}
            cfg = localBaseConfig('Chiori', customArtifact_Chiori(), fullfile(projectRoot, 'data', 'Chiori', 'rotation_Chiori.txt'));

        case {'sigewinne'}
            cfg = localBaseConfig('Sigewinne', customArtifact_Sigewinne(), fullfile(projectRoot, 'data', 'Sigewinne', 'rotation_Sigewinne.txt'));

        case {'clorinde'}
            cfg = localBaseConfig('Clorinde', customArtifact_Clorinde(), fullfile(projectRoot, 'data', 'Clorinde', 'rotation_Clorinde.txt'));

        case {'emilie'}
            cfg = localBaseConfig('Emilie', customArtifact_Emilie(), fullfile(projectRoot, 'data', 'Emilie', 'rotation_Emilie.txt'));

        case {'kachina'}
            cfg = localBaseConfig('Kachina', customArtifact_Kachina(), fullfile(projectRoot, 'data', 'Kachina', 'rotation_Kachina.txt'));

        case {'kinich'}
            cfg = localBaseConfig('Kinich', customArtifact_Kinich(), fullfile(projectRoot, 'data', 'Kinich', 'rotation_Kinich.txt'));

        case {'sethos'}
            cfg = localBaseConfig('Sethos', customArtifact_Sethos(), fullfile(projectRoot, 'data', 'Sethos', 'rotation_Sethos.txt'));

        case {'ororon', 'olorun'}
            cfg = localBaseConfig('Ororon', customArtifact_Ororon(), fullfile(projectRoot, 'data', 'Ororon', 'rotation_Ororon.txt'));

        case {'mizuki', 'yumemizuki mizuki', 'yumemizukimizuki'}
            cfg = localBaseConfig('Mizuki', customArtifact_Mizuki(), fullfile(projectRoot, 'data', 'Mizuki', 'rotation_Mizuki.txt'));

        case {'ifa'}
            cfg = localBaseConfig('Ifa', customArtifact_Ifa(), fullfile(projectRoot, 'data', 'Ifa', 'rotation_Ifa.txt'));

        case {'dahlia'}
            cfg = localBaseConfig('Dahlia', customArtifact_Dahlia(), fullfile(projectRoot, 'data', 'Dahlia', 'rotation_Dahlia.txt'));

        case {'aino'}
            cfg = localBaseConfig('Aino', customArtifact_Aino(), fullfile(projectRoot, 'data', 'Aino', 'rotation_Aino.txt'));

        case {'jahoda'}
            cfg = localBaseConfig('Jahoda', customArtifact_Jahoda(), fullfile(projectRoot, 'data', 'Jahoda', 'rotation_Jahoda.txt'));

        case {'illuga'}
            cfg = localBaseConfig('Illuga', customArtifact_Illuga(), fullfile(projectRoot, 'data', 'Illuga', 'rotation_Illuga.txt'));

        case {'varka'}
            cfg = localBaseConfig('Varka', customArtifact_Varka(), fullfile(projectRoot, 'data', 'Varka', 'rotation_Varka.txt'));

        case {'lohen'}
            cfg = localBaseConfig('Lohen', customArtifact_Lohen(), fullfile(projectRoot, 'data', 'Lohen', 'rotation_Lohen.txt'));

        case {'prune'}
            cfg = localBaseConfig('Prune', customArtifact_Prune(), fullfile(projectRoot, 'data', 'Prune', 'rotation_Prune.txt'));

        case {'lanyan', 'lan yan'}
            cfg = localBaseConfig('LanYan', customArtifact_LanYan(), fullfile(projectRoot, 'data', 'LanYan', 'rotation_LanYan.txt'));

        otherwise
            cfg = localBuildImportedConfig(name, projectRoot);
    end

    cfg = localApplyConfigOverrides(cfg, overrides);
    cfg.Build = materializeArtifactPieceModel(cfg.Name, cfg.Build, struct());
end

function cfg = localBuildImportedConfig(name, projectRoot)
    entry = getCharacterRegistryEntry(name);
    key = string(entry.Key);
    if strlength(key) == 0
        key = string(regexprep(char(string(name)), '[^A-Za-z0-9]', ''));
    end

    if strlength(key) == 0
        error('Unsupported character in unified entry: %s', name);
    end

    build = localLoadOrBuildImportedArtifact(projectRoot, key);
    rotationFile = fullfile(projectRoot, 'data', char(key), sprintf('rotation_%s.txt', char(key)));
    cfg = localBaseConfig(char(key), build, rotationFile);
    if strlength(string(entry.DisplayName)) > 0
        cfg.DisplayName = string(entry.DisplayName);
    end
    if isfield(entry, 'Element') && strlength(string(entry.Element)) > 0
        cfg.Element = string(entry.Element);
    end
end

function build = localLoadOrBuildImportedArtifact(projectRoot, key)
    artifactPath = fullfile(projectRoot, 'data', char(key), sprintf('artifacts_%s.csv', char(key)));
    if exist(artifactPath, 'file') == 2
        try
            tbl = readtable(artifactPath, 'TextType', 'string');
            if ~isempty(tbl)
                build = table2struct(tbl(1, :), 'ToScalar', true);
                return;
            end
        catch
        end
    end

    build = buildGenericCharacterArtifact(key);
end

function cfg = localBaseConfig(displayName, build, rotationFile)
    build = materializeArtifactPieceModel(displayName, build, struct());
    cfg = struct( ...
        'Name', displayName, ...
        'DisplayName', string(displayName), ...
        'TalentLevel', 10, ...
        'Constellation', 0, ...
        'Build', build, ...
        'EnemyState', struct(), ...
        'RotationFile', rotationFile);
end

function cfg = localApplyConfigOverrides(cfg, overrides)
    if isempty(overrides)
        return;
    end

    if isfield(overrides, 'Build')
        cfg.Build = applyStructOverrides(cfg.Build, overrides.Build);
        overrides = rmfield(overrides, 'Build');
    end

    if isfield(overrides, 'Name')
        overrides = rmfield(overrides, 'Name');
    end

    cfg = applyStructOverrides(cfg, overrides);
end
