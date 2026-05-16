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

        case {'lanyan', 'lan yan', 'lanyan'}
            cfg = localBaseConfig('LanYan', customArtifact_LanYan(), fullfile(projectRoot, 'data', 'LanYan', 'rotation_LanYan.txt'));

        otherwise
            error('Unsupported character in unified entry: %s', name);
    end

    cfg = localApplyConfigOverrides(cfg, overrides);
    cfg.Build = materializeArtifactPieceModel(cfg.Name, cfg.Build, struct());
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
